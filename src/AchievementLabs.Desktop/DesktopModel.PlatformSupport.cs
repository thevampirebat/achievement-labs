namespace AchievementLabs.Desktop;
public sealed partial class DesktopModel
{
    public bool HasWindowsLocalTools => OperatingSystem.IsWindows();
    public string ConnectActionLabel => OperatingSystem.IsMacOS() ? "Sign in with Microsoft" : "Attach Xbox PC app";
    public string UpdateActionLabel => OperatingSystem.IsMacOS() ? "Open downloaded Mac update" : "Install update and restart";
    public bool OAuthManualRedirectAvailable => !OperatingSystem.IsMacOS();
    public string OAuthSectionTitle => OperatingSystem.IsMacOS() ? "Microsoft sign-in" : "Microsoft OAuth fallback";
    public string OAuthSignInDescription => OperatingSystem.IsMacOS()
        ? "Sign in in the Microsoft window. Achievement Labs connects automatically when you finish. You can also use a protected saved sign-in."
        : "Use Microsoft browser sign-in when Xbox PC app attachment is unavailable. Try a protected saved sign-in first. For a new sign-in, copy the final login.live.com address and use the single paste-and-finish button.";
    public string OAuthStartLabel => OperatingSystem.IsMacOS() ? "Sign in with Microsoft" : "Open Microsoft sign-in";
    public string RememberOAuthLabel => OperatingSystem.IsMacOS() ? "Remember this sign-in securely on this Mac" : "Remember this fallback sign-in for this Windows user";
    private void PrepareMacSignIn()
    {
        XboxPcAppDetected=false;XboxPcAttached=false;OAuthFallbackAvailable=session==null;
        XboxPcAttachmentLabel=session==null?"Microsoft sign-in for Mac":"Connected on Mac";
        XboxPcAttachmentDetail="Sign in with Microsoft in the Mac sign-in window, or use a protected saved session.";
        if(session==null)Notice="Choose Sign in with Microsoft. The app will complete sign-in automatically.";
    }
}
