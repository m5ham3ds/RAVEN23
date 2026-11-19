# PHASE63.31 — Playback Cache, Live Download Quality Picker, and Offline Player

## Scope

Repair the existing playback/download/offline playback paths without adding a parallel source resolver, quality catalogue, cache, or Android playback engine.

This phase builds on the existing PHASE11–PHASE13 playback cache and quality-target contracts, PHASE63.27–PHASE63.30 download catalogue and source-stability work, and the existing Media3 offline download implementation.

## Existing components retained

- `PlaybackStreamCacheStore` remains the 24-hour per-URL cache and keeps each URL's original discovery timestamp.
- `ProviderLoader.restoreCachedSelection` remains the single entry point for reusing cached source results.
- `ProviderScanSession` remains responsible for ordered, bounded provider scanning and the 480p/720p/1080p completion target.
- `PlaybackQualityCatalog` remains the single catalogue builder. It continues to retain non-standard resolutions and separate server/source identities.
- `AdaptiveQualityScanner` continues to discover concrete HLS/DASH renditions without mutating the active player's data source.
- `StreamDownloadStore`, `StreamOfflinePlayerFactory`, and the Media3 read-only download cache remain the Android offline playback implementation.

## Changes

### 1. Cached URL validation and fallback

- A cache hit now receives a quick HTTP Range probe before it is selected for playback.
- A definite expired/not-found response (401, 403, 404, or 410) invalidates only that exact URL; the remaining qualities and providers are kept.
- Timeouts, server errors, rate limits, and other ambiguous responses do not delete cached links. The normal source scan remains the fallback when no URL can be confirmed.
- Existing per-link 24-hour expiry and original discovery timestamps are unchanged.

### 2. Download picker inside the player

- The picker opens from the qualities already collected by the active player; it no longer waits for `ProviderScanSession.completed`.
- The picker listens to the same provider/adaptive scan updates and adds new choices while remaining open.
- The active stream URL and BetterPlayer resolutions are not changed by background discovery.
- The search indicator remains visible while providers or adaptive manifests are still being inspected.

### 3. Download picker from movie and episode pages

- Movie and episode download actions restore usable cached provider results first.
- Only providers missing from the cache are scheduled for the next scan.
- Existing qualities are displayed as soon as the validated cache is available; newly returned qualities update the visible picker.
- The scan stops scheduling additional providers when all three standard target heights are discovered, or when eligible sources are exhausted. Every returned quality (including resolutions below 480p or above 1080p) remains selectable.
- Adaptive manifest discoveries are reported to the same scan session so they can satisfy the standard-height target.
- Scan results are persisted through the existing cache; selecting a download quality updates the preferred cached provider/URL without refreshing the discovery timestamps of older links.

### 4. Android offline playback

- The Android offline player screen now invokes the already-registered `com.m5ham3ds.raven23/offline_player` PlatformView.
- The native view resolves the completed Media3 DownloadRequest and reads its segments from the existing read-only download cache.
- A per-view EventChannel reports readiness, playing, paused, buffering, progress, completion, and player errors to Flutter so the offline wellness session retains timing and completion data.
- Non-Android platforms retain the existing BetterPlayer fallback.

## Validation coverage

- Cache restoration tests cover a rejected last URL falling back to another cached quality and an inconclusive probe preserving the cache for a fresh-source fallback.
- Existing cache tests continue to cover per-URL age, provider persistence, subtitle metadata, and invalidating one link without deleting other qualities.
- Existing source-scan and quality-catalogue tests continue to cover retaining all resolutions while treating 480p/720p/1080p as completion targets.
- Android's existing Media3 offline player contract test continues to verify the native store accessors used by the PlatformView.
- The scoped Dart formatter now includes `playback_stream_cache.dart` and `offline_player_screen.dart`.

## Acceptance criteria

1. A download picker opened during playback is populated from the active session immediately; late source results appear without restarting or closing the picker.
2. Download actions from movie and episode pages reuse cached sources, then fill missing standard heights in the background.
3. Non-standard qualities are never removed just because a standard target is not yet present.
4. A valid cached URL is reused after a quick probe; a clearly dead URL is removed individually, with the normal provider scan as fallback.
5. A completed Android download opens through Media3's local download cache rather than an HTTP request to a synthetic `raven23-offline://` URL.
6. Existing provider ordering, source eligibility, embedded-player handling, audio-track selection, and download renewal behavior remain unchanged.
