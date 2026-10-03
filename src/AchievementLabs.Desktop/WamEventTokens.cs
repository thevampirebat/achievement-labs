using System.Net.Http;
using System.Text;
using System.Text.Json;
using Avalonia.Controls;
using Avalonia.Layout;
using AchievementLabs.MultiSelect;
using Windows.Security.Authentication.Web.Core;
using Windows.Security.Credentials;
using XboxAuthNet.XboxLive.Crypto;

namespace AchievementLabs.Desktop;

// Uses the Windows account broker and a device-bound exchange, rather than
// re-minting a cached Gaming Services user token. No token values are logged.
public static class WamEventTokens
{
    const string ClientId = "000000004424da1f";
    public static async Task<AutomaticEventToken.Grant?> AcquireAsync(Window owner, string xuid, CancellationToken ct)
    {
        if (!OperatingSystem.IsWindows()) return null;
        var provider = await WebAuthenticationCoreManager.FindAccountProviderAsync("https://login.live.com", "consumers");
        if (provider == null) return null;
        var found = await WebAuthenticationCoreManager.FindAllAccountsAsync(provider, ClientId);
        var accounts = found.Accounts.ToArray();
        if (accounts.Length == 0) return null;
        ct.ThrowIfCancellationRequested();
        var dialog = new Window { Title = "Choose your Windows Xbox account", Width = 480, Height = 240, WindowStartupLocation = WindowStartupLocation.CenterOwner };
        var choices = new ComboBox { ItemsSource = accounts.Select(a => a.UserName).ToArray(), SelectedIndex = 0 };
        var submit = new Button { Content = "Get event token" };
        var cancel = new Button { Content = "Cancel" };
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
        buttons.Children.Add(submit); buttons.Children.Add(cancel);
        var panel = new StackPanel { Margin = new Avalonia.Thickness(18), Spacing = 15 };
        panel.Children.Add(new TextBlock { Text = "Choose the account connected to Achievement Labs.", TextWrapping = Avalonia.Media.TextWrapping.Wrap });
        panel.Children.Add(choices); panel.Children.Add(buttons); dialog.Content = panel;
        submit.Click += (_, _) => dialog.Close(choices.SelectedIndex);
        cancel.Click += (_, _) => dialog.Close(-1);
        int? selected = await dialog.ShowDialog<int?>(owner);
        if (selected is not int index || index < 0 || index >= accounts.Length) throw new OperationCanceledException();
        ct.ThrowIfCancellationRequested();
        var result = await WebAuthenticationCoreManager.GetTokenSilentlyAsync(new WebTokenRequest(provider, "service::user.auth.xboxlive.com::MBI_SSL", ClientId), accounts[index]);
        if (result.ResponseStatus != WebTokenRequestStatus.Success) return null;
        var msa = result.ResponseData.FirstOrDefault()?.Token;
        if (string.IsNullOrWhiteSpace(msa)) return null;
        using var http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromSeconds(30) };
        return await ExchangeAsync(http, msa, xuid, ct);
    }

    public static async Task<AutomaticEventToken.Grant?> ExchangeAsync(HttpClient http, string msa, string xuid, CancellationToken ct)
    {
        var signer = new XboxRequestSigner(new ECDCertificatePopCryptoProvider());
        async Task<JsonDocument?> Post(string url, object body, bool signed = false)
        {
            var json = JsonSerializer.Serialize(body);
            using var request = new HttpRequestMessage(HttpMethod.Post, url) { Content = new StringContent(json, Encoding.UTF8, "application/json") };
            request.Headers.TryAddWithoutValidation("x-xbl-contract-version", "2");
            if (signed) request.Headers.TryAddWithoutValidation("Signature", signer.SignRequest(url, "", json));
            using var response = await http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode) return null;
            return JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
        }
        string? Token(JsonDocument? doc) => doc?.RootElement.TryGetProperty("Token", out var t) == true ? t.GetString() : null;
        using var device = await Post("https://device.auth.xboxlive.com/device/authenticate", new { Properties = new { AuthMethod = "RPS", SiteName = "user.auth.xboxlive.com", RpsTicket = "t=" + msa, Version = Environment.OSVersion.Version.ToString(), ProofKey = signer.ProofKey }, RelyingParty = "http://auth.xboxlive.com", TokenType = "JWT" }, true);
        if (Token(device) is not string deviceToken) return null;
        using var user = await Post("https://user.auth.xboxlive.com/user/authenticate", new { Properties = new { AuthMethod = "RPS", SiteName = "user.auth.xboxlive.com", RpsTicket = "t=" + msa }, RelyingParty = "http://auth.xboxlive.com", TokenType = "JWT" });
        if (Token(user) is not string userToken) return null;
        async Task<JsonDocument?> Xsts(string rp) => await Post("https://xsts.auth.xboxlive.com/xsts/authorize", new { Properties = new { SandboxId = "RETAIL", UserTokens = new[] { userToken }, DeviceToken = deviceToken }, RelyingParty = rp, TokenType = "JWT" });
        using var identity = await Xsts("http://xboxlive.com");
        if (identity == null) return null;
        var claim = identity.RootElement.GetProperty("DisplayClaims").GetProperty("xui")[0];
        if (!claim.TryGetProperty("xid", out var xid) || xid.GetString() != xuid) throw new InvalidDataException("The selected Windows account does not match the connected Xbox account.");
        var hash = claim.GetProperty("uhs").GetString();
        using var events = await Xsts("http://events.xboxlive.com");
        if (events == null || Token(events) is not string eventToken) return null;
        var eventClaim = events.RootElement.GetProperty("DisplayClaims").GetProperty("xui")[0];
        if (string.IsNullOrWhiteSpace(hash) || eventClaim.GetProperty("uhs").GetString() != hash) throw new InvalidDataException("Event account mismatch.");
        if (eventClaim.TryGetProperty("xid", out var eventXid) && eventXid.GetString() != xuid) throw new InvalidDataException("Event account mismatch.");
        var expires = events.RootElement.GetProperty("NotAfter").GetDateTimeOffset();
        if (expires <= DateTimeOffset.UtcNow.AddMinutes(1)) return null;
        return new AutomaticEventToken.Grant("x:XBL3.0 x=" + hash + ";" + eventToken, expires);
    }
}
