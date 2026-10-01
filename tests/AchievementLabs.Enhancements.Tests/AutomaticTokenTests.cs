using AchievementLabs.MultiSelect;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;

static class AutomaticTokenTests
{
    static void Check(bool b,string name){if(!b)throw new Exception(name);}
    sealed class Fake:HttpMessageHandler
    {
        public int EventsRequests;public string EventXuid="123";public string EventHash="hash";public bool Expired;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken token)
        {
            Check(request.Method==HttpMethod.Post && request.RequestUri!.ToString()=="https://xsts.auth.xboxlive.com/xsts/authorize","Only Microsoft authentication endpoint used");
            using var doc=JsonDocument.Parse(await request.Content!.ReadAsStringAsync(token));var root=doc.RootElement;
            string rp=root.GetProperty("RelyingParty").GetString()!;string input=root.GetProperty("Properties").GetProperty("UserTokens")[0].GetString()!;
            Check(root.GetProperty("Properties").GetProperty("SandboxId").GetString()=="RETAIL","Correct auth sandbox");
            string xuid=input=="wrong-user"?"999":"123",uhs="hash";
            if(rp=="http://events.xboxlive.com"){EventsRequests++;xuid=EventXuid;uhs=EventHash;Check(input!="wrong-user","Never mint an event token for a different account");}
            else Check(rp=="http://xboxlive.com","Account verification precedes event request");
            string json=JsonSerializer.Serialize(new {Token="synthetic-test-token",NotAfter=DateTimeOffset.UtcNow.AddHours(Expired?-1:12).ToString("O"),DisplayClaims=new{xui=new[]{new{xid=xuid,uhs}}}});
            return new HttpResponseMessage(HttpStatusCode.OK){Content=new StringContent(json)};
        }
    }
    public static void Run()
    {
        string Cache(string kind,string rp,DateTimeOffset expiry)=>JsonSerializer.Serialize(new{IdentityType=kind,RelyingParty=rp,TokenData=new{Token="synthetic-cache-token",NotAfter=expiry.ToString("O")}});
        var now=DateTimeOffset.UtcNow;
        Check(AutomaticEventToken.ParseCandidate(Encoding.UTF8.GetBytes(Cache("Utoken","http://auth.xboxlive.com",now.AddHours(1))))!=null,"Current user token accepted");
        Check(AutomaticEventToken.ParseCandidate(Encoding.UTF8.GetBytes(Cache("Utoken","http://auth.xboxlive.com",now.AddHours(-1))))==null,"Expired cache token rejected");
        Check(AutomaticEventToken.ParseCandidate(Encoding.UTF8.GetBytes(Cache("Device","http://auth.xboxlive.com",now.AddHours(1))))==null,"Other identities excluded");
        Check(AutomaticEventToken.ParseCandidate(Encoding.UTF8.GetBytes(Cache("Utoken","http://other",now.AddHours(1))))==null,"Other audiences excluded");
        using var handler=new Fake();using var http=new HttpClient(handler);
        var candidates=new[]{new AutomaticEventToken.Candidate("wrong-user",now.AddHours(1)),new AutomaticEventToken.Candidate("correct-user",now.AddHours(1))};
        var grant=AutomaticEventToken.Acquire(http,"123",candidates,CancellationToken.None).GetAwaiter().GetResult();
        Check(grant!=null && handler.EventsRequests==1,"Only verified connected account gets event authorization");
        Check(grant!.Value=="x:XBL3.0 x=hash;synthetic-test-token","Expected event token format");
        Check(!grant.ToString().Contains("synthetic") && !candidates[0].ToString().Contains("wrong-user"),"Object diagnostics are redacted");
        handler.EventXuid="999";Check(AutomaticEventToken.Acquire(http,"123",candidates,CancellationToken.None).GetAwaiter().GetResult()==null,"Mismatched event account rejected");
        handler.EventXuid="123";handler.EventHash="wrong";Check(AutomaticEventToken.Acquire(http,"123",candidates,CancellationToken.None).GetAwaiter().GetResult()==null,"Mismatched user hash rejected");
        handler.EventHash="hash";handler.Expired=true;Check(AutomaticEventToken.Acquire(http,"123",candidates,CancellationToken.None).GetAwaiter().GetResult()==null,"Expired grant rejected");
        using var cancel=new CancellationTokenSource();cancel.Cancel();
        try{AutomaticEventToken.Acquire(http,"123",candidates,cancel.Token).GetAwaiter().GetResult();throw new Exception("Cancellation ignored");}catch(OperationCanceledException){}
        Console.WriteLine("PASS: synthetic token-cache parsing, identity/audience/expiry checks, account verification before event authorization, event-account/hash mismatch rejection, redacted diagnostics and cancellation. No real credentials accessed or authentication requests sent.");
    }
}
