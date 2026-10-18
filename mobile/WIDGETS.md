# Session timers and home-screen widgets

The iOS spoof timer is bounded by the expiry of the last accepted Xbox heartbeat (600 seconds), rather than a 45-second UI refresh. Each accepted heartbeat renews the deadline. This is elapsed session time, not Xbox-recorded playtime. If the app stops updating, the card eventually asks you to check status. Force-quitting cannot guarantee an immediate stop request to Xbox.

Live Activity updates are serialized and coalesced. The next achievement, game and absolute countdown change when the queue advances; timers animate locally rather than depending on a status push every second.

## Android

Delay fields are in minutes, including fractional minutes. Existing queues and exported files keep seconds internally, so an existing 120-second delay displays as 2 minutes.

Auto Unlock displays Running/Paused, session elapsed time and a next-unlock countdown. The ongoing notification also uses a native countdown. Checking/submitting is shown when no unlock delay is running.

To add the home-screen widget, open Settings → App → Add Labs sessions widget, or long-press an empty area of the home screen and choose Widgets → Achievement Labs. It shows spoof elapsed time, next game/achievement and an unlock countdown. Pause queue and Stop spoof act on the current session. Open/resume opens the queue for review, without automatically sending an achievement. Widgets do not restart a killed service. Cached widget status can lag; the widget shows its last update time.

## iPhone and iPad

Long-press the home screen → Edit → Add Widget → Achievement Labs → Labs sessions. Medium and large sizes are included. Controls open the app to pause, stop or review/resume. The widget does not grant extra background execution, and iPadOS decides when to refresh widget data; the Live Activity remains the more immediate session display.

Session-data sharing uses the App Group `group.org.achievementlabs.mobile` in both the main app and widget extension. No authorization, renewal or event tokens are placed in widget storage. The signing profile must authorize the same group for both targets. Keep the widget extension when signing. The unsigned IPA alone cannot guarantee that Signulous will supply this capability. Settings → App reports whether shared widget storage is available. Without it, the home widget still opens the app, but cannot show current session data. AppGroups.entitlements is provided for signing setups that support the group.

## Manual queue sync

1. Pause Auto Unlock on the source device.
2. Expand Saved game queues and choose Export queue sync file. Android also has these controls in Settings → Sync.
3. Copy the JSON file to the other device using Files, a cable or your preferred file-sharing method.
4. Sign into the same Xbox account there, pause Auto Unlock, and choose Import queue sync file.
5. Load a saved game, review progress and delays, then press Start when ready.

This is manual file transfer, not automatic cloud synchronization. Imports verify achievement IDs and names against Xbox metadata and do not start unlocking. A game already in the active mobile queue is protected from being overwritten. PC rejects unresolved previously submitted items until progress is refreshed or their source status is explicitly reset; it does not silently replay them.
