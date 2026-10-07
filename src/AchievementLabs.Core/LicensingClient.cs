using System.Net.Http.Json;
using System.Text.Json;

namespace AchievementLabs.Core;

public sealed record EventCatalogStatus(string[] TitleIds, string[]? TestingTitleIds, string[] ComingSoonTitleIds);
public sealed record EventTitleMapping(string[] AchievementIds);
public sealed record EventPayloads(string[] Payloads);

/// <summary>Reads event mappings from the bundled public catalogue or remote catalogue.</summary>
public sealed class EventCatalogClient : IDisposable
{
    private readonly HttpClient http = new()
    {
        BaseAddress = new Uri("https://achievementlabs.org/api/licensing/"),
        Timeout = TimeSpan.FromSeconds(25)
    };
    private readonly BundledEventCatalog? bundled;
    public EventCatalogClient() { }
    public EventCatalogClient(bool useBundledCatalog) { if (useBundledCatalog) bundled = BundledEventCatalog.Instance; }
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public Task<EventCatalogStatus> GetCatalogAsync(CancellationToken ct) => bundled != null ? ReadBundledStatus(ct) : SendAsync<EventCatalogStatus>(HttpMethod.Get, "catalog", null, ct);
    private Task<EventCatalogStatus> ReadBundledStatus(CancellationToken ct) { ct.ThrowIfCancellationRequested(); return Task.FromResult(bundled!.Status); }
    public Task<EventTitleMapping> GetTitleAsync(string id, CancellationToken ct) =>
        AchievementLabs.MultiSelect.EventIdMapping.NormalizeCatalog(
            ReadTitleAsync(id, ct), id);
    private Task<EventTitleMapping> ReadTitleAsync(string id, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        return bundled?.Contains(id) == true ? bundled.TitleAsync(id, ct) : SendAsync<EventTitleMapping>(HttpMethod.Get, "titles/" + Uri.EscapeDataString(id), null, ct);
    }
    public Task<EventPayloads> GetPayloadsAsync(string id, string achievementId, string xuid, CancellationToken ct) =>
        AchievementLabs.MultiSelect.EventIdMapping.ValidatePayloads(
            ReadPayloadsAsync(id, achievementId, xuid, ct), id, achievementId);
    private Task<EventPayloads> ReadPayloadsAsync(string id, string achievementId, string xuid, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        var mappedId = AchievementLabs.MultiSelect.EventIdMapping.PayloadId(id, achievementId);
        return bundled?.Contains(id) == true ? bundled.PayloadsAsync(id, mappedId, xuid, ct) : SendAsync<EventPayloads>(HttpMethod.Post, "titles/" + Uri.EscapeDataString(id) + "/payloads", new { achievementId = mappedId, xuid }, ct);
    }

    private async Task<T> SendAsync<T>(HttpMethod method, string path, object? body, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(method, path);
        if (body != null) request.Content = JsonContent.Create(body, options: Json);
        using var response = await http.SendAsync(request, ct);
        if (!response.IsSuccessStatusCode)
        {
            var message = "The event catalog request could not be completed.";
            try
            {
                var error = await response.Content.ReadFromJsonAsync<JsonElement>(Json, ct);
                if (error.TryGetProperty("error", out var value)) message = value.GetString() ?? message;
            }
            catch (JsonException) { }
            throw new HttpRequestException(message, null, response.StatusCode);
        }
        return await response.Content.ReadFromJsonAsync<T>(Json, ct) ?? throw new InvalidDataException("Empty event catalog response.");
    }

    public void Dispose() => http.Dispose();
}
