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
        box.Children.Add(new TextBlock {Text="This cached-user-token method may return a token that does not credit achievements. It is not XAU's preferred Windows sign-in method. Saved/manual tokens are preserved during background retrieval. Get event token now explicitly replaces the active token. Save event token writes it to disk. Avoid sharing tokens.",FontSize=12,Opacity=.75,TextWrapping=TextWrapping.Wrap});
        panel.Children.Insert(panel.Children.IndexOf(actions),box);
        var http=new HttpClient(new HttpClientHandler {AllowAutoRedirect=false}){Timeout=TimeSpan.FromSeconds(30)};
        CancellationTokenSource? request=null;object? observed=null;DateTimeOffset next=DateTimeOffset.MinValue;bool closed=false;string installed="";
        async Task Check(bool manual=false)
        {
            if(closed)return;
            object? session=Session(model);
            if(!ReferenceEquals(observed,session))
            {
                request?.Cancel();TokenPresentation.ClearOwnInput(model,installed);observed=session;next=DateTimeOffset.UtcNow.AddSeconds(2);installed="";
                status.Text=session==null?"Connect your Xbox account first.":"Ready to retrieve a matching event token.";
            }
            bool ready=session!=null && Prop(model,"CanQuery") is true;
            button.IsEnabled=ready && request==null;
            if(!ready || request!=null || !manual && (toggle.IsChecked!=true || DateTimeOffset.UtcNow<next))return;
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
                var grant=await Task.Run(async ()=> {
                    var candidates=AutomaticEventToken.ReadCache(cancellation.Token);
                    return await AutomaticEventToken.Acquire(http,xuid,candidates,cancellation.Token);
                });
                if(closed || cancellation.IsCancellationRequested || !ReferenceEquals(session,Session(model)))return;
                if(grant==null){status.Text="No usable token for this account. Open the Xbox app, sign in, launch an Xbox PC game, then try again. Manual entry is still available.";return;}
                if(!TokenPresentation.Install(model,session!,grant,installed,manual))
                {
                    status.Text="Saved/manual token preserved; the retrieved token was not installed.";
                    return;
                }
                installed=grant.Value;next=grant.ExpiresAt.AddMinutes(-5);
                if(next<DateTimeOffset.UtcNow.AddMinutes(1))next=DateTimeOffset.UtcNow.AddMinutes(1);
                string message=$"Experimental cached-user token acquired · expires {grant.ExpiresAt.LocalDateTime:g}. Account matched; achievement credit is NOT verified. No unlock was sent to test it.";
                status.Text=message;model.GetType().GetProperty("EventTokenStatus",Flags)?.SetValue(model,message);
            }
            catch(OperationCanceledException){if(!closed && !cancellation.IsCancellationRequested)status.Text="Token retrieval timed out. Try again later.";}
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
                var session=Session(model);
                if(installed.Length>0 && Equals(Prop(session,"EventsToken"),installed))session?.GetType().GetProperty("EventsToken",Flags)?.SetValue(session,"");
                TokenPresentation.ClearOwnInput(model,installed);installed="";status.Text="Automatic retrieval is off. Manual entry is available.";
                model.GetType().GetProperty("EventTokenStatus",Flags)?.SetValue(model,"Automatic retrieval is off; use a saved or manual event token.");
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
