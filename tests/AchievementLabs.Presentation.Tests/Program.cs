using System.Text.Json;
using AchievementLabs.Desktop.Presentation;
void Assert(bool condition,string message){if(!condition)throw new Exception(message);Console.WriteLine("PASS: "+message);}
var m=new FakeModel();
var load=SpooferTitleLoader.LoadAsync(m);
Assert(m.Lookups==1 && m.SpoofTitleName=="Selected game" && m.SpoofTitleImageUrl=="https://example.com/cover.jpg","Selected game is shown immediately and lookup starts automatically");
await SpooferTitleLoader.LoadAsync(m);
Assert(m.Lookups==1,"Repeated opening while lookup is running does not duplicate the request");
m.Pending.SetResult();await load;
Assert(m.SpoofTitleDetails=="Fresh Xbox metadata","Lookup result replaces placeholder details");
var other=new FakeModel {PresenceTitleId="9"};await SpooferTitleLoader.LoadAsync(other);
Assert(other.Lookups==0,"Mismatched selected title cannot populate another title");
var disconnected=new FakeModel {CanLookupSpoofTitle=false};await SpooferTitleLoader.LoadAsync(disconnected);
Assert(disconnected.Lookups==0 && disconnected.SpoofTitleName=="Selected game" && !disconnected.SpoofTitleDetails.Contains("Loading"),"Disconnected fallback shows selected game without attempting account requests");
var failed=new FakeModel();var failing=SpooferTitleLoader.LoadAsync(failed);failed.Pending.SetException(new IOException());await failing;
Assert(failed.Notice.Contains("retry"),"Lookup failures provide a retry message without unhandled exceptions");
var combined=new FakeModel {IsSpoofer=false,IsQueues=true};var combinedLoad=SpooferTitleLoader.LoadAsync(combined);Assert(combined.Lookups==1,"Automatic title lookup also runs when entering through Auto Unlock");combined.Pending.SetResult();await combinedLoad;
var outside=new FakeModel {IsSpoofer=false,IsQueues=false};await SpooferTitleLoader.LoadAsync(outside);Assert(outside.Lookups==0,"Title lookup does not start outside the combined session");
using var doc=JsonDocument.Parse("""
{"LocalizedProperties":[{"Images":[
{"ImagePurpose":"BoxArt","Width":2048,"Height":2048,"Uri":"//example.com/square"},
{"ImagePurpose":"SuperHeroArt","Width":3840,"Height":2160,"Uri":"//example.com/hero"},
{"ImagePurpose":"TitledHeroArt","Width":1920,"Height":1080,"Uri":"//example.com/full"}
]}]}
""");
Assert(WideArtwork.SelectWide(doc.RootElement)=="https://example.com/full","Artwork selection prefers full landscape title art over square covers and generic hero images");
using var unavailable=JsonDocument.Parse("""{"LocalizedProperties":[{"Images":[{"ImagePurpose":"Poster","Width":1080,"Height":1920,"Uri":"//example.com/poster"}]}]}""");
Assert(WideArtwork.SelectWide(unavailable.RootElement)==null,"Portrait-only catalog returns fallback instead of claiming it is wide art");
if(Environment.GetEnvironmentVariable("LABS_TEST_LIVE_CATALOG")=="1")foreach(var id in new[]{"1938834516","1794566092"}){
 var url=await WideArtwork.ResolveAsync(id,CancellationToken.None);
 Assert(url?.StartsWith("https://store-images.s-microsoft.com/")==true,"Live Microsoft catalog resolves wide art for title "+id);
}
var prefsFile=Path.Combine(Path.GetTempPath(),"AchievementLabs-Presentation-"+Guid.NewGuid().ToString("N"),"preferences.json");
var completionGames=new[]{new CompletionGame("1",50,100,true,true,false),new CompletionGame("2",200,200,true,true,true),new CompletionGame("3",0,900,false,false,false),new CompletionGame("1",50,100,true,true,false)};
var completion=CompletionSummary.Calculate(completionGames);
Assert(completion.Titles==3 && completion.Mythics==2 && completion.FullyCompleted==1,"Completion overview deduplicates titles and separates earned mythics from full completion");
Assert(completion.KnownTitles==2 && completion.Unlocked==250 && completion.Achievements==300 && Math.Abs(completion.Percentage!.Value-83.333333)<.001,"Overall completion is weighted by known achievements and excludes missing account progress");
Assert(CompletionSummary.Calculate(Array.Empty<object>()).Percentage==null,"An empty library shows unavailable percentage rather than fabricated zero progress");
Assert(CompletionSummary.Calculate(new[]{new CompletionGame("4",150,100,true,false,false)}).Percentage==100,"Completion percentage clamps excess unlock counts");
Assert(CompletionSummary.GamePercentage(completionGames[2])=="Progress unavailable" && CompletionSummary.GamePercentage(completionGames[0])=="50% complete","Per-game percentages distinguish known and unavailable progress");
var route=new LibraryRouteModel();var routeGame=new FakeGame();LibraryPresentation.OpenSession(route,routeGame,false);
Assert(ReferenceEquals(route.SelectedLibraryGame,routeGame) && ReferenceEquals(route.GamePassedToSession,routeGame) && route.Calls==1,"Library session action selects its row and invokes the existing session route once");
var prefs=new AppearancePreferences {BackgroundMode="Custom image",CustomBackgroundPath="C:/Example/background image.jpg",GlassTransparency=62,GlassBlur=65,GlassColour="#30223f",PersistentGameArtwork=false,OledMode=true};prefs.Save(prefsFile);var restored=AppearancePreferences.Load(prefsFile);
Assert(restored.GlassBlur==65 && restored.GlassColour=="#30223F","Custom glass blur and colour survive save/reload");
prefs.GlassBlur=double.NaN;prefs.GlassColour="bad colour";prefs.Normalize();Assert(prefs.GlassBlur==30 && prefs.GlassColour=="#111E27","Invalid blur and colour recover to safe defaults");
prefs.GlassBlur=0;prefs.Save(prefsFile);Assert(AppearancePreferences.Load(prefsFile).GlassBlur==0,"No-blur preference survives save/reload");
Assert(restored.BackgroundMode=="Custom image" && restored.CustomBackgroundPath==prefs.CustomBackgroundPath && restored.GlassTransparency==62 && restored.OledMode && !restored.PersistentGameArtwork,"Appearance background, transparency, OLED and persistence survive save/reload");
prefs.GlassTransparency=200;prefs.BackgroundMode="invalid";prefs.Save(prefsFile);restored=AppearancePreferences.Load(prefsFile);Assert(restored.GlassTransparency==85 && restored.BackgroundMode=="Game artwork","Invalid appearance values are normalized safely");
File.WriteAllText(prefsFile,"invalid json");Assert(AppearancePreferences.Load(prefsFile).GlassTransparency==35,"Corrupt appearance preferences fall back to defaults");
var clock=new DateTimeOffset(2026,10,21,12,0,0,TimeSpan.Zero);var policy=new PlaytimeRefreshPolicy();
Assert(!policy.ShouldRefresh(true,"42",false,false,clock),"Opening session waits for playtime reader readiness/cooldown");
Assert(policy.ShouldRefresh(true,"42",true,false,clock.AddSeconds(1)),"Opening session requests playtime once the reader is ready");
Assert(!policy.ShouldRefresh(true,"42",true,false,clock.AddSeconds(3)),"Repeated page notifications do not duplicate the opening playtime read");
Assert(policy.ShouldRefresh(true,"43",true,false,clock.AddSeconds(15)),"Changing the game requests its own playtime");
policy.ShouldRefresh(false,"43",true,false,clock.AddSeconds(20));Assert(policy.ShouldRefresh(true,"43",true,true,clock.AddSeconds(30)),"Reopening through Auto Unlock also requests playtime");
Assert(!policy.ShouldRefresh(true,"43",false,true,clock.AddMinutes(6)),"Periodic queue-route refresh still respects rate-limit readiness");
Assert(policy.ShouldRefresh(true,"43",true,true,clock.AddMinutes(7)),"Queue-route playtime refresh resumes after the cooldown");
Directory.Delete(Path.GetDirectoryName(prefsFile)!,true);
class FakeGame {public string Id=>"42";public string Name=>"Selected game";public string ImageUrl=>"https://example.com/cover.jpg";}
record CompletionGame(string Id,int Completed,int Total,bool ProgressKnown,bool BaseComplete,bool FullyComplete,bool NoDefinitionsReturned=false);
class LibraryRouteModel {
 public object? SelectedLibraryGame {get;set;}public object? SelectedGame {get;private set;}public object? GamePassedToSession;public int Calls;
 public void OpenGameSpoofer(){GamePassedToSession=SelectedGame;Calls++;}
}
class FakeModel {
 public FakeGame SelectedGame {get;}=new();public string PresenceTitleId {get;set;}="42";public bool IsSpoofer {get;set;}=true;public bool IsQueues {get;set;}
 public bool CanLookupSpoofTitle {get;set;}=true;public string SpoofTitleName {get;set;}="";public string SpoofTitleDetails {get;set;}="";
 public string? SpoofTitleImageUrl {get;set;}public string Notice {get;set;}="";public int Lookups;
 public TaskCompletionSource Pending {get;}=new();
 public async Task LookupSpoofTitleAsync(){Lookups++;await Pending.Task;SpoofTitleDetails="Fresh Xbox metadata";}
}
