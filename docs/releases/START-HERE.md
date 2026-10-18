# Achievement Labs — start here

**Early beta: bugs are expected.** Some features may fail or behave differently between devices. Start with a small queue, keep an export of important saved queues, and refresh Xbox progress to check results.

## 1. Install

- **Windows:** extract the PC ZIP, then run `AchievementLabs.exe`.
- **Android:** install the APK. Allow notifications if you want session status and alerts.
- **iPhone/iPad:** extract the iOS ZIP, upload the `.ipa` to Signulous, then sign and install it. Keep the Live Activity extension when signing.

Install over your existing app where possible. Removing the app can delete local settings and saved queues.

## 2. Connect your Xbox account

You can sign in normally on mobile. The PC QR route is useful if normal sign-in works for the library but spoofing is refused:

1. Connect your account in the PC app.
2. Click the **mobile icon** beside **Attach Xbox PC App**.
3. Choose **Sign-in + event token** for both, **Sign-in only** for the account, or **Event token only** to update the token.
4. On mobile, choose **Sync from PC / Scan PC QR codes**. Keep the camera pointed at the cycling codes until finished, check the account shown, then confirm.

Event-token-only sync requires the same account to be signed in already. Sign-in-only sync keeps any existing event token for that account. Event-based achievements need a working event token as well as account sign-in. Sign-in codes expire after ten minutes.

## 3. Use the app

- **Library:** choose a game to view and filter its achievements.
- **Auto Unlock:** add achievements or build a timing queue using a reference gamertag. Check the delays and order, then press **Start / Resume**. Loading a saved queue does not start it.
- **Title Spoofing:** select a game or enter its Title ID, then press **Start spoofing**. It can run alongside Auto Unlock.
- **Settings:** account, sync, library and app options are grouped into tabs.

An accepted request is not proof of an unlock. Refresh Xbox progress before retrying uncertain results.

## 4. Move saved queues to another device

Pause Auto Unlock and sign into the **same Xbox account** on both devices. Open **Auto Unlock → Saved game queues**.

- **File:** export the queue sync file, copy it to the other device, then import it.
- **QR:** display the queue codes on one device and use **Scan queue QR** on the other.
- **Importing QR on PC:** on mobile choose **Share all QR images**, copy every image to PC, then select them together using **Import queue QR images**.

Confirm the import, load a saved game, review it, then press Start. This copies a snapshot; changes do not sync automatically. If a mobile import would overwrite a game in the current queue, load another saved game first. Use file transfer for large exports.

## Background status

Android has session notifications and a Home Screen widget. iOS has a lock-screen Live Activity and Dynamic Island display; its Home Screen widget has been removed. iOS may pause or stop background sessions, and a visible timer does not prove the app is still running. Timers show this session, not Xbox-recorded playtime.

## Reporting a bug

Include your platform, app version, game and Title ID, achievement name if relevant, what you clicked, and the error text. Never include passwords, account/event tokens or sign-in QR screenshots.
