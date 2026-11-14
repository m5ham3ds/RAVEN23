# Phase 47 — Audit

## Baseline and phase position

The main blueprint places Phase47 immediately after Phase46 — Unified Live TV Service Manager — and before Phase48 Pluto TV, Phase49 XMLTV/EPG, Phase50 WebView fallback and Phase51 integration/release. Phase46 is present in `RAVEN23-PHASE46` but its documentation says **Implementation Prepared — CI Pending**. The only successful CI evidence supplied in the project tracker is run `42428688859`, which covers Phases37–45; it is not evidence for Phase46 or Phase47.

## Existing components reused

- `LiveTvService`, `DaddyLiveCatalog`, `DaddyLiveStream`, `Channel` and `LivePlayer` form the existing compatibility contract.
- `LiveTvServiceManager` introduced the central provider registry, lifecycle, selection, health and namespaces in Phase46.
- `LiveTVDatabaseController(namespace: ...)` provides provider-isolated channel/favorite/recent storage; Mobile and TV cache the selected catalog through this controller.
- `SourceRepositoryManager.sync()` supplies installed/enabled sources; `QuickJsProviderRuntime` invokes the repository's JavaScript methods; `mapQuickJsVideoSources` converts stream options.
- `SourceHostPolicy` checks remote playlist origin and each HTTP redirect destination.
- `SourceManifest.requiresLiveTvAdapter` already blocks marked sources from `supportsMedia()` VOD queries.

## Gaps identified before Phase47

1. No parser or repository existed for user M3U channel lists.
2. No distinction existed between channel-list M3U and HLS media playlist input.
3. No local/remote playlist lifecycle, bounded cache or playlist management UI existed.
4. No dedicated Live TV execution path existed for the audited Spyhell `getHome()` channel sources.
5. The 15 Spyhell channel IDs were marked as requiring a Live TV adapter but did not have a complete Live TV adapter path.
6. Mobile and TV needed to expose the same M3U management operation without introducing separate provider implementations.

## Security and correctness decisions

- User-selected local files are copied into app-private storage, and only that internal copied path is persisted.
- Remote playlist origins and redirects pass through `SourceHostPolicy`; redirect count and body size are bounded.
- URL parsing accepts HTTP(S) only and rejects embedded username/password credentials.
- Playlist-supplied headers are limited to `Accept`, `Origin`, `Referer` and `User-Agent`, with CR/LF and length checks.
- JavaScript is invoked only for the exact curated Spyhell IDs when their sources are present in the installed/enabled snapshot and belong to the expected repository path.
- All Spyhell live channel sources retain `requiresLiveTvAdapter=true`; the VOD guard is not relaxed.
- Unknown IPTV group names are preserved as labels rather than silently mapped to a generic category.

## Verification boundary

This audit is a static source review. No Dart/Flutter SDK was available in the working environment, so no analyzer, test runner, build, or real device/player verification was performed. Those are explicitly pending in the report and tracker.
