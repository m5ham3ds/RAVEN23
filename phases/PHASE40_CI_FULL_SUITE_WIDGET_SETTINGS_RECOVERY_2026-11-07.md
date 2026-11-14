# Phase 40 — Full-suite widget, settings, and compatibility recovery

**Date:** 2026-11-07  
**Observed CI run:** `42331596314`  
**Observed commit:** `5ff06e54d4bb514d5c2d12336eaf144260623a1e`  
**Workflow:** `RAVEN23 Local Android APK Build`  
**Build mode:** Release  
**Observed outcome:** failed at `Complete Flutter test suite`; no APK was produced.

## 1. Evidence from the supplied report

The attached CI report and expanded Flutter test log are the source of truth for the baseline described here.

| Gate | Observed result |
|---|---|
| `flutter pub get` | Passed |
| Dart format fix + strict check | Passed |
| `flutter analyze` | Passed |
| Focused architecture/Stremio/provider-scan tests | Passed (147 tests in the report) |
| Full Flutter test suite | Failed: 2,155 passed, 23 failed, 11 skipped |
| Gradle Wrapper generation | Not reached |
| Android Release ARM64 APK build | Not reached |
| APK audit | Not reached |

The latest supplied formatter archive contained a patch for `test/tv_sport_picker_test.dart`. The patch is already applied in the working tree (the patch tool reports a reversed/already-applied patch on dry-run); the file is also in the formatter target list.

## 2. Full-suite failures and targeted recovery changes

The 23 failed test cases were traced to the following areas. Changes below are present in the current working tree, but have **not yet been rerun in GitHub Actions**.

| Test area | Failure observed in CI | Follow-up change prepared |
|---|---|---|
| `search_screen_test.dart` (3) | Three tests ended with a pending `VisibilityDetector` timer; the main test stack included `pumpAndSettle`. | Added a shared test helper that configures `VisibilityDetectorController.updateInterval = Duration.zero`, restores the previous setting during teardown, and flushes pending callbacks. This addresses detector batching in tests without changing production timing. |
| `mobile/widgets/reveal_item_test.dart` (1) | Reveal opacity remained `0.0` at the expected midpoint because the visibility callback was still batched. | Uses the same zero-interval test helper; production `RevealItem` still retains its real visibility gate and staggered animation. Its stagger timer is cancelled on dispose. |
| `data/onesignal_messaging_client_test.dart` (1) | Platform tag assertion did not match the native call emitted by the pinned SDK. | Assertion now checks `OneSignal#addTags` and the `flixquest_platform: tv` map entry, matching the existing `OneSignal.User.addTagWithKey` call and pinned `onesignal_flutter` 5.5.2 implementation. No production SDK initialization or dashboard tag was changed. |
| `discover_screen_test.dart` (1) | `anime_status` was not found because the target is in a lazily built/scrollable area. | Test scrolls the relevant content into view before asserting/tapping. |
| `tv_remote_navigation_test.dart` (1) | Expected semantics described obsolete subtitle defaults (`17px, Regular`); application defaults are `12px, Bold`. | Test expectation updated to the current `defaultSubtitleFontSize` and `defaultSubtitleTextStyle`; interaction assertion updated to the selected size while preserving Bold. |
| `playback_stream_cache_test.dart` (1) | Deserialization wrote `language` but restored only legacy `lang`/`label`, yielding null. | `RegularSubtitleLinks.fromJson` now reads `language`, then legacy aliases, preserving backwards compatibility. |
| `app_colors_test.dart` (1) | The curated orange swatch was transformed by `ColorScheme.fromSeed` and did not retain its exact configured value. | Exact-primary behavior is enabled for curated palette entries so the configured swatch is preserved. |
| `poster_grid_test.dart` (1) | A `VisibilityDetector` batching timer remained pending after widget disposal. | Uses the shared visibility test helper; no product UI behavior is disabled. |
| `occasional_theme_test.dart` (1) | Selecting a theme whose date window had ended remained selected instead of falling back to the currently active automatic theme. | `OccasionalThemeCatalog.resolve` now validates a date-bounded selected theme at the supplied instant before returning it. Manual presets with no date bounds remain selectable. |
| `tv_settings_screen_test.dart` (1) | Expected English as the initial selected subtitle language; current provider default is Arabic. | Test now asserts the actual configured default (`ar`). |
| `new_and_hot_screen_test.dart` (1) | Ad position test ended with pending visibility batching timer. | Uses shared visibility test helper. |
| `title_details_screen_test.dart` (3) | Two tests left visibility callbacks pending; one assertion required exactly one `Opacity` although an unaired episode has product dimming plus reveal opacity. | Uses shared visibility test helper; the dimming assertion now checks for an ancestor with opacity `0.5`, independent of the reveal wrapper. |
| `external_subtitle_service_test.dart` (2) | Arabic SRT fixture was passed through a Latin-1 `http.Response` encoder; header lookup was case-sensitive. | Arabic fixture uses `http.Response.bytes(utf8.encode(...), 200)`; test header lookup is case-insensitive. Service continues sending both `User-Agent` and `X-User-Agent` for compatibility. |
| `quickjs_stream_mapper_test.dart` (1) | URL ending in `.mp4` but with no declared container resolved as `unknown`. | Empty container declarations now count as absent, allowing URL extension inference; explicit unsupported non-empty container labels remain `unknown`. Added fixture coverage for both cases. |
| `legacy_provider_adapter_test.dart` (1) | Provider display name was appended to quality (`540p · Provider`). | Quality label contains quality/audio only; provider identity remains in the server field. |
| `presentation/config_source_controller_test.dart` (1) | A user-selected seasonal theme outside its configured date window remained active after source change. | Covered by the selected-theme active-window validation in `OccasionalThemeCatalog.resolve`; persisted selection remains stored and can become active again when its window opens. |
| `home_screen_test.dart` (2) | Expected row order omitted Anime/Series rows added to the feed; screen test searched for rows not yet built by the lazy Sliver. | Expected order now includes `trending_anime`, `new_episodes_anime`, `popular_anime`, and `top_rated_anime`; widget test scrolls the relevant rows into view before assertions and returns to the top between filters. |

The test suite contains no skips added by this recovery. The only skip count in the table above is the 11 skips reported by the original CI run.

## 3. Warning analysis

### EasyLocalization warnings

The report counted 6,157 warning occurrences and 255 unique warning messages. Parsing the expanded test log found 253 distinct localization keys. Every one of those 253 keys exists in each packaged locale JSON (`en.json`, `ar.json`, `es.json`, `hi.json`); each locale currently contains 1,982 keys.

The warnings are therefore consistent with widget tests mounting translated screens without the production `EasyLocalization` asset/provider setup, rather than missing keys in the shipped locale files. No translation strings were fabricated or added to silence the test harness. A separate test-harness localization bootstrap improvement may be considered if it can be done without changing production fallback behavior.

### Other diagnostics

- Android SDK Manager printed a CLI deprecation warning recommending the newer Android CLI. It was non-fatal and did not cause the full-suite failure.
- The test output included an `HttpClient` warning: Flutter widget-test binding does not perform real network requests; tests needing HTTP should inject a deterministic client. The two external-subtitle regressions were changed to use explicit byte fixtures and controlled headers.
- `unhandled element <defs/>; Picture key: Svg loader` appeared as an SVG test-renderer diagnostic. The supplied report did not show it as a failing assertion.
- Test log messages such as mocked `offline`, failed ad fetch, and cache reset exceptions were expected test scenarios and were not independently counted as failures.

## 4. Formatter patch and CI coverage

The supplied `RAVEN23-dart-format-patch(2).zip` contains a formatter patch for `test/tv_sport_picker_test.dart`. That patch is already applied in the current working tree. The formatter target list was reviewed and the duplicate entry for `test/external_subtitle_service_test.dart` was removed. All configured formatter target paths were checked for existence; Dart formatting itself is still performed by the pinned Flutter/Dart CI toolchain.

The existing Phase 40 regression step covers the 17 test files most directly associated with the 23 failures. The full test log and comprehensive Markdown build report continue to be uploaded even when a later workflow stage fails.

## 5. Local verification limits

The current execution environment does not provide `flutter` or `dart`; therefore this follow-up has not been verified by running `flutter test`, `flutter analyze`, or an Android build locally. Static checks performed for this handoff include:

- all 253 localization keys found in the supplied expanded log exist in all four locale JSON files;
- formatter target paths exist and the duplicate target was removed;
- the supplied formatter patch is already applied;
- CI YAML and embedded report-generator Python are syntax-checked before packaging;
- full-project ZIP integrity and file comparison are checked before handoff.

No claim is made that the 23 tests now pass. The next GitHub Actions run must first pass the focused 17-file regression suite, then the full suite, then Gradle Wrapper generation, Release ARM64 APK build, and APK audit.

## 6. Phase status

**Phase 40 remains `In Progress — CI rerun pending`.** The observed run failed before Gradle Wrapper generation and produced no APK. Phase 41 remains Not Started and must not begin until Phase 40 and the earlier validation gates are accepted.


## 7. File inventory compared with the previous full-suite recovery archive

- Previous project files: 1361
- Current project files: 1366
- Modified existing files: 35
- New files: 5
- Deleted files: 0

### Modified existing files

- `.github/workflows/android-ci.yml`
- `.gitignore`
- `lib/mobile/widgets/reveal_item.dart`
- `lib/models/app_colors.dart`
- `lib/models/occasional_theme.dart`
- `lib/services/external_subtitle_service.dart`
- `lib/video_providers/common.dart`
- `lib/video_providers/provider_loader.dart`
- `lib/video_providers/unified/legacy_provider_adapter.dart`
- `lib/video_providers/unified/quickjs/quickjs_stream_mapper.dart`
- `lib/video_providers/unified/source_repository_parser.dart`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_56.md`
- `phases/MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md`
- `phases/PHASE40_CI_STREMIO_TEST_RECOVERY.md`
- `phases/PHASE40_STREMIO_MANIFEST_CONFIGURATION_CHANGELOG.md`
- `phases/PHASE40_STREMIO_MANIFEST_CONFIGURATION_IMPLEMENTATION.md`
- `phases/PHASE40_STREMIO_MANIFEST_CONFIGURATION_REPORT.md`
- `phases/PHASE40_STREMIO_MANIFEST_CONFIGURATION_TESTS.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `test/data/onesignal_messaging_client_test.dart`
- `test/discover_screen_test.dart`
- `test/external_subtitle_service_test.dart`
- `test/home_screen_test.dart`
- `test/mobile/widgets/reveal_item_test.dart`
- `test/new_and_hot_screen_test.dart`
- `test/poster_grid_test.dart`
- `test/provider_background_scan_test.dart`
- `test/search_screen_test.dart`
- `test/title_details_screen_test.dart`
- `test/tv_remote_navigation_test.dart`
- `test/tv_settings_screen_test.dart`
- `test/tv_sport_picker_test.dart`
- `test/video_providers/quickjs_stream_mapper_test.dart`
- `test/video_providers/source_repository_parser_test.dart`
- `tool/format_phase37_40_dart.sh`

### New files

- `phases/PHASE40_CI_COMPREHENSIVE_BUILD_REPORTING.md`
- `phases/PHASE40_CI_FULL_SUITE_WIDGET_SETTINGS_RECOVERY_2026-11-07.md`
- `phases/PHASE40_CI_FULL_TEST_SUITE_FAILURE_ANALYSIS.md`
- `phases/PHASE40_CI_FULL_TEST_TV_WIDGET_TIMEOUT_RECOVERY.md`
- `test/support/visibility_detector_test_helper.dart`

### Deleted files

- None.
