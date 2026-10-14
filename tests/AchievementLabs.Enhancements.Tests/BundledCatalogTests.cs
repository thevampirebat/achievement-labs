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
    sealed class UpstreamFixture : HttpMessageHandler
    {
        public List<string> Paths = [];
        public bool Fail;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Paths.Add(request.RequestUri!.AbsolutePath);
            var json = request.Method == HttpMethod.Get ? "{\"achievementIds\":[\"69\"]}" : "{\"payloads\":[\"fixture-payload\"]}";
            return Task.FromResult(new HttpResponseMessage(Fail ? HttpStatusCode.ServiceUnavailable : HttpStatusCode.OK) { Content = new StringContent(json) });
        }
    }
    public static void Run()
    {
        WindowPlacementTests.Run();
        UpstreamEventCatalogueTests.Run();
        using var client = new EventCatalogClient(useBundledCatalog: true);
        var handler = new NoNetwork();
        typeof(EventCatalogClient).GetField("http", BindingFlags.Instance | BindingFlags.NonPublic)!.SetValue(client, new HttpClient(handler));
        var status = client.GetCatalogAsync(CancellationToken.None).GetAwaiter().GetResult();
        var titles = status.TitleIds.Concat(status.TestingTitleIds ?? []).Distinct().ToArray();
        Assert(titles.Length == 410 && titles.Contains("60633334"), "New snapshot exposes 410 enabled titles including 7 Days to Die");
        Assert(status.TitleIds.Length == 263 && status.TestingTitleIds!.Length == 147 && status.ComingSoonTitleIds.Length == 3, "Published 1.0.6 classifications retained");
        Assert(status.TestingTitleIds.Contains("60633334") && status.TestingTitleIds.Contains("1745806870"), "Both mapped 7 Days editions labelled Testing");
        Assert(!client.BundledTitleIds.Contains("136671143") && status.TitleIds.Contains("136671143"), "Public-only recipes remain on catalogue-service fallback");
        int achievements = 0, payloads = 0;
        foreach (var titleId in client.BundledTitleIds)
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
        // Exclude exactly the 123 recipes deliberately routed back to upstream.
        Assert(!client.BundledTitleIds.Contains("345903534") && client.BundledTitleIds.Contains("1828326430"), "Only legacy Minecraft leaves the local route");
        Assert(achievements >= 15725 - 123 && payloads >= achievements, "Remaining enabled catalogue validated after the explicit 123-recipe exclusion");
        var sonic = client.GetTitleAsync("129325438", CancellationToken.None).GetAwaiter().GetResult();
        Assert(sonic.AchievementIds.Length == 48, "Previously validated Sonic Forces recipes retained");
        DishonoredMappingTests.Run(client);
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
        using (var remote = new EventCatalogClient(true)) {
            var fixture = new UpstreamFixture();
            typeof(EventCatalogClient).GetField("http", BindingFlags.Instance | BindingFlags.NonPublic)!.SetValue(remote,
                new HttpClient(fixture) { BaseAddress = new Uri("https://fixture.invalid/api/licensing/") });
            var remoteIds = remote.GetTitleAsync("345903534", default).GetAwaiter().GetResult();
            Assert(remoteIds.AchievementIds.SequenceEqual(new[]{"69"}), "Cupid mapping comes from upstream fixture");
            var remotePayload = remote.GetPayloadsAsync("345903534", "69", "0", default).GetAwaiter().GetResult();
            Assert(remotePayload.Payloads.SequenceEqual(new[]{"fixture-payload"}) && fixture.Paths.Count == 2
                && fixture.Paths[1].EndsWith("/titles/345903534/payloads"), "Legacy payload uses upstream route");
            fixture.Fail = true; blocked = false;
            try { remote.GetPayloadsAsync("345903534", "69", "0", default).GetAwaiter().GetResult(); }
            catch (HttpRequestException) { blocked = true; }
            Assert(blocked && fixture.Paths.Count == 3, "Unavailable upstream fails without borrowed bundled fallback");
        }
        Console.WriteLine($"PASS: bundled 1.0.6 catalogue: {titles.Length} advertised titles, {client.BundledTitleIds.Length} local titles, {achievements} usable achievements and {payloads} strict-JSON payloads; edition guards, invalid-entry rejection and 43 7 Days to Die mappings. No live requests.");
    }
}
