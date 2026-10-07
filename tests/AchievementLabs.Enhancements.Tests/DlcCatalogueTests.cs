using AchievementLabs.MultiSelect;
using System.Net;

public static class DlcCatalogueTests
{
    static void Assert(bool value, string message) { if (!value) throw new Exception(message); }
    const string Sample = """
        {"schemaVersion":1,"titles":[{"titleId":"42","platforms":["XboxOne"],"source":"https://example.com/verified",
          "packs":[{"name":"Base game","kind":"base","achievements":[{"id":"1","name":"First"}]},
                   {"name":"Expansion","kind":"dlc","achievements":[{"id":"9","name":"Last"}]}]}]}
        """;
    sealed class Handler(string body) : HttpMessageHandler
    {
        public int Calls;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Calls++;
            Assert(request.Method == HttpMethod.Get && request.RequestUri == SharedDlcCatalogue.PublishedUri, "Public metadata GET only");
            Assert(request.Headers.Authorization == null, "No account token sent");
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(body) });
        }
    }
    public static void Run()
    {
        var catalogue = SharedDlcCatalogue.Bundled();
        var ghosts = catalogue.Find("572802557", "XboxOne")!;
        Assert(ghosts.Packs.Select(p => p.Achievements.Length).SequenceEqual(new[] { 50,11,10,10,10 }), "All verified Ghosts packs retained");
        Assert(SharedDlcCatalogue.Group(ghosts,"92","Hat-Trick") == "Nemesis", "Punctuation preserved with exact ID");
        Assert(SharedDlcCatalogue.Group(ghosts,"91","Hat Trick") == "Unclassified", "Shifted ID not guessed");
        Assert(catalogue.Find("572802557", "PC") == null, "Wrong edition not matched");
        catalogue.Merge(Sample);
        SharedDlcCatalogue.Current.Merge(Sample);
        var game = new { Id="42", Platform="XboxOne" };
        var rows = new[] { new {Id="9",Name="Last"}, new {Id="1",Name="First"} };
        Assert(AchievementView.Arrange(rows,true,1,"Expansion",game).Length == 1, "Generic pack filter works in achievement view");
        var title = catalogue.Find("42", "XboxOne / XboxSeries")!;
        Assert(SharedDlcCatalogue.Group(title,"9","Last") == "Expansion", "Generic DLC title mapped");
        Assert(catalogue.Find("43", "XboxOne") == null, "Exact Title ID required");
        try { catalogue.Merge(Sample.Replace("\"id\":\"9\"", "\"id\":\"1\"")); throw new Exception("Expected invalid map"); }
        catch (InvalidDataException) { }
        Assert(SharedDlcCatalogue.Group(catalogue.Find("42","XboxOne")!,"9","Last") == "Expansion", "Invalid update leaves prior mappings intact");
        var cache = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"), "packs.json");
        try
        {
            var handler = new Handler(Sample); using var http = new HttpClient(handler);
            catalogue.RefreshAsync(http,cache,CancellationToken.None).GetAwaiter().GetResult();
            catalogue.RefreshAsync(http,cache,CancellationToken.None).GetAwaiter().GetResult();
            Assert(handler.Calls == 1, "Recent cache avoids repeat network requests");
            var invalid = new Handler("{}"); using var invalidHttp = new HttpClient(invalid);
            catalogue.RefreshAsync(invalidHttp,cache,CancellationToken.None,true).GetAwaiter().GetResult();
            Assert(catalogue.Find("42","XboxOne") != null, "Malformed response keeps cached mapping");
        }
        finally { if (Directory.Exists(Path.GetDirectoryName(cache))) Directory.Delete(Path.GetDirectoryName(cache)!,true); }
        Console.WriteLine("PASS: Verified DLC groups, edition and ID guards, atomic invalid-update rejection, unauthenticated public reads and offline cache.");
    }
}
