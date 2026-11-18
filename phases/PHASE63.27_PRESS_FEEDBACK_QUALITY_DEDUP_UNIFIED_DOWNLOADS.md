# PHASE63.27 — Press Feedback, Unique Quality Rows & Unified Offline Downloads (2026-11-16)

## Scope

This increment continues from the RAVEN23 PHASE63.26 archive only. No Zangetsu, FlixQuest or OpenStream archive was inspected or changed. Firebase and backend integration remain out of scope.

## Interaction feedback

- `AppPressFeedback` now receives pointer events with an opaque hit-test boundary. This fixes nested tap targets where a child InkWell/GestureDetector could otherwise prevent the shared listener from receiving the pointer event.
- The shared press scale remains `0.985` (1.5% shrink, consistent with PHASE63.26) over 100 ms using `easeOutCubic`; it returns to `1.0` on pointer up/cancel, and retains the platform Reduce Motion behavior and 10 px drag cancellation.
- Navigation destinations, `PillButton` actions (Play/My List), Manga Read, and Manga source-management actions already use the shared component; the global hit-test fix applies to those existing boundaries without changing callbacks or hit targets. Disabled/busy PillButtons no longer animate.

## Quality catalogue

- The mobile quality sheet and Android TV quality menu now show exactly one entry for each normalized resolution, including one Auto row. Duplicate 1080p/720p/etc. entries from different sources collapse into one visible row. Adaptive renditions supplied by the active player are merged with the same catalogue, one row per height, and cannot add a second Auto row.
- The active exact source (provider bucket + source key + URL) wins when it belongs to a duplicate group. Otherwise the first discovered candidate is retained deterministically. Its original URL, request headers, HLS/DASH metadata, size token and adaptive metadata remain attached.
- Other servers remain available in the provider/server picker; only the duplicate resolution rows are consolidated. The `{480, 720, 1080}` scheduling target and retention of all provider results (including lower qualities) are unchanged.

## Offline download integration

- Movie and episode download flows now discover installed Unified repository sources instead of skipping them whenever `download == true`. The flow still makes a fresh source request and sends the selected source's exact URL, original headers, quality, format and metadata into `OfflineDownloadService`.
- Download format resolution uses declared HLS/DASH/container metadata first and URL-path inference second. MP4/WebM/progressive URLs no longer default to HLS.
- `RegularVideoLinks` preserves the declared container even when a signed URL has no file extension.
- Android Media3 now prepares MP4/WebM/progressive downloads as progressive `DownloadRequest`s. Manifest-only audio inspection is skipped for progressive media. Optional subtitles are fetched before the progressive request is serialized, so a successful offline subtitle path/name is retained in its metadata; subtitle failure remains best-effort and does not block the video.
- Legacy scraper-provider download recovery recognizes progressive formats as well as HLS/DASH. Unified source URLs do not yet have an Android-side source-renewal adapter; they retain their original URL/headers for the queued download. No claim of automatic renewal for unified temporary URLs is made.

## Tests and CI

- Updated quality catalogue tests to require a unique visible quality set and active-source preservation.
- Added nested InkWell press-feedback and download-format tests; extended legacy adapter and Android progressive MIME contract tests.
- Scoped formatter inventory: 159 unique Dart targets. Focused Flutter CI inventory: 26 unique test files. Android CI now runs the focused `StreamDownloadStorePlayerContractTest` class (4 cases) alongside the 3-case Mihon ABI contract; it covers progressive MP4/WebM MIME mapping and declared containers on opaque signed URLs.

## Validation boundary

The project owner confirms that PHASE63.26 built successfully. The current editing environment has Java 21 but no Flutter or Dart executable. Static validation covers workflow YAML, formatter/test path existence and uniqueness, shell syntax, embedded CI Python validation, source-level metadata/format contracts and ZIP integrity. No new Dart format, Flutter Analyze, Flutter tests, Android Gradle tests, Release APK build, or device interaction/download test is claimed for PHASE63.27. CI and a device run remain required before the phase is treated as build-accepted.

## Changed implementation files

- `lib/design/app_press_feedback.dart`
- `lib/mobile/widgets/pill_button.dart`
- `lib/functions/video_utils.dart`
- `lib/video_providers/common.dart`
- `lib/video_providers/quality_catalog.dart`
- `lib/video_providers/unified/legacy_provider_adapter.dart`
- `lib/screens/common/player.dart`
- `lib/screens/movie/movie_video_loader.dart`
- `lib/screens/tv/tv_video_loader.dart`
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/downloads/StreamDownloadStore.kt`
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/downloads/DownloadSourceResolver.kt`

## Regression tests and CI files

- `test/app_press_feedback_test.dart`
- `test/mobile/mobile_nav_bar_test.dart`
- `test/pill_button_test.dart`
- `test/quality_catalog_test.dart`
- `test/video_utils_download_format_test.dart`
- `test/video_providers/legacy_provider_adapter_test.dart`
- `android/app/src/test/kotlin/com/m5ham3ds/raven23/downloads/StreamDownloadStorePlayerContractTest.kt`
- `tool/format_phase57_dart.sh`
- `.github/workflows/android-ci.yml`
