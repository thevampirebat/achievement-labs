# Achievement Labs — standalone iOS beta

Native SwiftUI app for iPhone and iPad, iOS/iPadOS 17 or later. No PC companion or running desktop app is required. This is a separate early mobile beta, not a replacement for the Windows release.

## What is implemented

- Xbox library with search, remembered A–Z/Z–A/last-played sorting, completion colouring and base-completion indicator after a verified achievement read.
- Modern and legacy achievement reads, search/filter/sorting, expandable verified DLC/base/update sections matched by Title ID, platform, achievement ID and name.
- Manual unlock/retry, multi-selection into an account-specific persisted queue, per-item delays, pause/resume, remove items and remove achievements confirmed unlocked by Xbox.
- Foreground title-presence heartbeats and elapsed timer alongside the queue, failure/completion notification options and stop-on-presence-failure.
- Microsoft browser sign-in with PKCE and a pasted final redirect, optional manual authorization, separate event-token entry, iOS Keychain storage. No passwords, tokens or real accounts in tests, logs or artifacts.
- Bundled current fork catalogue, prepared from committed source. Only deterministic Replace operations with checked targets, placeholders and title/service identity are enabled. Unsupported edition routes (including Minecraft's hosted route and the three guarded edition aliases) remain disabled until their full guards are ported. Disabled author titles stay disabled. See catalogue-report.json in the build artifact for exact coverage.

## First connection

In Settings choose **Sign in with Microsoft in browser**. Complete Microsoft sign-in, copy the entire final address from the browser address bar, return to the app and choose **Finish browser sign-in**. The final Microsoft page can appear blank. Do not share the final URL; it contains a short-lived authorization code. This beta uses the existing OAuth profile's registered desktop redirect and therefore requires this manual return step.

Alternatively paste a current **Xbox service authorization** (`XBL3.0 x=…;…`) and tap Connect. This is separate from the **event token** (`x:XBL3.0 x=…;…`), saved in its own section after connecting. Automatic event-token acquisition is not included. A standalone app still needs valid service credentials; it cannot read another app's protected account store.

The app does not unlock anything on launch, sign-in, refresh or queue load. Manual Unlock/Retry and Start/Resume send actions. Collector acceptance is shown separately from confirmed Xbox progress. Queues skip achievements Xbox already reports unlocked; manual Retry can resend them. Refresh to confirm progress, including delayed credit.

## Foreground operation and current limitations

Queues and presence pause when the scene becomes inactive; reopening never automatically resumes them. While running in the foreground the screen is kept awake. Do not rely on background execution or a heartbeat stopping instantly after a lost connection. Queue requests interrupted during submission are marked for review rather than automatically retried. Timers show this app session, not Xbox-recorded playtime.

This beta has no Steam/Epic/Ubisoft clients, Xbox 360/GFWL write/profile tools, Windows token capture, stats editor, automatic catalogue refresh or Windows executable updater. DLC metadata and mappings are bundled with each mobile build. Legacy achievements are read-only. Live authentication, event credit and presence still require physical-device testing; simulator/core tests do not prove service compatibility.

## Build and sign

The **iOS standalone beta** GitHub workflow prepares resources, runs synthetic tests plus every enabled generated recipe, builds arm64 iPhone/iPad and simulator apps, verifies simulator launch plus synthetic Keychain save/read/delete and creates `AchievementLabs-iOS-0.1.1-UNSIGNED.ipa`. Simulator-only ad-hoc entitlements are used to exercise Keychain APIs; they are never included in the unsigned device app. Device signing must supply the normal application identity and Keychain entitlements.

**The unsigned IPA cannot be installed directly.** It needs signing/provisioning appropriate for your device or distribution method. No Apple account, certificate or provisioning profile is bundled. Never commit private signing credentials. No App Store/TestFlight release is claimed.

For a Mac/Xcode development build:

```sh
python3 mobile/tools/prepare_catalogue.py
brew install xcodegen
cd mobile
xcodegen generate
open AchievementLabsMobile.xcodeproj
```

In Xcode select your signing team, use a unique bundle identifier you control, select your device and build/run. Xcode supplies the signing/provisioning flow. For simulator-only testing a signing team is unnecessary. The CI artifact has an unsigned device IPA for a separate user-controlled signing flow.

Documentation: [Apple device distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices).

Desktop source, licences and author attribution remain in the repository. No private Xbox signing material or TLS trust bypass is included. Mobile sources are independent of the Windows projects and build workflows.

Browser sign-in: Settings → Sign in with Microsoft in browser. After signing in, copy the full final login.live.com/oauth20_desktop.srf address back into Finish browser sign-in. PKCE, state validation and a one-use response protect this manual callback. Account authorization is verified with Xbox before replacing the saved account. Event tokens remain separate. OAuth access tokens are held only during exchange; refresh tokens are not retained in this beta. Sign in again when authorization expires.
