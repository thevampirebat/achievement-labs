using System.Text;
namespace AchievementLabs.Desktop;
public sealed partial class DesktopModel
{
    private string platformFilter = "All", titleLookup = "";
    public string[] PlatformFilters { get; } = ["All", "Xbox One/Series", "PC", "GFWL", "Xbox 360", "Win32", "Windows 8/Legacy", "Incomplete Games"];
    private string librarySort = "A-Z";
    private readonly string librarySortPath = AchievementLabs.Core.AchievementLabsPaths.LocalFile("library-sort.txt");
    public string[] LibrarySortOptions { get; } = ["A-Z", "Z-A", "Last Played"];
    public string LibrarySort
    {
        get => librarySort;
        set
        {
            var next = LibrarySortOptions.Contains(value) ? value : "A-Z";
            if (librarySort == next) return;
            librarySort = next;
            try { AchievementLabs.Core.LibrarySortPreferences.Save(librarySortPath, next); }
            catch { Notice = "Sort changed, but could not be remembered for next launch."; }
            Changed(); Changed(nameof(VisibleGames));
            if (next == "Last Played") _ = RefreshLibraryAsync();
        }
    }
    public string PlatformFilter { get => platformFilter; set { platformFilter = value ?? "All"; Changed(); Changed(nameof(VisibleGames)); } }
    public string TitleLookup { get => titleLookup; set { titleLookup = value ?? ""; Changed(); } }
    public bool CanQuery => !QueueActive && !busy && session != null;
    public bool CanExport => achievements.Length > 0;
    public static bool HasDevice(Game game, string device) => game.Platform.Split('/', StringSplitOptions.TrimEntries).Contains(device, StringComparer.OrdinalIgnoreCase);
    public static bool UsesLegacyEndpoint(Game game) => new[] { "Xbox360", "Mobile", "WindowsPhone", "Win8", "Windows8" }.Any(d => HasDevice(game, d));
    public static bool MatchesPlatform(Game game, string filter) => filter switch
    {
        "Xbox One/Series" => HasDevice(game, "XboxOne") || HasDevice(game, "XboxSeries"),
        "PC" => HasDevice(game, "PC") || AchievementLabs.MultiSelect.GfwlTitles.Supports(game.Id), "GFWL" => AchievementLabs.MultiSelect.GfwlTitles.Supports(game.Id), "Xbox 360" => HasDevice(game, "Xbox360") && !AchievementLabs.MultiSelect.GfwlTitles.IsExclusive(game.Id), "Win32" => HasDevice(game, "Win32"),
        "Windows 8/Legacy" => UsesLegacyEndpoint(game), "Incomplete Games" => game.ProgressKnown && game.Completed < game.Total, _ => true
    };
    public async Task LookupTitleAsync()
    {
        if (!CanQuery) return;
        if (!uint.TryParse(TitleLookup.Trim(), out var id) || id == 0) { Notice = "Enter a numeric Xbox title ID."; return; }
        var key = id.ToString();
        await SelectGameAsync(Games.FirstOrDefault(g => g.Id == key) ?? new Game(key, "Title " + key, "XboxOne", 0, 0, 0, false));
    }
    public async Task RefreshAchievementsAsync()
    {
        if (CanQuery && SelectedGame is { } game) await SelectGameAsync(game);
    }
    public async Task RefreshLibraryAsync()
    {
        if (!CanQuery) return;
        Busy(true);
        try
        {
            await RefreshSharedTotalsAsync(lifetime.Token);
            LoadLibraryTotals();
            await requests.WaitAsync(lifetime.Token);
            try
            {
                if (client == null || session == null) return;
                totalsReport.Clear();
        var api = client; var xuid = session.Xuid;
                var result = await Task.Run(() => api.GetGamesListAsync(xuid), lifetime.Token) ?? throw new InvalidDataException();
                lifetime.Token.ThrowIfCancellationRequested();
                Games = result.Titles.Where(t => t.TitleId != null).Select(t => new Game(t.TitleId!, t.Name ?? t.TitleId!, string.Join(" / ", t.Devices), t.Achievement?.CurrentAchievements ?? 0, t.Achievement?.TotalAchievements ?? 0, t.Achievement?.CurrentGamerscore ?? 0, t.Achievement != null, ResolveTitleImage(t.DisplayImage, t.Images), t.TitleHistory?.LastTimePlayed)).OrderBy(g => g.Name, StringComparer.OrdinalIgnoreCase).ToArray();
                Notice = $"Refreshed {Games.Length} titles.";
            }
            finally { requests.Release(); }
        }
        catch (OperationCanceledException) { }
        catch { Notice = "Could not refresh the library. Your previous list is still available."; }
        finally { Busy(false); }
    }
    private readonly AchievementLabs.Core.SharedAchievementTotals sharedLibraryTotals = AchievementLabs.Core.SharedAchievementTotals.Bundled();
    private readonly Dictionary<string, int> knownLibraryTotals = new();
    private Game WithSharedTotal(Game game) => game.Total <= 0 && sharedLibraryTotals.TryGet(game.Id, game.Platform, out var total)
        ? game with { Total = total, ProgressKnown = game.ProgressKnown && game.Completed <= total, NoDefinitionsReturned = false } : game;
    private async Task RefreshSharedTotalsAsync(CancellationToken ct)
    {
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
        await sharedLibraryTotals.RefreshAsync(http, AchievementLabs.Core.AchievementLabsPaths.LocalFile("shared-library-totals.json"), ct);
        if (AutoRefreshDlc && !dlcRefreshRunning) await AchievementLabs.MultiSelect.SharedDlcCatalogue.Current.RefreshAsync(http, AchievementLabs.Core.AchievementLabsPaths.LocalFile("shared-achievement-packs.json"), ct);
        if (!dlcRefreshRunning) UpdateDlcCatalogueStatus();
        TotalsStatus = $"Shared totals available for {sharedLibraryTotals.Count} titles. Fill missing totals checks the remaining titles.";
    }
    private CancellationTokenSource? totalsCancellation;
    private string totalsStatus = "";
    public bool TotalsRunning => totalsCancellation != null;
    public string TotalsStatus { get => totalsStatus; private set { totalsStatus = value; Changed(); } }
    public bool CanFillTotals => session != null && !busy && !TotalsRunning;
    private string? TotalsPath => ulong.TryParse(session?.Xuid, out _) ? AchievementLabs.Core.AchievementLabsPaths.LocalFile($"library-totals-{session!.Xuid}.json") : null;
    private void LoadLibraryTotals()
    {
        knownLibraryTotals.Clear();
        try
        {
            if (TotalsPath is string path && File.Exists(path))
                foreach (var entry in System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, int>>(File.ReadAllText(path)) ?? new())
                    if (entry.Value > 0) knownLibraryTotals[entry.Key] = entry.Value;
        }
        catch { } // A damaged cache must not prevent sign-in.
    }
    private void RememberLibraryTotal(string id, int total)
    {
        if (total <= 0) return;
        knownLibraryTotals[id] = total;
        try
        {
            if (TotalsPath is not string path) return;
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            var temporary = path + ".tmp";
            File.WriteAllText(temporary, System.Text.Json.JsonSerializer.Serialize(knownLibraryTotals));
            File.Move(temporary, path, true);
        }
        catch { TotalsStatus = "Totals updated; cache could not be saved."; }
    }
    public static Game WithKnownTotal(Game game, IReadOnlyDictionary<string, int> totals)
        => game.Total <= 0 && totals.TryGetValue(game.Id, out var total) && total > 0 ? game with { Total = total, ProgressKnown = game.ProgressKnown && game.Completed <= total } : game;
    public bool CanExportVerifiedTotals => !TotalsRunning && Games.Any(g => knownLibraryTotals.ContainsKey(g.Id));
    public TotalsReportRow[] VerifiedTotalsForExport() => Games
        .Where(g => knownLibraryTotals.TryGetValue(g.Id, out var total) && total > 0)
        .Select(g => new TotalsReportRow(g.Id, g.Name, g.Platform, "Cached definition total", knownLibraryTotals[g.Id], "Updated"))
        .OrderBy(r => r.Name, StringComparer.OrdinalIgnoreCase).ToArray();
    public async Task ExportVerifiedTotalsAsync(string path)
    {
        var entries = VerifiedTotalsForExport();
        static string Q(string value) => "\"" + value.Replace("\"", "\"\"") + "\"";
        var rows = new[] { "Title ID,Title,Platform,Endpoint,Total,Result" }.Concat(entries.Select(r =>
            string.Join(",", new[] { r.TitleId, r.Name, r.Platform, r.Endpoint, r.Total.ToString(), r.Result }.Select(Q))));
        await File.WriteAllLinesAsync(path, rows, new UTF8Encoding(true), lifetime.Token);
        Notice = $"Exported {entries.Length} cached successful totals across your library. No unlocked counts or account details included.";
    }
    public sealed record TotalsReportRow(string TitleId, string Name, string Platform, string Endpoint, int Total, string Result, int? PersistentUnlocked = null, int? HistoryUnlocked = null);
    private readonly List<TotalsReportRow> totalsReport = new();
    public static string TotalsFailureReason(Exception error) => error switch
    {
        HttpRequestException { StatusCode: { } status } => $"HTTP {(int)status}",
        HttpRequestException => "Network request failed",
        OperationCanceledException => "Request timed out",
        Newtonsoft.Json.JsonException => "Unexpected JSON response",
        InvalidDataException => "Incomplete or invalid achievement definitions",
        _ => "Unexpected scan error"
    };
    public void CancelFillTotals() => totalsCancellation?.Cancel();
    public async Task FillMissingTotalsAsync()
    {
        if (!CanFillTotals || client == null || session == null) return;
        var pending = Games.Where(g => g.Total <= 0 || g.Completed > g.Total).ToArray();
        using var cancel = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
        totalsCancellation = cancel; Changed(nameof(CanExportVerifiedTotals)); Changed(nameof(TotalsRunning)); Changed(nameof(CanFillTotals)); Changed(nameof(CanDisconnect));
        totalsReport.Clear();
        var api = client; var xuid = session.Xuid; var filled = 0; var failed = 0; var checkedCount = 0;
        async Task<TotalsReportRow> CheckAsync(Game game)
        {
            var legacy = UsesLegacyEndpoint(game);
            var endpoint = legacy ? "Legacy" : "Modern";
            var previous = "";
            for (var attempt = 0; attempt < 2; attempt++)
            {
                try
                {
                    var counts = await api.GetAchievementCountsAsync(xuid, game.Id, cancel.Token, legacy);
                    var total = counts.Total;
                    if (total > 0)
                        return new(game.Id, game.Name, game.Platform, endpoint, total, counts.Unlocked.HasValue || total >= game.Completed ? "Updated" : "Count below earned achievements", counts.Unlocked, game.Completed);
                    previous = "Empty achievement list";
                }
                catch (OperationCanceledException) when (cancel.IsCancellationRequested) { throw; }
                catch (HttpRequestException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound && attempt == 0)
                { previous = TotalsFailureReason(ex); }
                catch (Exception ex)
                { return new(game.Id, game.Name, game.Platform, endpoint, 0, previous.Length > 0 ? previous + "; " + TotalsFailureReason(ex) : TotalsFailureReason(ex)); }
                if (attempt == 0) { legacy = !legacy; endpoint += legacy ? " → Legacy" : " → Modern"; }
            }
            return new(game.Id, game.Name, game.Platform, endpoint, 0, previous);
        }
        try
        {
            foreach (var game in pending)
            {
                cancel.Token.ThrowIfCancellationRequested();
                TotalsStatus = $"Checking totals {checkedCount}/{pending.Length} (1 at a time)…";
                // Dedicated read-only HTTP clients avoid the auto unlock/presence request gate.
                var results = new[] { await CheckAsync(game) };
                var updates = new Dictionary<string, TotalsReportRow>();
                foreach (var result in results)
                {
                    totalsReport.Add(result);
                    if (result.Result != "Updated") { failed++; if (result.Result == "Empty achievement list") updates[result.TitleId] = result; continue; }
                    RememberLibraryTotal(result.TitleId, result.Total);
                    updates[result.TitleId] = result; filled++;
                }
                if (updates.Count > 0)
                    Games = Games.Select(g => updates.TryGetValue(g.Id, out var result) ? result.Result == "Updated" ? g with { Total = result.Total, Completed = result.PersistentUnlocked ?? g.Completed, ProgressKnown = result.PersistentUnlocked.HasValue || g.ProgressKnown, NoDefinitionsReturned = false } : g with { NoDefinitionsReturned = g.Completed == 0 && g.Score == 0 } : g).ToArray();
                checkedCount++;
            }
            var reasons = string.Join("; ", totalsReport.Where(r => r.Result != "Updated").GroupBy(r => r.Result).Select(g => $"{g.Key}: {g.Count()}"));
            TotalsStatus = $"Totals updated: {filled}; unavailable: {failed}. {reasons}";
        }
        catch (OperationCanceledException) { TotalsStatus = $"Totals scan stopped; {filled} results saved."; }
        finally { totalsCancellation = null;  Changed(nameof(CanExportVerifiedTotals)); Changed(nameof(TotalsRunning)); Changed(nameof(CanFillTotals)); Changed(nameof(CanDisconnect)); }
    }
    public async Task ExportCsvAsync(string path)
    {
        static string Quote(string text) => "\"" + text.Replace("\"", "\"\"") + "\"";
        var rows = new List<string> { "Title ID,Title,Achievement ID,Achievement,Description,Status,Gamerscore" };
        foreach (var a in BatchAchievements)
            rows.Add(string.Join(",", new[] { SelectedGame?.Id ?? "", SelectedGame?.Name ?? "", a.Id, a.Name, a.Description, a.Status, a.ScoreKnown ? a.Score.ToString() : "" }.Select(Quote)));
        await File.WriteAllLinesAsync(path, rows, new UTF8Encoding(true), lifetime.Token);
        Notice = $"Exported {rows.Count - 1} visible achievements.";
    }
}
