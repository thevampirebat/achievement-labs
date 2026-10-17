using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
namespace AchievementLabs.Core;
public sealed record MobileTransferFile(byte[] Bytes, string PairingKey);
public static class MobileTransfer
{
    public static MobileTransferFile Create(string authorization, string xuid, string eventToken, DateTimeOffset? authorizationExpiresAt)
    {
        if (!ulong.TryParse(xuid,out _) || string.IsNullOrWhiteSpace(authorization)) throw new InvalidDataException("Connect an Xbox account first.");
        var key = RandomNumberGenerator.GetBytes(32); var nonce = RandomNumberGenerator.GetBytes(12);
        var plain = JsonSerializer.SerializeToUtf8Bytes(new { schemaVersion=1,xuid,authorization,eventToken,expiresAt=DateTimeOffset.UtcNow.AddMinutes(10).ToUnixTimeSeconds(),authorizationExpiresAt=authorizationExpiresAt?.ToUniversalTime().ToString("O") });
        try {
            var encrypted = new byte[plain.Length]; var tag = new byte[16];
            using var aes = new AesGcm(key,16);
            aes.Encrypt(nonce,plain,encrypted,tag,Encoding.UTF8.GetBytes("AchievementLabs-PC-Transfer-v1"));
            var envelope = JsonSerializer.SerializeToUtf8Bytes(new { schemaVersion=1,nonce=Convert.ToBase64String(nonce),ciphertext=Convert.ToBase64String(encrypted),tag=Convert.ToBase64String(tag) });
            return new(envelope,Convert.ToBase64String(key).TrimEnd('=').Replace('+','-').Replace('/','_'));
        } finally { CryptographicOperations.ZeroMemory(plain); CryptographicOperations.ZeroMemory(key); }
    }
}
