# Achievement Labs — Apple Silicon Mac desktop preview

This is an unpublished prototype of the Windows/Avalonia desktop interface, targeting Apple Silicon (M1 or newer) and macOS 14 or later. It is the unofficial vampirebat fork of https://github.com/Achievement-Labs/achievement-labs.

The first build retains Home, Library and search, achievements, Game Session/spoofing/queues, appearance controls, and the Xbox 360 exported-profile editor with backups and signed export. Original profiles remain untouched. Copying a profile back to a console stays a separate step.

Windows Xbox-app attachment, Windows account-broker token retrieval, GFWL injection and local Windows Steam/Epic/Ubisoft integrations are unavailable in this preview. Windows-only navigation is hidden. The app uses your Microsoft browser sign-in instead; complete sign-in in Settings → Account by pasting the final redirect into the app, never into chat. Remembered sign-in and event tokens use authenticated encryption backed by this Mac user's Keychain. A rejected/locked Keychain does not fall back to plaintext. Sign-in and live Xbox requests still require testing on your own Mac.

Event tokens can be entered in Settings using the existing account-match checks. Automatic Windows-broker acquisition is not available on Mac. Direct Mac event-token acquisition has not yet been verified. Browser sign-in for ordinary account access does not depend on getting an event token.

For this first preview, Mac updates are manual downloads from https://github.com/thevampirebat/achievement-labs/releases. It does not select or install Windows update packages. Event JSON/catalogue updates continue to use Achievement-Labs/achievement-labs.

The .app is self-contained and needs no separate .NET installation. It is ad-hoc signed for testing, not Developer ID signed or notarized. Normal public Mac distribution still needs that signing/notarization step. Do not disable macOS security protections.

Build on a Mac with .NET 9 SDK: `bash tools/macos/build-preview.sh`. Output: `artifacts/macos-preview/AchievementLabs-macOS-0.1.0.3-arm64.zip`. The app contains only the approved reusable CON identity; no personal profiles, account sessions or custom signing stores are packaged. CI uses a synthetic profile to check editing/signing and renders disconnected screens without Xbox account/event requests.

## Preview 0.1.0.3 startup checks

The app now keeps its self-contained runtime beside the entry point instead of relying on runtime symlinks. The downloadable ZIP is extracted and launched through macOS LaunchServices from /, with normal startup and a visible native window checked separately from the synthetic profile smoke test.

If it still does not open, check ~/Library/Logs/AchievementLabs/startup.log. This report includes only version, runtime/architecture, startup stages and exception type names; it excludes sign-in data, profile contents and exception messages. A managed startup failure also displays a native alert. A failure before the .NET runtime starts may produce no report. The app remains ad-hoc signed for testing, without Developer ID notarization.

When Apple Silicon runners are unavailable, the ARM64 package can be cross-built and ad-hoc signed on an Intel Mac. CI then launches a native Intel sibling built from the same source to exercise extracted ZIP/LaunchServices startup, Keychain and profile operations. BUILD-INFO.json identifies the native check architecture; an Intel sibling pass does not claim native ARM64 execution. The ARM64 package separately checks that libhostfxr is an actual ARM64 Mach-O file rather than an extracted symlink's text.


Preview 0.1.0.3 uses a native, ephemeral WebKit sign-in window. The Mac button now captures the registered Microsoft desktop callback before the landing page clears its authorization code and completes the existing PKCE/state-protected exchange automatically. Callback data stays in an anonymous process pipe; it is not written to logs, browser history, the clipboard or a callback file. Closing the window cancels sign-in. Windows retains its existing manual fallback. A synthetic native WebKit test verifies callback capture without requesting Microsoft or using account credentials; actual sign-in and two-factor behaviour still require the user's Mac.
