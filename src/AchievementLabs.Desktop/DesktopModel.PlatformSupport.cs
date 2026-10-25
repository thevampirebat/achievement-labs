namespace AchievementLabs.Desktop;
public sealed partial class DesktopModel
{
    public bool HasWindowsLocalTools => OperatingSystem.IsWindows();
    public string ConnectActionLabel => OperatingSystem.IsMacOS() ? "Sign in with Microsoft" : "Attach Xbox PC app";
    public string UpdateActionLabel => OperatingSystem.IsMacOS() ? "Open downloaded Mac update" : "Install update and restart";
    private void PrepareMacSignIn()
    {
        XboxPcAppDetected=false;XboxPcAttached=false;OAuthFallbackAvailable=session==null;
        XboxPcAttachmentLabel=session==null?"Microsoft sign-in for Mac":"Connected on Mac";
        XboxPcAttachmentDetail="Use Microsoft browser sign-in or a protected saved session. Windows Xbox-app attachment is unavailable on macOS.";
        if(session==null)Notice="Choose Sign in with Microsoft, then complete sign-in in Settings → Account.";
    }
}
