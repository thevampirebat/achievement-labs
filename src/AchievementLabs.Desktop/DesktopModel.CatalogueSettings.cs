using AchievementLabs.Core;
using AchievementLabs.MultiSelect;

namespace AchievementLabs.Desktop;

public sealed partial class DesktopModel
{
    private bool dlcRefreshRunning;
    private string dlcCatalogueStatus = "Bundled DLC sections loaded. Automatic checks run daily while the app is open.";
    public bool CanRefreshDlcCatalogue => !dlcRefreshRunning;
    public string DlcCatalogueStatus { get => dlcCatalogueStatus; private set { dlcCatalogueStatus = value; Changed(); } }
    private void UpdateDlcCatalogueStatus()
    {
        var catalogue = SharedDlcCatalogue.Current;
        DlcCatalogueStatus = $"{catalogue.LastRefreshStatus} · {catalogue.Count:N0} title lists" +
            (catalogue.LastSuccessfulRefresh is { } refreshed ? $" · Last successful check: {refreshed.ToLocalTime():g}" : "");
    }
    public async Task RefreshDlcCatalogueAsync(bool force = true)
    {
        if (dlcRefreshRunning || !force && !AutoRefreshDlc || OfflineChecks) return;
        dlcRefreshRunning = true; Changed(nameof(CanRefreshDlcCatalogue));
        DlcCatalogueStatus = "Refreshing DLC and title-update sections…";
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
            await SharedDlcCatalogue.Current.RefreshAsync(http, AchievementLabsPaths.LocalFile("shared-achievement-packs.json"), lifetime.Token, force);
            UpdateDlcCatalogueStatus();
            Changed(nameof(VisibleAchievements)); RefreshLibraryPresentation();
        }
        catch (OperationCanceledException) { }
        catch { DlcCatalogueStatus = "Could not refresh the catalogue. Existing sections were retained."; }
        finally { dlcRefreshRunning = false; Changed(nameof(CanRefreshDlcCatalogue)); }
    }
    public void OpenDebugReports()
    {
        var folder = ExportBaseFolder();
        if (folder == null) { Notice = "No export reports folder exists yet. Export achievements first."; return; }
        if (CompletionAccount is { } account)
        {
            var scoped = Path.Combine(folder, "AchievementLabs-export-" + account);
            if (Directory.Exists(scoped)) folder = scoped;
        }
        try
        {
            if (!Directory.Exists(folder)) { Notice = "The saved export reports folder is no longer available."; return; }
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(folder) { UseShellExecute = true });
        }
        catch { Notice = "Could not open the export reports folder."; }
    }
    public void OpenCatalogueReview(string review)
    {
        var file = review == "bulk" ? "bulk-dlc-2026-10-08.json" : "dlc-corrections-2026-10-08.json";
        try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(
            "https://github.com/thevampirebat/achievement-labs/blob/main/catalog/reviews/" + file) { UseShellExecute = true }); }
        catch { Notice = "Could not open the catalogue review."; }
    }
}
