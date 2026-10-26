using AchievementLabs.Core;

namespace AchievementLabs.Desktop;

public sealed partial class DesktopModel
{
    private PcPresenceAuthorization? pairedPcPresence;
    private int pairedPcPresenceGeneration;
    private string pcPresenceComparison = "Pair PC authorization, then compare its public envelope metadata with the Mac account token. The report contains no credentials or account claims.";
    public string PcPresenceComparison { get => pcPresenceComparison; private set { pcPresenceComparison = value; Changed(); } }
    public void ComparePcPresenceMetadata()
    {
        if (session == null || pairedPcPresence == null || sessionGeneration != pairedPcPresenceGeneration || session.Xuid != pairedPcPresence.Xuid)
        { PcPresenceComparison = "Import a PC pairing for the current account before comparing."; return; }
        PcPresenceComparison = PresenceAuthorizationMetadata.Compare(session.Authorization, pairedPcPresence.Authorization);
    }
    public bool IsMacPlatform => OperatingSystem.IsMacOS();
    public PcPresenceAuthorization ReadPcPresence(byte[] bytes, string key)
        => PcPresenceTransfer.Read(bytes, key, session?.Xuid ?? "", DateTimeOffset.UtcNow);
    public string PcPresenceStatus => pairedPcPresence != null && pairedPcPresenceGeneration == sessionGeneration
        ? $"PC pairing test stops by {pairedPcPresence.ExpiresAt.LocalDateTime:g}. " + (pairedPcPresence.IssuerExpiryKnown ? "Known authorization expiry is respected. " : "Token expiry is unknown; this is a local test limit. ") + "Start the spoofer to test acceptance. Automatic renewal is unavailable."
        : "Optional test: import a PC sync file for the same Xbox account. Mac sign-in and event tokens stay in place. The pairing is kept in memory only.";

    public async Task ImportPcPresenceAsync(PcPresenceAuthorization imported)
    {
        if (!OperatingSystem.IsMacOS() || !CanQuery || PresenceRunning || WorkflowBusy) throw new InvalidOperationException();
        var generation = sessionGeneration;
        var xuid = session!.Xuid;
        if (imported.Xuid != xuid || imported.ExpiresAt <= DateTimeOffset.UtcNow.AddMinutes(1)) throw new InvalidDataException();
        Busy(true);
        try
        {
            using var api = new XboxApiClient(imported.Authorization, RegionOverride);
            var profile = await api.GetBasicProfileAsync(lifetime.Token);
            if (profile?.ProfileUsers.FirstOrDefault()?.Id != xuid || session?.Xuid != xuid || sessionGeneration != generation)
                throw new InvalidDataException();
            pairedPcPresence = imported;
            pairedPcPresenceGeneration = generation;
            PcPresenceComparison = "PC authorization paired. Choose Compare authorization metadata to generate a local report; no network request is sent.";
            Changed(nameof(PcPresenceStatus));
            Notice = "PC authorization verified for the same account. No heartbeat sent. Open Game Session and start the spoofer to test it.";
        }
        finally { Busy(false); }
    }

    public void ClearPcPresence()
    {
        if (PresenceRunning) { Notice = "Stop the spoofer before removing its PC pairing."; return; }
        pairedPcPresence = null;
        PcPresenceComparison = "No PC pairing is loaded.";
        Changed(nameof(PcPresenceStatus));
    }

    private string? PairedPresenceAuthorization(string xuid)
    {
        if (pairedPcPresence == null) return null;
        if (pairedPcPresenceGeneration != sessionGeneration || pairedPcPresence.Xuid != xuid)
        { ClearPcPresence(); throw new InvalidOperationException("PC pairing belongs to an earlier sign-in. Pair again."); }
        if (pairedPcPresence.ExpiresAt <= DateTimeOffset.UtcNow.AddMinutes(1))
            throw new InvalidOperationException("PC presence authorization has expired or is expiring. Export a fresh PC sync file and pair again.");
        return pairedPcPresence.Authorization;
    }
}
