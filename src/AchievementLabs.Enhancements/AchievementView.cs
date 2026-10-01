using System.Collections;
using System.Reflection;
using System.Runtime.CompilerServices;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Templates;
using Avalonia.Layout;
using Avalonia.LogicalTree;
using Avalonia.Media;

namespace AchievementLabs.MultiSelect;
public static class AchievementView
{
    const BindingFlags Flags=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static object? Prop(object? o,string key)=>o?.GetType().GetProperty(key,Flags)?.GetValue(o);
    public static string Normalize(string text)=>new string(text.Where(char.IsLetterOrDigit).Select(char.ToLowerInvariant).ToArray());
    public static readonly string[] Packs={"All packs", "Base game", "Onslaught", "Devastation", "Invasion", "Nemesis", "Unclassified"};
    public static readonly string[] Sorts={"Original order", "Name A–Z", "Name Z–A"};
    public static readonly Dictionary<string,string> Ghosts=new(StringComparer.Ordinal);
    static AchievementView()
    {
        Add("Base game", "Ghost Stories|Spatial Awareness|Brave New World|Liberty Wall|No Man's Land|Blimey O'Riley|Struck Down|Waste Not|Homecoming|Go Ugly Early|Legends Never Die|It Came from Below!|Federation Day|Sleeping Beauty|Carbon Faceprint|Birds of Prey|Burn Baby Burn|The Hunted|Jungle Ghosts|Clockwork|Deep Freeze|Atlas Falls|Grindin'|Piece of cake|Into the Deep|David & Goliath|End of the Line|Cog in the machine|Sin City|Jack-pot|All or nothing|End of your rope|Severed Ties|Fly-by-wire|Loki|They look like ants|The Ghost Killer|Tickets please|Audiophile|No Man Left|Sprinter|Made it Out Alive|Completionist|Cabin Fever|City Dweller|Any Means necessary|Trash Picker|Throttled Escape|Safeguard|You've earned it");
        Add("Onslaught", "Undiscovered Truths|Pushing Ahead|Weapon Facility|Survived Nightfall|Speed Slayer|Turnabout is Fair Play|Nightfall Completionist|Throttled Survival|Phantom Exterminator|Egg-stra XP!|Pea Shooter");
        Add("Devastation", "The Belly of the Beast|Come Up For Air|Survived Mayday|Upping the Ante|Mayday Completionist|Inquisitive Mind|Deforestation|Big Game Trapper|Egg-stra Devastation!|The Architect");
        Add("Invasion", "Targets Acquired|A Bridge To Somewhere|Escaped Awakening|Twice The Fun|Awakening Completionist|Spelunker|Dog Fight|Egg-stra Awakening!|Like A Glove|Well Rounded");
        Add("Nemesis", "Mass Exodus|Unstoppable|Nemesis Completionist|The Final Chapter|Postmaster|Eggstra Nemesis!|Timing is Everything|You Wish|Always Hard|Hat Trick");
    }
    static void Add(string pack,string names){foreach(var n in names.Split('|'))Ghosts.Add(Normalize(n),pack);}
    public static bool Supports(object? game)
    {
        return Prop(game,"Id")?.ToString()=="572802557";
    }
    public static string Group(object? row)=>Ghosts.TryGetValue(Normalize(Prop(row,"Name")?.ToString()??""),out var pack)?pack:"Unclassified";
    public sealed class Settings { public int Sort; public string Pack="All packs"; internal object? LastGame; }
    static readonly ConditionalWeakTable<object,Settings> States=new();
    public static Settings For(object model)
    {
        var s=States.GetValue(model,_=>new Settings());object? game=Prop(model,"SelectedGame");
        if(!ReferenceEquals(game,s.LastGame)){s.Pack="All packs";s.LastGame=game;}
        return s;
    }
    public static object[] Arrange(IEnumerable rows,bool grouped,int sort,string pack)
    {
        IEnumerable<object> result=rows.Cast<object>();
        if(grouped && pack!="All packs")result=result.Where(r=>Group(r)==pack);
        IOrderedEnumerable<object> ordered=result.OrderBy(r=>grouped?Array.IndexOf(Packs,Group(r)):0);
        if(sort==1)ordered=ordered.ThenBy(r=>Prop(r,"Name")?.ToString(),StringComparer.CurrentCultureIgnoreCase);
        if(sort==2)ordered=ordered.ThenByDescending(r=>Prop(r,"Name")?.ToString(),StringComparer.CurrentCultureIgnoreCase);
        return ordered.ToArray();
    }
    public static Array Transform(Array rows,object model)
    {
        var s=For(model);var selected=Arrange(rows,Supports(Prop(model,"SelectedGame")),s.Sort,s.Pack);
        Array typed=Array.CreateInstance(rows.GetType().GetElementType()!,selected.Length);
        for(int i=0;i<selected.Length;i++)typed.SetValue(selected[i],i);
        return typed;
    }
    public static bool StartsGroup(IEnumerable? rows,object row)
    {
        string? previous=null;
        if(rows is null)return false;
        foreach(object current in rows)
        {
            string group=Group(current);
            if(ReferenceEquals(current,row))return previous!=group;
            previous=group;
        }
        return false;
    }
    public static Border Divider(string group)=>new Border {
        Name="AchievementPackDivider", BorderBrush=new SolidColorBrush(Color.Parse("#58DBA1")),
        BorderThickness=new Thickness(0,2,0,0),Margin=new Thickness(0,14,0,8),Padding=new Thickness(0,7,0,0),
        HorizontalAlignment=HorizontalAlignment.Stretch,
        Child=new TextBlock {Text=group,FontSize=14,FontWeight=FontWeight.SemiBold,Foreground=new SolidColorBrush(Color.Parse("#58DBA1"))}
    };
    public static void Attach(Window owner,object model,Panel panel,Button before)
    {
        var controls=new StackPanel { Spacing=5,Margin=new Thickness(0,12,0,10) };
        var sort=new ComboBox {Name="AchievementNameSort",ItemsSource=Sorts,SelectedIndex=For(model).Sort,HorizontalAlignment=HorizontalAlignment.Stretch};
        var packs=new ComboBox {Name="AchievementPackFilter",ItemsSource=Packs,SelectedIndex=0,HorizontalAlignment=HorizontalAlignment.Stretch};
        var packLabel=new TextBlock {Text="BASE GAME / DLC",FontSize=11,Opacity=0.75};
        var info=new TextBlock {FontSize=11,Opacity=0.7,TextWrapping=TextWrapping.Wrap};
        controls.Children.Add(new TextBlock{Text="SORT ACHIEVEMENTS",FontSize=11,Opacity=0.75});controls.Children.Add(sort);
        controls.Children.Add(packLabel);controls.Children.Add(packs);controls.Children.Add(info);
        panel.Children.Insert(panel.Children.IndexOf(before),controls);
        void Changed()=>model.GetType().GetMethod("Changed",Flags)?.Invoke(model,new object[]{"VisibleAchievements"});
        bool updating=false;
        sort.SelectionChanged+=(_,_)=>{if(updating)return;For(model).Sort=Math.Max(0,sort.SelectedIndex);Changed();};
        packs.SelectionChanged+=(_,_)=>{if(updating)return;For(model).Pack=packs.SelectedItem as string??"All packs";Changed();};
        void Update()
        {
            updating=true;
            bool grouped=Supports(Prop(model,"SelectedGame"));var s=For(model);
            packs.IsVisible=packLabel.IsVisible=grouped;packs.SelectedItem=s.Pack;
            info.IsVisible=grouped;info.Text=s.Pack=="All packs"?"Base game → Onslaught → Devastation → Invasion → Nemesis":"Showing "+s.Pack;
            updating=false;
        }
        if(model is System.ComponentModel.INotifyPropertyChanged npc)
        {
            System.ComponentModel.PropertyChangedEventHandler changed=(_,e)=>{if(e.PropertyName is "SelectedGame" or "VisibleAchievements" or "")Update();};
            npc.PropertyChanged+=changed;owner.Closed+=(_,_)=>npc.PropertyChanged-=changed;
        }
        // Keep real achievement rows selectable; draw a heading only at each visible pack boundary.
        var list=owner.GetLogicalDescendants().OfType<ListBox>().FirstOrDefault(l=>l.Name=="AchievementLabsAchievementList");
        if(list?.ItemTemplate is IDataTemplate template)
        {
            list.ItemTemplate=new FuncDataTemplate<object>((row,_)=>
            {
                // Avalonia clears item content while recycling virtualized rows.
                if(row is null)return null;
                Control? original=template.Build(row);
                if(!Supports(Prop(model,"SelectedGame")))return original;
                var box=new StackPanel {Spacing=3};
                var divider=Divider(Group(row));divider.Tag=row;divider.IsVisible=StartsGroup(list.ItemsSource,row);box.Children.Add(divider);
                if(original!=null)box.Children.Add(original);return box;
            },false);
            list.PropertyChanged+=(_,e)=>
            {
                if(e.Property.Name!="ItemsSource")return;
                Avalonia.Threading.Dispatcher.UIThread.Post(()=> {
                    foreach(var divider in list.GetLogicalDescendants().OfType<Border>().Where(b=>b.Name=="AchievementPackDivider"))
                        divider.IsVisible=Supports(Prop(model,"SelectedGame")) && divider.Tag is object row && StartsGroup(list.ItemsSource,row);
                });
            };
        }
        Update();
    }
}
