# Phase 40 — CI Widget Regression Recovery Follow-up 2

**Date:** 2026-11-07  
**CI run reviewed:** `42375238484` / attempt `1`  
**Commit reviewed:** `b165afffb67b023e8f151f6b92070269a19c5581`  
**Workflow:** `RAVEN23 Local Android APK Build`  
**Reference release:** `RAVEN23-PHASE35.1.zip`  
**Status:** Source corrections prepared; CI rerun required. Phase 40 remains In Progress.

## 1. Exact result of the new CI run

The supplied report and logs describe one run and one workflow attempt:

| Gate | Result |
|---|---|
| Dependency resolution | Passed |
| Dart format fix + strict check | Passed; the formatter patch changed only the layout of one finder expression in `test/discover_screen_test.dart` |
| `flutter analyze` | Passed — `No issues found!` |
| Focused architecture/Stremio/provider tests | Passed — 160 tests |
| Phase 40 widget regression gate | Failed — 160 passed / 4 failed |
| Complete Flutter test suite | Skipped; not reached |
| Gradle Wrapper generation | Skipped; not reached |
| Android Release ARM64 APK build | Skipped; not reached |
| APK/ABI audit | Skipped; no APK produced |

**This is not evidence of an Android Gradle or APK compiler failure.** The workflow stopped at the Phase 40 regression gate before it invoked the complete Flutter suite or Android build. The four failures below are the first blockers in this run.

## 2. Four failures and source-derived causes

### 2.1 `RevealItem` — zero-delay timer was not started before animation time advanced

**Observed:** `test/mobile/widgets/reveal_item_test.dart:49` expected opacity greater than zero after the 180 ms animation interval, but received `0.0`.

**Cause:** the test flushed the pending `VisibilityDetector` callback and pumped a zero-duration frame, but then advanced directly by 180 ms. The callback schedules `Timer(Duration.zero)`. In the fake clock used by the widget test, that zero-delay timer can be delivered at the end of the first positive time advance, meaning the controller only begins at the end of the 180 ms interval. The animation consequently still reads as zero at the assertion.

**Correction:** keep the initial-state assertions, then pump a deterministic positive 1 ms scheduling tick before pumping the 180 ms animation interval. This separates delivery of the zero-delay timer from measurement of animation progress. No production `RevealItem` timing, animation curve, stagger, opacity, translation, or scale is changed.

### 2.2 Discover Anime — `scrollUntilVisible` was asked to locate a Sliver child that did not exist yet

**Observed:** `test/discover_screen_test.dart` failed while trying to scroll to `anime_status`; the stack ends in `WidgetController.element` / `dragUntilVisible` with `Bad state: No element`.

**Cause:** `anime_status` is a child later in the `SliverList.list`. Before that sliver child is built, `find.text('anime_status')` has no Element. The previous test correction still passed that not-yet-built finder directly to `scrollUntilVisible`, which tries to resolve the target element while performing the drag. Scoping the scrollable to the root `CustomScrollView` was correct, but it did not solve the absent-target problem.

**Correction:** add `test/support/scroll_until_built.dart`. Its helper repeatedly drags the screen's root scrollable by a bounded increment while the target has no Element; as soon as the lazy list builds the target, it uses `ensureVisible` and settles. Discover uses it for both the genre choice and `anime_status`. `lib/mobile/screens/discover_screen.dart` remains unchanged.

### 2.3 TV subtitle settings — the setting changed, but the owned FocusNode diagnostic label stayed stale

**Observed:** the test expected `Subtitle settings, 15px, Bold, White`, but `FocusManager.instance.primaryFocus?.debugLabel` remained `Subtitle settings, 12px, Bold, White` after selecting 15px.

**Important distinction:** the same test had already confirmed `settings.subtitleFontSize == 15` and that the visible summary was `15px, Bold, White`. Therefore the selected setting and visible UI had updated. The failing value was only the `FocusNode.debugLabel` used for focus diagnostics.

**Cause:** `_TvSubtitleOption` rebuilds `TvFocusable` with an updated `semanticLabel`, but `TvFocusable.didUpdateWidget` previously retained its internally owned `FocusNode` and never updated that node's `debugLabel`. The node kept the old `12px` diagnostic text even though its semantics and child content had changed.

**Correction:** when the same internally owned focus node is retained and `semanticLabel` changes, update only `_ownedFocusNode.debugLabel`. Externally supplied focus nodes remain untouched. This preserves the current focus node and focus state while keeping diagnostic labels consistent. No subtitle defaults, persisted settings, layout, or displayed strings are changed.

### 2.4 Home — the same not-yet-built Sliver-child assumption

**Observed:** `test/home_screen_test.dart:392` failed inside `scrollUntilVisible`, again with `Bad state: No element`.

**Cause:** Home renders feed rows with `SliverList.builder`. Lower rows such as anime and new-episode sections are not guaranteed to have Elements until the root Home scroll view approaches them. The prior test correction still used `scrollUntilVisible` with a finder that could refer to an unbuilt row.

**Correction:** use the same bounded `scrollUntilBuiltAndVisible` helper for the six requested Home feed labels. After each requested row is built, `ensureVisible` positions it for the assertion. The test then jumps the root Home scroll position back to zero before filter interaction. `lib/mobile/screens/home_screen.dart` and the Home row production implementation remain unchanged.

## 3. Files changed for this follow-up

Application code:
- `lib/tv/focus/tv_focusable.dart` — update the debug label of an internally owned FocusNode when the widget's semantic label changes; external FocusNodes remain caller-owned.

Tests and test support:
- `test/mobile/widgets/reveal_item_test.dart` — add a 1 ms positive fake-clock tick before measuring the entrance animation.
- `test/support/scroll_until_built.dart` — new helper for lazy Sliver targets that do not yet have an Element.
- `test/discover_screen_test.dart` — use the lazy-target helper for the Discover genre and Anime status section.
- `test/home_screen_test.dart` — use the lazy-target helper for Home feed rows.

Phase documentation:
- `phases/PHASE40_CI_WIDGET_REGRESSION_RECOVERY_FOLLOWUP_2_2026-11-07.md`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_56.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md`

## 4. Preservation boundary

The following user-facing screen and animation implementations are not changed in this follow-up:
- `lib/mobile/screens/home_screen.dart`
- `lib/mobile/screens/discover_screen.dart`
- `lib/mobile/widgets/reveal_item.dart`
- `lib/tv/screens/tv_settings_screen.dart`
- `lib/functions/subtitle_style.dart` and subtitle default values

The only production file changed is the reusable `TvFocusable` focus-diagnostics behavior described in section 2.3. Phase 35.1 remains the behavior/design reference; this follow-up does not reopen or redesign Home, Discover, or TV settings.

## 5. Non-blocking log messages

The Phase 40 regression log contains many EasyLocalization missing-key warnings and an SVG loader notice (`unhandled element <defs/>`). The run's final failure count is explicitly four widget tests; those warnings are not reported as separate failed tests. Previous locale-key auditing found the warning keys in the packaged locale assets, so placeholder translations must not be added merely to silence the widget-test harness. The line `TV cache clearing failed: Exception: Failed to clear cache` is diagnostic output in the log but is not one of the four `[E]` test failures listed by the runner.

## 6. Verification limits

This packaging environment does not contain Flutter or Dart (`flutter` and `dart` are not installed). Accordingly, the corrections in this archive have been source-reviewed and packaged, but **have not been run locally** through `dart format`, `flutter analyze`, widget tests, the complete test suite, Gradle, or APK inspection. Do not treat this archive as a proven successful build.

The supplied CI run confirms that its previous commit passed formatting, Analyze and the 160-test focused source suite, but failed the separate widget regression gate. The next run must verify these new changes in order:

1. formatter fix and strict format check;
2. `flutter analyze`;
3. focused architecture/Stremio/provider tests;
4. Phase 40 widget regression tests;
5. complete Flutter test suite;
6. Gradle Wrapper generation and Release ARM64 APK build;
7. APK package and ABI audit.

If the widget gate passes but the complete suite fails, diagnose the actual expanded full-suite log separately. Do not infer that a green regression subset establishes full-suite success.

**Phase 40 remains `In Progress`. Phase 41 remains `Not Started` and blocked until all required validation and Release acceptance gates pass.**
