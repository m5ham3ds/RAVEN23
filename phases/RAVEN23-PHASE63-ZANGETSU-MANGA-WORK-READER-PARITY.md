# RAVEN23 — PHASE63: Zangetsu Manga Work & Reader Parity

**Date:** 2026-11-12  
**Baseline:** Owner-supplied `RAVEN23_PHASE62_MANGA_WORK_DETAIL.zip`  
**Reference:** Owner-supplied `Zangetsu-main.zip`  
**Scope:** Manga / Manhwa / Manhua work detail and chapter reader only.

## 1. Baseline and decision record

PHASE62 is retained as the project baseline. Its Mihon runtime, source repositories/extensions, explicit work-to-source binding, chapter catalogue, chapter downloads, read/unread state, saved-work store, per-source reading progress and AniList metadata service were not replaced. The owner confirmed that all builds through PHASE62 succeeded; that confirmation applies to the baseline, not to this new phase.

The supplied conversational report contains conflicting descriptions of the bottom reader arrows. The implementation in the actual Zangetsu reference source (`lib/features/reader/manga_reader_screen.dart`, `_buildBottomBar`) is the deciding reference: the left/right actions navigate to the previous/next chapter, and the slider seeks within the current chapter. RAVEN23 follows that source behavior. The chapter title control opens the chapter picker.

The work page is limited to four tabs: **Chapters, Characters, Relations, Details**. Source management remains available from the Chapters experience as a modal; it is not a fifth tab. The work Details section contains metadata, genres, tags and synopsis in the corresponding sequence. There is no Recommendations block or Volumes row in the Manga work UI.

## 2. Work page changes

- Kept exactly four tabs and a four-page `TabBarView` / `TabController` pairing.
- Removed the separate Sources tab concept; source discovery, binding, change and detach remain available through the Chapters source-management action.
- Kept Relations limited to the AniList manga relation set. No recommendation collection or recommendation cards are requested or rendered; anime and novel relations remain excluded.
- Reconciled the Details field order with the Manga detail reference: bound source, status, year, chapter count, format, score (`/10`), popularity, favourites, source material, country of origin, start/end dates, native title, up to five aliases, genres, spoiler-aware tags, synopsis.
- Added/retained the relevant AniList detail fields (`endDate`, `favourites`, `source`, `tags{name rank isMediaSpoiler}`) in the detail query and model.
- Spoiler tags are hidden initially; the reader can reveal them explicitly.
- Replaced the extra AniList external-link and separate bookmark/status icons with an icon-over-label row: My List, Share and Web (Web appears only when a Mihon source is bound and has a base URL). The My List sheet manages local list membership and reading status together. It does not claim remote AniList account synchronization.
- Removed the redundant app-bar refresh action; chapter/source refresh actions remain in their relevant Chapters flow.
- Added a short synopsis preview with “Read more” navigation to Details, plus compact Starring / Creators / Genres lines above the My List / Share / Web action row.
- Kept missing actions honest: notification subscription and external tracker synchronization are not fabricated. This RAVEN23 baseline uses public unauthenticated AniList queries and has no Manga chapter-notification/tracker integration equivalent to Zangetsu's optional services.

## 3. Reader changes

- Floating top controls show back, work/chapter title and page counter, chapter-picker access, and the overflow menu.
- The overflow menu keeps source WebView/browser actions where a valid chapter URL exists, translate chapter, mark/unmark read and reader settings.
- Floating bottom controls use previous chapter, an intra-chapter page slider, and next chapter. This matches the actual Zangetsu `_buildBottomBar` contract.
- Reader settings are organized into five groups matching the reference naming: Translation, Reading, Display, Navigation and Comfort.
- Existing settings are persisted locally: vertical / LTR / RTL reading, fit mode, background, image filters, auto-scroll and speed, keep-screen-on, fullscreen and brightness.
- Translation uses an on-device OCR stage. The page file is taken from the existing Mihon/cache image flow or downloaded through the selected Mihon source and written to app-private temporary storage for recognition. The page image is not sent to the online translation endpoint; only OCR text blocks are sent when Online is selected.
- Online translation currently uses the Google Translate web endpoint. Offline translation uses Google ML Kit Translate and requires its language models to be downloaded. Both OCR recognizer modules and translation models are requested only after the user confirms the download prompt.
- Android OCR recognizers are configured for Japanese, Chinese, Korean, Latin-script English/Spanish/French/German/Portuguese/Italian and Devanagari Hindi. The offline translation language set is taken from ML Kit's supported language list; the reader's target-language selector is a curated subset.
- Translated text regions are drawn over the page using normalized OCR bounding boxes, and the overlay accounts for the reader's image fit mode. Translation batches and their settings flow are bound to the active chapter-load generation: switching chapters invalidates the previous generation before the progress-save await, and stale OCR/model-status/model-download continuations cannot apply results or start translation on the newly selected chapter.

## 4. Files changed or added

- `lib/manga/anilist/anilist_manga_service.dart`
- `lib/manga/ui/manga_work_screen.dart`
- `lib/manga/ui/manga_reader_screen.dart`
- `lib/manga/translation/manga_translation_models.dart` (new)
- `lib/manga/translation/manga_translation_platform.dart` (new)
- `lib/manga/translation/manga_page_translation_service.dart` (new)
- `lib/manga/translation/manga_translation_overlay.dart` (new)
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/MainActivity.kt`
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/MangaTranslationBridge.kt` (new)
- `android/app/build.gradle`
- `assets/translations/ar.json`, `en.json`, `es.json`, `hi.json`
- `test/manga_detail_metadata_test.dart`
- `tool/format_phase57_dart.sh` (updated formatter gate to include all new PHASE63 translation Dart files)
- `.github/workflows/android-ci.yml` (updated CI step/report labels and the formatter target count to PHASE63 / 50 files)
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/README_CHANGED_FILES.txt`
- `phases/RAVEN23-PHASE62-MANGA-WORK-DETAIL-AND-READER.md` (historical note only)
- this PHASE63 report

## 5. Preserved boundaries

No Movie, Series, Anime, TV, player, subtitle, video-source or Home catalogue implementation was intentionally changed in this phase. Application-code changes are confined to Manga metadata/detail/reader, the Android OCR/translation bridge and the four app locale JSON files. The additional workflow/formatter changes only extend the PHASE63 CI formatting gate and its labels; documentation and one focused metadata regression test were updated. The Mihon source runtime still owns extension networking, headers, cookies, Cloudflare and page retrieval. The app's saved-work state and chapter progress remain local and source-scoped as before.

## 6. Static checks performed in the editing environment

- Delimiter/lexical structure check passed for the changed Dart sources, metadata test and Kotlin bridge/activity files.
- Reader translation cancellation was hardened so chapter navigation invalidates prior work before awaiting progress persistence; the translation settings flow and the OCR/model-status/model-download continuations also verify the active chapter generation before changing state. The reader has one brightness reset on disposal (no duplicate restore call).
- Arabic, English, Spanish and Hindi locale JSON files parsed successfully; all four locale key sets match, including the new `web` label.
- Structural check confirmed four Manga tabs, no Sources tab, no Recommendations copy and no Volumes entry in the work-screen UI.
- Details metadata sequence and spoiler-hidden-by-default behavior were reviewed against the current source.
- AniList query/model field additions and the Android MethodChannel names were reviewed for matching identifiers.
- Updated the existing formatter script invoked by Android CI so all four new PHASE63 translation Dart files are covered; `bash -n` passes, all 50 formatter targets exist, and the workflow YAML parses successfully. The workflow labels and generated CI summary now identify PHASE63 / 50 files.
- Parsed the Arabic, English, Spanish and Hindi locale JSON files successfully; each has 2,281 keys and all four key sets match exactly.

## 7. Validation not performed / remaining compatibility differences

The editing container does not contain Flutter, Dart, Gradle or an Android SDK (`ANDROID_HOME` / `ANDROID_SDK_ROOT` are unset). Consequently, this phase has **not** been run through `dart format`, `flutter analyze`, `flutter test`, Kotlin/Gradle compilation, Android Release APK assembly, APK audit or physical-device testing. No claim is made that PHASE63 has built successfully. The owner's prior successful builds through PHASE62 are preserved as baseline evidence only.

This is a scoped parity implementation, not a claim of 100% feature parity with every optional Zangetsu integration. The current RAVEN23 reader does not yet expose Zangetsu's Auto Webtoon detection, double-page landscape, crop borders, pull-to-change-chapter gesture, hardware volume-key paging/inversion, or its full set of configurable online translation providers (the current online provider is Google only). The Manga detail action row also does not show Notify or Tracking because this baseline has no matching notification/tracker service. These items must remain recorded as gaps rather than being represented as implemented.

**Next required gate:** run the existing repository CI with the focused Manga metadata and reading-store tests, scoped formatter, `flutter analyze`, Android Mihon ABI test and ARM64 Release/APK audit. Then verify the Manga work page and reader on-device, including OCR module availability and both translation modes. Only after those checks should PHASE63 be marked build/device accepted.

## 8. CI failure follow-up — 2026-11-12

The first uploaded PHASE63 Release workflow (run `43283800739`, commit `5115fe26b4c82e843295c0b7b7352d62afa84888`) passed dependency resolution and the 50-file scoped formatter, then stopped at `flutter analyze`. The two blocking errors were both undefined `AppType.caption` getters in `manga_reader_screen.dart` (settings subtitle and translation note). `AppType` defines `metadata` but not `caption`; both usages are now `AppType.metadata`. The follow-up also updates the two deprecated dropdown initializers to `initialValue` and removes three analyzer-confirmed redundant imports. The exact formatter patch and original logs are retained under `docs/build-reports/2026-11-12-phase63-run-43283800739/`; the repair details are in `PHASE63_BUILD_REPAIR_2026-11-12.md`.

The original CI never reached focused Flutter tests, Android Mihon unit tests, wrapper generation, Release APK build or APK audit. This repair environment does not have Flutter/Dart/Android SDK installed, so no successful analyzer/test/Gradle/APK result is claimed. PHASE63 remains **pending a fresh CI run and device validation**.
