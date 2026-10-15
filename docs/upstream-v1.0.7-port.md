# Upstream v1.0.7 combined with the fork

Upstream source: a6d64af6e14037f8acc35ef97df14bcc54b015d3. Fork base: a3fc53c9747019895c7bf9b6c46679cbbeb36216 (v1.0.6-fork.3).

Upstream now credits and includes much of this fork: achievement grouping/selection/sorting, queue controls, library sorting/completion, exports, notifications and window settings. New features include a persistent multi-title Build Queue with checkpoints, separate Steam queue navigation, Global % sorting and achievement artwork, Store-link-to-Title-ID lookup, Open stats in library rows, expanded event-stat support, authorization maintenance and more explicit queue/token recovery.

The author catalogue contains 442 blocks, classified as 267 Supported / 169 Testing / 6 Coming Soon. The release notes list 42 new blocks and 43 newly Supported titles (including promotions). Classifications are author metadata, not independent proof of live credit. The embedded catalogue includes existing-title recipe/template changes and Stats.json, while the working Minecraft Xbox One Edition hosted route remains reserved.

Retained fork behavior: reviewed Infinite Warfare, Modern Warfare Remastered and Escapists: The Walking Dead edition guards and signature validation; approved Dishonored/Ghosts corrections already present in the author catalogue; all display metadata and account-isolation features; fork-only executable updates; normal-window default and stored placement preferences; optional explicit connected-account token retrieval. Experimental background token scraping is not restored. New upstream queue checkpoints and manual replacement-token waiting behavior are retained.

New fixes in this integration:

- Event checks use the original repository's latest stable release Events.zip asset rather than raw Data.json. The new Data.json is 78,568,872 bytes and exceeded the former 64 MiB limit. ZIP downloads are SHA-256 checked against GitHub release metadata and bounded to 32 MiB compressed / 256 MiB total expanded / 128 MiB Data.json. Paths and duplicates are validated; no files are extracted into the installation. All candidate recipes are validated before an atomic public-data cache replacement. Existing mappings remain reserved; new additions are Testing. The screen reports the failing stage and HTTP/archive validation error while keeping the previous cache. Only published stable releases with an Events.zip and a digest are accepted.
- Library refresh shows authorization/metadata/download/application stages, actual bytes and total bytes when supplied, title counts and elapsed time. Unknown download size uses an indeterminate bar, avoiding invented percentages. It retains the previous list on failure and adds no per-title requests.
- Settings retains explicit current-account token retrieval without background account-cache scanning, account-generation checks discard stale results, and retrieval uses existing protected save validation.

Public source still omits the Xbox 360 signing dependency. The existing fork stub and pre-write disabled-action guards remain; no signing material was extracted or added. Browsing/backups remain available.

Validation: Windows CI runs upstream and fork offline suites, new release-ZIP/cache tests including >64 MiB Data.json, edition guards, library controls and updater checks. No live Xbox sign-in, event/stat submissions, token capture or achievement unlocks during development.
