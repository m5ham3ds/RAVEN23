# PHASE63.34 — Partial Offline Playback

Status: The earlier “design only / deliberately disabled” wording is superseded by PHASE63.39. Partial offline playback is now an explicit product requirement. Keep the completed-file fallback until the cache-only incremental path below is implemented and verified; do not silently treat this transitional fallback as completion of the requested feature.
User scenario: Watch the already-downloaded portion of a movie or episode while the remaining download continues.

## Why a download percentage is not a playable-time percentage

A progress value such as 40% describes downloaded bytes. It does not prove that the first 40% of the video's timeline is present. HLS and DASH downloads contain manifests, initialization data, audio/video tracks and individual segments; segments can be missing, incomplete or downloaded out of timeline order. A file-size or byte-percentage shortcut would produce false playable ranges.

## Existing playback contract

- Completed downloads are exported from the Media3 download cache to a validated MP4.
- The Flutter offline player uses the application's BetterPlayer-based controls and gestures.
- The existing completed-file path uses the same BetterPlayer-based player surface; it remains the safe fallback while a verified incremental cache bridge is built.
- The complete-download export path must remain cache-only and must not fetch missing segments from the internet during offline playback.

Removing the completed-state guard or opening the partial cache directly in the separate native player would either fail at cache misses or break the requirement to retain the same player controls. It is therefore not an acceptable implementation.

## Required implementation design

1. Determine the contiguous playable timeline beginning at time zero, not merely the downloaded byte percentage.
2. For HLS, DASH and progressive downloads, verify manifest/init data and every audio/video segment required up to the proposed playback boundary.
3. Stop at the first missing, incomplete or undecodable segment; never seek into unverified cache ranges.
4. Expose the verified cache range to the existing BetterPlayer-based offline player through a cache-only playback bridge. It must not silently switch to a different player UI.
5. Keep the downloader active while playback reads the verified prefix; coordinate cache reads/writes and cancellation without invalidating the active playback source.
6. Update the available playable range as new contiguous segments arrive, and handle reaching the boundary with a clear message and safe resume when more segments become available.
7. Preserve airplane-mode behavior: playback must read only verified local cache segments and never fall through to the network.

## Acceptance tests

- Partial HLS, DASH and progressive downloads expose only a verified contiguous prefix.
- A 40% byte download with non-contiguous cached segments does not claim 40% timeline availability.
- Seeking beyond the verified boundary is prevented.
- Playback uses the same BetterPlayer controls, gestures, subtitle/audio handling and orientation behavior as completed offline playback.
- Downloading continues without corrupting or evicting the segments used by playback.
- Completed-download export validation remains unchanged and still requires a complete audio/video track set and a trusted source duration.

## 2026-11-20 implementation revalidation

The current Android `StreamOfflinePlayerView` still enforces `Download.STATE_COMPLETED` before creating a Media3 cache-backed player. The app's download cache is a Media3 `SimpleCache` rooted at `filesDir/offline_streams`; the player uses a read-only cache datasource with no upstream. The current Flutter offline-player route is for completed downloads only and does not expose a verified playable-prefix timeline.

This design was rechecked during the source-scan/quality-estimation work. No partial-playback code was enabled because the repository still has no cache-range timeline verifier for HLS, DASH, or progressive MP4, no moving playable-boundary bridge to the existing BetterPlayer UI, and no tests for concurrent cache reads/writes while the download continues. Merely removing the completed-state guard would violate cache-only playback and could fail at the first missing segment.

The above guard is a transitional safety fallback only. The required end state is concurrent preparation from the earliest safely available cache data and playback of the verified contiguous prefix while download continues. The percentage downloaded must never be substituted for timeline coverage. PHASE63.39 is the active scope and acceptance authority; older wording that frames partial playback as a permanently disabled or out-of-scope feature must not be used.
