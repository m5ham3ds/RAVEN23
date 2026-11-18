# RAVEN23 — PHASE63.2: Pinned Manga tabs, per-work persistence, Notify and Mihon picker parity

**Date:** 2026-11-13  
**Baseline:** Owner-confirmed successful PHASE63.1 build and follow-up device screenshots.  
**Reference-first audit:** `Zangetsu-main.zip`, especially `lib/features/detail/detail_screen.dart`, `lib/features/detail/detail_tabs.dart`, `lib/core/ui/source_switcher.dart`, `lib/core/ui/detail_prefs.dart`, and the manga source resolution path.  
**Scope:** Manga / Manhwa / Manhua detail header, pinned tabs, chapter preferences, automatic source matching, Mihon source switcher and work actions.

## 1. Pinned four-tab header

RAVEN23 now follows the same nested-scroll structure as Zangetsu:

- `NestedScrollView` hosts the expandable `SliverAppBar`, work information and a pinned `SliverPersistentHeader` containing the four tabs: Chapters, Characters, Related titles and Details.
- `TabBarView` retains a separate scroll position for each tab.
- Empty and loading states use a scrollable viewport with `AlwaysScrollableScrollPhysics` and a minimum viewport height. This is important: an inert `Center` in an empty tab can prevent the outer nested scroll from collapsing, making the pinned tab header appear to move or stop pinning.
- Work-specific `PageStorageKey`s preserve the nested page and each tab's scroll state while switching tabs.

## 2. Requested work-header composition

Replaced the previous banner-then-text-block design with the owner-provided composition:

- Full-width banner artwork with a dark readability gradient.
- The cover poster overlaps the bottom-left area of the banner.
- Main title, English title/subtitle and the format/country/score chips sit to the poster's right.
- The top app-bar title remains visible in its collapsed state.
- The full-width Continue / Find-source action, Mihon source card, synopsis, credits and work actions remain below the artwork in the established Zangetsu order.

## 3. Chapter order and per-work settings persistence

- Chapter metadata and chapter names are normalized to numeric chapter values before sorting. Values returned as strings and Arabic/Persian numerals are handled; Mihon's `-1` unset sentinel is ignored so the chapter title can supply the number.
- The default is ascending (smallest chapter first). Reverse order is an explicit user toggle and only changes the visible list order.
- Per-work preferences are stored under the AniList work id: list/grid view, ascending/reversed order, scanlator filter, selected tab, Notify enablement, chapter-count baseline and notification source id.
- `updateWorkPreferences` performs serialized read-modify-write merges. Chapter refreshes update only notification baselines and cannot overwrite concurrently changed view/order/tab preferences.
- Restoring preferences waits for queued writes. This addresses the quick-close/reopen case where a final route save might otherwise still be pending while the new route reads an older value.
- Source pins, reading status, chapter progress, downloads and reader settings remain in their existing scoped stores.

## 4. Work actions and Notify

The action row now presents, in order, **My List → Notify → Share → Web**. Notify is not a decorative toggle:

- It requests Android notification permission.
- It stores an enablement flag and the current chapter-count baseline for this work and source.
- On opening the work page and when the app resumes, the catalogue is refreshed; a higher chapter count triggers a local notification.
- The enablement state and baseline are restored per work.

**Explicit boundary:** this implementation does not run a periodic checker while the app process is closed or the user is away from the work page. A WorkManager/background subscription worker would be a separate enhancement and is not claimed as complete Zangetsu parity. Tracking-provider synchronization is also not implemented.

## 5. AniList aliases and all-source resolution

- The detail query requests `title{romaji english native}` and `synonyms`; the `MangaTitle` model retains each value.
- `buildMangaTitleQueries` produces an ordered, de-duplicated list of all available title aliases.
- `_searchOneSource` searches every alias, not only the primary display name, and de-duplicates catalogue URLs returned across aliases.
- Automatic resolution tries the last successful source first, then continues through every other installed Mihon source if no strict match is found. A remembered global provider is a preference, not a reason to stop the source sweep.
- Auto-binding remains conservative: a whole normalized AniList title/alias match is required. Similarity scores rank manual suggestions only; partial title matches are not silently bound.
- An existing work-specific source binding remains authoritative until the user explicitly chooses another source or invokes Auto Resolve.

## 6. Mihon source picker parity

- The source selector is a bottom sheet with **All** and **Manga** tabs, an **Auto Resolve** row, a Manga group heading, current-source highlighting and a long-press pin/unpin gesture.
- Pinned sources retain user-selected ordering and appear before other installed sources.
- Each source row displays its extension icon extracted from the already trusted/installed extension APK. If the APK has no readable icon, the existing generic extension glyph is used as a safe fallback.
- The row overflow menu exposes Solve Cloudflare and Sign in for HTTP sources, and Source settings only when the source advertises configurable settings.
- In the current RAVEN Mihon bridge, every enumerated source belongs to the Manga extension runtime; therefore All and Manga presently show the same entries. They will diverge only when other media-type source families are added.

## 7. Files changed

- `lib/manga/ui/manga_work_screen.dart` — pinned tabs, scrollable empty/loading states, requested header, Notify placement and state, numeric chapter sorting, all-alias source resolution, source-picker layout/actions/icons, and per-work preference restoration.
- `lib/manga/ui/manga_reading_store.dart` — source pin order, per-work atomic preferences, and queued-write-safe preference reads.
- `lib/manga/ui/manga_source_matcher.dart` — title alias collection and chapter number parsing (including localized digits).
- `lib/manga/mihon/mihon_runtime.dart` — optional base64 extension-icon data from the native bridge.
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/mihon/MihonExtensionLoader.kt` — safely extracts a small PNG icon from the trusted extension APK; icon failures do not block loading.
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/mihon/MihonBridge.kt` — emits the optional extension icon with source metadata.
- `test/manga_reading_store_test.dart` — verifies queued final preference saves are visible on immediate restore, alongside existing work-scoped preferences and source pin order tests.
- `tool/format_phase57_dart.sh` — includes the modified `mihon_runtime.dart`; target count increases to 51.
- `.github/workflows/android-ci.yml` — formatter summary count updated to 51.
- `assets/translations/ar.json`, `en.json`, `es.json`, `hi.json` — unchanged in this follow-up; all four remain key-identical at 2,317 keys.
- `phases/README_MASTER_IMPLEMENTATION.md`, `phases/README_CHANGED_FILES.txt` and this report.

No Movie, Series, Anime, TV, video-provider, player, Home feed or video-source implementation was intentionally changed.

## 8. Verification and limitations

Static checks completed in the editing environment:

- All four locale JSON files parse and contain exactly **2,317** identical keys.
- `bash -n tool/format_phase57_dart.sh` passes.
- All **51** formatter target paths exist.
- `.github/workflows/android-ci.yml` parses successfully as YAML.
- The Anilist query still requests Romaji, English, Native and synonyms; the screen passes all four alias families to the all-source search.
- The work page contains a pinned `SliverPersistentHeader`; empty/loading tab states are scrollable.
- Source icon data is optional and has a generic UI fallback; native icon extraction is guarded so an icon failure does not abort a trusted extension load.

Flutter, Dart, Gradle and the Android SDK are unavailable in this editing environment. Kotlin compiler is present, but Android/Mihon dependencies and Android SDK classes are not; therefore no `dart format`, `flutter analyze`, `flutter test`, Kotlin/Gradle build, Release APK or on-device test is claimed here. The ZIP archive is only a source handoff, not a build-accepted release.

**Next validation:** run the existing Android CI gate and install the resulting APK. On-device acceptance should confirm that tabs remain pinned after scrolling each of the four tabs, empty tabs still collapse the header, the initial chapter order is ascending, work-specific choices survive back/reopen, Notify is between My List and Share, all AniList aliases are searched across installed Mihon sources, extension icons load, and the three source overflow actions call the correct native flows.
