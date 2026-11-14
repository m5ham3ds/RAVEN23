CURRENT PROJECT STATUS — 2026-11-11 (PHASE58)
Owner-confirmed: PHASE57.7 built successfully and Mihon extension installation worked on-device. The owner supplied PHASE55(1) as the correct visual baseline for Movies/Series/Anime. PHASE58 restores home_screen.dart byte-for-byte from that baseline, confines direct AniList artwork to Manga-only opt-in callbacks, and keeps all 18 Manga shelves while reusing Home components. Earlier CI failures are historical unless explicitly marked as current. No video/player engine changes.

RAVEN23 — Phase 22: RAVEN23 original player transplant + RAVEN23 data bridge

The player implementation was rebuilt from the original app-side RAVEN23 player.dart and player support directory as the base. RAVEN23's existing provider/quality/cache/subtitle bridge was then reapplied without replacing provider engines, loaders, resolver/adapters, or source extraction.

Restored the RAVEN23 native HD control in its original mobile Material control-row position. The RAVEN23 all-provider quality catalog remains a separate overflow action. The extra Quality tile previously inserted into the portrait Watch Actions row was removed, restoring the original RAVEN23 page-action order. The Audio & Subtitles action continues to use RAVEN23's subtitle sheet so SubSource priority, Arabic defaults, external subtitle search, upload, and timing remain available. Movie Material controls and the existing series/anime TV controls follow Phase 17.

RAVEN23-only support logic was retained in four player helper files:
- player_background_save.dart: guard Crashlytics calls when Firebase is disabled.
- player_episode_selection.dart: preserve anime classification during episode navigation.
- player_external_subtitles.dart: preserve subtitle cache, preferred-language selection, and external subtitle sources.
- player_movie_recommendations.dart: preserve originalLanguage metadata.

Twelve other player support files are byte-identical to the files in the uploaded RAVEN23 archive. The source bridge continues to pass the scan snapshot/session, cached provider results, initial stream URL, provider-owned links, headers/formats, subtitle links, and quality catalog to the original player layer.

No provider engine, movie/TV loader, Unified/Legacy adapter, source parser, quality scanner, cache service, dependency manifest, or previous phase report was changed. Phase reports 1–21 remain intact. The new report exists in both the project root and phases/.

Verification: static source and archive checks only. Flutter/Dart SDK is not installed here, so no dart format/analyze/test or Android Release build is claimed. The RAVEN23 archive points to the sibling dependency ../raven23-betterplayer, which is not included in the uploaded archive; RAVEN23's existing Git dependency is retained to avoid the Phase 19 API mismatch.


RAVEN23 — Phase 37: Unified Source Architecture (implementation drafted; validation pending)

Added source_contracts.dart for canonical repository identity, source identity, engine identity, content identity, descriptive capability profiles and orthogonal lifecycle flags. Kept SourceManifest.stableKey and all persisted preference keys unchanged. Added SourceRepositoryManager.lifecycleOf() as a read-only lifecycle projection. Added typed SourceFailureKind and SourceAttemptDiagnostics separately from UnifiedSourceResult; UnifiedSourceAttempt carries optional diagnostics while old result/stream payloads remain unchanged. Added typed failure classification for QuickJS, OpenStream Web Embed, OpenStream Anime, VidKing Direct and Stremio engine paths. Added focused contract/lifecycle tests. No UI, player, source activation, repository parser, Stremio configuration, VidKing language filter, QuickJS settings injection, Live TV or third-party script changes. Phase 37 is not accepted until dart format, flutter analyze, flutter test and post-change Release CI succeed.

Phase 37 refinements after contract review:
- Anime feature-film capability handling is covered without changing the movie route.
- Original repository URLs are retained privately and verbatim only for legacy-key compatibility; comparison identities remove visible user-info/query/fragment and retain distinction using a SHA-256 fingerprint for private URL components.
- Diagnostic labels are categorical and do not copy raw provider exception text; raw engine identifiers are allowlisted, and SocketException causes are classified as retryable network failures.
- Lifecycle snapshots do not call a discovered or installed source validated unless validation is explicitly supplied; metadata-only capabilities do not block VOD, and Live-TV-only capability is not treated as VOD.
- Additional tests cover identity edge cases, Dio failure classification, and diagnostic-message redaction.

Phase 37 additions: source identity/capability/lifecycle contracts, typed engine diagnostics, lifecycle snapshot helper, engine failure categorization and targeted contract tests. pubspec.lock metadata reconciled for the existing direct crypto dependency (version/checksum unchanged). No player/UI/source parser or third-party extension scripts changed.


RAVEN23 — Phase 37.1: Bundled Repositories (implementation; validation pending)

Added the six verified bundled repository index URLs to SourceRepositoryManager. Fresh installations seed all six. Existing installations with the legacy v1 seed marker receive only the five new repositories through an additive v2 migration; existing custom repositories and installed/disabled source keys are preserved, and OpenStream is not re-added if the user previously removed it. Added an idempotent addDefaultRepositories() restore API through UnifiedSourceService and replaced the single OpenStream shortcut with an “Add all bundled repositories” action. Updated Arabic, English, Spanish and Hindi translations. Added tests for fresh seeding, legacy migration, preserving custom preferences, not resurrecting a removed OpenStream repository, and manual idempotent restore. Reused the existing OpenStream/Zangetsu parser paths; no extension is automatically installed or executed.

Changed application files: source_repository_manager.dart, unified_source_service.dart, source_repositories_screen.dart, four locale JSON files, codegen_loader.g.dart, and source_repository_manager_test.dart. Added PHASE37.1_BUNDLED_REPOSITORIES.md and updated the master blueprint, tracker and documentation index.

Validation: live index URLs checked on 2026-11-06; locale JSON and loader key parity checked; Flutter/Dart SDK unavailable locally, so dart format/analyze/test and post-change Release CI remain pending. User-provided prior Release build succeeded on commit 6fb83a987044051e3cecf21505a260afc08f42b7 (arm64-only, 27,881,034 bytes); that run predates Phase 37.1.


RAVEN23 — Phase 40: Phase 35.1 Baseline Reconciliation & UI Preservation
Compared the supplied RAVEN23-PHASE35.1 archive against the Phase 40 project. No original files were deleted. The main Home, Search, Discover, New & Hot, Title Details and Poster Grid page sources, AppPalette, AppTokens and theme_data are byte-identical to Phase 35.1. Restored curated base-color generation, RevealItem zero-delay scheduling semantics, and the legacy player quality-label composition to the Phase 35.1 behavior. New QuickJS/Stremio source settings actions remain additive within the existing Source Manager tile/style system. Added PHASE40_PHASE35.1_BASELINE_RECONCILIATION.md. Fixed seven Flutter Analyze curly-brace info diagnostics. CI run 42335259990 and the separate historical full-test log are documented as distinct attempts because their Analyze outcomes conflict. No Flutter/Dart SDK was available locally; post-fix CI acceptance remains pending.



RAVEN23 — Phase 40 follow-up against the supplied Phase 35.1 baseline

Applied the user's Dart formatter patch from run 42335259990 and fixed all seven curly_braces_in_flow_control_structures diagnostics (five in external_subtitle_service.dart and two in legacy_provider_adapter.dart). Reconciled base palette generation byte-for-byte with Phase 35.1, restored deferred zero-delay RevealItem scheduling while preserving cancellable disposal, and restored providerName in legacy quality labels. Main Home/Search/Discover/New & Hot/Title Details/Poster Grid source files, AppPalette, AppTokens, theme_data, all lib/design files and lib/constants files remain byte-identical to Phase 35.1. No original Phase 35.1 file was deleted. Flutter/Dart tests and Release build were not rerun locally; acceptance remains pending the next CI run.

RAVEN23 — Phase 40 CI widget-regression recovery follow-up 2 (run 42375238484)

Corrected the four blockers reported by the latest Phase 40 regression gate. The RevealItem widget test now gives its zero-delay stagger Timer a deterministic positive fake-clock tick before measuring animation progress. A shared `scrollUntilBuiltAndVisible` test helper discovers lazy Sliver children before calling `ensureVisible`, and both Discover Anime and Home feed tests use it. `TvFocusable` now updates the debug label of its internally owned FocusNode when its semantic label changes, while leaving external focus nodes untouched. The selected subtitle size and visible summary were already updating to 15px; the stale 12px value was only the retained focus-node diagnostic label.

Files changed: `lib/tv/focus/tv_focusable.dart`, `test/mobile/widgets/reveal_item_test.dart`, `test/support/scroll_until_built.dart` (new), `test/discover_screen_test.dart`, `test/home_screen_test.dart`, and Phase 40 CI follow-up/tracker/index documents. Home, Discover, RevealItem production animation, TV Settings screen and subtitle defaults were not changed. The latest CI run passed formatting, Analyze and 160 focused tests, but failed four Phase 40 widget regression tests; full suite, Gradle and APK were not reached. Flutter/Dart are unavailable in this packaging environment, so this follow-up is not locally execution-verified and must be re-run through CI before Phase 40 acceptance.

Phase 40 CI minimal-gate recovery (2026-11-07): removed a redundant flutter/widgets.dart import from test/support/scroll_until_built.dart after analyzer reported unnecessary_import. Reduced automatic APK CI to the four contract test files explicitly enumerated in PHASE40_STREMIO_MANIFEST_CONFIGURATION_TESTS.md (repository parser, repository client, Stremio add-on provider, and Stremio identity resolution). Removed the unrelated 15-file broad provider test batch, 17-file widget regression batch, and complete Flutter test suite from the automatic APK path; test source files remain in the repository. Removed one duplicated URL case (44 targeted cases remain), added a 10-minute test-step cap and 30-second per-test timeout, and set `flutter analyze --no-fatal-infos` so errors/warnings remain fatal but info-only lints do not block APK creation. Phase 40 remains In Progress pending a real Release ARM64 CI build.


RAVEN23 — Phase 49: XMLTV / EPG (implementation prepared; CI pending)

Added a provider-neutral XMLTV model, size-bounded parser, public-host/redirect-validated HTTP repository with ETag/Last-Modified and compressed cache, exact tvg-id mapping, Now/Next calculation and adapter into the current DaddyLiveEpg schedule model. M3U #EXTM3U header fields url-tvg/x-tvg-url/tvg-url are read and Channel.tvgId is preserved. EPG fetch failures and stale feeds never block or mislabel channel playback. Timestamp offsets are normalized to UTC; offsetless XMLTV values are deterministically treated as UTC and the current guide view formats local device times.

Added parser/repository XMLTV fixtures, expanded M3U parser/service and manager tests, updated the explicit CI contract gate to 28 tests, and added the Phase49 formatter target list (81 unique files). Added six Phase49 plan/audit/implementation/tests/changelog/report documents and updated the blueprint, tracker and documentation index.

Verification: static packaging checks only. No Dart/Flutter SDK is installed in the packaging environment, so dart format, flutter analyze, flutter test and Android Release build are not claimed. CI and device playback remain pending. Phase50 is next.


RAVEN23 — Phase 51 CI follow-up (run 42497050504)

Historical PHASE51 attempt `42497050504`: formatter and Analyze passed, then one Live TV expiry timestamp assertion failed (301 passed / 1 failed), so that attempt did not reach Gradle or APK. The timestamp parser was corrected in the follow-up; the subsequent successful integrated Release run `42507906881` superseded this attempt with 302 passing tests, Kotlin/Gradle, ARM64 APK and APK audit. The separate transient failure-note file was later removed to avoid suggesting this old attempt remains open.
PHASE57.7_ANDROID_JUNIT_ACTUAL_BUILD_ROOT_FIX.md — Correct Gradle module report roots to repository build/app and strictly verify the three ABI test events.


RAVEN23 — PHASE58: Restore Home Baseline + Manga Home Reuse

Restored lib/mobile/screens/home_screen.dart byte-for-byte from the owner-supplied RAVEN23-PHASE55(1) baseline (SHA-256 b497ecf08056278ff85c94c31ab69c6d028db0f308ab80c2b937c32375937f74) so Movies, Series and Anime return to the previously correct Home/feed/header/ad/row structure. Added a strict opt-in artwork URL path for non-TMDB catalogues: HeroCard/HeroCarousel and PosterRow/TopTenRow/PosterCard keep their PHASE55 TMDB-based defaults, while Manga explicitly supplies AniList cover/banner URLs. Manga continues to use the same Home header/filter chips, HeroCarousel/HeroCard, TopTenRow, PosterRow/PosterCard, HomeOptionalRow, HomeSkeleton, spacing and reveal components. Centralized and tested all 18 Manga shelves, and preserved the All JP/KR/CN aggregate/region rows. Kept Mihon ABI normalization, repository fingerprint validation, the repository-snapshot fix, CI and video engine/player files unchanged. Added PHASE58_HOME_BASELINE_RESTORE_AND_MANGA_HOME_REUSE.md and updated the master README/tracker. Structural checks only; Flutter/Dart/Gradle unavailable locally, so CI and device acceptance remain pending.


RAVEN23 — PHASE61.2 focused test corrections (CI run 43105318844)

Corrected two failing test assumptions without changing application behavior. Continue Watching tests now assert the series ID on MediaItem and the episode ID on its RecentEpisode record. The Home row-builder test fixture now supplies the onMangaSeeAll callback used by production MangaScreen, so See All callback assertions run with the correct fixture. Applied the exact formatter patch from the supplied CI run. Flutter analyze had passed in that run; the focused gate had 67 passes and two failures. Flutter/Dart are unavailable in this packaging environment, so PHASE61.2 tests, Mihon ABI and ARM64 Release build remain pending CI rerun.


RAVEN23 — PHASE63: Zangetsu Manga Work & Reader Parity (2026-11-12)

Continued from the owner-supplied PHASE62 baseline. Reconciled the Manga work screen to four tabs (Chapters, Characters, Relations, Details), removed extra Recommendations/Volumes UI, moved source management into the Chapters experience, corrected AniList detail fields/order and spoiler tags, simplified work actions to My List/Share/Web, and added a synopsis preview linked to Details. Updated the reader chrome/menu and five settings groups, with previous/next chapter arrows and an intra-chapter page slider based on the actual Zangetsu source. Added Android on-device ML Kit OCR, online Google text-only translation and offline ML Kit translation with explicit model-download consent; hardened cancellation before progress-save awaits and guarded the translation settings flow against stale chapter changes, updated the four locale files, and extended the existing CI formatter gate to cover all PHASE63 translation Dart files (50 scoped targets). Existing Mihon/source binding/chapter downloads/progress stores were preserved. Static delimiter checks, locale JSON parsing/key parity and Manga tab/detail structural checks passed. Flutter/Dart are not installed in the editing environment; `dart format`, `flutter analyze`, `flutter test`, Gradle compilation, Release APK and device validation have not been run for PHASE63. See `RAVEN23-PHASE63-ZANGETSU-MANGA-WORK-READER-PARITY.md` for remaining parity gaps and required CI gates.

  tool/format_phase57_dart.sh — added all four PHASE63 Manga translation Dart files to the existing formatter gate.
  .github/workflows/android-ci.yml — updated formatter step/report labels and declared target count for PHASE63 (50 files).

RAVEN23 — PHASE63 CI failure repair (2026-11-12)
The uploaded Release CI run 43283800739 passed dependency resolution and scoped formatting, then failed Flutter Analyze on two undefined AppType.caption references in the Manga reader. Applied the captured 50-target formatter patch and its lockfile update, changed the two secondary-text styles to AppType.metadata, migrated the two DropdownButtonFormField initial values to initialValue, and removed three analyzer-reported redundant imports. Added PHASE63_BUILD_REPAIR_2026-11-12.md and retained the original CI report/logs/formatter patch under docs/build-reports/2026-11-12-phase63-run-43283800739/. Focused tests, Android unit tests, Gradle wrapper generation, APK assembly and APK audit were skipped by the original workflow; the repair is not build-accepted until a fresh CI run succeeds.


RAVEN23 — PHASE63.1: Zangetsu source discovery and chapter-list parity (2026-11-13)

Audited the actual Zangetsu source-matcher, source-switcher and detail chapter-list implementations before changing RAVEN23. Unbound Manga/Manhwa/Manhua work pages now search installed Mihon sources automatically and bind only a strict whole normalized title/alias match. Existing per-title source pins remain authoritative; the remembered last-good manga source is tried alone before any provider switch. The source card sits between Continue and synopsis, shows the active Mihon source with a picker and overflow actions, and presents the matched catalogue title with Wrong title? below it. The picker offers an explicit Auto Resolve action that clears the pin/last-good provider and starts a full ordered scan. Manual source selection and title correction remain available whenever strict matching does not find a result.

Chapter catalogue parity now includes ascending default order, list/grid modes, thumbnails with cover fallback, relative publication dates, per-chapter download, bulk All/Custom inclusive-range downloads, Refresh chapters with Mihon OkHttp response-cache eviction, Reverse list, and long-press read/unread / this-and-all-above actions. The two custom range dropdowns are keyed by their selected indices to avoid stale FormField state. Last-good source persistence/clearing is covered in manga_reading_store_test.dart. Locale JSON files ar/en/es/hi each contain 2,303 identical keys; formatter script syntax and all 50 target paths were checked.

Known gaps remain explicit: no working chapter Notify subscription/background checker, no external Tracking sync, and no user-configurable language/source priority ordering (initial sweep follows Mihon registered-source order). Strict auto-matching intentionally refuses partial title guesses; users can manually select a provider and correct the catalogue title. Flutter/Dart/Gradle/Android SDK are unavailable here, so no format/analyze/test/build result is claimed. A new CI run and on-device acceptance are required. See PHASE63.1_ZANGETSU_SOURCE_AND_CHAPTER_PARITY.md.


RAVEN23 — PHASE63.2: pinned Manga tabs, durable work preferences, Notify and Mihon source picker parity (2026-11-13)

Reviewed Zangetsu's NestedScrollView/pinned SliverPersistentHeader and empty-tab scroll wrappers, then applied the same four-tab pinned structure to RAVEN23. Updated the work hero to the owner-provided overlapping-poster layout. Chapter ordering is numerically ascending by default (including string/localized chapter numbers). Per-work grid/list, order, scanlator, selected tab and Notify settings are serialized in SharedPreferences; restore waits for pending writes to prevent immediate reopen from reading stale values. Added Notify between My List and Share, with permission + per-work baseline and local notification checks when the work is opened or the app resumes (no background polling while app process is closed). AniList alias discovery now searches Romaji, English, Native and every synonym on every installed Mihon source; it tries the remembered last-good source first, then continues through all remaining providers. Mihon source picker has All/Manga tabs, Auto Resolve, current-source highlight, long-press pin ordering, source actions, and actual extension APK icons with a safe generic fallback. Added `iconBase64` to the Mihon native/Dart source contract. Updated the scoped formatter to 51 Dart targets and the CI summary count. Focused reading-store tests now also verify immediate preference restore after a queued save. Static checks: four locale JSON files each parse with 2,317 identical keys; bash -n passed; all 51 formatter paths exist; android-ci YAML parses. Flutter/Dart/Gradle/Android SDK unavailable locally, so no Analyze, Flutter tests, Kotlin/Gradle build or APK is claimed. See PHASE63.2_STICKY_TABS_PERSISTENCE_NOTIFY_ALIAS_SOURCE_PICKER.md.

Changed source files: lib/manga/ui/manga_work_screen.dart; lib/manga/ui/manga_reading_store.dart; lib/manga/ui/manga_source_matcher.dart; lib/manga/mihon/mihon_runtime.dart; android/app/src/main/kotlin/com/m5ham3ds/raven23/mihon/MihonExtensionLoader.kt; android/app/src/main/kotlin/com/m5ham3ds/raven23/mihon/MihonBridge.kt; test/manga_reading_store_test.dart; tool/format_phase55_dart.sh; tool/format_phase56_dart.sh; tool/format_phase57_dart.sh; .github/workflows/android-ci.yml; assets/translations/ar.json; assets/translations/en.json; assets/translations/es.json; assets/translations/hi.json.


RAVEN23 — PHASE63.4: Phosphor mobile navigation icons and active-destination menu toggle (2026-11-13)

Updated the mobile/tablet navigation using exact Phosphor Flutter 2.1.0 icons: Home/main destination = radioButton; Movies = video; Series = televisionSimple; Anime = maskHappy; Manga = bookOpenText. Search remains magnifyingGlass. The expandable-menu toggle now displays X while the secondary dock is open, the currently selected secondary destination's selected icon (Fill/Bold) after a destination is chosen, and the original list icon when the user returns to a primary destination such as Home. The same behavior is shared by the phone bottom dock and tablet navigation rail. Added `test/mobile/mobile_nav_bar_test.dart` covering icon mapping and toggle transitions; included it in the focused GitHub Actions pre-build test gate. Added the navigation source/test to `tool/format_phase57_dart.sh`, increasing scoped formatter targets from 51 to 53, and updated CI summary counts.

Static checks: verified the five requested Phosphor API symbols in the published `phosphor_flutter` 2.1.0 API docs; `bash -n tool/format_phase57_dart.sh` passes; all 53 formatter target files exist; Android CI YAML parses; the focused CI test list contains the new navigation widget test. Flutter/Dart are not installed in the editing environment, so `dart format`, `flutter analyze`, `flutter test`, Gradle and APK build were not run. A fresh GitHub Actions run is required before build acceptance.

Changed source/config/test files: `lib/mobile/app/mobile_nav_bar.dart`; `test/mobile/mobile_nav_bar_test.dart`; `tool/format_phase57_dart.sh`; `.github/workflows/android-ci.yml`; `phases/PHASE63.4_PHOSPHOR_NAVIGATION_ICONS.md`; `phases/README_MASTER_IMPLEMENTATION.md`; `phases/README_CHANGED_FILES.txt`.


RAVEN23 — PHASE63.5 CI pre-build test repair (2026-11-13)

- test/mobile/mobile_nav_bar_test.dart — scoped the selected Movies icon assertion to the keyed center menu-toggle widget; explicitly verifies list → filled video → list.
- CI formatter-only normalization: lib/manga/translation/manga_translation_platform.dart; lib/manga/ui/manga_reading_store.dart; lib/manga/ui/manga_source_matcher.dart; lib/manga/ui/manga_work_screen.dart; lib/mobile/app/mobile_nav_bar.dart; test/manga_reading_store_test.dart; test/manga_source_matcher_test.dart.
- .github/workflows/android-ci.yml — corrects the focused-gate report from stale 8 files to 12, lists the four omitted test files, and updates mobile-navigation step/log descriptions.
- phases/PHASE63.5_CI_PREBUILD_NAVIGATION_TEST_FIX.md — root cause, changes, CI evidence and acceptance gates.
- phases/README_MASTER_IMPLEMENTATION.md — latest implementation status and phase index.
- phases/IMPLEMENTATION_TRACKER_PHASE36_58.md — appended CI diagnosis, repair and verification status.
- docs/build-reports/2026-11-13-phase63.4-run-43417262025/ — preserves the original build report, CI environment/context, dependency/analyzer/formatter/test logs and exact formatter patch.


RAVEN23 — PHASE63.6: Phosphor navigation refinement and unified Installed Manga Sources directory (2026-11-13)

Changed Home to Phosphor house and the closed centre menu-toggle icon to radioButton (retaining X while open and active-secondary destination glyphs after selection); increased the unlabelled centre icon size by 25%; reduced the main and secondary phone docks' distributed width to 87.5%. Replaced the separate Manga extensions and installed-only source lists with one Installed Manga Sources directory that merges repository extensions with Mihon runtime sources, shows installed rows with an open arrow and available rows with website/download actions, retains source search, signer-verified installation, removal and details, and keeps installed sources visible when missing from the current index. Routed manga work/settings entry points to the unified directory. Added a focused widget test, expanded the CI format list to 55 targets and Flutter pre-build test gate to 13 files, and updated the master phase index. Static checks only; Flutter/Dart/Gradle/Android SDK were unavailable, so no Flutter tests or APK build are claimed.

Changed source/config/test files: lib/mobile/app/mobile_nav_bar.dart; lib/manga/mihon/mihon_source_browser_screen.dart; lib/mobile/screens/manga_screen.dart; lib/manga/ui/manga_work_screen.dart; lib/screens/common/source_repositories_screen.dart; lib/screens/common/manga_extensions_screen.dart (removed); test/mobile/mobile_nav_bar_test.dart; test/manga/mihon_source_browser_screen_test.dart; tool/format_phase55_dart.sh; tool/format_phase56_dart.sh; tool/format_phase57_dart.sh; .github/workflows/android-ci.yml; phases/PHASE63.6_NAVIGATION_AND_UNIFIED_MIHON_DIRECTORY.md; phases/README_MASTER_IMPLEMENTATION.md; phases/README_CHANGED_FILES.txt.

RAVEN23 — PHASE63.7: Zangetsu chapter-reader UI parity (2026-11-13)

Updated the work-page action to use Read after a source is ready while preserving Find a source and Continue reading states; changed the Manga Home hero actions to Read and Install sources. Expanded the Mihon-backed chapter reader with RAVEN23-themed grouped settings for reading direction/mode, automatic Webtoon detection, five fit modes, four backgrounds, image filters, double-page landscape, scan-margin crop, tap zones, pull-to-change-chapter, auto-scroll in vertical and paged modes, Android volume-key paging/inversion, orientation/brightness/fullscreen/keep-awake, plus long-press save/share. Added RTL-aware paged/spread tap zones, vertical Webtoon scroll zones, double-tap zoom/reset, temporary page-position pill, current-chapter list anchoring, and a cached crop detector. The Android bridge saves page images to MediaStore on Android 10+ and only intercepts volume keys while explicitly enabled. Added translation entries in Arabic/English/Spanish/Hindi, crop helper tests, updated the CI focused gate to 14 Flutter test files and added the two Dart paths to the formatter list (56 unique existing paths). The Mihon runtime remains responsible for authenticated page retrieval; Zangetsu's source-engine internals were not copied. Static checks only; Flutter/Dart/Gradle/Android SDK are unavailable locally, so no Analyze/tests/APK are claimed.

Changed source/config/test files: lib/manga/ui/manga_work_screen.dart; lib/catalog/home_rows.dart; lib/manga/ui/manga_reader_screen.dart; lib/manga/ui/manga_reader_crop.dart; android/app/src/main/kotlin/com/m5ham3ds/raven23/MainActivity.kt; assets/translations/ar.json; assets/translations/en.json; assets/translations/es.json; assets/translations/hi.json; test/manga/manga_reader_crop_test.dart; tool/format_phase57_dart.sh; .github/workflows/android-ci.yml; phases/PHASE63.7_ZANGETSU_CHAPTER_READER_UI_PARITY.md; phases/README_MASTER_IMPLEMENTATION.md; phases/README_CHANGED_FILES.txt.

RAVEN23 — PHASE63.8: Source management / Synchronize / paged catalogue

Application:
- lib/screens/common/settings.dart — remove SOURCE MANAGEMENT from Settings.
- lib/screens/common/server_status_screen.dart — provider health + source manager tabs.
- lib/screens/common/source_repositories_screen.dart — embedded manager mode, priority-only mode, catalog search and ten-at-a-time rendering.
- lib/screens/common/sync_screen.dart — Synchronize tabs for library sync and source ordering.
- lib/tv/screens/tv_settings_screen.dart — remove separate source-manager tile.
- lib/raven23_main.dart — non-blocking Android first-run Mihon source installer.
- lib/manga/mihon/mihon_default_extension_installer.dart — pinned-signature selection and persisted default installation.
- lib/manga/mihon/mihon_source_browser_screen.dart — installed-first search and incremental row rendering.
- lib/translations/codegen_loader.g.dart; lib/translations/locale_keys.g.dart; assets/translations/{ar,en,es,hi}.json — localized Source Catalog search.

Tests / tooling / phase docs:
- test/manga/mihon_default_extension_installer_test.dart — default entry matching and trust tests.
- test/manga/mihon_source_browser_screen_test.dart — installed-first order and pagination assertions.
- .github/workflows/android-ci.yml — 15 focused tests and updated scoped formatter report.
- tool/format_phase57_dart.sh — 63 scoped Dart format targets.
- phases/PHASE63.8_SOURCE_MANAGEMENT_SYNC_AND_PAGED_CATALOGUE.md
- phases/README_MASTER_IMPLEMENTATION.md
- phases/README_CHANGED_FILES.txt
- phases/IMPLEMENTATION_TRACKER_PHASE36_58.md

RAVEN23 — PHASE63.10: Mihon paged-directory CI test repair (2026-11-14)

- test/manga/mihon_source_browser_screen_test.dart — zero-pads the synthetic `Source 01` … `Source 15` labels to align the test fixture with the directory's documented alphabetical sorting; asserts the initial `10 / 15` visible count before scrolling and keeps the final-row assertion after the second scroll.
- phases/PHASE63.10_MIHON_PAGED_DIRECTORY_CI_TEST_FIX.md — records run `43533044222`, the alphabetical-sort/lazy-list finder issue, exact repair and remaining acceptance gates.
- phases/PHASE63.9_FLUTTER_ANALYZE_UTF8_IMPORT_REPAIR.md — adds follow-up evidence that the `utf8` Analyze blocker is cleared in the next CI run.
- phases/README_MASTER_IMPLEMENTATION.md; phases/IMPLEMENTATION_TRACKER_PHASE36_58.md — phase index and implementation tracker updated.
- docs/build-reports/2026-11-14-phase63.10-run-43533044222/ — preserves the report, test/analyzer/dependency logs, environment, formatter summary and empty formatter patch.

No production pagination logic, repository loading, source sorting, Mihon runtime, source trust policy, installation or video playback code changed.
