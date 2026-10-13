using System.Security.Cryptography;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace AchievementLabs.Core;

// Reviewed by exact achievement names and full recipe equality, never list position.
internal static class DishonoredEditionOverride
{
    private static string Hash(string text) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text))).ToLowerInvariant();
    internal static bool Apply(JObject data, IReadOnlyDictionary<string, string> templates)
    {
        const string title = "1100121502", source = "1627819535";
        if (data[title] is not JObject xbox) return false;
        using var stream = typeof(DishonoredEditionOverride).Assembly.GetManifestResourceStream("AchievementLabs.DishonoredEditionOverride.json")
            ?? throw new InvalidDataException("Dishonored edition mapping is missing.");
        using var reader = new StreamReader(stream);
        var review = JObject.Parse(reader.ReadToEnd());
        var original = xbox["Achievements"] as JObject;
        var pc = data[source]?["Achievements"] as JObject;
        bool valid = original != null && pc != null && templates.TryGetValue(title, out var template)
            && Hash(original.ToString(Formatting.None)) == (string?)review["expectedXboxRecipesSha256"]
            && Hash(pc.ToString(Formatting.None)) == (string?)review["expectedPcRecipesSha256"]
            && Hash(template) == (string?)review["expectedXboxTemplateSha256"]
            && (string?)xbox["ServiceConfigId"] == (string?)review["serviceConfigId"]
            && (string?)review["titleId"] == title && (string?)review["sourceTitleId"] == source;
        if (!valid)
        {
            // Keep other titles usable, and refuse this edition rather than guessing new IDs.
            xbox["Achievements"] = new JObject();
            xbox["ResearchStatus"] = "Catalogue differs from the reviewed Dishonored edition mapping; remap review required.";
            return false;
        }
        var entries = (JArray)review["entries"]!;
        if (entries.Count != 80 || entries.Select(e => (string)e["xboxId"]!).Distinct().Count() != 80
            || entries.Select(e => (string)e["pcId"]!).Distinct().Count() != 80
            || entries.Select(e => (string)e["name"]!).Distinct().Count() != 80)
            throw new InvalidDataException("Dishonored identity mapping is incomplete or ambiguous.");
        var corrected = new JObject();
        var names = new JObject();
        foreach (var entry in entries)
        {
            var xboxId = (string)entry["xboxId"]!;
            var pcId = (string)entry["pcId"]!;
            var recipe = pc![pcId] ?? throw new InvalidDataException("Dishonored source recipe is missing.");
            if (entry["previousCatalogId"]?.Type == JTokenType.String
                && !JToken.DeepEquals(original![(string)entry["previousCatalogId"]!], recipe))
                throw new InvalidDataException("Dishonored existing recipe changed.");
            var copy = (JObject)recipe.DeepClone();
            if (xboxId is "61" or "65")
            {
                // Console candidate: Headhunter succeeded using the pinned template's asId 778.
                // These two recipes instead force 11858 in every PC-derived variant.
                // The uploaded PC package identifies ByMyHandOnly and TimeManager, not the catalogue names.
                // Converting those enum suffixes to collector criteria remains a console hypothesis.
                var direct = copy["Request1"]?["CriteriaReplacement"] as JObject
                    ?? throw new InvalidDataException("Dishonored direct trial criterion is missing.");
                var candidate = (JObject)direct.DeepClone();
                candidate["Replacement"] = xboxId == "61" ? "DLC05ByMyHandOnly" : "DLC05TimeManager";
                copy = new JObject { ["CriteriaReplacement"] = candidate };
            }
            // The reviewed recipes contain CRLF metadata blocks; the pinned Xbox template uses LF.
            // Repair this edition only, retaining the original schema and event/stat values.
            foreach (var property in copy.Descendants().OfType<JProperty>().Where(p => p.Name == "MetadataSchemaReplacement"))
            {
                var operation = (JObject)property.Value;
                var target = ((string)operation["Target"]!).Replace("\r\n", "\n");
                if (!templates[title].Contains(target, StringComparison.Ordinal))
                    throw new InvalidDataException("Dishonored metadata replacement does not match its reviewed template.");
                operation["Target"] = target;
                operation["Replacement"] = ((string)operation["Replacement"]!).Replace("\r\n", "\n");
            }
            corrected.Add(xboxId, copy);
            names.Add(xboxId, entry["name"]!.DeepClone());
        }
        xbox["Achievements"] = corrected;
        xbox["AchievementNames"] = names;
        xbox["ResearchStatus"] = "80 name-matched Xbox One IDs; 74 existing recipes retained and six PC-backed candidates added. Console achievement credit requires live verification.";
        return true;
    }
}
