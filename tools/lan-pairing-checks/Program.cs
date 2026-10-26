using System.Buffers.Binary;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using AchievementLabs.Core;

static void Check(bool value, string failure) { if (!value) throw new Exception(failure); }
async Task Reject(Func<Task> action)
{
    try { await action(); }
    catch (Exception ex) when (ex is InvalidDataException or EndOfStreamException or OperationCanceledException or IOException or System.Security.Authentication.AuthenticationException) { return; }
    throw new Exception("Invalid operation was accepted.");
}

foreach (var ip in new[] { "127.0.0.1", "10.1.2.3", "192.168.1.1", "172.16.1.2", "172.31.255.254", "169.254.1.1" }) Check(LanPairing.IsLocalAddress(IPAddress.Parse(ip)), "Local address rejected.");
foreach (var ip in new[] { "8.8.8.8", "0.0.0.0", "172.32.0.1", "224.0.0.1", "::ffff:8.8.8.8" }) Check(!LanPairing.IsLocalAddress(IPAddress.Parse(ip)), "Public or multicast address accepted.");
Console.WriteLine("PASS: local IPv4 destinations only.");

async Task Exchange(bool acceptHost, bool acceptClient, bool wrongAccount = false, string session = "")
{
    using var host = new LanPairing.Host(loopbackOnly: true);
    using var serverIdentity = LanPairing.NewIdentity(); using var clientIdentity = LanPairing.NewIdentity();
    using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(12));
    string? serverCode = null, clientCode = null; var created = 0; var imported = false; var remembered = false;
    var sending = host.SendAsync(serverIdentity, _ => false, review => { serverCode = review.Code; return Task.FromResult(new LanPairing.Approval(acceptHost, true)); },
        () => { created++; return Task.FromResult(MobileTransfer.Create("XBL3.0 x=hash;synthetic-only", "123", "", null, signInOnly: true)); },
        (fp, save) => { Check(fp == LanPairing.Fingerprint(clientIdentity), "Unexpected client identity."); remembered = save; }, timeout.Token);
    var receiving = LanPairing.ReceiveAsync(new("127.0.0.1", host.Port, session), clientIdentity, _ => false,
        review => { clientCode = review.Code; return Task.FromResult(new LanPairing.Approval(acceptClient, true)); },
        (transfer, token) => { token.ThrowIfCancellationRequested(); var result = PcPresenceTransfer.Read(transfer.Bytes, transfer.PairingKey, wrongAccount ? "456" : "123", DateTimeOffset.UtcNow); imported = result.Authorization == "XBL3.0 x=hash;synthetic-only"; return Task.CompletedTask; }, timeout.Token);
    if (acceptHost && acceptClient && !wrongAccount && session == "")
    {
        await Task.WhenAll(sending, receiving);
        Check(serverCode == clientCode && serverCode?.Length == 9, "Comparison codes differ.");
        Check(created == 1 && imported && remembered && receiving.Result.Remember, "Transfer/acknowledgement failed.");
        Check(receiving.Result.PeerFingerprint == LanPairing.Fingerprint(serverIdentity), "Unexpected server identity.");
    }
    else
    {
        try { await receiving; throw new Exception("Invalid import succeeded."); }
        catch (Exception ex) when (ex is InvalidDataException or IOException or OperationCanceledException) { }
        timeout.Cancel(); await Reject(() => sending);
        Check(!remembered && !imported, "Rejected transfer was imported or remembered.");
        if (!acceptHost || !acceptClient || session.Length > 0) Check(created == 0, "Authorization created before both approvals.");
    }
}
await Exchange(true, true); Console.WriteLine("PASS: mutual TLS, matching comparison code, encrypted synthetic transfer, same-account import, receipt acknowledgement.");
await Exchange(false, true); await Exchange(true, false); Console.WriteLine("PASS: either device declining prevents authorization creation and trust.");
await Exchange(true, true, wrongAccount: true); Console.WriteLine("PASS: different account rejected; no successful receipt/trust.");
await Exchange(true, true, session: new string('0', 32)); Console.WriteLine("PASS: substituted discovery invitation rejected before authorization creation.");

using (var host = new LanPairing.Host(loopbackOnly: true))
using (var udp = new UdpClient())
using (var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(5)))
{
    await udp.SendAsync(Encoding.ASCII.GetBytes("AL-LAN-PAIR-1?"), new IPEndPoint(IPAddress.Loopback, LanPairing.DiscoveryPort), timeout.Token);
    var reply = Encoding.ASCII.GetString((await udp.ReceiveAsync(timeout.Token)).Buffer);
    Check(reply.StartsWith($"AL-LAN-PAIR-1|{host.Port}|") && reply.Split('|').Length == 3 && !reply.Contains("123" + "synthetic"), "Invalid discovery reply.");
}
Console.WriteLine("PASS: local discovery returns invitation and port without account authorization.");

foreach (var size in new[] { -1, 0, 1, 196609, int.MaxValue })
{
    var prefix = new byte[4]; BinaryPrimitives.WriteInt32BigEndian(prefix, size);
    await Reject(async () => await LanPairing.ReadAsync<object>(new MemoryStream(prefix), CancellationToken.None));
}
var duplicate = Encoding.UTF8.GetBytes("{\"Accept\":true,\"Accept\":false}");
using (var frame = new MemoryStream())
{
    var prefix = new byte[4]; BinaryPrimitives.WriteInt32BigEndian(prefix, duplicate.Length); frame.Write(prefix); frame.Write(duplicate); frame.Position = 0;
    await Reject(async () => await LanPairing.ReadAsync<object>(frame, CancellationToken.None));
}
Console.WriteLine("PASS: invalid lengths and duplicate JSON fields rejected.");

if (OperatingSystem.IsWindows() || OperatingSystem.IsMacOS())
{
    var folder = Path.Combine(Path.GetTempPath(), "Labs-LAN-synthetic-check-" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(folder); var path = Path.Combine(folder, "test.protected");
    try
    {
        string fingerprint;
        using var peer = LanPairing.NewIdentity(); var peerFingerprint = LanPairing.Fingerprint(peer);
        using (var store = new LanPairingStore(path)) { fingerprint = LanPairing.Fingerprint(store.Identity); store.Remember(peerFingerprint, "123"); }
        using (var loaded = new LanPairingStore(path))
        {
            Check(fingerprint == LanPairing.Fingerprint(loaded.Identity) && loaded.IsTrusted(peerFingerprint, "123") && !loaded.IsTrusted(peerFingerprint, "456"), "Trust not stable or not account scoped.");
        }
        var cipher = File.ReadAllBytes(path); cipher[0] ^= 0x80; File.WriteAllBytes(path, cipher);
        try { using var invalid = new LanPairingStore(path); throw new Exception("Tampered storage accepted."); }
        catch (CryptographicException) { }
    }
    finally { if (File.Exists(path)) File.Delete(path); Directory.Delete(folder); }
    Console.WriteLine("PASS: OS-protected identity persists, trust is account scoped, tampered store rejected; isolated test data removed.");
}
Console.WriteLine("No Xbox services contacted; no account credentials used. All network tests bound to loopback.");
