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
    sealed class TotalsRateHandler : HttpMessageHandler
    {
        public int Calls;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Calls++;
            var response = new HttpResponseMessage(Calls == 1 ? HttpStatusCode.TooManyRequests : HttpStatusCode.OK) { Content = new StringContent("synthetic page") };
            if (Calls == 1) response.Headers.RetryAfter = new System.Net.Http.Headers.RetryConditionHeaderValue(TimeSpan.Zero);
            return Task.FromResult(response);
        }
    }
    public static void Run()
    {
        var rateHandler = new TotalsRateHandler();
        using (var totalsHttp = new HttpClient(rateHandler))
            Assert(AchievementTotals.ReadPageAsync(totalsHttp, "https://synthetic.invalid/achievements", CancellationToken.None).GetAwaiter().GetResult() == "synthetic page" && rateHandler.Calls == 2, "Totals retry rate limits without live HTTP");
        var pages = new Queue<string>(new[] {
            "{\"achievements\":[{\"id\":\"1\"},{\"id\":\"2\"}],\"pagingInfo\":{\"continuationToken\":\"next\"}}",
            "{\"achievements\":[{\"id\":\"2\"},{\"id\":\"3\"},{\"id\":\"4\",\"achievementType\":\"Challenge\"}]}" });
        var tokens = new List<string?>();
        var total = AchievementTotals.CountAsync(token => { tokens.Add(token); return Task.FromResult(pages.Dequeue()); }, CancellationToken.None).GetAwaiter().GetResult();
        Assert(total == 3 && tokens.SequenceEqual(new string?[] { null, "next" }), "Totals count all pages, deduplicate IDs and exclude challenges");
        try { AchievementTotals.CountAsync(_ => Task.FromResult("{\"achievements\":[],\"pagingInfo\":{\"continuationToken\":\"repeat\"}}"), CancellationToken.None).GetAwaiter().GetResult(); throw new Exception("Repeated paging should fail"); }
        catch (InvalidDataException) { }
        var missing = new LibraryGame("1", "Title", "XboxOne", 5, 0, 0);
        Assert(DesktopModel.WithKnownTotal(missing, new Dictionary<string, int> { ["1"] = 20 }).Total == 20, "Known totals repair omitted title-history counts");
        Assert(DesktopModel.WithKnownTotal(missing, new Dictionary<string, int> { ["1"] = 4 }).Total == 0, "Stale totals below earned count rejected");
        Assert(DesktopModel.WithKnownTotal(missing with { Total = 30 }, new Dictionary<string, int> { ["1"] = 20 }).Total == 30, "Fresh Xbox count takes priority");
        var notices = 0;
        var failureVm = new AutoUnlockerViewModel(new NativeNotices(_ => { }), new NativeAccountContext()) { FailureNotification = _ => notices++ };
        var failedEntry = new AutoUnlockQueueEntry { AchievementName = "Synthetic achievement" };
        Assert(!failureVm.HandleUnlockFailure(failedEntry, "synthetic failure") && notices == 1, "Default notifies and continues");
        failureVm.NotifyOnFailure = false; failureVm.StopOnFailure = true;
        Assert(failureVm.HandleUnlockFailure(failedEntry, "synthetic failure") && notices == 1 && failureVm.StatusText.Contains("Click Start to retry"), "Stopping is independent of notification toggle");
        var statePath = AutoUnlockState.GetSavePath();
        var backup = File.Exists(statePath) ? File.ReadAllBytes(statePath) : null;
        try
        {
            var saveState = new AutoUnlockState { GameName = "Synthetic game", Queue = new() { new() { DelaySeconds = 123 } } };
            typeof(AutoUnlockerViewModel).GetField("_state", BindingFlags.Instance | BindingFlags.NonPublic)!.SetValue(failureVm, saveState);
            failureVm.SaveQueue();
            var saved = AutoUnlockState.Load()!;
            Assert(saved.Queue.Single().DelaySeconds == 123 && saved.StopOnFailure && !saved.NotifyOnFailure && !saved.IsRunning, "Manual save preserves delays and failure options");
            failureVm.IsRunning = true;
            saveState.Queue[0].DelaySeconds = 456;
            failureVm.SaveQueue();
            Assert(AutoUnlockState.Load()!.Queue.Single().DelaySeconds == 123, "Manual save cannot overwrite a running queue");
            failureVm.IsRunning = false;
            var pendingIndex = saveState.CurrentIndex;
            Assert(failureVm.HandleUnlockFailure(saveState.Queue[0], "synthetic failure") && saveState.CurrentIndex == pendingIndex && !saveState.Queue[0].Completed, "Stop failure preserves pending achievement for retry");
        }
        finally { if (backup == null) File.Delete(statePath); else File.WriteAllBytes(statePath, backup); }
        var settings = Newtonsoft.Json.JsonConvert.DeserializeObject<AutoUnlockState>("{}")!;
        Assert(settings.NotifyOnFailure && !settings.StopOnFailure, "Old saved queues keep safe compatible failure defaults");
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
        Assert(model.CanStartPresence && model.CanLookupSpoofTitle && model.CanFillTotals && !model.CanQuery && !model.CanDisconnect, "Queue allows spoofing but still protects disconnect");
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
