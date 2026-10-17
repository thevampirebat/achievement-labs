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

In Settings choose **Sign in with Microsoft**. The embedded Microsoft webpage returns automatically after sign-in; PKCE, state and single-use callback checks remain enabled. The page uses an ephemeral WebKit store; no scripts inspect passwords, page contents or cookies. If the embedded page does not support your sign-in method, use **Safari / manual sign-in** and paste the final redirect into the app. Never share that URL.

Choose **Xbox desktop** to use the same OAuth profile as the desktop fork, or **Xbox iOS** to retain the previous beta profile. Existing sessions retain their profile until you sign in again. A successful library read does not guarantee presence permissions: a heartbeat 403 is reported as a service-specific refusal and is not retried or bypassed.

Alternatively paste a current **Xbox service authorization** (`XBL3.0 x=…;…`) and tap Connect. This is separate from the **event token** (`x:XBL3.0 x=…;…`), saved in its own section after connecting. Automatic event-token acquisition is not included. A standalone app still needs valid service credentials; it cannot read another app's protected account store.

The app does not unlock anything on launch, sign-in, refresh or queue load. Manual Unlock/Retry and Start/Resume send actions. Collector acceptance is shown separately from confirmed Xbox progress. Queues skip achievements Xbox already reports unlocked; manual Retry can resend them. Refresh to confirm progress, including delayed credit.

## Foreground operation and current limitations

Queues and presence pause when the scene becomes inactive; reopening never automatically resumes them. While running in the foreground the screen is kept awake. Do not rely on background execution or a heartbeat stopping instantly after a lost connection. Queue requests interrupted during submission are marked for review rather than automatically retried. Timers show this app session, not Xbox-recorded playtime.

This beta has no Steam/Epic/Ubisoft clients, Xbox 360/GFWL write/profile tools, Windows token capture, stats editor, automatic catalogue refresh or Windows executable updater. DLC metadata and mappings are bundled with each mobile build. Legacy achievements are read-only. Live authentication, event credit and presence still require physical-device testing; simulator/core tests do not prove service compatibility.

## Build and sign

The **iOS standalone beta** GitHub workflow prepares resources, runs synthetic tests plus every enabled generated recipe, builds arm64 iPhone/iPad and simulator apps, verifies simulator launch plus synthetic Keychain save/read/delete and creates `AchievementLabs-iOS-0.2.1-UNSIGNED.ipa`. Simulator-only ad-hoc entitlements are used to exercise Keychain APIs; they are never included in the unsigned device app. Device signing must supply the normal application identity and Keychain entitlements.

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

Browser sign-in: use the embedded Microsoft page for automatic callback capture, or Safari / manual sign-in as a fallback. PKCE, state validation and a one-use response protect both paths. Account authorization is verified with Xbox before replacing the saved account. Event tokens remain separate. With Remember sign-in enabled, OAuth renewal credentials and Xbox authorization are stored in the iOS Keychain. Rotated renewal credentials are saved before the next Xbox exchange. The renewed XUID must match the active account. Disabling remembering removes saved credentials; Disconnect also clears Microsoft browser data held by this app. No Microsoft password is stored.

## Mobile 0.2.1 refinements

Compact inline navigation and library rows; nested Xbox image fallback; profile gamerpic and gamerscore from Xbox; loaded library game/achievement counts; desktop star-and-laurel Mythic artwork and persistent, account-specific completion evidence. “Mythic · known” counts verified base completions plus fully completed titles, excluding multi-game hubs. It is a local display calculation, not a new Xbox award. Settings can scan unchecked titles sequentially; leaving the app stops that scan after the current read. Bundled shared totals fill missing totals only for a matching title/platform and never replace account unlocked counts.

Auto Unlock has reference gamertag + title ID timing import, fresh same-title achievement matching, preview-only queue building, editable minute delays, estimated finish and collapsible options. Timing gaps reproduce intervals, not historical achievement timestamps. Library/game shortcuts and typed-ID lookup show title art in both Auto Unlock and Title Spoofing. Xbox-recorded playtime is read separately when available. No claim is made that a heartbeat will increase it. The desktop OAuth profile is available for compatibility testing; actual spoofing permission remains subject to Xbox accepting the request.

## Session persistence and spoofing diagnostics (0.2.1)

Remember sign-in is enabled by default. Sign in once after upgrading to capture renewal credentials (older versions discarded them). The embedded Microsoft page uses a persistent app-local WebKit data store when remembering is enabled and an ephemeral store otherwise. The app never reads page passwords, cookies or unrelated password-manager entries. Native token/code fields are tagged as code fields rather than passwords. Safari remains available when in-app AutoFill suggestions are incorrect; it needs the manual redirect return.

Known-expiring authorization renews before reads or actions; read-only requests may retry once after a 401 using renewed authorization. Failed unlock requests and failed heartbeat requests are not automatically replayed. Renewal is shared across concurrent callers, rotates its protected credentials before Xbox exchange, validates the connected XUID and preserves the separate event token. Account changes invalidate an in-flight renewal. Turning remembering off removes the protected saved session and Microsoft web data; Disconnect does the same. If Microsoft revokes renewal, browser sign-in is required.

Spoofing 403 is now reported without repeatedly recommending the already-tested desktop profile. A failed heartbeat produces sanitized server-code/correlation diagnostics and one read-only profile check to distinguish general authorization failure from heartbeat-specific refusal. No authorization, event token, OAuth credentials or raw response bodies are included in Copy diagnostics. A successful profile check does not grant spoofing permission.
