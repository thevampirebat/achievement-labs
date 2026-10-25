# Achievement Labs — Apple Silicon Mac desktop preview

This is an unpublished prototype of the Windows/Avalonia desktop interface, targeting Apple Silicon (M1 or newer) and macOS 14 or later. It is the unofficial vampirebat fork of https://github.com/Achievement-Labs/achievement-labs.

The first build retains Home, Library and search, achievements, Game Session/spoofing/queues, appearance controls, and the Xbox 360 exported-profile editor with backups and signed export. Original profiles remain untouched. Copying a profile back to a console stays a separate step.

Windows Xbox-app attachment, Windows account-broker token retrieval, GFWL injection and local Windows Steam/Epic/Ubisoft integrations are unavailable in this preview. Windows-only navigation is hidden. The app uses your Microsoft browser sign-in instead; complete sign-in in Settings → Account by pasting the final redirect into the app, never into chat. Remembered sign-in and event tokens use authenticated encryption backed by this Mac user's Keychain. A rejected/locked Keychain does not fall back to plaintext. Sign-in and live Xbox requests still require testing on your own Mac.

Event tokens can be entered in Settings using the existing account-match checks. Automatic Windows-broker acquisition is not available on Mac. Direct Mac event-token acquisition has not yet been verified. Browser sign-in for ordinary account access does not depend on getting an event token.

For this first preview, Mac updates are manual downloads from https://github.com/thevampirebat/achievement-labs/releases. It does not select or install Windows update packages. Event JSON/catalogue updates continue to use Achievement-Labs/achievement-labs.

The .app is self-contained and needs no separate .NET installation. It is ad-hoc signed for testing, not Developer ID signed or notarized. Normal public Mac distribution still needs that signing/notarization step. Do not disable macOS security protections.

Build on a Mac with .NET 9 SDK: `bash tools/macos/build-preview.sh`. Output: `artifacts/macos-preview/AchievementLabs-macOS-0.1.0.1-arm64.zip`. The app contains only the approved reusable CON identity; no personal profiles, account sessions or custom signing stores are packaged. CI uses a synthetic profile to check editing/signing and renders disconnected screens without Xbox account/event requests.
