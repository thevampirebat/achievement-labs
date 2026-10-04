using AchievementLabs.MultiSelect;
using System.Reflection;
using System.Net;

public static class PortTests
{
 public sealed class Session {public string EventsToken{get;set;}="";}
 public sealed class Model {public string EventTokenInput{get;set;}="";}
 static void Assert(bool value,string message){if(!value)throw new Exception(message);}
 sealed class Handler:HttpMessageHandler
 {
  public int Calls;
  protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage r,CancellationToken ct)
  {
   Calls++;Assert(r.Method==HttpMethod.Get && r.RequestUri!.Host=="profile.xboxlive.com","Read-only profile destination");
   Assert(r.Headers.GetValues("Authorization").Single()=="synthetic-auth","Configured authorization");
   return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK));
  }
 }
 public static void Run()
 {
  QueuePresenceTokenTests.Run();
  var model=new Model();var session=new Session();
  var grant=new AutomaticEventToken.Grant("synthetic-event-token",DateTimeOffset.UtcNow.AddHours(1));
  TokenPresentation.Install(model,session,grant,"",false);
  Assert(model.EventTokenInput==grant.Value && session.EventsToken==grant.Value,"Auto token shown and active");
  model.EventTokenInput="manual-edit";
  var newer=new AutomaticEventToken.Grant("synthetic-new-token",DateTimeOffset.UtcNow.AddHours(1));
  TokenPresentation.Install(model,session,newer,grant.Value,false);
  Assert(model.EventTokenInput=="manual-edit" && session.EventsToken==grant.Value,"Background preserves both manual edit and active token");
  TokenPresentation.ClearOwnInput(model,newer.Value);Assert(model.EventTokenInput=="manual-edit","Clear preserves manual input");
  model.EventTokenInput="";session.EventsToken="saved-manual-token";
  Assert(!TokenPresentation.Install(model,session,newer,grant.Value,false) && session.EventsToken=="saved-manual-token" && model.EventTokenInput=="","Saved active token protected with empty box");
  model.EventTokenInput=grant.Value;session.EventsToken=grant.Value;
  Assert(TokenPresentation.Install(model,session,newer,grant.Value,false) && model.EventTokenInput==newer.Value && session.EventsToken==newer.Value,"Owned background refresh remains supported");
  TokenPresentation.Install(model,session,newer,"",true);Assert(model.EventTokenInput==newer.Value,"Explicit retrieval shows token");
  TokenPresentation.ClearOwnInput(model,newer.Value);Assert(model.EventTokenInput=="","Own token cleared");
  var h=new Handler();using var http=new HttpClient(h);
  Assert(PresenceDiagnostics.Check(http,"synthetic-auth","1",CancellationToken.None).GetAwaiter().GetResult()==200 && h.Calls==1,"Read-only auth test");
  var response=PresenceDiagnostics.Observe(Task.FromResult((401,"private-response-must-not-be-displayed")),new object(),"638965135").GetAwaiter().GetResult();
  Assert(response.Item1==401 && PresenceDiagnostics.Explain(401).Contains("event token is separate"),"401 preserved and explained");
  Assert(PresenceDiagnostics.Explain(200).Contains("does not guarantee"),"No false playtime promise");
  Console.WriteLine("PASS: token display, manual-edit preservation, explicit reveal source, clear behavior and read-only presence diagnostics. No real credentials used.");
 }
}
