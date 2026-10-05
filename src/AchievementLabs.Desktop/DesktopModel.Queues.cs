using AchievementLabs.Core;
using AchievementLabs.Desktop.Workflows;
namespace AchievementLabs.Desktop;
public sealed partial class DesktopModel
{
    public Func<CancellationToken, Task<bool>>? QueueTokenRefresh { get; set; }
    public Action<string>? AutoUnlockFailure { get; set; }
    private readonly NativeAccountContext queueAccount = new();
    private AutoUnlockerViewModel? xboxQueue;
    private SteamAutoUnlockerViewModel? steamQueue;
    public AutoUnlockerViewModel XboxQueue => xboxQueue ??= new(new NativeNotices(message => Notice = message), queueAccount) { EventCatalog = eventCatalog, SendEventAchievementAsync = SendQueueEventAchievementAsync, ReadQueueAchievementsAsync = ReadQueueAchievementsAsync, ExternalPresenceActive = () => PresenceRunning, PresenceGate = requests, RefreshEventTokenAsync = ct => QueueTokenRefresh?.Invoke(ct) ?? Task.FromResult(false), FailureNotification = message => AutoUnlockFailure?.Invoke(message) };
    public SteamAutoUnlockerViewModel SteamQueue => steamQueue ??= ObserveWorkflow(new SteamAutoUnlockerViewModel(steam, new NativeNotices(message => Notice = message)));
    public bool IsQueues => page == "Queues";
    private bool queueActive;
    public bool QueueActive { get => queueActive; private set { queueActive = value; Changed(); Busy(busy); } }
    public void OpenQueues()
    {
        queueAccount.LastOAuthResponse = session?.OAuthResponse; queueAccount.XAUTH = session?.Authorization ?? ""; queueAccount.XUIDOnly = session?.Xuid ?? ""; queueAccount.EventsToken = session?.EventsToken ?? ""; queueAccount.EventsDirectory = EventsDirectory;
        XboxQueue.OnNavigatedTo(); Navigate("Queues");
    }
    private async Task<AchievementsResponse?> ReadQueueAchievementsAsync(string titleId, CancellationToken ct)
    {
        var active = session ?? throw new InvalidOperationException("Connect an Xbox account first.");
        var api = client ?? throw new InvalidOperationException("Xbox client is unavailable.");
        ct.ThrowIfCancellationRequested();
        var response = await api.GetAchievementsForTitleAsync(active.Xuid, titleId);
        ct.ThrowIfCancellationRequested();
        if (session?.Xuid != active.Xuid) throw new InvalidOperationException("The connected Xbox account changed.");
        return response;
    }
    private async Task<bool> SendQueueEventAchievementAsync(string titleId, string achievementId, CancellationToken ct)
    {
        // Read the live session on every attempt, including after manual save or automatic refresh.
        var active = session ?? throw new InvalidOperationException("Connect an Xbox account first.");
        var api = client ?? throw new InvalidOperationException("Xbox client is unavailable.");
        if (!EventTokenValidator.TryValidate(active.EventsToken, out var token, out _))
            throw new AchievementLabs.Core.MissingEventTokenException();
        var payloads = await eventCatalog.GetPayloadsAsync(titleId, achievementId, active.Xuid, ct);
        if (payloads.Payloads.Length == 0) throw new InvalidOperationException("No mapped event data is available.");
        await requests.WaitAsync(ct);
        try
        {
            foreach (var payload in payloads.Payloads)
            {
                ct.ThrowIfCancellationRequested();
                if (session?.Xuid != active.Xuid) throw new InvalidOperationException("The connected Xbox account changed.");
                var result = await api.UnlockEventBasedAchievementWithDiagnostics(token, payload);
                if (result.StatusCode < 200 || result.StatusCode >= 300)
                    throw new HttpRequestException($"Event request failed: HTTP {result.StatusCode} {result.ReasonPhrase}.", null,
                        (System.Net.HttpStatusCode)result.StatusCode);
            }
        }
        finally { requests.Release(); }
        return true;
    }
    public async Task<bool> RefreshQueueEventTokenAsync(Avalonia.Controls.Window owner, CancellationToken ct)
    {
        if (session == null) return false;
        var xuid = session.Xuid;
        var grant = await WamEventTokens.AcquireAsync(owner, xuid, ct);
        ct.ThrowIfCancellationRequested();
        if (grant == null || session?.Xuid != xuid) return false;
        session = session with { EventsToken = grant.Value };
        queueAccount.EventsToken = grant.Value;
        EventTokenInput = grant.Value;
        EventTokenStatus = "Queue refreshed the event token for the connected Xbox account.";
        return true;
    }
    public async Task RunXboxQueueAsync()
    {
        if (QueueActive && !XboxQueue.IsRunning) return;
        if (session == null && !XboxQueue.IsRunning) return;
        if (XboxQueue.IsRunning) { await XboxQueue.StartStopAutoUnlock(); return; }
        if (busy) { Notice = "Wait for the current operation before starting a queue."; return; }
        QueueActive = true;
        try { await XboxQueue.StartStopAutoUnlock(); } finally { QueueActive = false; }
    }
    public async Task RunSteamQueueAsync()
    {
        if (QueueActive || busy) return;
        QueueActive = true;
        try { await SteamQueue.StartCommand.ExecuteAsync(null); } finally { QueueActive = false; }
    }
    private void StopQueues()
    {
        steamQueue?.StopCommand.Execute(null);
        if (xboxQueue?.IsRunning == true) _ = xboxQueue.StartStopAutoUnlock();
    }
}

