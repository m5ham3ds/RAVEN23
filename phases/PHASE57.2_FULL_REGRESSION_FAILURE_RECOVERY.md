# PHASE57.2 — Full Regression Failure Recovery & Independent CI Diagnostics

**Date:** 2026-11-10  
**Input run:** GitHub Actions `42888346400` (commit `a8f31321ff87d966fae16b3bbd9061e0da1bc1a3`)  
**Input artifacts:** `RAVEN23-build-report-and-diagnostics(20261110-195523).zip`, `RAVEN23-complete-regression-test-logs.zip`, and `RAVEN23-dart-format-patch(20261110-195521).zip`.

## 1. Actual failure status

The workflow's dependency resolution, Dart formatting and `flutter analyze` all succeeded. The full Flutter test suite then ran rather than being skipped:

- **2,260 passed**
- **21 failed**
- **11 skipped**
- **259 Flutter test source files discovered**

The first failing gate was the Flutter suite. As a result, the prior workflow skipped the optional Laravel checks, Gradle wrapper generation, all 10 Android unit-test source files, APK packaging and APK audit. No APK was produced. The 11 skipped Flutter test invocations were conditional skips (for example, optional ad-block simulation and guarded staging/live test setup), not the 21 failing tests.

The run did not show 21 unrelated production defects. The failures clustered into eight root-cause groups:

| Group | Failed tests | Cause and correction in PHASE57.2 |
|---|---:|---|
| Search navigation | 1 | Test tapped Search before opening the secondary navigation dock. It now opens the real overflow/menu control, waits for the dock, and then selects Search. |
| Banner placement contract | 1 | The scanner inferred `home_anime_hero`, `home_anime_trending`, and `home_anime_genres` from the generic ad-base switch, although Anime returns through its dedicated row branch and those placements are not part of the backend contract. Anime now has no generic `adBase`; the helper throws if an unreachable generic slot is requested. |
| Discover Anime filter | 1 | The test used ambiguous text and an arbitrary Scrollable. The Anime segment and the Discover `CustomScrollView` now have stable keys; the test asserts the selected Semantics state and drags the actual Scrollable inside the keyed view. |
| Background provider scan | 2 | Test fixtures assumed two scraper providers from the same engine could run concurrently, contradicting the production per-engine limit. Fixtures now mix the legacy scraper and native engines while retaining the production concurrency policy. |
| Generated localization | 1 | `codegen_loader.g.dart` and `locale_keys.g.dart` lagged the four translation assets. All four generated maps and locale key constants are regenerated from the JSON source (2,131 top-level keys per locale). Existing generated key identifiers remain unchanged; 208 newly added asset keys are included. |
| Stremio identity / repository snapshot | 3 | First-use recommended-source configuration performed a second sync and replaced a caller-supplied repository snapshot. An explicit snapshot is now preserved for the whole search operation; default searches may still refresh after configuration. |
| Unified source execution test setup | 11 | Tests invoked `SharedPreferences` through the priority manager before Flutter test binding/mock initialization. The suite now initializes `TestWidgetsFlutterBinding` and mock SharedPreferences before each test. |
| Home lazy-shelf assertion | 1 | The test queried lower shelves before earlier rows and then attempted forward-only scrolling. Assertions now follow the Home feed's top-to-bottom shelf order. |

## 2. Production behavior and test integrity

- No production concurrency limit was increased to satisfy the background-scan tests.
- No source eligibility rule, provider priority, player route or stream selection rule was weakened.
- Explicit repository snapshots remain stable; normal searches without an explicit snapshot retain the current repository-sync path.
- No banner placement was added to the backend contract. Anime's dedicated feed continues to render without the generic Home ad slots it never uses.
- Search and Discover test selectors are based on the app's real interactive controls and stable widget keys, not arbitrary screen coordinates or duplicate text labels.
- All current test files remain in place. No failed test was deleted, skipped or converted to a passing expectation to make CI green.
- The uploaded Dart formatting patch contained one additional required blank line in `manga_screen.dart`; that canonical formatting change is included.

## 3. Translation source alignment

The four source catalogs (`en.json`, `hi.json`, `es.json`, `ar.json`) have identical key sets with **2,131 entries**. The previous generated loader contained **2,026 keys per locale**, missing 105 newer entries (including `audio`). The old `LocaleKeys` file contained 1,923 constants, missing 208 newer top-level keys. PHASE57.2 rebuilds all four generated locale maps from their matching JSON files, including nested plural maps, and rebuilds `LocaleKeys` while preserving every previously emitted identifier exactly. This keeps source JSON and compiled codegen catalogs equal rather than patching a single missing key.

## 4. CI execution order and independent diagnostics

Once `flutter pub get` succeeds, these diagnostic stages now execute independently instead of allowing one failed suite to hide the others:

1. Scoped Dart formatter (`tool/format_phase57_dart.sh`; **23 Dart targets**).
2. Full-project `flutter analyze --no-fatal-infos`.
3. Complete `flutter test` discovery under `test/` (259 files in this source snapshot; no file allow-list).
4. Optional Laravel foundation smoke test when `LARAVEL_SMOKE_URL` is supplied.
5. Optional write-enabled Laravel migration E2E only when both the staging URL and the explicit write switch are supplied.
6. Gradle Wrapper generation.
7. Full Android app unit-test task `:app:testProdReleaseUnitTest` without test-name filtering, covering the 10 current Kotlin/Java unit-test source files.

The analyzer and Flutter tests still run when formatting fails, as long as dependencies are available. Gradle wrapper generation and Android unit tests still run when Flutter tests fail, provided Java, the pinned Gradle installation, Flutter, Android SDK, dependency resolution and wrapper generation themselves succeed. Optional live tests remain isolated by their explicit environment requirements. The generated build report interprets a log line beginning `Skipped:` as **skipped**, not as a successful test result.

**APK protection remains strict:** the APK build step is gated on successful dependency resolution, formatting, analyzer, complete Flutter tests, every configured optional integration gate, Gradle wrapper generation and Android unit tests. Independent diagnostics can continue after a failure; APK packaging cannot.

The Android test step verifies JUnit XML reports exist, contain at least one executed test and report zero failures/errors. An empty report is not accepted as a successful test run.

## 5. Historical scope boundaries

- The active Flutter suite is every current `test/**/*_test.dart` file. The current archive contains 259 such files.
- The Android suite is every current app unit-test source under `android/app/src/test/` (10 Kotlin files in this archive).
- The dedicated PHASE52/PHASE53 test files were previously retired after owner-accepted milestones; PHASE57.2 does not silently restore removed historical files or treat their retirement as a current test failure.
- `integration/laravel_foundation_smoke_test.dart` remains outside the normal deterministic `test/` suite and runs only with a configured URL.
- `test/integration/laravel_migration_e2e_test.dart` remains part of normal Flutter discovery and retains its environment guard. Its destructive/write path requires a disposable staging endpoint plus an explicit allow-writes flag.

## 6. Validation and acceptance boundary

Static checks are performed on the workflow syntax and source inventory before archiving. Flutter, Dart, Gradle and the Android SDK are not installed in the archive-editing environment, so this phase does **not** claim that the patched Flutter tests, Kotlin tests, Release APK or device install were run locally.

- [x] Diagnose the complete prior Flutter suite and map all 21 failures to their source/test root causes.
- [x] Fix the production repository snapshot replacement bug.
- [x] Correct SharedPreferences test initialization.
- [x] Make provider scan fixtures comply with the existing per-engine concurrency limits.
- [x] Correct Search/Discover/Home test interaction and ordering.
- [x] Remove unsupported Anime ad-placement inference without changing the Anime UI feed.
- [x] Regenerate all four translation maps and locale keys from the JSON assets.
- [x] Make formatting, analyzer, Flutter tests and independent Android tests report outcomes independently.
- [x] Keep APK assembly blocked unless all required gates pass.
- [ ] Re-run Flutter suite in GitHub Actions; expected result must be verified, not inferred from source changes.
- [ ] Run all Android unit tests and verify non-empty, failure-free JUnit reports.
- [ ] Build and audit ARM64 Release APK.
- [ ] Install and test the extension runtime and Manga pages on the user's device.

**Status:** Source and CI recovery prepared. Phase57.2 is not accepted until the new CI run and device verification succeed.
