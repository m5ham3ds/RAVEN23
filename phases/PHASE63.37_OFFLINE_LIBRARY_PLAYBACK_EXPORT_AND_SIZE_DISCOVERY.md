# PHASE63.37 — Offline library playback, safe export, and size discovery

## Scope

Continue the existing PHASE63.31–PHASE63.36 contracts. This phase fixes completed-download player readiness, adds explicit user confirmation and a predictable Documents export location, and reduces avoidable work during export. It does not change source catalogue order, PRIMARY/BACKUP semantics, source scanning order, or partial-download playback safety.

## Existing contracts preserved

- Android offline playback remains the registered Media3 PlatformView reading from the existing read-only Media3 cache. It must not fall back to network access.
- HLS/DASH/progressive source formats remain identified by their declared MIME/container. A fragmented manifest is never renamed to .mp4 without successful preparation and validation.
- The existing selected subtitle remains a local sidecar and is not re-fetched during export.
- The signed stream-size estimate remains exact-link/token bound. Unknown values stay unknown; no estimate is invented from resolution, runtime, or byte-progress percentage.
- Partial-download playback remains disabled until a contiguous playable timeline range is verified cache-only.

## Implemented in this phase

### 1. Offline player readiness

- Flutter no longer treats an EventChannel snapshot/progress heartbeat as proof of media readiness.
- The loading state is cleared only after the native Media3 player reports STATE_READY; native player errors remain visible.
- The native Media3 player uses the existing read-only cache factory and has no upstream/network fallback.

### 2. Destination and confirmation

- Save-copy and delete actions now require a confirmation dialog.
- Save-copy writes to Documents/RAVEN23 through Android MediaStore on Android 10+; it does not open the document picker.
- Movies are written to Documents/RAVEN23/MOVIES; selected subtitle sidecars are written to Documents/RAVEN23/MOVIES/SUBTITLE.
- Episodes use a series-title directory under Documents/RAVEN23/<SERIES>/; video and subtitle are written beside a SUBTITLE child directory using the same filename stem.
- Episode filename stems include season and episode numbers; provider labels in display subtitles are not copied into the filename.
- Android versions before 10 request only WRITE_EXTERNAL_STORAGE when the user explicitly starts a save. No new all-files permission is requested.
- Re-saving an existing file updates the MediaStore entry for the same name and relative path rather than creating duplicate copies.

### 3. Export performance and correctness

- A completed progressive download can be copied directly from Media3 cache only if its MIME type is MP4, its state is completed, and its known content length exactly matches downloaded bytes.
- The direct-copy path is cache-only and uses bounded 1 MiB buffers on a background executor.
- A previously validated MP4 export is reused.
- HLS/DASH are not treated as single-file MP4. A remux/export is still needed to prepare those formats for a single MP4 file. This phase does not claim instant export for manifest-based downloads; if a validated MP4 is not already available, save-copy returns an explanatory error rather than starting a costly conversion invisibly.
- Subtitle files retain their original SRT/WebVTT extension and use the same filename stem as the exported video.
- Export title, series title, season, and episode metadata are explicitly persisted in the native Media3 request metadata.

### 4. Download size discovery

- The signed sizeToken API remains the primary size-estimate source and is cached by exact token/link identity.
- No unconditional HEAD/Range probes are added to every quality row. Such probes can cause extra origin-provider requests, can be denied or return chunked/segmented semantics, and can slow picker population.
- A future fallback may perform one short, cancellable HEAD/range probe only for the selected link when no token estimate exists; it must be limited, cached per exact URL+headers, and return unknown on ambiguous results.
- Content-Length from an actual completed/active transfer is the authoritative actual size when available; before then, the UI may show the backend estimate or unknown.

## Validation added

- Dart model test verifies independent exportTitle serialization alongside subtitle, season, and episode metadata.
- Downloads UI tests verify save confirmation before writing and verify cancelling deletion preserves the download.
- MethodChannel test verifies native saved=true results are decoded correctly.
- Android contract tests cover movie and episode export naming, unsafe path characters, and the strict progressive MP4 cache-copy eligibility predicate.

## Acceptance criteria

1. Android downloaded playback remains cache-only and does not mark the player ready until Media3 reaches STATE_READY.
2. Save and delete operations cannot execute until the user confirms.
3. Movies and episodes are saved under the exact Documents/RAVEN23 directory tree, with matching subtitle sidecar stems.
4. Progressive MP4 cache copy is enabled only when completed state, MP4 MIME type, and exact byte-count checks all pass.
5. HLS/DASH are not silently renamed as MP4; when no validated MP4 export exists, the UI receives a clear explanation.
6. Existing provider order, server catalogue order, PRIMARY order, automatic BACKUP recovery behavior, and partial-playback guard remain unchanged.
7. Phase acceptance requires successful GitHub Actions analysis/test/Android contract/release build plus on-device playback and export validation.