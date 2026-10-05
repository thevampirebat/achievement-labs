using System.Net;
using System.Reflection;
using System.Text.Json;
using AchievementLabs.Desktop;
using AchievementLabs.Core;
using AchievementLabs.Desktop.Workflows;
using AchievementLabs.Models;
using AchievementLabs.MultiSelect;
using LibraryGame = AchievementLabs.Desktop.Game;

public static class QueuePresenceTokenTests
{
    static void Assert(bool ok, string message) { if (!ok) throw new Exception(message); }
    sealed class ExchangeHandler(string identity = "123", string eventHash = "hash", bool expired = false) : HttpMessageHandler
    {
        public int Calls;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Calls++;
            using var body = JsonDocument.Parse(await request.Content!.ReadAsStringAsync(ct));
            var root = body.RootElement;
            string json;
            if (Calls == 1)
            {
                Assert(request.RequestUri!.Host == "device.auth.xboxlive.com" && request.Headers.Contains("Signature"), "Device exchange is signed");
                Assert(root.GetProperty("Properties").GetProperty("ProofKey").GetProperty("alg").GetString() == "ES256", "Device proof key");
                json = "{\"Token\":\"fake-device\"}";
            }
            else if (Calls == 2) json = "{\"Token\":\"fake-user\"}";
            else
            {
                Assert(root.GetProperty("Properties").GetProperty("DeviceToken").GetString() == "fake-device", "Both XSTS requests carry the device token");
                Assert(root.GetProperty("RelyingParty").GetString() == (Calls == 3 ? "http://xboxlive.com" : "http://events.xboxlive.com"), "Identity is verified before events exchange");
                json = JsonSerializer.Serialize(new { Token = "fake-event", NotAfter = DateTimeOffset.UtcNow.AddHours(expired ? -1 : 1), DisplayClaims = new { xui = new[] { new { xid = identity, uhs = Calls == 3 ? "hash" : eventHash } } } });
            }
            return new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(json) };
        }
    }
    public static void Run()
    {
        var sortPath = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"), "sort.txt");
        try
        {
            Assert(LibrarySortPreferences.Load(sortPath) == "A-Z", "Default library sort");
            LibrarySortPreferences.Save(sortPath, "Last Played");
            Assert(LibrarySortPreferences.Load(sortPath) == "Last Played", "Library sort survives reload");
            File.WriteAllText(sortPath, "invalid");
            Assert(LibrarySortPreferences.Load(sortPath) == "A-Z", "Unknown saved sort falls back safely");
        }
        finally { Directory.Delete(Path.GetDirectoryName(sortPath)!, true); }
        var state = new AutoUnlockState { CurrentIndex = 1, RemainingDelaySeconds = 30, Queue = new() {
            new() { Completed = true, DelaySeconds = 1000 }, new() { DelaySeconds = 60 },
            new() { Completed = true, DelaySeconds = 999 }, new() { DelaySeconds = 90 } } };
        Assert(AutoUnlockerViewModel.EstimateRemaining(state, 2) == TimeSpan.FromSeconds(60), "ETA uses saved remaining delay, speed and pending entries");
        state.CurrentIndex = 4;
        Assert(AutoUnlockerViewModel.EstimateRemaining(state, 1) == TimeSpan.Zero, "Finished queue has no remaining time");
        var visited = new List<int>();
        var matching = WamEventTokens.FindMatchingAccountAsync(new[] { 1, 2, 3, 4 }, id => {
            visited.Add(id);
            if (id == 1 || id == 3) throw new InvalidDataException("wrong Xbox account");
            return Task.FromResult(id == 4 ? new AutomaticEventToken.Grant("synthetic", DateTimeOffset.UtcNow.AddHours(1)) : null);
        }, CancellationToken.None).GetAwaiter().GetResult();
        Assert(matching?.Value == "synthetic" && visited.SequenceEqual(new[] { 1, 2, 3, 4 }), "Four Windows accounts choose only the verified matching Xbox identity");
        var cancelled = new CancellationToken(true);
        try { WamEventTokens.FindMatchingAccountAsync(new[] { 1 }, _ => Task.FromResult<AutomaticEventToken.Grant?>(null), cancelled).GetAwaiter().GetResult(); throw new Exception("Cancellation expected"); }
        catch (OperationCanceledException) { }
        using var model = new DesktopModel();
        var flags = BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public;
        typeof(DesktopModel).GetProperty("Games")!.SetValue(model, new[] {
            new LibraryGame("1", "Zulu", "XboxOne", 0, 1, 0, LastPlayed: DateTime.UtcNow),
            new LibraryGame("2", "Alpha", "PC", 0, 1, 0),
            new LibraryGame("3", "Bravo", "XboxOne", 0, 1, 0, LastPlayed: DateTime.UtcNow.AddDays(-1)) });
        Assert(model.VisibleGames.Select(g => g.Id).SequenceEqual(new[] { "2", "3", "1" }), "A-Z");
        model.LibrarySort = "Z-A";
        Assert(model.VisibleGames.First().Id == "1", "Z-A");
        model.LibrarySort = "Last Played";
        Assert(model.VisibleGames.Select(g => g.Id).SequenceEqual(new[] { "1", "3", "2" }), "Last Played puts missing dates last");
        var refreshed = model.Games.Select(g => g with { Name = g.Name + " refreshed" }).ToArray();
        model.SelectedLibraryGame = model.Games.Single(g => g.Id == "3");
        typeof(DesktopModel).GetProperty("Games")!.SetValue(model, refreshed);
        Assert(model.SelectedLibraryGame?.Id == "3" && model.SelectedLibraryGame.Name.EndsWith("refreshed"), "Refresh preserves selected title using the new record");
        model.SelectedLibraryGame = null;
        typeof(DesktopModel).GetProperty("Games")!.SetValue(model, refreshed);
        Assert(model.SelectedLibraryGame?.Id == "1", "No selection chooses first game in active sort, not A-Z backing array");
        model.PlatformFilter = "Xbox One/Series";
        Assert(model.VisibleGames.Count() == 2, "Sort retains platform filter");
        typeof(DesktopModel).GetField("session", flags)!.SetValue(model, new ConnectedXboxSession("synthetic", "123", ""));
        typeof(DesktopModel).GetProperty("QueueActive")!.SetValue(model, true);
        Assert(model.CanStartPresence && model.CanLookupSpoofTitle && !model.CanQuery && !model.CanDisconnect, "Queue allows spoofing but still protects disconnect");
        var row = new AutoUnlockerViewModel.AutoUnlockQueueDisplay { Status = "Unlocked", CanEditDelay = true };
        model.XboxQueue.QueueItems.Add(row);
        model.XboxQueue.IsRunning = true;
        Assert(row.RowBackground == "#245C38" && !row.CanEditDelay, "Completed rows green and delay editing disabled during run");
        model.XboxQueue.ExternalPresenceActive = () => true;
        // No API is configured: this succeeds only if the queue preserves external presence.
        var task = (Task)typeof(AutoUnlockerViewModel).GetMethod("UpdatePresenceAsync", flags)!.Invoke(model.XboxQueue, new object[] { true })!;
        task.GetAwaiter().GetResult();
        model.XboxQueue.IsRunning = false;
        Assert(row.CanEditDelay, "Delay editing restored when stopped");
        foreach (var scenario in new[] { "valid", "account", "hash", "expiry" })
        {
            var handler = new ExchangeHandler(scenario == "account" ? "999" : "123", scenario == "hash" ? "wrong" : "hash", scenario == "expiry");
            using var http = new HttpClient(handler);
            try
            {
                var grant = WamEventTokens.ExchangeAsync(http, "fake-msa", "123", CancellationToken.None).GetAwaiter().GetResult();
                Assert(scenario == "valid" ? grant?.Value == "x:XBL3.0 x=hash;fake-event" && handler.Calls == 4 : scenario == "expiry" && grant == null, "Reject invalid token claims and expiry");
            }
            catch (InvalidDataException) { Assert(scenario is "account" or "hash", "Only mismatch scenarios throw"); if (scenario == "account") Assert(handler.Calls == 3, "Wrong account rejected before requesting event token"); }
        }
        Console.WriteLine("PASS: library ordering, concurrent presence gates, queue row state and device-bound token exchange. Synthetic requests only.");
    }
}
