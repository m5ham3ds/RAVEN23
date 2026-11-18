# RAVEN23 — PHASE63.14: HomeScreen animation-controller lifecycle repair

**Date:** 2026-11-14  
**Input CI run:** [43613983587](https://github.com/m5ham3ds/RAVEN23/actions/runs/43613983587)  
**Commit reported by CI:** `c8bf1c38723d1994f5c362399e9e0ef68c6e7516`  
**Baseline:** PHASE63.13 Dio/Analyze repair project.

## 1. Actual CI outcome

The run passed dependency resolution, scoped Dart formatting (72 targets), and `flutter analyze --no-fatal-infos`. The focused Flutter pre-build test step then failed with exactly one widget-test failure. The test runner reached `+128 -1`; all other focused tests completed successfully.

The failed test was:

`test/home_screen_test.dart` — `successful empty response shows No results, not Retry`

The Android Gradle wrapper generation, focused Mihon ABI unit test, Release APK build, and APK size/ABI audit were skipped because the required Flutter test gate failed. No APK was produced by this run.

## 2. Root cause

`lib/mobile/screens/home_screen.dart` declared `_fade` as a lazily initialized `late final AnimationController`:

```dart
late final AnimationController _fade = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 220),
  value: 1,
);
```

On a successful empty catalogue response, the Home screen can complete without ever reading `_fade` (no row fade is required). `dispose()` nevertheless reads `_fade` to dispose it. Because the field was lazy, that read initialized the controller during `dispose()`. `SingleTickerProviderStateMixin.createTicker` then attempted to look up `TickerMode` from an already deactivated widget tree, causing:

`Looking up a deactivated widget's ancestor is unsafe.`

The stack points to `_HomeScreenState._fade` (line 84), `_HomeScreenState.dispose` (line 138), and `test/home_screen_test.dart`'s successful-empty-response case.

## 3. Repair applied

- Changed `_fade` to an uninitialized `late final AnimationController` field.
- Added `initState()` and constructed the controller there, while the State is active and can safely provide a ticker.
- Kept the 220 ms duration, initial value `1`, all `forward(from: 0)` call sites, and the existing `dispose()` call unchanged.
- Did not change Home feed loading, TMDB/AniList cache policy, offline/empty-state classification, row order, or any other page behavior.
- Strengthened the existing failing widget test to explicitly unmount the empty Home screen and assert `tester.takeException()` is null. This turns the previously teardown-only framework exception into an explicit regression assertion without adding a duplicate test.

## 4. Formatter patch and scope

The supplied formatter patch archive contains an empty `dart-format.patch` (0 bytes); the original CI run already passed all 72 scoped Dart formatter targets. `home_screen.dart` is included in `tool/format_phase57_dart.sh`, so the modified file remains covered by the same formatter gate. No formatting patch hunk was available or needed.

## 5. Validation boundary and next gate

The exact source change was applied to the PHASE63.13 project and reviewed against the exception stack. This editing environment does not have Flutter or Dart installed, so the widget test was **not rerun locally**. Static structure checks and archive integrity checks were performed for the resulting project.

Run GitHub Actions again. Acceptance requires the formatter and Analyze gates to pass, all 17 focused Flutter test files to pass (including the empty-response teardown test), the Mihon ABI unit test to pass, and a Release `arm64-v8a` APK to be built and audited. Do not mark PHASE63.14 build-accepted until those downstream stages complete.
