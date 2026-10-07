using System.IO.Compression;
using System.Collections.Concurrent;
using Newtonsoft.Json.Linq;

namespace AchievementLabs.Core;

/// <summary>The uploaded public 1.0.5 catalogue, kept separate from account data.</summary>
internal sealed class BundledEventCatalog
{
    private static readonly Lazy<BundledEventCatalog> instance = new(() => new());
    internal static BundledEventCatalog Instance => instance.Value;
    private readonly JObject data;
    private readonly Dictionary<string, string> templates = new(StringComparer.Ordinal);
    public EventCatalogStatus Status { get; }
    private BundledEventCatalog()
    {
        using var stream = typeof(BundledEventCatalog).Assembly.GetManifestResourceStream("AchievementLabs.EventCatalog.1.0.5.zip")
            ?? throw new InvalidDataException("Bundled event catalogue is missing.");
        using var archive = new ZipArchive(stream, ZipArchiveMode.Read);
        string Read(ZipArchiveEntry entry) { using var reader = new StreamReader(entry.Open()); return reader.ReadToEnd(); }
        data = JObject.Parse(Read(archive.GetEntry("Data.json") ?? throw new InvalidDataException("Catalogue data is missing.")));
        if (data.Properties().Last().Name != "SupportedTitleIDs") throw new InvalidDataException("SupportedTitleIDs must be last.");
        foreach (var entry in archive.Entries.Where(e => e.Name != "Data.json" && e.Name.EndsWith(".json")))
            templates.Add(Path.GetFileNameWithoutExtension(entry.Name), Read(entry));
        var supported = data["SupportedTitleIDs"]!.Values().Select(x => x.ToString()).ToHashSet(StringComparer.Ordinal);
        var enabled = supported.Where(id => data[id] is JObject block && (bool?)block["Enabled"] != false && templates.ContainsKey(id)).ToArray();
        Status = new(enabled.Where(id => (bool?)data[id]!["FullySupported"] == true).ToArray(),
            enabled.Where(id => (bool?)data[id]!["FullySupported"] != true).ToArray(),
            data.Properties().Where(p => p.Name.All(char.IsDigit) && !enabled.Contains(p.Name)).Select(p => p.Name).ToArray());
    }
    public bool Contains(string titleId) => Status.TitleIds.Contains(titleId) || Status.TestingTitleIds!.Contains(titleId);
    private readonly ConcurrentDictionary<string, Lazy<Task<string[]>>> validated = new();
    public async Task<EventTitleMapping> TitleAsync(string titleId, CancellationToken ct)
    {
        var ids = await validated.GetOrAdd(titleId, id => new(() => ValidateTitleAsync(id))).Value.WaitAsync(ct);
        // Return a fresh record because edition normalization replaces AchievementIds.
        return new(ids.ToArray());
    }
    private async Task<string[]> ValidateTitleAsync(string titleId)
    {
        var valid = new List<string>();
        foreach (var entry in ((JObject)data[titleId]!["Achievements"]!).Properties())
        {
            try { await BuildAsync(titleId, entry.Name, "0", CancellationToken.None); valid.Add(entry.Name); }
            catch (Exception ex) when (ex is InvalidOperationException or InvalidDataException or Newtonsoft.Json.JsonException or ArgumentException or KeyNotFoundException or InvalidCastException or FormatException) { }
        }
        return valid.ToArray();
    }
    public async Task<EventPayloads> PayloadsAsync(string titleId, string achievementId, string xuid, CancellationToken ct)
    {
        var mapping = await TitleAsync(titleId, ct);
        if (!mapping.AchievementIds.Contains(achievementId)) throw new InvalidDataException("This catalogue entry is incomplete or its payload failed validation. It was not submitted.");
        return await BuildAsync(titleId, achievementId, xuid, ct);
    }
    private async Task<EventPayloads> BuildAsync(string titleId, string achievementId, string xuid, CancellationToken ct)
    {
        var catalog = new EventCatalog(data, (id, token) =>
        {
            token.ThrowIfCancellationRequested();
            return Task.FromResult(templates[id]);
        });
        var payloads = await catalog.BuildPayloadsAsync(titleId, achievementId, xuid, DateTime.UtcNow, ct);
        foreach (var payload in payloads)
        {
            var body = JObject.Parse(payload)["data"]?["baseData"];
            if (body?["titleId"] == null || body["titleId"]!.ToString() != titleId)
                throw new InvalidDataException("Catalogue payload is missing the selected Title ID.");
        }
        return new(payloads.ToArray());
    }
}
