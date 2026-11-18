# PHASE63.7 — Zangetsu chapter-reader UI parity on the Mihon runtime

**Date:** 2026-11-13  
**Status:** Source changes prepared; Flutter CI, Android build and device validation pending.

## Scope and reference boundary

This phase works on RAVEN23 only. The chapter-reader screen in the supplied Zangetsu project was inspected as the UI/interaction reference. FlixQuest and OpenStream were not opened or inspected.

The goal is to bring the chapter-reader controls and user-facing reading options closer to Zangetsu while keeping RAVEN23's existing Mihon extension runtime as the source of chapter pages, authenticated requests, headers, cookies and Cloudflare/session state. Zangetsu's Mangayomi page queue, native image provider, multi-chapter strip queue and tracking internals were not transplanted because they are coupled to Zangetsu's source and page models and are not interchangeable with `MihonRuntimeService`.

## Work item changes

- `lib/manga/ui/manga_work_screen.dart`: once a source and chapter are ready, the primary action uses the concise `Read` label. The no-source state remains `Find a source`; existing `Continue reading` behavior is retained for partial progress.
- `lib/catalog/home_rows.dart`: the Manga/Manhwa/Manhua Home hero carousel uses `Read` and `Install sources` for its two actions. The detail-page synopsis action is not renamed.

## Chapter-reader UI and behavior

`lib/manga/ui/manga_reader_screen.dart` now exposes the following reader controls in the RAVEN23 palette and spacing system:

- **Reader chrome:** back, work/chapter title and chapter picker, overflow menu, chapter previous/next controls, page scrubber and page position display.
- **Overflow actions:** open the source chapter in RAVEN23's source WebView or the external browser, translate chapter, mark read/unread, and open reader settings.
- **Reading modes:** continuous vertical/Webtoon, left-to-right paged and right-to-left paged reading; automatic Webtoon detection from the first decoded page; optional two-page landscape spreads.
- **Display:** width, height, contain, original and smart fit modes; black, white, gray and app-surface backgrounds; none, grayscale, invert and sepia filters; optional scan-margin cropping.
- **Navigation:** RTL-aware page-edge tap zones in paged mode (one full spread in double-page mode); top/bottom viewport scroll zones and a centre controls zone in Webtoon mode; optional pull-to-previous/next-chapter at strip boundaries; auto-scroll in both continuous and paged modes, with adjustable speed and pause/resume/stop controls; optional Android volume-key paging with inversion. The chapter picker opens near the currently selected chapter.
- **Zoom and position feedback:** pinch zoom remains available through `InteractiveViewer`; double-tap toggles a 2.2× zoom and reset; a temporary page-number pill appears as the reader moves.
- **Comfort:** keep screen awake, immersive/fullscreen mode, system/portrait/landscape orientation and per-reader brightness with a system-brightness reset. Paged auto-scroll advances one page or one spread at a speed-derived interval; continuous mode scrolls smoothly through the vertical strip.
- **Page actions:** long-press a loaded page to save it to the Android gallery or share it. Gallery saving uses MediaStore on Android 10+ and reports unsupported older Android versions rather than silently claiming success.
- **Translation:** existing page/chapter translation, language and engine selection, translated-page display and cancellation are retained.

The reader continues to persist mode, direction, display and comfort preferences through `MangaReadingStore`. The default settings preserve the existing RAVEN23 behavior unless the new preference is explicitly enabled.

## Crop helper and tests

- Added `lib/manga/ui/manga_reader_crop.dart`, a bounded-resolution scan-margin detector that returns normalized content bounds.
- Added `test/manga/manga_reader_crop_test.dart` for flat-margin detection, no-margin scans and invalid pixel buffers.
- Crop detection is cached per page state, including the no-crop result, so a scan is not repeatedly decoded on subsequent widget rebuilds.
- Added the crop test to `.github/workflows/android-ci.yml`; the focused Flutter pre-build suite now contains 14 test files.
- Added the crop helper and its test to `tool/format_phase57_dart.sh`. The current formatter list contains 56 unique existing Dart paths.

## Android bridge

`MainActivity.kt` provides two narrowly scoped methods:

- `raven23/reader_volume_keys`: intercepts volume keys only while the reader's explicit preference is enabled; the activity disables interception on pause and cleanup.
- `raven23/reader_comfort` / `saveImageToGallery`: writes requested page bytes into `Pictures/RAVEN23` through MediaStore on Android 10+; failed writes delete the incomplete MediaStore row.

When the volume-key preference is off, Android receives its normal volume-key events.

## Local checks and acceptance gate

Static validation is limited to the checks that are available in this editing environment: locale JSON parsing and key parity, CI YAML parsing, shell syntax, formatter/test path existence and uniqueness, and Kotlin parser diagnostics. Flutter/Dart, Gradle and Android SDK are not installed here. Therefore this phase is **not** marked built or runtime-accepted until GitHub Actions has passed `flutter analyze`, formatting, all 14 focused Flutter tests, the Android Mihon ABI test, ARM64 Release APK build and APK audit, followed by on-device checks for chapter loads, page turns, rotation/double-page layout, save/share and source-authenticated image delivery.

## Changed files

- `lib/manga/ui/manga_work_screen.dart`
- `lib/catalog/home_rows.dart`
- `lib/manga/ui/manga_reader_screen.dart`
- `lib/manga/ui/manga_reader_crop.dart`
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/MainActivity.kt`
- `assets/translations/ar.json`
- `assets/translations/en.json`
- `assets/translations/es.json`
- `assets/translations/hi.json`
- `test/manga/manga_reader_crop_test.dart`
- `tool/format_phase57_dart.sh`
- `.github/workflows/android-ci.yml`
- `phases/PHASE63.7_ZANGETSU_CHAPTER_READER_UI_PARITY.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/README_CHANGED_FILES.txt`
