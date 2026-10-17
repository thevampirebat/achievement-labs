using AchievementLabs.Core;
namespace AchievementLabs.Desktop;
public sealed partial class DesktopModel
{
    public MobileTransferFile CreateMobileTransfer()
    {
        if (session == null) throw new InvalidOperationException("Connect Xbox first.");
        return MobileTransfer.Create(session.Authorization,session.Xuid,session.EventsToken,session.AuthorizationExpiresAt);
    }
}
