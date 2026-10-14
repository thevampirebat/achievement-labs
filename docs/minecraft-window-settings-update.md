# Minecraft Xbox One Edition and desktop settings

Minecraft Xbox One Edition (345903534) now uses the upstream catalogue service for title mappings and payloads, matching the regular app's source. Its bundled entry contains Windows/Bedrock event data and is not used as a fallback. Other editions retain their existing routes. No Xbox events were sent during development; Cupid unlocking still requires user verification. The service can fail or be unavailable, in which case its error is surfaced. No tokens were inspected or copied.

Settings are grouped into window/appearance, library completion, DLC metadata, exports, account/events, startup/unlock behaviour, notifications, account connection, updates and Debug. Remember window size and automatic maximization default off. Normal dimensions are kept separately from account/session data, clamped to the display when restored, and remembered on close after preferences have loaded. Saving settings persists the two toggles. Automatic maximization overrides the startup size while preserving normal dimensions for Restore.

Enter is explicitly supported for opening Xbox titles, title/profile searches, Steam achievement loading, spoofer title lookup and saving the typed event token. Disabled actions stay disabled. Search filters already update live. Enter does not unlock achievements, start spoofing/queues, write stats, remove saved data or submit multiline editors.

Validation: Windows offline enhancement checks and release build via PR CI; no live account operations. Minecraft live success is unverified.
