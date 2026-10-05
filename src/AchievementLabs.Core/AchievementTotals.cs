using Newtonsoft.Json.Linq;
using System.Net;

namespace AchievementLabs.Core;

public static class AchievementTotals
{
    public static async Task<string> ReadPageAsync(HttpClient http, string url, CancellationToken ct)
    {
        for (int attempt = 0; ; attempt++)
        {
            using var response = await http.GetAsync(url, ct);
            if (response.StatusCode == HttpStatusCode.TooManyRequests && attempt < 2)
            {
                var wait = response.Headers.RetryAfter?.Delta
                    ?? (response.Headers.RetryAfter?.Date - DateTimeOffset.UtcNow)
                    ?? TimeSpan.FromSeconds(5 * (attempt + 1));
                await Task.Delay(wait > TimeSpan.Zero ? wait : TimeSpan.FromSeconds(1), ct);
                continue;
            }
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadAsStringAsync(ct);
        }
    }

    public static async Task<int> CountAsync(Func<string?, Task<string>> getPage, CancellationToken ct)
    {
        var ids = new HashSet<string>(StringComparer.Ordinal);
        var tokens = new HashSet<string>(StringComparer.Ordinal);
        string? continuation = null;
        do
        {
            ct.ThrowIfCancellationRequested();
            var page = JObject.Parse(await getPage(continuation));
            if (page["achievements"] is not JArray rows) throw new InvalidDataException("Achievement definitions were not returned.");
            foreach (var row in rows)
            {
                if (string.Equals((string?)row["achievementType"], "Challenge", StringComparison.OrdinalIgnoreCase)) continue;
                var id = (string?)row["id"];
                if (string.IsNullOrWhiteSpace(id)) throw new InvalidDataException("Achievement ID missing.");
                ids.Add(id);
            }
            continuation = (string?)page["pagingInfo"]?["continuationToken"];
            if (!string.IsNullOrEmpty(continuation) && !tokens.Add(continuation)) throw new InvalidDataException("Repeated achievement page.");
        } while (!string.IsNullOrEmpty(continuation));
        return ids.Count;
    }
}
