# Achievement Labs — Home Screen widget test

**Developer-signed test build 0.12.4 (22). Early beta; bugs are expected.** This is a separate app named **Labs Widget Test**. Its app ID and URL scheme differ from the normal app. It does not replace or migrate your normal installation, sign-in, settings or saved queues. PC QR sign-in and manual queue transfer remain available.

The Home Screen widget supports **medium and large** sizes. It shows spoof elapsed time, the next-unlock countdown, game/achievement names and queue progress. Green outlines mark the last reported active sessions. When a snapshot expires, the card asks you to open the app. Controls open the test app to show Auto Unlock/Title Spoofing or pause/stop the relevant session; the widget does not submit Xbox requests itself.

## Simplest test for your developer friend

1. Use their paid Apple Developer team to register a unique app ID, the widget extension ID and an App Group. The same App Group must be enabled on both IDs and present in both provisioning profiles. They need Account Holder/Admin access to register the group.
2. Use the included source ZIP on a Mac with Xcode 26.2 or later, Python 3 and XcodeGen. The generated catalogue and app icon are included.
3. In the extracted source folder, configure their identities (replace these examples):

   `python3 tools/configure_widget_test.py --source . --team-id ABCDE12345 --bundle-id com.yourname.labs.widgettest --group-id group.com.yourname.labs.widgettest`

4. Run `xcodegen generate`. Open `AchievementLabsMobile.xcodeproj`, select their developer team for **both** targets and check the App Groups capability uses the configured identifier. Connect their registered iPhone/iPad, select the app scheme and Run. Let Xcode create/update profiles. Signing and installation must use their developer team, not a Signulous profile.
5. Open **Labs Widget Test → Settings → App → Home Screen widget**. Enable sharing and press **Check App Group / refresh widget**. It should report that the shared group is accessible.
6. Enable **Show sample widget data**. This shares clearly labelled DEMO information without signing into Xbox or sending events. Add **Labs Widget Test** from the Home Screen widget gallery and try medium/large sizes. Turn sample data off for real sessions; starting a real session also disables demo mode.

They can do the initial layout/signing test without your Xbox account or tokens. Keep their Apple password and private signing key on their own computer.

## Using the unsigned IPA instead

The default IDs are `org.achievementlabs.widgettest` and `org.achievementlabs.widgettest.sessionwidget`, with App Group `group.org.achievementlabs.widgettest`. If these are available to their team, register them and sign the IPA with matching app/extension profiles and the included AppGroups.entitlements template.

For unique IDs without rebuilding, use the included Python script before signing:

`python3 configure_widget_test.py --ipa AchievementLabs-iOS-0.12.4-WIDGET-TEST-UNSIGNED.ipa --output Configured-Widget-Test.ipa --team-id ABCDE12345 --bundle-id com.yourname.labs.widgettest --group-id group.com.yourname.labs.widgettest`

This updates both Info.plists, shared-group metadata, the test URL scheme and background-task prefix, and creates an App Groups entitlement template. It **does not sign the IPA**. Use a signing tool that supports separate app and extension profiles, preserving the App Group entitlement on both. Xcode source installation is the easier route when signing tools cannot do this.

## What to check

- Both widget sizes appear in the gallery and stay readable with long game/achievement names.
- Two clocks display independently; next-unlock time changes when the queue advances.
- Queue/Spoofing/Pause/Stop links open **Labs Widget Test**, even with the normal app installed.
- Pause/stop clears the corresponding active indicator. Disconnect or disabling sharing clears shared data.
- The expired/stale display asks for confirmation rather than presenting the last snapshot as current activity.
- Relaunch, screen lock and returning from the background update sensibly. Record device model, iOS version, app version, displayed group status and screenshots if something fails.

Only an explicit display-data allowlist is written to the shared container: names, counts, timestamps and session flags. No authorization/event tokens, account identifiers, credentials or event payloads are shared.

Widget reload timing and background execution remain controlled by iOS. A ticking clock does not guarantee the app is running or that Xbox recorded playtime. Force-quitting may not deliver the app's termination callback; the last shared snapshot expires instead. App Groups signing cannot remove these OS limits. Do not publish this test build as an ordinary update.
