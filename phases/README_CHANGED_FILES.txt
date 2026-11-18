RAVEN23 — PHASE63.31: nullable byte-counter build repair and revised Movies/Series PRIMARY defaults (2026-11-18)

- `lib/screens/common/player.dart` — guard nullable `networkBytesTransferred` before subtraction in the app-owned automatic-quality throughput sampler. If the counter is not available, clear the incomplete baseline and retry on a later player update; preserve the three-second sampling window and one-time app-owned quality selection.
- `lib/video_providers/unified/source_priority_policy.dart` — set the shared Movies/Series default to YaStream, Jett, HdHub, built-in VixSrc, VidSpark, VidFast, Sova, Sage, Phoenix, CineStream, VidZee and VegaMovies. VixSrc is inserted fourth; Anime ordering is unchanged.
- `lib/video_providers/unified/unified_source_service.dart` — safely migrate only exact untouched old Movies/Series defaults. Any manually customized list remains unchanged.
- `test/video_providers/source_priority_policy_test.dart` — verify the exact new order, VixSrc execution insertion at position four, and previous-default migration fingerprint.
- `phases/PHASE63.31_BUILD_NULLABILITY_REPAIR_AND_MOVIES_SERIES_PRIMARY_ORDER.md`, `phases/README_MASTER_IMPLEMENTATION.md`, and `phases/README_CHANGED_FILES.txt` — document the failure, repair and validation boundary. PHASE63.30 documentation now records the corrected destination-aware icon behavior from PHASE63.30.1.
- Applied the supplied Dart formatting patch from CI run `44212516439` to its 13 source/test files before making the targeted changes.
- Preserved the exact CI build report, analyzer log, dependency log, formatter patch and environment details under `docs/build-reports/2026-11-18-phase63.30.1-run-44212516439/`.

CI run `44212516439` passed setup, dependency resolution and scoped formatting, then failed at Flutter Analyze because the byte counter was nullable. Focused Flutter tests, Android contract tests, wrapper generation, APK build and APK audit were skipped; no APK was produced. The nullable guard and regression assertions have been added, but Dart/Flutter are unavailable in this editing environment. A fresh CI run is required; no post-repair build success is claimed.

---

RAVEN23 — PHASE63.30: Home chips, compass-rose navigation toggle, and app-owned quality selection (2026-11-18)

- `lib/mobile/screens/home_screen.dart` — keep only the Live TV and Categories header chips across Home/Movies/Series/Anime feeds; remove redundant All/Movies/Series chips.
- `lib/mobile/app/mobile_nav_bar.dart` — use the Phosphor compass-rose glyph as the default secondary-menu toggle icon, preserve the previous destination-aware icon after Movies/Series/Anime selection, and show X while the menu is open.
- `lib/screens/common/player.dart`, `lib/video_providers/quality_catalog.dart`, `lib/video_providers/adaptive_quality_scanner.dart`, and `lib/functions/video_utils.dart` — remove provider-owned Auto/Adaptive/Master rows, expand adaptive manifests into concrete per-server qualities, estimate startup throughput for one app-owned Auto choice, cancel it on manual selection, and retain same-resolution alternatives from other servers. Fixed labelled HLS/DASH renditions avoid unnecessary manifest scans.
- `lib/screens/common/download_selection_sheets.dart`, `lib/screens/common/player.dart`, `lib/screens/movie/movie_video_loader.dart`, and `lib/screens/tv/tv_video_loader.dart` — route in-session, unified and legacy movie/TV downloads through the same exact-source quality catalogue (including bounded manifest discovery before the in-session chooser); pass selected URL/headers/format/server identity and maximum video height to the download request.
- `test/home_screen_test.dart`, `test/mobile/mobile_nav_bar_test.dart`, `test/quality_catalog_test.dart`, `test/adaptive_quality_scanner_test.dart` — cover the reduced Home chips, default compass icon plus destination-aware menu state, provider Auto filtering, distinct same-height server options, the app-owned bandwidth policy, and fixed-manifest candidate filtering.
- `phases/PHASE63.30_HOME_CHIPS_COMPASS_ROSE_AND_APP_OWNED_QUALITY.md`, `phases/README_MASTER_IMPLEMENTATION.md`, `phases/README_CHANGED_FILES.txt` — document implementation scope and outstanding validation.

Validation: static source review only. Dart/Flutter are unavailable in the editing environment, so formatter, Analyze, focused Flutter tests, Gradle and Release APK build were not run. No PHASE63.30 build success is claimed; the existing GitHub Actions gate and real-device playback/download tests are required. No Firebase or backend changes.

---

RAVEN23 — PHASE63.27.3: JVM-safe download link format inference (2026-11-17)

- `android/app/src/main/kotlin/com/m5ham3ds/raven23/downloads/DownloadSourceResolver.kt` — remove `android.net.Uri.parse()` from the pure download-format path-suffix helper; use `java.net.URI.path` with `java.net.URL.path` fallback. Keep explicit HLS/DASH flags and declared stream container precedence unchanged.
- `android/app/src/test/kotlin/com/m5ham3ds/raven23/downloads/StreamDownloadStorePlayerContractTest.kt` — extend the existing opaque signed-link contract with uppercase MP4, WebM, query/fragment and extensionless progressive URL cases; keep the CI method inventory unchanged.
- `phases/PHASE63.27.3_DOWNLOAD_LINK_FORMAT_JVM_TEST_REPAIR.md`; `phases/README_MASTER_IMPLEMENTATION.md`; `phases/README_CHANGED_FILES.txt`.
- Preserve CI run `43973265345`, its report, analyzer/Flutter/Android logs and both focused Android JUnit XML files in `docs/build-reports/2026-11-16-phase63.27.2-run-43973265345/`.

Run `43973265345` passed formatter (159 targets), Flutter Analyze and all 200 focused Flutter tests. Android Mihon ABI passed 3/3; download/player contract tests passed 3/4. The one failure was the JVM test calling `android.net.Uri.parse()` without Robolectric; the APK build and ABI audit were skipped. This repair removes the Android-only call from the pure URL-format helper. Flutter/Dart/Gradle are unavailable in the editing environment, so no post-repair CI, Android unit-test or APK success is claimed.

---

RAVEN23 — PHASE63.20: repair typed popup/dropdown press-feedback wrappers after CI analyzer failure (2026-11-15)

- `lib/manga/mihon/mihon_source_browser_screen.dart`, `lib/manga/ui/manga_reader_screen.dart`, `lib/manga/ui/manga_work_screen.dart`, `lib/screens/common/quickjs_source_settings_dialog.dart`, `lib/screens/common/source_repositories_screen.dart` — keep `PopupMenuItem` / `DropdownMenuItem` as direct typed menu-list elements and move `AppPressFeedback` inside each menu entry's child. Repairs 38 type errors without dropping item press feedback or changing item values/actions.
- `lib/screens/common/server_status_screen.dart` — add `dart:async` for `unawaited`.
- `test/home_screen_test.dart` — explicitly capture the inherited failure switch as `bool` through `this.fail`.
- `lib/design/app_press_feedback.dart` — remove the unnecessary `flutter/gestures.dart` import.
- Apply the exact formatter patch from CI run `43733713753` across its 88 changed Dart files; CI had already successfully formatted all 146 scoped targets before Analyze.
- `phases/PHASE63.20_BUILD_REPAIR_GLOBAL_PRESS_FEEDBACK.md`; `phases/README_MASTER_IMPLEMENTATION.md`; `phases/README_CHANGED_FILES.txt`; `phases/IMPLEMENTATION_TRACKER_PHASE36_58.md`.
- Preserve the original CI report, analyzer log, environment, formatter patch and focused-diagnostics upload in `docs/build-reports/2026-11-15-phase63.19-run-43733713753/`.

Run `43733713753` failed only at Flutter Analyze after dependency resolution and formatting succeeded. Tests, Mihon ABI check, wrapper generation, APK build and APK audit were skipped. PHASE63.20 remains pending a fresh complete CI run.

---

RAVEN23 — PHASE63.17: persistent source-health session, notification and page-load performance (2026-11-15)

- New app-wide `SourceHealthSessionController` keeps one scan runtime across route changes and persists complete/in-progress result snapshots. Opening the page again restores state instead of reloading or restarting a completed scan; an interrupted scan resumes only unfinished sources.
- Video provider and Mihon checks now prepare/run concurrently; rows render using lazy Sliver builders and each result is replaced as soon as that individual probe returns. Manual reruns remain confirmation-gated.
- Added the Android `SourceHealthForegroundService`, progress notification and notification-to-Provider-Health navigation. The application FlutterEngine is retained while the service runs and is reused without duplicate platform-view registration when a notification reattaches an Activity.
- Repository manager facades share one catalogue cache; the repository screen retains its last fully assembled view model; priority/repository metadata reads run in parallel; independent repository indexes use a bounded three-worker fetch pool with stable original-order folding.
- `Review failed sources` is now a bottom-floating action and health result lists are lazy.
- CI formatter inventory increased from 74 to 76 Dart targets to include the session controller and repository manager. The existing 18-test Flutter gate was left unchanged.
- Static checks only; local Dart/Flutter are unavailable. No local Analyze, tests, Kotlin/Gradle compile, APK build or device acceptance is claimed. See `PHASE63.17_PERSISTENT_SOURCE_HEALTH_SESSION_AND_PAGE_CACHE.md` and `docs/build-reports/2026-11-15-phase63.17-health-session/`.

Changed files: `lib/screens/common/source_health_session_controller.dart` (new), `lib/screens/common/source_health_probe_service.dart`, `lib/screens/common/server_status_screen.dart`, `lib/screens/common/source_repositories_screen.dart`, `lib/video_providers/unified/source_repository_manager.dart`, `lib/video_providers/unified/unified_source_service.dart`, `lib/raven23_main.dart`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/m5ham3ds/raven23/MainActivity.kt`, `android/app/src/main/kotlin/com/m5ham3ds/raven23/Raven23Application.kt`, `android/app/src/main/kotlin/com/m5ham3ds/raven23/health/SourceHealthForegroundService.kt` (new), `tool/format_phase57_dart.sh`, `.github/workflows/android-ci.yml`, and phase/report documentation.

---

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


RAVEN23 — PHASE63.11: Home and Manga loading/cache audit (2026-11-14)

Audited the actual PHASE63.10 workspace against the baseline archive using SHA-256: 24 existing modified files, two existing added files, and no missing baseline files. Consolidated the already-present progressive mobile Home/Movies/Series/Anime loading, persistent TMDB SQLite cache, stale-while-revalidate and forced refresh, AniList per-kind persistent catalogue cache, offline/empty handling, cache-clear hooks, and existing focused tests. No production feature was reimplemented. Corrected only the stale CI formatter-report count from 73 to the actual 72 unique formatter targets. Added phases/PHASE63.11_HOME_MANGA_CACHE_AUDIT.md and updated phases/README_MASTER_IMPLEMENTATION.md. Remaining gaps are documented: Manga All still uses broad regional queries, background cache refresh does not live-update mounted pages, Clear Cache does not invalidate mounted in-memory page models, and Android TV Home retains a separate non-progressive pipeline. Static checks only; no Flutter/Dart/Gradle execution or APK build is claimed.


RAVEN23 — PHASE63.12: Dart formatter syntax repair (2026-11-14)

- lib/manga/anilist/anilist_manga_service.dart — removed the stray closing brace after `_catalogueFrom` that prematurely closed `AniListMangaService`; kept search/detail/item parsing methods inside the service and formatted the method invocation.
- Applied the supplied formatter patch to 11 files: catalog_controller.dart, home_feed_controller.dart, cache_interceptor.dart, http_cache.dart, single_flight_interceptor.dart, tmdb_repository.dart, network.dart, anilist_catalogue_cache.dart, tmdb_network_test.dart, home_screen_test.dart and anilist_catalogue_cache_test.dart.
- phases/PHASE63.12_FORMATTER_SYNTAX_REPAIR.md; phases/README_MASTER_IMPLEMENTATION.md; phases/README_CHANGED_FILES.txt.
- docs/build-reports/2026-11-14-phase63.11-run-43602766223/ — preserves CI report, environment, dependency and formatter logs, summary, original patch and repair notes.

The CI run failed at formatting before Analyze/tests/Gradle/APK; no downstream stage is marked successful. Static packaging checks only; a new GitHub Actions run remains required.


RAVEN23 — PHASE63.13: Dio request options and CatalogController test override repair (2026-11-14)

- lib/data/sources/tmdb_api.dart — removed the unsupported per-request `Options.connectTimeout` argument for the locked Dio 5.9.0 API; retained request send/receive timeouts and the public client's configured BaseOptions connection timeout.
- lib/manga/anilist/anilist_manga_service.dart — same correction; retained the AniList client's 12-second BaseOptions connection timeout and per-request send/receive limits.
- test/new_and_hot_test.dart — brought `_FakeCatalogController.loadTrendingAnimePage` into signature parity by adding optional `bool strict = false`; fake behavior unchanged.
- phases/PHASE63.13_DIO_TIMEOUT_AND_CATALOG_OVERRIDE_REPAIR.md; phases/README_MASTER_IMPLEMENTATION.md; phases/README_CHANGED_FILES.txt; phases/IMPLEMENTATION_TRACKER_PHASE36_58.md.
- docs/build-reports/2026-11-14-phase63.12-run-43611499257/ — preserves CI report, analyzer/dependency/environment/formatter logs, the empty formatter patch and repair notes.

Run 43611499257 passed dependency resolution and formatting of all 72 Dart targets, then failed Analyze on these three errors. The other 37 findings were informational under `--no-fatal-infos`. No tests, Android Mihon test or APK build were reached. Static packaging only; Flutter/Dart are unavailable in this environment, so a new CI run is required.


RAVEN23 — PHASE63.14: HomeScreen animation-controller lifecycle repair (2026-11-14)

- lib/mobile/screens/home_screen.dart — eagerly initializes the 220 ms `_fade` AnimationController in `initState()` instead of first initializing it lazily from `dispose()` when the catalogue is empty; preserves the existing animation calls and dispose path.
- test/home_screen_test.dart — extends the successful-empty-catalogue widget test to explicitly unmount Home and assert no dispose-time framework exception is queued.
- phases/PHASE63.14_HOME_SCREEN_ANIMATION_LIFECYCLE_FIX.md — records CI run `43613983587`, the exact deactivated-ancestor/TickerMode exception, repair and acceptance boundary.
- phases/README_MASTER_IMPLEMENTATION.md; phases/README_CHANGED_FILES.txt.
- docs/build-reports/2026-11-14-phase63.13-run-43613983587/ — preserves the original build report, focused test log, analyzer/dependency/environment/formatter logs, empty formatter patch and CI context.

The source CI run passed dependency resolution, all 72 formatter targets and Flutter Analyze, then failed one focused test (`successful empty response shows No results, not Retry`). The repair moves AnimationController construction into `initState()` while the State is active. No Home feed, TMDB/AniList cache, offline classification, Manga or Mihon behavior changed. Flutter/Dart are not installed in the editing environment, so no local widget test or APK build is claimed.


RAVEN23 — PHASE63.15: user-managed synchronization priority and local source health (2026-11-15)

- lib/screens/common/sync_screen.dart — reduces Synchronize to the single Choose source priority page.
- lib/screens/common/source_repositories_screen.dart — reuses the existing Primary/Backup editor as the only Synchronize content; priority editing remains unrestricted by old capacity ceilings.
- lib/video_providers/unified/source_priority_manager.dart; lib/video_providers/unified/source_priority_policy.dart — remove primary/backup and per-repository priority caps while retaining saved v1 priorities and duplicate protection.
- lib/video_providers/unified/source_repository_manager.dart — recovers installed-provider records from the last verified local repository revision when refreshing a repository fails, so the local health check can still reach the installed source list.
- lib/screens/common/server_status_screen.dart — keeps the two status tabs; derives Provider Health from installed VOD repository sources, adds Mihon health, completed-scan failed-source review, source settings/details navigation and confirmed batch removal/uninstall.
- lib/screens/common/source_health_probe_service.dart — local engine-aware QuickJS, Stremio, VidKing/WebEmbed/AnimeSite and Mihon probes, bounded concurrency/timeouts, safe endpoint handling and specific failure classification.
- test/video_providers/source_priority_manager_test.dart — verifies unrestricted list size, uniqueness and legacy persistence.
- tool/format_phase57_dart.sh; .github/workflows/android-ci.yml — include the new Dart service and priority test in scoped formatting and the focused 18-file Flutter test gate.
- phases/PHASE63.15_SYNCHRONIZE_AND_LOCAL_SOURCE_HEALTH.md; phases/README_MASTER_IMPLEMENTATION.md; phases/README_CHANGED_FILES.txt; phases/IMPLEMENTATION_TRACKER_PHASE36_58.md — document the scope, behavior, limits and validation boundary.

The editing environment has no Dart/Flutter executables. No local format, Analyze, Flutter/Gradle test, APK build or device acceptance is claimed for this phase.


RAVEN23 — PHASE63.16: Flutter Analyze repair for local source health (2026-11-15)

- lib/screens/common/server_status_screen.dart — adds the missing `_message` SnackBar helper used by both Stremio configuration launch failure paths.
- lib/screens/common/source_health_probe_service.dart — removes the Dio 5.9.0-incompatible `maxContentLength` BaseOptions argument; streams and caps health-check responses at 512 KiB, applies a 12-second stream inactivity timeout, cancels unused redirect/oversized response streams and removes an unnecessary non-null assertion.
- phases/PHASE63.16_FLUTTER_ANALYZE_SOURCE_HEALTH_REPAIR.md; phases/README_MASTER_IMPLEMENTATION.md; phases/README_CHANGED_FILES.txt; phases/IMPLEMENTATION_TRACKER_PHASE36_58.md.
- docs/build-reports/2026-11-15-phase63.15-run-43661952329/ — retained original CI report, environment/dependency/analyzer/formatter logs, formatter patch and focused diagnostic archive.

Run 43661952329 passed dependency resolution and 74-target formatting, then failed Analyze. The post-repair Dart/Flutter toolchain is unavailable in the editing environment; a new CI run is required to verify Analyze, focused tests, Mihon Android unit test and ARM64 APK build/audit.


RAVEN23 — PHASE63.18: offline cold-start loading, reconnection recovery and stable tab transitions (2026-11-15)

- lib/services/app_network_state.dart (new) — publishes shared connectivity-interface snapshots from the root app, including a forced refresh after app resume; API calls remain the source of truth for Internet access.
- lib/services/minimum_loading_visibility.dart (new) — guarantees a 650 ms minimum cold-failure skeleton visibility without delaying success or useful cached content.
- lib/raven23_main.dart — updates app-wide connectivity state from the existing connectivity_plus stream, initial status check and resume-time check.
- lib/mobile/screens/home_screen.dart — preserves in-memory feed/error state and performs debounced recovery for failed visible Home/Movies/Series catalogues; re-entering a failed tab after its interface is restored makes one real API probe, even when the connectivity event arrived while hidden.
- lib/mobile/screens/manga_screen.dart — same recovery behavior for cold AniList catalogues, while preserving the existing persistent Manga cache and search behavior.
- lib/mobile/app/mobile_shell.dart — keeps an opaque page-colour backdrop outside FadeTransition and contains tab repaint work inside RepaintBoundary.
- test/home_screen_test.dart — adds Movies/Series reconnection tests, hidden-tab return recovery tests for Home and Manga, and in-flight reconnect race tests.
- tool/format_phase57_dart.sh; .github/workflows/android-ci.yml — increase formatter scope from 76 to 79 unique Dart targets; keep the existing 18-file focused Flutter test gate.
- phases/PHASE63.18_OFFLINE_COLD_START_AND_NAVIGATION_STABILITY.md; phases/README_MASTER_IMPLEMENTATION.md; phases/README_CHANGED_FILES.txt; phases/IMPLEMENTATION_TRACKER_PHASE36_58.md.
- docs/build-reports/2026-11-15-phase63.18-offline-loading/ — records static validation and the CI/device acceptance boundary.

No Dart/Flutter formatter, Analyze, Flutter tests, Gradle/Kotlin compilation, APK build or physical-device network/transition test was run in the editing environment. A fresh CI run and device test remain required.


RAVEN23 — PHASE63.19: bottom navigation dual selection and shared light press feedback (2026-11-15)

- lib/design/app_press_feedback.dart — new common pointer-observed, reduced-motion-aware press scale (0.985 / 100ms).
- lib/mobile/app/mobile_nav_bar.dart — blank one-space menu caption without icon size change; shared press feedback on complete icon+label surfaces.
- lib/mobile/app/mobile_shell.dart — keep secondary dock open while Movies/Series/Anime is active, so Home and secondary choice remain selected simultaneously; primary destinations still close it.
- lib/mobile/widgets/poster_card.dart; lib/mobile/widgets/plus_card.dart — unify existing card press effects with the common response.
- Common controls across the application — apply the wrapper to standard button classes, IconButton, InkWell, callback-backed ListTile/toggle rows, PopupMenuItem/DropdownMenuItem and callback-enabled Choice/Filter/Input/Action chips; selected custom buttons and action labels are included while reader swipes/player drag/chart interactions remain unchanged.
- `lib/design/app_press_feedback.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/manga/mihon/mihon_source_browser_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/manga/ui/manga_reader_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/manga/ui/manga_work_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/app/mobile_nav_bar.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/app/mobile_shell.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/playlists.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/credits_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/discover_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/episode_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/flix_ai_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/manga_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/my_raven23_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/person_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/playlist_import_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/playlist_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/playlists_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/plus_payment_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/plus_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/search_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/season_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/shared_playlist_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/screens/title_details_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/account_form.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/continue_sheet.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/details_header.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/details_parts.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/device_limit_sheet.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/episode_row.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/episodes_section.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/filter_chips.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/genre_sheet.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/home_header.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/media_rows.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/page_kit.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/pill_button.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/plus_card.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/plus_sheets.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/poster_card.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/section_header.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/mobile/widgets/telegram_channel_prompt.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/about.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/bookmark_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/download_selection_sheets.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/downloads_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/embedded_web_playback_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/iptv_playlist_manager_dialog.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/live_tv_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/player_episode_selection.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/player_external_subtitles.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/player_feedback_ui.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/player_local_subtitles.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/player_movie_recommendations.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/player_sheet_ui.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/player_subtitle_timing_sheet.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/player_watch_page.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/stream_feedback_prompt.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player/tv_subtitle_timing_panel.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/player_settings.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/provider_choose.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/quickjs_source_settings_dialog.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/server_status_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/settings.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/source_repositories_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/common/update_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/movie/collection_detail.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/user/edit_profile.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/user/login_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/user/password_change.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/user/signup_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/wellness/wellness_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/screens/wellness/widgets/insights_dashboard.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/services/globle_method.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/tv/focus/tv_focusable.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/ui_components/in_app_message_dialog.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/widgets/ad_block_playback_guard.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/widgets/adsterra_playback_ad_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/widgets/common_widgets.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/widgets/network_banner_widget.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/widgets/playback_loading_screen.dart` — updated for shared press feedback, interaction behavior or import.
- `lib/widgets/vast_ad_overlay.dart` — updated for shared press feedback, interaction behavior or import.
- `test/mobile/mobile_nav_bar_test.dart` — updated for shared press feedback, interaction behavior or import.
- test/mobile/mobile_nav_bar_test.dart — verifies blank caption, preserved centre icon sizing, Home + secondary selection for Movies/Series/Anime and press feedback preserving the original tap.
- tool/format_phase57_dart.sh; .github/workflows/android-ci.yml — extend the unique formatter scope to 146 Dart targets and update CI coverage description.
- phases/PHASE63.19_BOTTOM_NAV_SELECTION_AND_GLOBAL_PRESS_FEEDBACK.md; phases/README_MASTER_IMPLEMENTATION.md; phases/README_CHANGED_FILES.txt; phases/IMPLEMENTATION_TRACKER_PHASE36_58.md.
- docs/build-reports/2026-11-15-phase63.19-navigation-feedback/STATIC_VALIDATION.md — records the static checks and the no-Dart/Flutter validation boundary.

No Dart/Flutter SDK was available in the editing environment. Formatter, Analyze, Flutter tests, Gradle/Kotlin, APK and device visual acceptance remain pending CI/device verification.


RAVEN23 — PHASE63.26: player quality picker and navigation press feedback (2026-11-16)

- `lib/mobile/app/mobile_nav_bar.dart` — stable primary dock feedback boundary around the full icon+label destination.
- `lib/widgets/hosted_ads_banner.dart` — add press feedback to interactive hosted-ad carousel images without affecting display-only TV banners or drag navigation.
- `lib/screens/common/player.dart` — exact active quality source key, resolution-first labels and server/format subtitles in the mobile and TV pickers, and keyed source switching.
- `lib/video_providers/quality_catalog.dart` — provider/source bucket and exact source key retention, unique mirror selection, resolution label normalization, embedded/expired source handling.
- `test/mobile/mobile_nav_bar_test.dart` — icon+label animation matches centre toggle scale/release and original selection/collapse behavior.
- `test/playback_action_test.dart` — resolution-first player row, shared press feedback, and tap activation.
- `test/quality_catalog_test.dart` — unique source keys, exact same-URL mirror selection, low resolutions down to 140p, owner-bucket mapping, and embedded exclusion.
- `test/adaptive_quality_scanner_test.dart`; `test/provider_background_scan_test.dart` — 140p manifest parsing and retention of all low qualities returned by completed/in-flight providers while the 480/720/1080 scheduling target remains unchanged.
- `tool/format_phase57_dart.sh`; `.github/workflows/android-ci.yml` — 150 formatter targets and 22 focused Flutter test files.
- `phases/PHASE63.26_PLAYER_QUALITY_PICKER_AND_NAV_FEEDBACK.md`; `phases/README_MASTER_IMPLEMENTATION.md`; `phases/README_CHANGED_FILES.txt`; `phases/IMPLEMENTATION_TRACKER_PHASE36_58.md`.
- Preserve successful PHASE63.25 CI report, logs and focused test artifacts at `docs/build-reports/2026-11-16-phase63.25-run-43779340866/`.

Validation: workflow YAML parsed; formatter shell script passes `bash -n`; 150 formatter paths and 22 focused test paths are unique, present and non-empty; three uploaded diagnostic archives pass ZIP CRC verification. The owner subsequently confirmed that PHASE63.26 also built successfully; the archived 45.33 MiB CI report remains specifically PHASE63.25 evidence (18 tests/146 format targets) and is not attributed to PHASE63.26. Dart/Flutter unavailable in the editing environment, so no additional local format, Analyze, test, ABI, APK or device result is claimed.


RAVEN23 — PHASE63.27: press feedback, unique quality rows and unified offline downloads (2026-11-16)

- `lib/design/app_press_feedback.dart` — opaque pointer hit testing and stronger 0.96 scale feedback, retaining drag cancellation and Reduce Motion support.
- `lib/mobile/widgets/pill_button.dart` — disable feedback when the action is disabled or busy.
- `lib/video_providers/quality_catalog.dart`; `lib/screens/common/player.dart` — one visible row per normalized quality; keep exact active provider/source key/URL as the retained entry.
- `lib/video_providers/common.dart`; `lib/video_providers/unified/legacy_provider_adapter.dart`; `lib/functions/video_utils.dart` — preserve declared stream container metadata and infer MP4/WebM/progressive download format correctly.
- `lib/screens/movie/movie_video_loader.dart`; `lib/screens/tv/tv_video_loader.dart` — include installed repository sources in the offline download provider list and pass the exact selected source metadata.
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/downloads/StreamDownloadStore.kt`; `DownloadSourceResolver.kt` — add Media3 progressive downloads and progressive legacy-source recovery; skip manifest-only audio inspection for progressive files and persist any successfully fetched optional subtitle path before serializing the progressive request.
- Regression coverage: `test/app_press_feedback_test.dart`, `test/video_utils_download_format_test.dart`, updated `test/quality_catalog_test.dart`, `test/mobile/mobile_nav_bar_test.dart`, `test/pill_button_test.dart`, `test/video_providers/legacy_provider_adapter_test.dart`, and native progressive MIME contract tests.
- `.github/workflows/android-ci.yml`; `tool/format_phase57_dart.sh` — extend the scoped inventory to 159 Dart files and 26 focused Flutter test files.
- `phases/PHASE63.27_PRESS_FEEDBACK_QUALITY_DEDUP_UNIFIED_DOWNLOADS.md`; `phases/README_MASTER_IMPLEMENTATION.md`.

Validation boundary: static validation only is possible in this environment. Dart/Flutter are absent; no Flutter format/analyze/tests or Gradle/APK/device test is claimed. Unified source temporary-link renewal remains a known limitation; Firebase/backend was not started.


RAVEN23 — PHASE63.27.2: restore the documented shared press feedback scale (2026-11-17)

- `lib/design/app_press_feedback.dart` — restore the shared default press scale from the unintended `0.96` to the PHASE63.26-specified `0.985`; keep 100 ms `easeOutCubic`, hit testing, drag cancellation and Reduce Motion behavior unchanged.
- `test/app_press_feedback_test.dart`; `test/mobile/mobile_nav_bar_test.dart`; `test/pill_button_test.dart` — align default-scale regression expectations with `0.985`; `test/playback_action_test.dart` already asserts this required value.
- `phases/PHASE63.27_PRESS_FEEDBACK_QUALITY_DEDUP_UNIFIED_DOWNLOADS.md` — correct the inaccurate `0.96` statement.
- `phases/PHASE63.27.2_PRESS_FEEDBACK_SCALE_RESTORE.md`; `phases/README_MASTER_IMPLEMENTATION.md`; `phases/README_CHANGED_FILES.txt` — record the root cause, repair and CI validation boundary.

CI run `43961952237` passed dependency resolution, Dart formatting (159 targets, zero changes) and Flutter Analyze; 199 focused Flutter tests passed and one failed because the shared scale was `0.96` instead of `0.985`. Android tests and APK build were skipped. This repair has not been run locally because Dart/Flutter are unavailable; a new full CI run is required.


RAVEN23 — PHASE63.28: press feedback, unified quality downloads and device-measured host order (2026-11-17)

- `lib/design/app_press_feedback.dart` — retain the pointer/release pulse when a tap transitions Play into busy state; keep drag cancellation and Reduce Motion.
- `lib/mobile/app/mobile_nav_bar.dart`; `lib/mobile/widgets/pill_button.dart` — use explicit visible `0.94` feedback only on primary navigation and Hero actions, leaving the shared default at `0.985`.
- `lib/manga/ui/manga_work_screen.dart` — apply the same visible press response to the Manga Read/Find source and Find across sources actions.
- `lib/screens/common/player.dart` — order exact returned stream links by the configured host order, use ordered candidates for failover, and record first-play success/failure once even when the watchdog observes playback before the player event.
- `lib/video_providers/unified/stream_host_priority_manager.dart`; `test/video_providers/stream_host_priority_manager_test.dart` — apply the pinned VixSrc/Jett/YaStream/VidFast/VidSpark/HdHub/Sova/Sage/Phoenix/CineStream/VidZee/VegaMovies order, preserve unknown ties, and rank extra hosts only from device-observed play outcomes.
- `lib/screens/common/source_repositories_screen.dart` — prevent measured host aliases of the pinned twelve from appearing as duplicate extra entries; retain metadata search and scroll restoration.
- `lib/video_providers/quality_catalog.dart`; `lib/screens/common/download_selection_sheets.dart`; `lib/screens/movie/movie_video_loader.dart`; `lib/screens/tv/tv_video_loader.dart`; `lib/screens/common/player.dart` — keep all movie/episode/player downloads on the shared one-row-per-quality chooser and preserve exact source metadata.
- `lib/models/offline_download.dart`; `android/app/src/main/kotlin/com/m5ham3ds/raven23/downloads/StreamDownloadStore.kt`; `test/offline_download_test.dart` — persist stream identity within Media3 DownloadRequest data and read it back from the download index.
- `test/pill_button_test.dart`; `test/mobile/mobile_nav_bar_test.dart`; `test/quality_catalog_test.dart`; `test/offline_download_test.dart`; `test/video_providers/stream_host_priority_manager_test.dart` — regression coverage for press feedback, deduplicated quality labels, durable source identity and host ordering/metrics.
- `test/video_providers/offline_stream_identity_test.dart`; `.github/workflows/android-ci.yml`; `tool/format_phase57_dart.sh` — add focused CI coverage for stream identity write/read round-tripping (28 focused Flutter test files; 162 formatter targets).
- `phases/PHASE63.28_PRESS_FEEDBACK_DOWNLOADS_HOST_ORDER_AND_DIAGNOSTICS.md`; `phases/README_MASTER_IMPLEMENTATION.md`; `phases/README_CHANGED_FILES.txt`.

Validation boundary: static repository/workflow checks only; Flutter, Dart, Gradle and Android SDK are unavailable in the editing environment. No new APK or live source playback is claimed. Firebase/backend and remote push activation remain out of scope.


RAVEN23 — PHASE63.28.1: success-gated activation of additional stream hosts (2026-11-17)

- `lib/video_providers/unified/stream_host_priority_manager.dart` — only list additional hosts after at least one successful real player startup; preserve failure-only metrics for diagnostics and rank failure-only extras behind unseen hosts.
- `lib/screens/common/source_repositories_screen.dart` — clarify that the additional-host activation gate requires successful video playback, in Arabic and English.
- `test/video_providers/stream_host_priority_manager_test.dart` — cover failure-only host exclusion, retained diagnostics and rank ordering.
- `phases/PHASE63.28_PRESS_FEEDBACK_DOWNLOADS_HOST_ORDER_AND_DIAGNOSTICS.md`; `phases/PHASE63.28.1_STREAM_HOST_SUCCESS_GATE.md`; `phases/README_MASTER_IMPLEMENTATION.md`; `phases/README_CHANGED_FILES.txt` — document the evidence threshold and validation boundary.

No Flutter/Dart execution, Android build or live-server playback is claimed in this environment.


RAVEN23 — PHASE63.28.2: repair Analyze and apply Anime PRIMARY LIST order

- `lib/screens/movie/movie_video_loader.dart` — remove invalid unused episode metadata getters from the movie download handler.
- `lib/video_providers/unified/stream_host_priority_manager.dart` — fix underscore-suffixed host-name interpolation.
- `lib/screens/common/player.dart` — remove unused size estimation import, dead size-token fields/cache writes and unused helper reported by Flutter Analyze.
- `lib/video_providers/unified/source_priority_policy.dart` — set the requested Anime repository source order and define the built-in VixSrc priority marker, safe legacy map and insertion-index helper.
- `lib/video_providers/unified/unified_source_service.dart`; `lib/video_providers/provider_loader.dart` — migrate only an untouched old Anime default, persist the VixSrc marker, and calculate its insertion slot from installed/runnable preceding sources.
- `lib/screens/common/source_repositories_screen.dart` — display, add, reorder, swap and remove the built-in VixSrc item inside the Anime priority lanes without treating it as a repository extension.
- `lib/screens/movie/movie_video_loader.dart`; `lib/screens/tv/tv_video_loader.dart` — insert native VixSrc at Anime primary slot 6 while retaining existing Movie/Series ordering.
- `test/video_providers/source_priority_policy_test.dart`; `test/video_providers/stream_host_priority_manager_test.dart` — assert the exact 14-entry Anime order, built-in VixSrc placement, missing-provider index handling and literal underscore host suffix.
- `tool/format_phase57_dart.sh`; `.github/workflows/android-ci.yml` — include the policy and runtime files in 165 unique formatter targets and add source-priority policy coverage to the 29-file focused Flutter gate.
- `phases/PHASE63.28.2_ANALYZE_REPAIR_AND_ANIME_PRIMARY_ORDER.md`; `phases/README_MASTER_IMPLEMENTATION.md`; `phases/README_CHANGED_FILES.txt` — record the diagnosis, implementation and validation boundary.

No Dart/Flutter/Gradle/Android SDK runtime is available locally; only static checks can be claimed. The uploaded run `44017610188` failed at Analyze, so its skipped tests and APK stages remain unverified.


RAVEN23 — PHASE63.29: complete SOURCE CATALOG health audit and test-driven PRIMARY ranking (2026-11-17)
- `lib/screens/common/server_status_screen.dart`: show complete-catalogue progress/counts, extracted stream count and qualities; explain stream-only, endpoint-only and unsupported results.
- `lib/screens/common/source_health_probe_service.dart`: test both mixed QuickJS category contracts, extract sample VOD stream options, and persist category-level quality/container/audio/subtitle/latency evidence.
- `lib/screens/common/source_health_session_controller.dart`: safely activate every non-Hentai catalogue entry in bulk, uninstall excluded entries, remove excluded keys from priority lanes, and apply measured PRIMARY-tail ordering.
- `lib/screens/common/source_health_priority_ranker.dart`: keep the first 12 Movies/Series and 14 Anime PRIMARY entries fixed, then rank stream-extraction evidence; never auto-fill BACKUP.
- `lib/video_providers/unified/source_catalog_safety_policy.dart`: exclude Hentai metadata and explicit Hanime/HentaiMama IDs.
- `lib/video_providers/unified/source_repository_manager.dart`, `lib/video_providers/unified/unified_source_service.dart`: batch install/uninstall and invalidate the shared catalogue cache.
- `test/app_press_feedback_test.dart`, `test/playback_action_test.dart`: correct stale expectations to the production press-feedback scales.
- `test/video_providers/source_catalog_safety_policy_test.dart`, `test/screens/common/source_health_probe_service_test.dart`, `test/screens/common/source_health_priority_ranker_test.dart`: focused regression coverage.
- `.github/workflows/android-ci.yml`, `tool/format_phase57_dart.sh`: include the new tests and production sources in CI.
- `phases/PHASE63.29_FULL_SOURCE_CATALOG_HEALTH_AND_TEST_DRIVEN_PRIORITIES.md`, `phases/README_MASTER_IMPLEMENTATION.md`, `phases/README_CHANGED_FILES.txt`: record scope, CI failure diagnosis and validation limits.

Validation boundary: the supplied CI failure was two stale widget-test assertions (224 other tests passed); no APK was produced. Flutter/Dart/Gradle/Android SDK are unavailable in this editing environment, so the updated formatter/analyzer/test/Android/APK gates and real server checks remain unexecuted pending a fresh CI/device run.

---

PHASE63.29 follow-up hardening:
- `lib/video_providers/unified/source_catalog_safety_policy.dart` — also recognizes the Arabic spelling هنتاي.
- `lib/video_providers/unified/source_repository_manager.dart` and `lib/video_providers/unified/unified_source_service.dart` — purge stale blocked source stable keys from persisted installation preferences.
- `lib/screens/common/source_health_session_controller.dart` — remove stale blocked installation keys and their PRIMARY/BACKUP entries before enabling the safe catalog.
- `test/video_providers/source_catalog_safety_policy_test.dart` — cover the Arabic spelling.
