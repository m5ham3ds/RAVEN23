# RAVEN23 — PHASE63.32 Focused Pre-build Test Gate Repair

## Scope

Repair the three failing assertions reported by CI run `44216443676` for commit
`3f3dd08619d2d0d36ed7c08c9509ff7ed8bacee5`. No production playback, source
priority, navigation, Home feed, or download behavior is changed in this phase.

## Findings from the supplied CI report

- Flutter dependency resolution completed successfully.
- The scoped Dart format step completed successfully.
- `flutter analyze --no-fatal-infos` completed successfully (43 informational
  diagnostics; exit code 0).
- The focused Flutter test gate failed with exactly three test failures.
- Gradle wrapper generation, Android ABI/offline-download tests, APK build, and
  APK audit were skipped because the Flutter test gate failed.

## Test repairs

1. `test/video_utils_download_format_test.dart`: expectations now preserve
   distinct quality rows for separate servers, even when the resolution is the
   same. This is required so a user can select a specific server rendition and
   so download selection does not collapse different URLs/headers/codecs.
2. The same test file now expects provider-owned `Auto`, `Auto (2)`, and
   `Adaptive` rows to be omitted from user-facing download choices, while
   retaining distinct unknown-quality and host-specific real choices.
3. `test/home_screen_test.dart`: the test now scrolls to and validates the lazy
   `top_10_series_today` shelf before returning to the top. The old assertion
   expected that off-screen lazy sliver to remain mounted even though the test
   had never scrolled to it.
4. Applied the supplied formatter patch to the two source-priority Dart files.

## Compatibility intent

- The user's PHASE63.31 Movies/Series PRIMARY LIST order remains unchanged.
- Anime ordering remains unchanged.
- Existing user-customized priority lists remain preserved.
- Provider Auto rows remain excluded from the player/download quality pickers;
  app-owned automatic selection is not changed here.
- Distinct server choices remain individually selectable in playback/download.

## Validation status

The supplied report proves the static analysis step passed and identifies the
three stale test expectations above. This editing environment does not have the
Flutter/Dart SDK installed, so `flutter test`, `flutter analyze`, and APK build
were not re-run here. The next CI run must execute the full configured gate
before this phase is considered build-confirmed.
