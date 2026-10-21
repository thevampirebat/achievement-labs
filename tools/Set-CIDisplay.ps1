# The hosted Windows display can clamp test windows to a 900px desktop.
# This helper is restricted to disposable GitHub Actions runners.
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Display configuration is restricted to GitHub Actions.' }
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
public static class PresentationCiDisplay {
    // DEVMODEW: https://learn.microsoft.com/windows/win32/api/wingdi/ns-wingdi-devmodew
    [StructLayout(LayoutKind.Explicit, Size=220)]
    public struct Mode {
        [FieldOffset(68)] public ushort Size;
        [FieldOffset(72)] public int Fields;
        [FieldOffset(168)] public int BitsPerPixel;
        [FieldOffset(172)] public int Width;
        [FieldOffset(176)] public int Height;
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    static extern bool EnumDisplaySettingsW(string device, int index, ref Mode mode);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    static extern int ChangeDisplaySettingsExW(string device, ref Mode mode, IntPtr hwnd, uint flags, IntPtr param);
    public static string Configure() {
        var modes = new List<Mode>();
        for (int i=0; ; i++) {
            var mode = new Mode { Size=220 };
            if (!EnumDisplaySettingsW(null, i, ref mode)) break;
            if (mode.Width>=1920 && mode.Height>=1080 && mode.BitsPerPixel==32) modes.Add(mode);
        }
        if (modes.Count==0) throw new Exception("The CI display has no supported 1920x1080 or larger mode.");
        var selected = modes.OrderBy(m=>m.Height>=1200 ? 0 : 1).ThenBy(m=>(long)m.Width*m.Height).First();
        selected.Fields=0x00080000 | 0x00100000; // DM_PELSWIDTH | DM_PELSHEIGHT
        int result=ChangeDisplaySettingsExW(null, ref selected, IntPtr.Zero, 0, IntPtr.Zero);
        if (result!=0) throw new Exception("CI display configuration failed: " + result);
        return "CI display: " + selected.Width + "x" + selected.Height;
    }
}
'@
[PresentationCiDisplay]::Configure()
