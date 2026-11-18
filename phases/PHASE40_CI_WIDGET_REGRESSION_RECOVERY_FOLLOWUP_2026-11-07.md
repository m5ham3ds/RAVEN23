# Phase 40 — Latest CI Widget Regression Recovery Follow-up

**Date:** 2026-11-07  
**CI run reviewed:** `42341398241`  
**Commit reviewed:** `c145f5ef05af8139588e8e845182d10b066f84a9`  
**Reference release:** `RAVEN23-PHASE35.1.zip`  
**Status:** Test-only recovery prepared; new CI execution required.

## 1. What the latest build report proves

The attached comprehensive report shows this exact sequence:

| Gate | Result |
|---|---|
| Dependency resolution | Passed |
| Dart format fix + strict check | Passed |
| `flutter analyze` | Passed — `No issues found!` |
| Focused architecture/Stremio/provider tests | Passed — `All tests passed!` |
| Phase 40 widget regression gate | Failed — four widget-test failures |
| Complete Flutter test suite | Skipped; not reached |
| Gradle Wrapper generation | Skipped; not reached |
| Android Release ARM64 APK build | Skipped; not reached |
| APK/ABI audit | Skipped; no APK produced |

This is **not an Android Gradle compile failure**. The workflow deliberately stopped at the Phase 40 regression gate before Android build steps could run. The current evidence therefore cannot establish whether the APK compiles after the test gate is green.

### Earlier CI failure chain — kept separate by run

1. **Run `42313561006` — formatter gate:** the strict check found 35 of 36 Dart targets unformatted and stopped before Analyze, tests, or Android packaging. `--output=none` did not write the formatting changes. The workflow was updated to run formatter `--fix` followed by a strict `--check`.
2. **Analyzer recovery:** after the formatter gate was passed, `flutter analyze` exposed seven test/API compile errors among 62 diagnostics. Those were corrected. A later analyzer execution still failed on ten blocking `info` lint findings (seven string-concatenation, two quote-style, and one dependency-order finding); those were also corrected. Subsequent supplied CI reached a clean analyzer result.
3. **Stremio-focused tests:** run `42321267991` passed Analyze but reported 138 passed / 7 failed in the focused source tests. Follow-up execution reached 140 passed / 5 failed, exposing empty query markers in derived `/configure` URLs. Manifest validation, configuration-state distinction, resource-profile handling, and URL derivation were patched with regression coverage.
4. **Complete-suite recovery:** run `42328559177` reported 2,143 passed / 34 failed / 11 skipped. Eleven timeouts were traced to `ProviderScanSession` awaiting a single-subscription updates stream to finish when no listener had subscribed; stream close is now initiated without blocking session completion and a late-listener regression test was added. The other failures were triaged separately rather than attributed wholesale to Stremio. A later full-suite run `42331596314` reported 2,155 passed / 23 failed / 11 skipped and prompted targeted fixes for widget visibility, settings defaults, serialization, fixtures, URL inference, and lazy-list assumptions.
5. **UI regression runs:** run `42339568444` passed formatting, Analyze, and 160 focused tests, then reported four failures in the Phase 40 widget regression group. The latest run `42341398241` again passed the preceding gates but exposed the four exact failures below. These are test assumptions/timing and a stale display expectation against existing production defaults—not evidence that the Home/Discover/TV screens should be redesigned.

The run IDs above represent distinct GitHub Actions executions and different gates. In particular, results from the separate full-suite log must not be substituted for the newest regression run, and no one of these reports shows a completed Phase 40 Android Release build.

The expanded regression log ends with `+160 -4`. Its four failed tests and assertion details are listed below. The separate focused-test log ends with `All tests passed!`; those are two different CI steps and must not be conflated.

## 2. Four current failures and corrections prepared

### 2.1 RevealItem visibility timing

**Observed:** `reveal_item_test.dart` expected opacity greater than zero after 180 ms, but observed `0.0`.

**Cause:** the test depended on `VisibilityDetector`'s batched callback and a zero-delay stagger timer being delivered at just the right point in the fake clock. A zero-duration frame pump alone did not reliably guarantee that the visibility callback had been dispatched before the entrance animation clock advanced.

**Correction:** expose `flushPendingVisibilityCallbacksForTest()` through the existing shared visibility test helper. The test first pumps a laid-out frame so the detector can collect its visibility measurements, explicitly flushes the pending callback, then pumps again to run the zero-delay stagger timer before advancing the 380 ms animation. Production `RevealItem` timing, stagger values, animation curves, opacity, travel, and scale are not changed.

### 2.2 Discover Anime status section

**Observed:** `discover_screen_test.dart` could not find `anime_status` immediately after switching to Anime.

**Cause:** the status section is later in the screen's `CustomScrollView`/sliver list. It is not guaranteed to have been built while it remains outside the viewport. The test asserted its text before scrolling to that lazy section.

**Correction:** use the `Scrollable` belonging to the screen's root `CustomScrollView`; first scroll to the Anime genre to select it, then scroll that same root scrollable to `anime_status` before asserting it. This replaces the earlier broad scrollable finder with a screen-scoped one. The Discover screen implementation is untouched.

### 2.3 TV subtitle background label

**Observed:** `tv_remote_navigation_test.dart` searched for `Black 45%` in the subtitle-settings summary, but found no such text.

**Cause:** a fresh `SettingsProvider` uses `defaultSubtitleBackgroundColor = Colors.transparent`. `_TvSubtitleSettingsContent` displays the current stored background value, and the English locale maps the transparent option to `Transparent`. `Black 45%` is one of the selectable alternatives, not the initial selection.

**Correction:** the assertion now expects `Transparent`, matching the production default and the existing settings implementation. Font-size expectations remain 12px initially and 15px after one right-arrow movement. No TV settings production code is changed.

### 2.4 Home lazy rows and filter switching

**Observed:** `home_screen_test.dart` could not find `new_episodes_series` during its first-pass assertions.

**Cause:** Home uses a `CustomScrollView` with lazily built slivers. The test searched for lower feed rows without first scrolling them into the viewport. Its later filter assertions also need a deterministic return to the top after the scroll.

**Correction:** scroll the root Home `CustomScrollView` to each expected row using the `Scrollable` nested directly under that view, then reset that same scroll position before switching filters and before checking the first row of each filter. This scopes the finder to the real Home feed scrollable rather than any nested row scrollables. The pinned filter header remains the same; Home production code is untouched.

## 3. Phase 35.1 preservation boundary

The follow-up modifies only test/support/documentation files. In particular, it does not modify:

- `lib/mobile/screens/home_screen.dart`
- `lib/mobile/screens/discover_screen.dart`
- `lib/tv/screens/tv_settings_screen.dart`
- `lib/mobile/widgets/reveal_item.dart`
- Android Gradle configuration, the player, source engines, or Stremio runtime code.

The Home, Discover, and TV Settings screen implementations were already verified byte-for-byte against Phase 35.1 in the prior baseline reconciliation. The RevealItem production file retains the previously documented cancellable zero-delay stagger; the new callback flush is confined to the widget-test helper.

## 4. Localization warning interpretation

The CI report contains many EasyLocalization missing-key warnings emitted by legacy widget tests. The existing baseline reconciliation verified that the reported keys are present in all four packaged locale JSON files. These warnings do not establish that translation assets are missing from the shipped app, and no translation values were fabricated or changed to silence the test harness.

## 5. Files changed in this follow-up

- `test/mobile/widgets/reveal_item_test.dart`
- `test/support/visibility_detector_test_helper.dart`
- `test/discover_screen_test.dart`
- `test/tv_remote_navigation_test.dart`
- `test/home_screen_test.dart`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_56.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- this report

No production application file is modified and no original Phase 35.1 file is deleted.

## 6. Verification limits and required next gate

This packaging environment does not contain Flutter or Dart, and external downloads are unavailable. Consequently, this follow-up has **not** been run through `dart format`, `flutter analyze`, `flutter test`, or Android Release build here. The current changes are source-reviewed, not execution-verified.

The next GitHub Actions run must pass, in order:

1. formatter fix and strict format check;
2. `flutter analyze`;
3. focused architecture/Stremio/provider tests;
4. Phase 40 widget regression tests;
5. the complete Flutter test suite;
6. Gradle Wrapper generation and Release ARM64 APK build;
7. APK package/ABI/size audit.

If the regression gate passes but the complete suite fails, use that run's full expanded log to triage its actual failures. Do not skip tests or mark the suite green based on this test-only patch. No APK has been built by the reviewed run.

**Phase 40 remains `In Progress`. Phase 41 remains `Not Started`.**
