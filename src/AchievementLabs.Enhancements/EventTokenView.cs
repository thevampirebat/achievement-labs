using System.ComponentModel;
using System.Net.Http;
using System.Reflection;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.LogicalTree;
using Avalonia.Media;
using Avalonia.Threading;

namespace AchievementLabs.MultiSelect;
public static class EventTokenView
{
    public static Func<Window,string,CancellationToken,Task<AutomaticEventToken.Grant?>>? PreferredAcquireAsync { get; set; }
    const BindingFlags Flags=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static object? Prop(object? o,string n)=>o?.GetType().GetProperty(n,Flags)?.GetValue(o);
    static object? Session(object model)=>model.GetType().GetField("session",Flags)?.GetValue(model);
    static string Preference=>Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"AchievementLabs","automatic-event-token.txt");
    public static void Attach(Window owner,object model)
    {
        var save=owner.GetLogicalDescendants().OfType<Button>().FirstOrDefault(b=>Equals(b.Content,"Save event token"));
        if(save?.Parent is not Control actions || actions.Parent is not Panel panel)return;
        bool enabled=false;
        try{if(File.Exists(Preference))enabled=File.ReadAllText(Preference)=="enabled";}catch(IOException){}catch(UnauthorizedAccessException){}
        var box=new StackPanel {Name="AutomaticEventToken",Spacing=7,Margin=new Thickness(0,12,0,12)};
        var toggle=new CheckBox {Name="AutomaticEventTokenEnabled",Content="Automatically retrieve a Gaming Services token (experimental)",IsChecked=enabled};
        var button=new Button {Name="GetEventTokenNow",Content="Get event token now"};
        var input=owner.GetLogicalDescendants().OfType<TextBox>().FirstOrDefault(t=>t.PlaceholderText=="Paste event token");
        var reveal=new CheckBox {Name="ShowEventToken",Content="Show event token",IsChecked=false};
        if(input!=null)
        {
            char mask=input.PasswordChar;
            reveal.IsCheckedChanged+=(_,_)=>input.PasswordChar=reveal.IsChecked==true?'\0':mask;
            owner.Closed+=(_,_)=>input.PasswordChar=mask;
        }
        else reveal.IsEnabled=false;
        var status=new TextBlock {Text="Connect the same account in Achievement Labs and the Xbox app.",TextWrapping=TextWrapping.Wrap};
        box.Children.Add(toggle);box.Children.Add(button);box.Children.Add(reveal);box.Children.Add(status);
        box.Children.Add(new TextBlock {Text="Get event token now uses Windows account sign-in and a device-bound exchange. Choose the same account connected here. Achievement credit needs testing on your PC. The automatic cache option remains experimental and may not credit achievements. Retrieved tokens stay visible when saved; background cache retrieval preserves a Windows account token.",FontSize=12,Opacity=.75,TextWrapping=TextWrapping.Wrap});
        panel.Children.Insert(panel.Children.IndexOf(actions),box);
        var http=new HttpClient(new HttpClientHandler {AllowAutoRedirect=false}){Timeout=TimeSpan.FromSeconds(30)};
        CancellationTokenSource? request=null;object? observed=null;DateTimeOffset next=DateTimeOffset.MinValue;bool closed=false;bool preferredInstalled=false;string installed="";
        async Task Check(bool manual=false)
        {
            if(closed)return;
            object? session=Session(model);
            // Saving updates the immutable session, but does not disconnect the account.
            bool sameAccount=observed!=null && session!=null && Equals(Prop(observed,"Xuid"),Prop(session,"Xuid")) && Equals(Prop(observed,"Authorization"),Prop(session,"Authorization"));
            if(!ReferenceEquals(observed,session) && !sameAccount)
            {
                request?.Cancel();TokenPresentation.ClearOwnInput(model,installed);observed=session;next=DateTimeOffset.UtcNow.AddSeconds(2);installed="";preferredInstalled=false;
                status.Text=session==null?"Connect your Xbox account first.":"Ready to retrieve a matching event token.";
            }
            observed=session;
            bool ready=session!=null && Prop(model,"CanQuery") is true;
            button.IsEnabled=ready && request==null;
            if(!ready || request!=null || !manual && (toggle.IsChecked!=true || DateTimeOffset.UtcNow<next))return;
            if(!manual && preferredInstalled)return;
            if(!TokenPresentation.CanInstall(model,session!,installed,manual))
            {
                status.Text="Saved/manual token preserved. Background retrieval is paused while a different token or manual edit is present.";
                return;
            }
            string xuid=Prop(session,"Xuid")?.ToString()??"";
            var cancellation=new CancellationTokenSource();request=cancellation;button.IsEnabled=false;next=DateTimeOffset.UtcNow.AddMinutes(10);
            status.Text="Retrieving an event token for the connected account…";
            try
            {
                var grant=manual && PreferredAcquireAsync!=null ? await PreferredAcquireAsync(owner,xuid,cancellation.Token) : await Task.Run(async ()=> {
                    var candidates=AutomaticEventToken.ReadCache(cancellation.Token);
                    return await AutomaticEventToken.Acquire(http,xuid,candidates,cancellation.Token);
                });
                if(closed || cancellation.IsCancellationRequested || !ReferenceEquals(session,Session(model)))return;
                if(grant==null){status.Text=manual && PreferredAcquireAsync!=null ? "Windows sign-in did not provide a device-bound event token. Add/sign in to the account in Windows first, or paste the working XAU token. The cache fallback was not used." : "No usable cached token for this account. Manual entry is still available.";return;}
                if(!TokenPresentation.Install(model,session!,grant,installed,manual))
                {
                    status.Text="Saved/manual token preserved; the retrieved token was not installed.";
                    return;
                }
                installed=grant.Value;preferredInstalled=manual && PreferredAcquireAsync!=null;next=grant.ExpiresAt.AddMinutes(-5);
                if(next<DateTimeOffset.UtcNow.AddMinutes(1))next=DateTimeOffset.UtcNow.AddMinutes(1);
                string message=$"{(preferredInstalled ? "Windows account + device token" : "Experimental cached-user token")} acquired · expires {grant.ExpiresAt.LocalDateTime:g}. Account matched; achievement credit is not verified. Save stores this token securely.";
                status.Text=message;model.GetType().GetProperty("EventTokenStatus",Flags)?.SetValue(model,message);
            }
            catch(OperationCanceledException){if(!closed)status.Text="Token retrieval cancelled or timed out. Your previous token is preserved.";}
            catch(Exception e)
            {
                // Never display raw native/cache/HTTP exception details: they could contain sensitive material.
                if(closed || cancellation.IsCancellationRequested || !ReferenceEquals(session,Session(model)))return;
                if(e is UnauthorizedAccessException)next=DateTimeOffset.MaxValue;
                if(!closed && !cancellation.IsCancellationRequested)status.Text=e is UnauthorizedAccessException?"Windows denied cache access. Automatic retrieval stopped; no elevation was attempted.":"Automatic retrieval was unavailable. Check the Xbox app sign-in and connection, or use manual entry.";
            }
            finally{if(ReferenceEquals(request,cancellation))request=null;cancellation.Dispose();if(!closed)button.IsEnabled=Session(model)!=null && Prop(model,"CanQuery") is true;}
        }
        toggle.IsCheckedChanged+=(_,_)=>
        {
            request?.Cancel();next=DateTimeOffset.MinValue;
            if(toggle.IsChecked!=true)
            {
                status.Text="Background cache retrieval is off. The current token is preserved.";
            }
            try{Directory.CreateDirectory(Path.GetDirectoryName(Preference)!);File.WriteAllText(Preference,toggle.IsChecked==true?"enabled":"disabled");}catch(IOException){}catch(UnauthorizedAccessException){}
        };
        button.Click+=async (_,_)=>await Check(true);
        var remove=owner.GetLogicalDescendants().OfType<Button>().FirstOrDefault(b=>Equals(b.Content,"Remove saved token"));
        if(remove!=null)remove.Click+=(_,_)=>toggle.IsChecked=false;
        var timer=new DispatcherTimer {Interval=TimeSpan.FromSeconds(5)};timer.Tick+=async (_,_)=>await Check();timer.Start();
        PropertyChangedEventHandler changed=async (_,e)=>{if(e.PropertyName is "CanQuery" or "CanConnect" or "")await Check();};
        if(model is INotifyPropertyChanged n)n.PropertyChanged+=changed;
        button.IsEnabled=Session(model)!=null && Prop(model,"CanQuery") is true;
        owner.Closed+=(_,_)=>{closed=true;request?.Cancel();timer.Stop();http.Dispose();if(model is INotifyPropertyChanged n)n.PropertyChanged-=changed;};
    }
}
