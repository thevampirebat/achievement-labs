namespace AchievementLabs.Services.Xbox360;

// The upstream tag omits its private signing dependency. No signing keys are packaged.
internal static class Xbox360ConSigningMaterial
{
    private static byte[] Missing() => throw new NotSupportedException("Xbox 360 profile signing is unavailable: the upstream public source omits its signing dependency. Profile browsing and backups remain available.");
    public static byte[] Certificate => Missing();
    public static byte[] PrimeP => Missing();
    public static byte[] PrimeQ => Missing();
}
