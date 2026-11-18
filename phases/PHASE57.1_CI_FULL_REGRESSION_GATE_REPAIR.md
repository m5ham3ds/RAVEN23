# PHASE57.1 — CI Analyzer Recovery & Full Regression Gate

**Date:** 2026-11-10  
**Base:** Owner-provided `RAVEN23_PHASE57.zip` and CI diagnostics from run `42857526541`  
**Status:** Source and CI workflow repaired; complete GitHub Actions run pending. PHASE57 remains unaccepted.

## 1. Failure evidence and exact root causes

The supplied Release run (`42857526541`, commit `04a6b6e6457dd994077cf6a4993954aa8383a077`) completed dependency resolution and PHASE57 Dart formatting, then stopped at `Flutter analyze`.

The analyzer reported two errors:

| File | Location | Error | Correction |
|---|---:|---|---|
| `lib/mobile/screens/manga_screen.dart` | 38:12 | `invalid_reference_to_this` | Declare `_fade` as `late final AnimationController` and initialize it in `initState`, where the `State` instance is a valid `vsync`. The controller is always initialized before `dispose` accesses it. |
| `test/home_screen_test.dart` | 240:3 | `undefined_class` (`HomeOptionalRow`) | Import `package:raven23/mobile/widgets/home_optional_row.dart` in the test that pattern-matches that Home row type. |

The same analyzer log reported three information-only lints: a local callback declared as a variable, a public `HomeHeader` constructor without a key parameter, and a redundant `dart:ui` import. These were cleaned up as well. CI uses `--no-fatal-infos`, so those infos did not cause the job failure.

**The Flutter runtime tests did not execute in that run.** Their step was skipped after analysis failed. The Kotlin unit test, Gradle wrapper generation, APK build and APK audit were also skipped. No test was recorded as failed or passed in that attempt. The archive named `RAVEN23-phase57-manga-runtime-test-log.zip` contains formatter output only; it is not a test result.

## 2. Source and formatter corrections

- Applied the exact canonical formatting patch returned by the failed run to the source archive (10 Dart files were changed by CI formatting).
- Initialized `MangaScreen._fade` in `initState` instead of referencing `this` in a field initializer.
- Added the missing `HomeOptionalRow` import to `home_screen_test.dart`.
- Converted the Manga row tap closure to a local function declaration.
- Added `super.key` to the public `HomeHeader` constructor.
- Removed the redundant `dart:ui` import from `home_optional_row.dart`; Flutter rendering already exports the referenced geometry types.

No video playback engine, Home behavior, video source priority, repository trust rule or Mihon ABI allow-list was changed by this recovery.

## 3. Full regression inventory

The supplied archive contains:

- **259 Flutter unit/widget test files** under `test/`.
- **10 Android unit-test source files** under `android/app/src/test/` (Kotlin/Java).
- Five direct Manga suites, all retained: repository manager, Phase55 catalogue, Phase55 Protobuf index, Phase56 Manga/trust regression, and Phase57 shelf aggregation.

The full Flutter suite includes every currently active feature/regression test still present under `test/`. Dedicated PHASE52 and PHASE53 test files were explicitly retired after those phases were owner-accepted, as documented in their phase records; they are not restored or counted here. All existing tests that remain active in this archive are run without a file allow-list.

No test source file was deleted in PHASE57.1. Existing suites cover active application contracts across catalogues, source repositories, video providers, playback, subtitles, ads, downloads, TV, account/configuration, and UI. Previous consolidation of duplicate sidecar-fingerprint assertions remains in place; it did not remove the independent Protobuf, trust, repository CRUD or catalogue checks.

## 4. Test execution sequence

The new APK gate is explicitly ordered:

1. `flutter pub get`.
2. Run the PHASE57 formatter fix and strict check.
3. Run project-wide `flutter analyze --no-fatal-infos` (this analyzes application and test sources).
4. Run the entire default Flutter test directory with no file allow-list:
   `flutter test --no-pub --reporter expanded --timeout 90s --concurrency=2`.
5. Run the read-only Laravel foundation smoke test only when the owner configures the `LARAVEL_SMOKE_URL` repository secret. Without it, the log explicitly records that no live endpoint was contacted.
6. Run the account-creating Laravel migration E2E test only when both `RAVEN23_E2E_STAGING_API_URL` and the explicit `RAVEN23_E2E_ALLOW_WRITES=true` repository secret are configured. This is limited to a disposable staging backend; no production URL is supplied by default.
7. Generate the pinned Gradle wrapper after the Flutter and configured integration gates pass.
8. Run the complete Android app unit-test task, without a `--tests` selector:
   `./gradlew :app:testProdReleaseUnitTest --no-daemon`.
   CI also verifies that Gradle emitted non-empty JUnit XML reports with at least one executed test and no failures/errors.
9. Build the ARM64 APK only after every preceding required/configured validation gate passes.
10. Audit APK archive integrity, ABI payload and application ID.

The Flutter step logs both its dynamically discovered test-file count and the full path inventory. In this archive it is 259 files. The Android step logs the discovered source-file count and file inventory (10 sources). The Flutter step has a 35-minute timeout and 90-second per-test timeout; Android unit tests have a 20-minute step timeout. The workflow job remains capped at 90 minutes.

A failure in Analyze means tests are intentionally not started and are explicitly reported as skipped. A Flutter or configured live integration test failure blocks Gradle wrapper generation and later steps. An Android unit-test failure or missing/empty test report blocks APK packaging. All logs and the generated report upload with `if: always()`, so skipped and failed states are preserved distinctly.

## 5. Historical full-suite risk and interpretation

Earlier Phase40 diagnostic records documented broad-suite failures (including UI timing/lazy-list assumptions, settings expectations, subtitle fixtures, and other provider contracts). Follow-up changes were prepared in later Phase40 records, but some of those broad runs were never rerun after the proposed fixes. A later focused Release gate is not evidence that every file in the current 259-file suite passed. The new full-suite gate intentionally rechecks the active tests and preserves the exact failing test names, exceptions, expected/actual values, and final log tail. Do not change production behavior or test expectations merely to force green; fix a failure only after matching it to the current implementation contract and concrete CI output.

The old dedicated PHASE52/PHASE53 tests were explicitly removed after owner-confirmed phase acceptance, as recorded in their historical phase documents. They are intentionally not resurrected. The current full suite covers every test file that remains active in this project archive.

## 6. Integration-only scope

- `test/integration/laravel_migration_e2e_test.dart` is discovered by the standard `flutter test` run and retains its environment/write guard. CI also offers a separate opt-in invocation using a staging-only URL and explicit write permission.
- Root-level `integration/laravel_foundation_smoke_test.dart` is outside `test/`; CI runs it only when the owner configures `LARAVEL_SMOKE_URL`. It must not silently contact a live backend during an ordinary offline regression run.

## 7. Static validation performed in the archive environment

- Workflow YAML parsed successfully; step IDs are unique and all `steps.<id>` references resolve.
- Every workflow `run:` block passed `bash -n`.
- Every embedded Python heredoc in the workflow compiled successfully.
- All 12 scripts under `tool/*.sh` passed `bash -n`.
- The Phase57 formatter contains 13 unique Dart targets and every path exists.
- All five Manga regression files exist; the full test inventory contains 259 Flutter test files and 10 Android unit-test source files.

Flutter, Dart and Gradle are not installed in this archive-editing environment. Therefore no post-fix `flutter analyze`, Flutter tests, Android unit tests, APK build or APK audit was executed locally. The next GitHub Actions run is the first runtime verification of these corrections.

## 8. Acceptance

- [x] Reproduced and documented both analyzer errors from the exact CI report.
- [x] Fixed the Manga animation controller initialization and missing Home test import.
- [x] Cleaned the three information-only analyzer lints reported in the same run.
- [x] Restored unrestricted discovery of all Flutter test files.
- [x] Expanded the Android test step from one filtered Mihon test to all Android app unit tests.
- [x] Added strict sequencing and APK gates for both complete suites.
- [x] Kept all existing test source files; no active coverage was deleted.
- [x] Validated workflow YAML, Bash blocks, embedded Python, target paths and test inventory statically.
- [ ] GitHub Actions project-wide Analyze passes.
- [ ] All Flutter unit/widget tests pass.
- [ ] All Android app unit tests pass.
- [ ] ARM64 Release APK build and audit pass.
- [ ] On-device Team X / trusted 1.6 extension install passes signature verification and loads.
- [ ] On-device Manga/Manhwa Home visual parity is confirmed.

**Current status:** PHASE57.1 source and CI repair prepared — complete CI and device acceptance pending.
