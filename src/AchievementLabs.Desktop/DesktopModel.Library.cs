using System.Text;
namespace AchievementLabs.Desktop;
public sealed partial class DesktopModel
{
    private string platformFilter = "All", titleLookup = "";
    public string[] PlatformFilters { get; } = ["All", "Xbox One/Series", "PC", "Xbox 360", "Win32", "Windows 8/Legacy", "Incomplete Games"];
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
        "PC" => HasDevice(game, "PC"), "Xbox 360" => HasDevice(game, "Xbox360"), "Win32" => HasDevice(game, "Win32"),
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
            await requests.WaitAsync(lifetime.Token);
            try
            {
                if (client == null || session == null) return;
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
    private readonly Dictionary<string, int> knownLibraryTotals = new();
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
        => game.Total <= 0 && totals.TryGetValue(game.Id, out var total) && total >= game.Completed ? game with { Total = total } : game;
    public void CancelFillTotals() => totalsCancellation?.Cancel();
    public async Task FillMissingTotalsAsync()
    {
        if (!CanFillTotals || client == null || session == null) return;
        var pending = Games.Where(g => g.Total <= 0).ToArray();
        using var cancel = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
        totalsCancellation = cancel; Changed(nameof(TotalsRunning)); Changed(nameof(CanFillTotals)); Changed(nameof(CanDisconnect));
        var api = client; var xuid = session.Xuid; var filled = 0; var failed = 0; var checkedCount = 0;
        async Task<(Game Game, int Total)> CheckAsync(Game game)
        {
            try { return (game, await api.GetAchievementTotalAsync(xuid, game.Id, cancel.Token, UsesLegacyEndpoint(game))); }
            catch (OperationCanceledException) when (cancel.IsCancellationRequested) { throw; }
            catch { return (game, 0); }
        }
        try
        {
            foreach (var batch in pending.Chunk(3))
            {
                cancel.Token.ThrowIfCancellationRequested();
                TotalsStatus = $"Checking totals {checkedCount}/{pending.Length} (3 at a time)…";
                // Dedicated read-only HTTP clients avoid the auto unlock/presence request gate.
                var results = await Task.WhenAll(batch.Select(CheckAsync));
                var updates = new Dictionary<string, int>();
                foreach (var result in results)
                {
                    if (result.Total <= 0 || result.Total < result.Game.Completed) { failed++; continue; }
                    RememberLibraryTotal(result.Game.Id, result.Total);
                    updates[result.Game.Id] = result.Total; filled++;
                }
                if (updates.Count > 0)
                    Games = Games.Select(g => updates.TryGetValue(g.Id, out var total) ? g with { Total = total } : g).ToArray();
                checkedCount += batch.Length;
            }
            TotalsStatus = $"Totals updated: {filled}; unavailable: {failed}.";
        }
        catch (OperationCanceledException) { TotalsStatus = $"Totals scan stopped; {filled} results saved."; }
        finally { totalsCancellation = null; Changed(nameof(TotalsRunning)); Changed(nameof(CanFillTotals)); Changed(nameof(CanDisconnect)); }
    }
    public async Task ExportCsvAsync(string path)
    {
        static string Quote(string text) => "\"" + text.Replace("\"", "\"\"") + "\"";
        var rows = new List<string> { "Title ID,Title,Achievement ID,Achievement,Description,Status,Gamerscore" };
        foreach (var a in VisibleAchievements)
            rows.Add(string.Join(",", new[] { SelectedGame?.Id ?? "", SelectedGame?.Name ?? "", a.Id, a.Name, a.Description, a.Status, a.ScoreKnown ? a.Score.ToString() : "" }.Select(Quote)));
        await File.WriteAllLinesAsync(path, rows, new UTF8Encoding(true), lifetime.Token);
        Notice = $"Exported {rows.Count - 1} visible achievements.";
    }
}
