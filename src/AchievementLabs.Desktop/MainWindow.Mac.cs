using System.Security.Cryptography;
using System.Text;
using Avalonia;
using Avalonia.Controls;
using Avalonia.LogicalTree;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using AchievementLabs.Core;
using AchievementLabs.Services.Xbox360;
namespace AchievementLabs.Desktop;
public partial class MainWindow
{
    private void ApplyMacPlatformControls()
    {
        if(!OperatingSystem.IsMacOS())return;
        foreach(var text in this.GetLogicalDescendants().OfType<TextBlock>().Where(t=>t.Text is "STEAM" or "EPIC GAMES" or "UBISOFT CONNECT"))
        { var card=text.GetLogicalAncestors().OfType<Border>().FirstOrDefault(b=>b.Classes.Contains("panel"));if(card!=null)card.IsVisible=false; }
        foreach(var button in this.GetLogicalDescendants().OfType<Button>())
        {
            if(button.Content is string content)
            {
                if(content is "Retry attachment")button.Content="Sign in with Microsoft";
                if(content.Contains("Windows account",StringComparison.OrdinalIgnoreCase))button.IsVisible=false;
            }
        }
        foreach(var toggle in this.GetLogicalDescendants().OfType<CheckBox>())
            if(toggle.Content is string content && (content.Contains("Xbox app",StringComparison.OrdinalIgnoreCase)||content.Contains("launch hidden",StringComparison.OrdinalIgnoreCase)))toggle.IsVisible=false;
    }
    private async Task RunMacSmokeAsync()
    {
        var args=Environment.GetCommandLineArgs();var output=Path.GetFullPath(args.SkipWhile(a=>a!="--output").Skip(1).First());Directory.CreateDirectory(output);
        try
        {
            await Task.Delay(100); // Let the native desktop lifetime finish opening before testing/closing.
            if(!OperatingSystem.IsMacOS()||System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture!=System.Runtime.InteropServices.Architecture.Arm64)throw new Exception("Expected native Apple Silicon runtime.");
            if(model.HasWindowsLocalTools)throw new Exception("Windows capabilities exposed on Mac.");
            await model.AttachXboxPcAppAsync();if(!model.OAuthFallbackAvailable||!model.ConnectActionLabel.Contains("Microsoft"))throw new Exception("Mac sign-in preparation failed.");
            var sample=Encoding.UTF8.GetBytes("synthetic-macos-storage-test");var encrypted=SecureUserData.Protect(sample);
            if(encrypted.AsSpan().IndexOf(sample)>=0||!SecureUserData.Unprotect(encrypted).SequenceEqual(sample))throw new Exception("Keychain storage round trip failed.");
            encrypted[^1]^=1;try{SecureUserData.Unprotect(encrypted);throw new Exception("Tampered storage accepted.");}catch(AuthenticationTagMismatchException){}
            if(!Xbox360SigningSession.LoadBundledIdentity()||!Xbox360ConSigner.SigningAvailable)throw new Exception("Bundled signing identity did not load.");
            var fixture=Path.GetFullPath(args.SkipWhile(a=>a!="--fixture").Skip(1).First());var originalHash=SHA256.HashData(File.ReadAllBytes(fixture));
            var packages=new Xbox360PackageService();var signed=Path.Combine(output,Convert.ToHexString(File.ReadAllBytes(fixture).AsSpan(0x371,8)));
            new Xbox360StfsSignedWriter(new Xbox360StfsUnsignedWriter(packages)).Write(fixture,signed,new Dictionary<string,byte[]>{{"FFFE07D1.gpd",packages.ReadEntryBytes(fixture,"FFFE07D1.gpd")}});
            if(!Xbox360ConSigner.VerifyFile(signed))throw new Exception("Synthetic signed profile verification failed.");
            var profiles=new Xbox360ProfileService(Path.Combine(output,"working-profiles"));var working=await profiles.ExtractProfileAsync(signed);
            var reader=new Xbox360ProfileReader(packages);var game=reader.ReadGames(working).First();var achievement=reader.ReadAchievements(working,game.TitleId).First(a=>(a.Flags&0x20000)==0);
            new Xbox360ProfileEditService(packages,profiles).Save(working,game.TitleId,new[]{achievement with{Flags=achievement.Flags|0x20000,UnlockedAt=null}});
            if(!Xbox360ConSigner.VerifyFile(working)||!reader.ReadAchievements(working,game.TitleId).Any(a=>a.Id==achievement.Id&&(a.Flags&0x20000)!=0)||!SHA256.HashData(File.ReadAllBytes(fixture)).SequenceEqual(originalHash))throw new Exception("Synthetic edit/sign or original preservation failed.");
            var root=this.FindControl<Grid>("PreviewRoot")!;
            foreach(var page in new[]{"Home","Library","Queues","Xbox360Profiles","Settings"})
            {
                model.Navigate(page);await Task.Delay(350);using var bitmap=new RenderTargetBitmap(new PixelSize((int)root.Bounds.Width,(int)root.Bounds.Height),new Vector(96,96));bitmap.Render(root);bitmap.Save(Path.Combine(output,"Mac-"+page+".png"),new PngBitmapEncoderOptions());
            }
            File.WriteAllText(Path.Combine(output,"mac-smoke.txt"),"PASS: native arm64 UI startup; Microsoft browser-sign-in entry; Keychain-backed AES-GCM round trip/tamper rejection; synthetic Xbox 360 working-copy edit and signed export verified; Home, Library, Game Session, Xbox 360 and Settings render; no account or event requests.");
        }
        catch(Exception ex){File.WriteAllText(Path.Combine(output,"mac-smoke-error.txt"),ex.ToString());Environment.ExitCode=1;}
        finally{Close();}
    }
}
