# PHASE63.27.2 — Restore Shared Press Feedback Scale (2026-11-17)

## Confirmed CI failure

This repair is based on the `RAVEN23_PHASE63.27.1_DART_FORMAT_REPAIR.zip` working tree and the three diagnostics archives for GitHub Actions run `43961952237`, commit `ca7e446eae804ade1be9a32c8287740379c6dfcf`. No Zangetsu, FlixQuest or OpenStream archive was inspected or changed. Firebase and backend work remain out of scope.

The run confirms that dependency resolution, the scoped Dart formatter check and Flutter Analyze succeeded. The focused Flutter gate then completed 199 tests successfully and failed one assertion in `test/playback_action_test.dart`:

```text
Expected: <0.985>
Actual:   <0.96>

test/playback_action_test.dart:63
```

Android Mihon/Media3 tests, Gradle wrapper generation and APK build were skipped because the focused Flutter test prerequisite failed. The formatter patch from this run is empty (`Patch bytes: 0`); Dart 3.9.2 reports all 159 scoped targets formatted with zero changes.

## Root cause

PHASE63.27 changed the shared `AppPressFeedback` default from `0.985` to `0.96`, which contradicted the accepted PHASE63.26 interaction specification and its documented navigation behavior. The PHASE63.27 update changed some regression expectations to `0.96`, while the player-quality interaction regression still correctly expected the documented `0.985` value. The failing test exposed this inconsistency; it is not an obsolete assertion.

## Repair

- Restore `AppPressFeedback` default scale to `0.985` (1.5% shrink). Keep its existing 100 ms duration, `easeOutCubic`, opaque pointer hit testing, drag cancellation, callback ownership and Reduce Motion behavior unchanged.
- Align the default-scale assertions in `test/app_press_feedback_test.dart`, `test/mobile/mobile_nav_bar_test.dart` and `test/pill_button_test.dart` with `0.985`. `test/playback_action_test.dart` already asserts the required value and remains unchanged.
- Correct the PHASE63.27 phase note so it no longer describes the unintended `0.96` value as the shared design.
- No quality catalogue, download resolver, Media3, source discovery or CI gate behavior is changed by this repair.

## Validation boundary

The uploaded CI evidence confirms the prior run's successful formatter and Analyze stages and isolates the only focused Flutter test failure. Source-level checks for this repair verify that all shared press-scale defaults and regression expectations are `0.985`, all unrelated press-feedback behavior is unchanged, and the source archive passes ZIP integrity checks. This editing environment does not contain Flutter or Dart, so this repair has not been run through `dart format`, `flutter analyze`, Flutter tests, Android unit tests, Gradle or Release APK build locally. A new CI run must pass the full gates and produce the ARM64 APK before PHASE63.27 is accepted.
