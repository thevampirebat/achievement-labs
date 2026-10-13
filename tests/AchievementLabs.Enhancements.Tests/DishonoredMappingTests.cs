using System.IO.Compression;
using System.Reflection;
using System.Text.Json;
using AchievementLabs.Core;
using Newtonsoft.Json.Linq;

public static class DishonoredMappingTests
{
    static void Assert(bool value, string message) { if (!value) throw new Exception(message); }
    public static void Run(EventCatalogClient client)
    {
        const string xbox = "1100121502", pc = "1627819535", scid = "88940100-b0a6-495b-9f60-d06b4192859e";
        var ids = Enumerable.Range(4, 50).Concat(Enumerable.Range(57, 30)).Select(i => i.ToString()).ToArray();
        var actual = client.GetTitleAsync(xbox, default).GetAwaiter().GetResult();
        Assert(actual.AchievementIds.Length == 80 && actual.AchievementIds.ToHashSet().SetEquals(ids), "All 80 exact Xbox IDs restored, without filling nonexistent gaps");
        var pairs = new Dictionary<string,string> { ["4"]="Thief", ["7"]="Shadow", ["10"]="Rogue", ["57"]="DLC05MrsPilsensRemorse",
            ["60"]="DLC05NaturalTalent", ["61"]="DLC05ByMyHandOnly", ["62"]="DLC05Daredevil",
            ["63"]="DLC05Headhunter", ["65"]="DLC05TimeManager", ["67"]="DLC06JustBusiness", ["81"]="DLC07Reprieve", ["82"]="DLC07SilenceIsGolden",
            ["83"]="DLC07CleanestHands", ["84"]="DLC07EnoughCoinsToDisappear", ["85"]="DLC07PartingShot", ["86"]="DLC07WallOfFlesh" };
        using var groupStream = typeof(AchievementLabs.MultiSelect.EditionMapping).Assembly.GetManifestResourceStream("AchievementLabs.SharedPacks.json")!;
        using var groups = JsonDocument.Parse(groupStream);
        var titles = groups.RootElement.GetProperty("titles").EnumerateArray().ToArray();
        Dictionary<string,string> Names(string title) => titles.Single(t => t.GetProperty("titleId").GetString()==title)
            .GetProperty("packs").EnumerateArray().SelectMany(pack => pack.GetProperty("achievements").EnumerateArray())
            .ToDictionary(a => a.GetProperty("id").GetString()!, a => a.GetProperty("name").GetString()!);
        var xboxNames=Names(xbox); var pcNames=Names(pc);
        var pcByName=pcNames.ToDictionary(a => a.Value, a => a.Key);
        Assert(xboxNames.Count==80 && pcByName.Count==80, "Complete unique edition names provide independent identity check");
        foreach (var id in ids)
        {
            var response = client.GetPayloadsAsync(xbox, id, "0", default).GetAwaiter().GetResult();
            var namedPcId=pcByName[xboxNames[id]];
            var expected=client.GetPayloadsAsync(pc, namedPcId, "0", default).GetAwaiter().GetResult();
            bool consoleCandidate = id is "61" or "65";
            Assert(response.Payloads.Length==(consoleCandidate ? 1 : expected.Payloads.Length),
                "Two console candidates isolate existing direct criteria; unrelated variants remain unchanged");
            if (consoleCandidate)
            {
                using var candidate = JsonDocument.Parse(response.Payloads[0]);
                Assert(candidate.RootElement.GetProperty("ext").GetProperty("app").GetProperty("asId").GetInt32()==778,
                    "Trial candidates preserve the console application context that worked for Headhunter");
                Assert(candidate.RootElement.GetProperty("data").GetProperty("baseData").GetProperty("name").GetString()=="AchievementShouldUnlock",
                    "Candidates send only a direct achievement event using package-derived names");
            }
            for (int index=0;index<response.Payloads.Length;index++)
            {
                using var consoleEvent=JsonDocument.Parse(response.Payloads[index]);
                using var pcEvent=JsonDocument.Parse(expected.Payloads[index]);
                var consoleBody=consoleEvent.RootElement.GetProperty("data").GetProperty("baseData");
                var pcBody=pcEvent.RootElement.GetProperty("data").GetProperty("baseData");
                Assert((consoleCandidate
                    ? consoleBody.GetProperty("properties").EnumerateObject().Count()==1
                    : JsonElement.DeepEquals(consoleBody.GetProperty("properties"), pcBody.GetProperty("properties")))
                    && consoleBody.GetProperty("name").GetString()==pcBody.GetProperty("name").GetString(),
                    "Unrelated payload values match the named PC achievement; candidate names are checked against package evidence");
            }
            foreach (var text in response.Payloads)
            {
                using var doc = JsonDocument.Parse(text);
                var root = doc.RootElement; var body = root.GetProperty("data").GetProperty("baseData");
                if (body.GetProperty("name").GetString() is "DunwallTrial" or "CityTrialStars")
                {
                    var schema = root.GetProperty("ext").GetProperty("metadata").GetProperty("f")
                        .GetProperty("baseData").GetProperty("f").GetProperty("properties").GetProperty("f");
                    foreach (var field in body.GetProperty("properties").EnumerateObject().Where(p => p.Value.ValueKind==JsonValueKind.Number))
                        Assert(schema.GetProperty(field.Name).GetInt32()==4, "Numeric trial fields retain catalogue metadata types");
                }
                Assert(body.GetProperty("titleId").ToString()==xbox && body.GetProperty("serviceConfigId").GetString()==scid,
                    "Xbox title/SCID preserved in every request");
                Assert(root.GetProperty("name").GetString()!.StartsWith("Microsoft.XboxLive.T"+xbox+"."), "Xbox event namespace retained");
                Assert(!text.Contains("Microsoft.XboxLive.T"+pc) && !text.Contains("00000000-0000-0000-0000-000061068e0f"), "PC identity never sent for console");
            }
            if (pairs.TryGetValue(id, out var criterion))
            {
                using var first = JsonDocument.Parse(response.Payloads[0]);
                Assert(first.RootElement.GetProperty("data").GetProperty("baseData").GetProperty("properties").GetProperty("AchievementName").GetString()==criterion,
                    "Named achievement receives its reviewed event criterion");
            }
        }
        var pcPayload = client.GetPayloadsAsync(pc, "1", "0", default).GetAwaiter().GetResult();
        using (var first = JsonDocument.Parse(pcPayload.Payloads[0]))
            Assert(first.RootElement.GetProperty("data").GetProperty("baseData").GetProperty("titleId").ToString()==pc, "PC mapping retains its own identity");
        using var stream = typeof(EventCatalogClient).Assembly.GetManifestResourceStream("AchievementLabs.EventCatalog.1.0.6.zip")!;
        using var zip = new ZipArchive(stream);
        string Read(string name) { using var reader = new StreamReader(zip.GetEntry(name)!.Open()); return reader.ReadToEnd(); }
        var raw = JObject.Parse(Read("Data.json"));
        var template = Read(xbox+".json");
        var apply = typeof(EventCatalogClient).Assembly.GetType("AchievementLabs.Core.DishonoredEditionOverride")!
            .GetMethod("Apply", BindingFlags.Static|BindingFlags.NonPublic)!;
        bool Apply(JObject data, string input) => (bool)apply.Invoke(null, new object[] { data, new Dictionary<string,string> { [xbox]=input } })!;
        var unchangedPc = raw[pc]!.DeepClone(); var unchangedOther = raw["60633334"]!.DeepClone();
        Assert(Apply(raw, template) && JToken.DeepEquals(raw[pc], unchangedPc) && JToken.DeepEquals(raw["60633334"], unchangedOther), "Override leaves PC and unrelated titles unchanged");
        foreach (var id in new[] { "61", "65" })
        {
            var operations = (JObject)raw[xbox]!["Achievements"]![id]!;
            Assert(operations.Properties().Count()==1 && operations["CriteriaReplacement"] != null,
                "Candidate contains no application-ID change or speculative stat events");
        }
        using (var working = JsonDocument.Parse(client.GetPayloadsAsync(xbox, "63", "0", default).GetAwaiter().GetResult().Payloads.Single()))
            Assert(working.RootElement.GetProperty("ext").GetProperty("app").GetProperty("asId").GetInt32()==778,
                "Known working Headhunter recipe is unchanged");
        Assert(raw.Properties().Last().Name=="SupportedTitleIDs", "Data.json ordering survives in-memory override");
        foreach (var scenario in new[] { "pc", "xbox", "template" })
        {
            var changed = JObject.Parse(Read("Data.json"));
            if (scenario=="pc") changed[pc]!["Achievements"]!["1"]!["CriteriaReplacement"]!["Replacement"]="WrongCriterion";
            if (scenario=="xbox") changed[xbox]!["Achievements"]!["7"]!["CriteriaReplacement"]!["Replacement"]="WrongCriterion";
            Assert(!Apply(changed, scenario=="template" ? template.Replace(xbox,"9999999999") : template)
                && !((JObject)changed[xbox]!["Achievements"]!).Properties().Any(), "Changed catalogue/template refuses all mappings for this edition");
        }
        Console.WriteLine("PASS: 80 Dishonored Xbox identity mappings, six PC-backed recipes, exact payload criteria and trial metadata schemas, edition isolation and changed-input refusal. No live requests.");
    }
}
