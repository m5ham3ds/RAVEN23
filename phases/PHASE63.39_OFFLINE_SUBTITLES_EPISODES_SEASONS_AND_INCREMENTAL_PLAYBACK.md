# PHASE63.39 — Offline subtitles, full episode metadata, local season switching and incremental readiness

Date: 2026-11-21
Baseline: `3e52042ce112605760e6d7556d8aeb69968ed210` (GitHub Actions #217)
Scope owner: the four offline-download/playback issues listed below only.

## Strict scope boundary

This phase authorizes changes only to:
1. the selected subtitle sidecar lifecycle during download and the DCIM save-copy path;
2. the episode-card metadata shown by the existing offline episode picker;
3. the season-switch action for shows with more than one season represented in completed downloads;
4. concurrent preparation and verified partial playback while a download is still progressing.

Do not change online playback behavior, player design, source catalogue contents, source ordering, PRIMARY/BACKUP priority, provider/server selection, quality policy, navigation outside these controls, Firebase/backend contracts, styling outside restoring the existing online episode-card details, or unrelated tests/files. Do not perform opportunistic refactors. Preserve existing behaviour except where one of the four requirements explicitly replaces it. If another file or subsystem appears to need changes, first show the exact dependency and do not widen this phase implicitly.

## 1. Selected subtitle sidecar

- A subtitle explicitly selected in the download flow must be persisted inside the app's offline subtitle directory before the native download request is committed.
- Support the provider subtitle URL path and the normalized external subtitle path. Preserve the selected language/name and SRT/WebVTT format where applicable.
- The exact persisted local file is the source for copy-out to the planned `DCIM/RAVEN23/.../SUBTITLE` folder; keep the matching video/subtitle filename stem and the existing movie/series directory layout.
- If a subtitle was selected but could not be persisted or copied, return a distinct, truthful subtitle failure. Do not report “video and selected subtitle saved” when the subtitle sidecar is absent.
- A download with no selected subtitle remains a valid video-only download.

## 2. Offline episode cards identical to online cards

- Reuse the current `PlayerEpisodeSelection` card widget and exact online card fields; do not create a visually different offline row.
- Persist enough TMDB metadata with the download to show episode still image, episode name, rating, runtime, air date and overview after network disconnection.
- Missing metadata must remain honestly absent; do not fabricate ratings, descriptions, artwork or episode IDs.

## 3. Offline season switching

- Show the season-switch control only when at least two distinct seasons of the same series have completed downloaded episodes.
- Populate the season list from locally stored metadata and the seasons that actually have completed downloads.
- Selecting a season replaces the episode list with the completed downloads from that season and keeps the selected/current episode identity intact.
- Offline season selection must not call TMDB, a provider, an online loader or any network API.
- Selecting an episode resolves the matching local download by series ID + season number + episode number.

## 4. Concurrent preparation and partial playback

- Begin preparation alongside the active download as soon as there is cache data that can be inspected. Do not queue all preparation work until the download is 100% merely because the final MP4 cannot yet be published.
- Expose playback only for the verified contiguous media timeline beginning at time zero. A byte percentage is not a playable-time percentage and may never be used as a shortcut.
- Progressive MP4 requires a verified readable container/index and decodable media range. HLS/DASH requires the manifest, initialization data and every dependent audio/video segment up to the boundary. Stop at the first missing, incomplete or undecodable segment.
- Keep reads cache-only while downloading continues. No network fallthrough is allowed in the offline player.
- Retain the current completed-download export/validation fallback until the incremental bridge is implemented for each format and passes concurrent read/write tests.
- Never write a partial staging artifact over the validated completed MP4, and never mark a partial export as complete or fully saved.

## Superseded and conflicting rules

- This phase supersedes the “completed same-season only” offline selector rule in PHASE63.38. Offline navigation is across every season with completed downloads for the same series.
- This phase replaces the old PHASE63.38 rule that started all preparation only after `STATE_COMPLETED`. Preparation must start concurrently at the earliest safe cache checkpoint; final publication still requires validation.
- The blanket “partial playback remains deliberately disabled / design-only” status in PHASE63.34 is superseded. Its technical safety rules (contiguous verified timeline, cache-only reads, no use of byte percentages, same BetterPlayer surface) remain mandatory acceptance criteria.
- PHASE63.37 is historical and remains superseded by PHASE63.38; its Media3 PlatformView and Documents/RAVEN23 requirements must not be reintroduced.
- Existing source order, provider catalog, PRIMARY/BACKUP order, signed-link recovery and cache identity are explicitly outside this phase and must remain byte-for-byte unchanged unless a dependency is demonstrated and approved within this phase.

## Acceptance and proof

- Test a provider subtitle and an external subtitle from selection through app-private persistence to DCIM copy. Test selected subtitle failure and no-subtitle downloads separately.
- Test the online episode card and its offline rendering with the same poster/still, title, rating, runtime and overview fields.
- Test one downloaded season (no season button), then two or more downloaded seasons (button visible); switch seasons in airplane mode and verify only completed local episodes appear.
- Test progressive MP4, HLS and DASH while download is active; verify contiguous range, seek boundary, cache-only behaviour and concurrent download/playback. Specifically test non-contiguous segments and a byte progress such as 40% that does not equal 40% timeline coverage.
- Run focused Flutter tests, Android JVM tests and the Release APK CI gate. A successful build alone does not prove device-level partial-playback correctness.
- No unrelated files may appear in the diff. The final diff must list each changed file and map it to one of the four scope items above.
