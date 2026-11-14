# PHASE63.10 — Mihon paged-directory widget test correction

Date: 2026-11-14

## Input CI run

- Workflow: `RAVEN23 Local Android APK Build`
- GitHub Actions run: `43533044222`, attempt `1`
- Commit: `a6fd0bd80c91544fd4b9a437ad1f036b3e3bb877`
- Build mode: Release; ABI target: `android-arm64`
- `flutter pub get`: success.
- Scoped Dart formatter: success; 63 targets, no formatter changes.
- `flutter analyze --no-fatal-infos`: success (36 non-fatal analyzer infos, including two Transform API deprecations).
- Focused Flutter test gate: 103 tests passed, one test failed.
- Gradle wrapper generation, Android Mihon ABI test, APK build and APK audit were skipped because the focused Flutter gate failed. No APK was produced.

## Failure evidence

The only failing test was:

`test/manga/mihon_source_browser_screen_test.dart`

Test: `reveals the next source batch while scrolling` (failure at line 122).

The assertion could not find `Source 15` after the final scroll. The test fixture generated `Source 1` through `Source 15`, while the production directory deliberately sorts names alphabetically. In that order, `Source 15` sorts between `Source 14` and `Source 2`, so it is not a reliable marker for the final page. In addition, `ListView` lazily builds only rows near the viewport; a source that sorts into the first batch can be outside the active widget tree after scrolling to the end of later rows. The original assertion therefore conflated alphabetical ordering with pagination and could fail even when the page count had advanced.

No application-side pagination failure is established by this log. The production implementation's ten-entry initial limit and scroll-triggered reveal remain unchanged.

## Repair

- Zero-pad the numeric test names (`Source 01` … `Source 15`) so the fixture's alphabetical order matches the intended row sequence and page boundary.
- Assert the initial `10 / 15` counter so the test explicitly verifies the first ten entries are rendered before scrolling.
- Retain the scroll-to-end sequence and assert `Source 15` only after the final batch has been revealed and scrolled into view.
- Do not change production sorting, source ranking, installed-first behavior, page size, scroll threshold, repository loading, or Mihon runtime behavior.

## Other diagnostics

- Dependency resolution and formatting succeeded.
- Flutter Analyze exited with code 0 under `--no-fatal-infos`; its 36 infos are not fatal.
- The captured test output also contains repeated Easy Localization missing-key warnings from lightweight test translation fixtures. These did not fail the run and are not the cause of the single failed test.
- The supplied `dart-format.patch` is empty (`0` bytes); the summary says no formatter changes were produced.

## Validation limits and acceptance

The current repair environment does not have Flutter or Dart on `PATH`. The test fixture has been corrected and the source/archive structure has been checked, but the corrected Flutter widget test has **not** been executed here. A new GitHub Actions run must confirm all 15 focused test files, the Mihon Android ABI unit test, ARM64 Release APK creation, and APK ABI/size audit before PHASE63.10 is accepted. The previous run produced no APK.

Raw report, dependency log, analyzer log, focused test log, environment details and empty formatter patch are preserved under:

`docs/build-reports/2026-11-14-phase63.10-run-43533044222/`
