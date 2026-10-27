using AchievementLabs.Core;
using AchievementLabs.MultiSelect;
using System.Text.Json;

public static class LocalCatalogueIntegrationTests
{
    static void Assert(bool value, string message) { if (!value) throw new Exception(message); }
    public static void CheckUnapprovedMappings()
    {
        // Match the reviewed mapping inventory already shipped by this fork; do not disable it during unrelated queue work.
        foreach (var id in new[] { "796798669", "2154930", "125965001" })
            Assert(EditionMapping.Supports(id), "Previously reviewed edition mapping retained: " + id);
        foreach (var id in new[] { "907086072", "527255540", "1766089184", "515050978" })
            Assert(!EditionMapping.Supports(id), "Unapproved edition mapping is disabled: " + id);
        Console.WriteLine("PASS: reviewed edition inventory retained and unapproved mappings disabled.");
    }
    public static void Run()
    {
        CheckUnapprovedMappings(); WindowPlacementTests.Run(); UpstreamEventCatalogueTests.Run();
        using var client = new EventCatalogClient(true);
        foreach (var id in new[] { "1079518187", "1147540192", "1327376519", "136671143", "767263759" })
            Assert(client.BundledTitleIds.Contains(id), "Author-only local title retained: " + id);
        Assert(!client.BundledTitleIds.Contains("345903534"), "Legacy Minecraft is routed to the original service.");
        var ghosts = client.GetTitleAsync("572802557", default).GetAwaiter().GetResult();
        Assert(ghosts.AchievementIds.Length == 91 && !ghosts.AchievementIds.Contains("51") && ghosts.AchievementIds.Contains("92"), "All corrected Ghosts Xbox IDs retained.");
        DishonoredMappingTests.Run(client);
        int count=0, bodies=0;
        foreach (var title in client.BundledTitleIds)
        {
            var mapping=client.GetTitleAsync(title,default).GetAwaiter().GetResult();
            foreach(var id in mapping.AchievementIds)
            {
                foreach(var text in client.GetPayloadsAsync(title,id,"0",default).GetAwaiter().GetResult().Payloads)
                {
                    using var doc=JsonDocument.Parse(text);
                    Assert(doc.RootElement.GetProperty("data").GetProperty("baseData").GetProperty("titleId").ToString()==title,"Correct title in every usable local payload.");
                    bodies++;
                }
                count++;
            }
        }
        Console.WriteLine($"PASS: author-maintained catalogue, {client.BundledTitleIds.Length} local routes, {count} usable recipes, {bodies} strict JSON payloads. No live requests.");
    }
}
