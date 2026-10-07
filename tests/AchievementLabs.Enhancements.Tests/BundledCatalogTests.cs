using System.Net;
using System.Reflection;
using System.Text.Json;
using AchievementLabs.Core;

public static class BundledCatalogTests
{
    static void Assert(bool condition, string message) { if (!condition) throw new Exception(message); }
    sealed class NoNetwork : HttpMessageHandler
    {
        public int Calls;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        { Calls++; throw new Exception("Bundled catalogue must not access the network."); }
    }
    public static void Run()
    {
        using var client = new EventCatalogClient(useBundledCatalog: true);
        var handler = new NoNetwork();
        typeof(EventCatalogClient).GetField("http", BindingFlags.Instance | BindingFlags.NonPublic)!.SetValue(client, new HttpClient(handler));
        var status = client.GetCatalogAsync(CancellationToken.None).GetAwaiter().GetResult();
        var titles = status.TitleIds.Concat(status.TestingTitleIds ?? []).Distinct().ToArray();
        Assert(titles.Length == 397 && titles.Contains("60633334"), "New snapshot exposes 397 enabled titles including 7 Days to Die");
        int achievements = 0, payloads = 0;
        foreach (var titleId in titles)
        {
            var mapping = client.GetTitleAsync(titleId, CancellationToken.None).GetAwaiter().GetResult();
            foreach (var id in mapping.AchievementIds)
            {
                var result = client.GetPayloadsAsync(titleId, id, "123456789", CancellationToken.None).GetAwaiter().GetResult();
                Assert(result.Payloads.Length > 0, "Nonempty mapped payloads");
                foreach (var text in result.Payloads)
                {
                    using var doc = JsonDocument.Parse(text);
                    var body = doc.RootElement.GetProperty("data").GetProperty("baseData");
                    Assert(body.GetProperty("titleId").ToString() == titleId, "Payload belongs to selected title");
                    Assert(!text.Contains("REPLACE"), "All transport and event placeholders resolved");
                    payloads++;
                }
                achievements++;
            }
        }
        Assert(achievements > 15000 && payloads >= achievements, "Full enabled catalogue validated");
        var sevenDays = client.GetTitleAsync("60633334", CancellationToken.None).GetAwaiter().GetResult();
        Assert(sevenDays.AchievementIds.Length == 43, "All 43 Xbox One 7 Days to Die mappings available");
        var quantum = client.GetTitleAsync("333628240", CancellationToken.None).GetAwaiter().GetResult();
        Assert(!quantum.AchievementIds.Contains("10"), "Incomplete incoming recipe remains unavailable");
        bool blocked = false;
        try { client.GetPayloadsAsync("333628240", "10", "123456789", CancellationToken.None).GetAwaiter().GetResult(); }
        catch (InvalidDataException) { blocked = true; }
        Assert(blocked, "Direct requests cannot bypass recipe validation");
        using var cancel = new CancellationTokenSource(); cancel.Cancel(); blocked = false;
        try { client.GetTitleAsync("60633334", cancel.Token).GetAwaiter().GetResult(); }
        catch (OperationCanceledException) { blocked = true; }
        Assert(blocked && handler.Calls == 0, "Cancellation respected and no network requests made");
        Console.WriteLine($"PASS: bundled 1.0.5 catalogue: {titles.Length} titles, {achievements} usable achievements and {payloads} strict-JSON payloads; edition guards, invalid-entry rejection and 43 7 Days to Die mappings. No live requests.");
    }
}
