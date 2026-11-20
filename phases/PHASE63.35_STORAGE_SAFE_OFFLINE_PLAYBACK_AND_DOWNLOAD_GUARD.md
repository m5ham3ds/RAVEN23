# PHASE63.35 — Storage-safe downloads and direct offline playback

## Scope

Continue the existing PHASE63.31–63.34 implementation. Provider priority, source eligibility, source catalogues, and quality-selection ordering are unchanged.

## Implemented

- Android offline playback opens the registered Media3 cache-backed PlatformView directly. It no longer runs the MP4 export/remux pipeline before watching a completed download, so playback does not create a second MP4 under `filesDir/offline_exports`.
- Non-Android playback retains the BetterPlayer export fallback. Android uses the native Media3 PlayerView controls; exact BetterPlayer control parity is not claimed by this cache-backed route.
- The existing backend `/api/v2/stream-size` endpoint is wired to the quality chooser through each link's signed `sizeToken`. Each row displays the backend estimate when available. No size is fabricated from resolution or runtime; sources without a usable token remain explicitly unknown.
- The selected estimate is carried through the Flutter request and persisted in Media3 request metadata.
- Initial download enqueue is checked against the estimated file size plus a 200 MiB safety reserve, both in the preflight dialog and again inside Android after source preparation.
- Active downloads are automatically stopped when the app's storage volume reaches 200 MiB free. The Downloads card explains the automatic pause. Resume/retry checks available storage against the estimated remaining bytes and provides an in-dialog recheck.
- Flutter and Android tests cover estimate serialization and 200 MiB storage boundaries.

## Partial-download playback remains guarded

PHASE63.34 partial-download playback is **not enabled in this phase**. A Media3 byte percentage is not a verified playable-time prefix. HLS/DASH require manifest, initialization data, audio/video track and segment continuity checks; progressive MP4 needs a valid initialization/index and verified readable prefix. The native offline player still rejects incomplete downloads until the cache-only bridge can prove the contiguous timeline and stop at the first missing segment without falling through to the network.

## Validation

- The routine CI gate already includes `test/offline_download_test.dart`; the focused Android Media3 contract class now includes four additional storage guard cases.
- This phase is not build-confirmed until its GitHub Actions Release gate passes.
- Device testing is still required for Android free-space accounting, background pause/resume, and airplane-mode playback from Media3 cache.
