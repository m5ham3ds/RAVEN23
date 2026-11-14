# RAVEN23 — Phase 40 CI Widget Regression Reconciliation

**Date:** 2026-11-07  
**Base project:** `RAVEN23-PHASE40-PHASE35.1-BASELINE-RECONCILIATION-AND-ANALYZE-FIX.zip`  
**Visual/behavior reference:** `RAVEN23-PHASE35.1`  
**CI run:** [42339568444](https://github.com/m5ham3ds/RAVEN23/actions/runs/42339568444)  
**Commit:** `2f172c10a71925256b35af85344728de2aa549db`

## 1. Actual CI result

The build report and full regression log establish the following sequence:

| Stage | Result |
|---|---|
| Dependency resolution | Passed |
| Dart format fix + strict check | Passed |
| Flutter analyze | Passed — no issues |
| Focused source/architecture tests | Passed — 160/160 |
| Phase 40 regression tests | Failed — 149 passed, 4 failed |
| Complete Flutter test suite | Not reached |
| Gradle wrapper generation | Not reached |
| Release ARM64 APK | Not reached |

This run did **not** report a Gradle or APK compilation error. It stopped at the Phase 40 widget-regression gate.

## 2. Four failing tests and their causes

### 2.1 `test/mobile/widgets/reveal_item_test.dart`

The test's visibility helper sets `VisibilityDetectorController.updateInterval` to zero. The first pumped frame dispatches the visibility callback, which schedules the zero-delay stagger `Timer`. The test then advanced 180ms immediately; in the fake clock that can deliver the timer at the end of the advance, starting the animation at that timestamp. The opacity therefore remains zero at the first assertion.

**Change:** add a second zero-duration pump after the visibility callback and before advancing the 180ms animation interval. The production `RevealItem` animation, duration, travel, scale, and stagger are not changed.

### 2.2 `test/discover_screen_test.dart`

The failing test added a new `scrollUntilVisible(animeStatus, ...)` call using a broad vertical `Scrollable` finder. This extra scroll was not part of the Phase 35.1 test flow. The app's `DiscoverScreen` implementation is byte-identical to Phase 35.1.

**Change:** restore the reference test flow: after selecting Anime, assert `anime_status` directly as the baseline test did; for the existing action/genre scroll, scope the finder to the vertical `Scrollable` owned by the root `CustomScrollView` rather than querying every vertical scrollable in the widget tree. No production Discover UI change.

### 2.3 `test/tv_remote_navigation_test.dart`

The test expected a `17px` picker option and then `20px`, but the actual and Phase 35.1 implementation uses `defaultSubtitleFontSize = 12`; the picker offers `[5, 10, 15, 20, 25, 30]` plus the current value if not already present. With a fresh `SharedPreferences` store, the initial focus is 12px; one D-pad right moves to 15px.

**Change:** update only the stale test expectations to 12px initially and 15px after one right-arrow movement. `tv_settings_screen.dart`, subtitle defaults, and visible design remain unchanged.

### 2.4 `test/home_screen_test.dart`

The failing test introduced a `scrollUntilVisible` loop for row labels. The failure occurred while trying to reveal a row through a broad `Scrollable` finder. The `HomeScreen` production source is byte-identical to Phase 35.1; the baseline test directly asserted the same row labels and then tested filter switching.

**Change:** restore the Phase 35.1 assertion flow for the existing rows and filter switching, removing the newly introduced fragile scrolling helper. No production Home UI change.

## 3. Phase 35.1 preservation check

A wider byte-for-byte comparison of the production UI folders found:

- `lib/mobile/screens/`: 18 of 19 shared files exactly match Phase 35.1. The only difference is `episode_screen.dart`, where the two changes are interpolation syntax in `ValueKey` strings (`${_seasonNumber}` to `$_seasonNumber`) and do not change the rendered key value.
- `lib/mobile/widgets/`: 25 of 26 shared files exactly match Phase 35.1. The only difference is `reveal_item.dart`, which uses a cancellable `Timer` for the existing stagger instead of `Future.delayed`; the animation duration (380ms), travel (28px), scale (0.94→1.0), easing and opacity curve are unchanged.
- `lib/tv/screens/`: all 17 shared files exactly match.
- `lib/tv/widgets/`: all 27 shared files exactly match.
- `lib/design/`: all 8 shared files exactly match.
- `lib/constants/`: all 4 shared files exactly match.

The following production files were verified byte-identical to `RAVEN23-PHASE35.1`: 

- `lib/mobile/screens/home_screen.dart`
- `lib/mobile/screens/discover_screen.dart`
- `lib/tv/screens/tv_settings_screen.dart`
- `lib/design/` and `lib/constants/` design-token files (baseline reconciliation already verified these).


A further check of the major mobile pages and player found these are also unchanged or differ only in string-interpolation syntax:

- `search_screen.dart`, `new_and_hot_screen.dart`, `title_details_screen.dart`, and `poster_grid.dart` are byte-identical to Phase 35.1.
- `player.dart` differs at two labels only by equivalent interpolation syntax (`${height}` → `$height`); the resulting quality/dimension strings are identical.
- `player_external_subtitles.dart` differs in one debug-log interpolation only (`${_preferredLanguageCode}` → `$_preferredLanguageCode`); it does not affect rendering or subtitle behavior.

No visual style, layout, sizing, animation duration, color, focus navigation, or player controls were changed by this follow-up.

The current follow-up changes only test timing/expectations and applies the supplied formatting patch to:

- `lib/video_providers/unified/legacy_provider_adapter.dart`
- `test/app_colors_test.dart`

No production screen, theme, color, layout, navigation, player, or playback component is changed by this follow-up.

## 4. Supplied Dart formatter patch

Applied the two formatting hunks contained in `RAVEN23-dart-format-patch(4).zip`:

- Wrapped the multi-condition `if` in `legacy_provider_adapter.dart` across lines.
- Formatted the `AppColor.colorGetter` invocation in `app_colors_test.dart`.

No semantic code changes are included in that patch.

## 5. Files changed in this follow-up

- `test/mobile/widgets/reveal_item_test.dart`
- `test/discover_screen_test.dart`
- `test/home_screen_test.dart`
- `test/tv_remote_navigation_test.dart`
- `lib/video_providers/unified/legacy_provider_adapter.dart` (formatter patch)
- `test/app_colors_test.dart` (formatter patch)
- `phases/IMPLEMENTATION_TRACKER_PHASE36_56.md`

New file:

- `phases/PHASE40_CI_WIDGET_REGRESSION_RECONCILIATION_2026-11-07.md`

No files deleted.

## 6. Validation and remaining gates

Static archive checks can verify file presence, JSON/YAML syntax, patch application, archive integrity, and preservation of baseline UI files. They cannot substitute for Flutter execution.

No Flutter/Dart SDK is available in the archive-preparation environment. Therefore the following are **pending**, not passed:

1. `dart format --output=none --set-exit-if-changed`
2. `flutter analyze`
3. Focused Phase 40 regression tests
4. Complete `flutter test --reporter expanded --timeout 60s`
5. Gradle wrapper generation
6. Release ARM64 APK build and APK ABI/package audit

Phase 40 remains **In Progress**. Phase 41 remains **Not Started**. The previous validation states for Phases 37, 37.1, 38, and 39 are unchanged.


## 7. Warnings in the supplied report

The same CI report records 4,665 EasyLocalization warning occurrences (167 unique missing-key messages) during the widget regression run. The project locale JSON files remain structurally valid and retain their 1,982-key schema; these warnings occur because these legacy widget tests render `tr()` calls without loading the app locale fixture, so the test runtime logs unresolved keys. They are diagnostic noise in this test harness, not evidence that the shipped locale JSON lost those entries. They are not suppressed in this follow-up.

The report also records the Android `sdkmanager` CLI deprecation notice. It did not cause the failure. The sole failed step was the Phase 40 regression group; the complete suite, wrapper generation, and APK build were skipped afterward.
