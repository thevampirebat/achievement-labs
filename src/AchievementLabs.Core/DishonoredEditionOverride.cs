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
            corrected.Add(xboxId, recipe.DeepClone());
            names.Add(xboxId, entry["name"]!.DeepClone());
        }
        xbox["Achievements"] = corrected;
        xbox["AchievementNames"] = names;
        xbox["ResearchStatus"] = "80 name-matched Xbox One IDs; 74 existing recipes retained and six PC-backed candidates added. Console achievement credit requires live verification.";
        return true;
    }
}
