# RAVEN23 PHASE63.22 — Focused Test Gate Repair

Date: 2026-11-15  
Base: `PHASE63.21_SECONDARY_DOCK_COLLAPSE_RESTORE`  
GitHub Actions run: `43738500315`  
Commit tested: `50aa4620d798492dceeedca453b4976dfd5b7d2f`

## CI diagnosis

The report shows that dependency resolution, the scoped Dart format check, and `flutter analyze --no-fatal-infos` succeeded. The analyzer emitted 40 informational lints but returned exit code 0; there were no analyzer errors blocking the pipeline.

The focused Flutter test gate failed with exactly two widget-test failures (142 passed, 2 failed in the combined run). Because that gate is required, wrapper generation, the Mihon ABI test, APK build, and APK audit were skipped.

### Failure 1 — secondary navigation dock collapse test

`test/mobile/mobile_nav_bar_test.dart`, test `secondary dock collapses after selection and restores both selections when reopened`.

The test required `find.text('Movies')` to return no widgets after closing the secondary dock. The production widget deliberately retains the dock's child under `AnimatedSize` so Flutter can animate its height from 54 dp to 0 dp. `ClipRect` clips the collapsed region and `IgnorePointer` prevents interaction. The text can therefore remain in the element tree even though the dock is fully collapsed and invisible. This was an invalid widget-tree expectation, not a failure of the visual collapse behavior.

The test now verifies the rendered contract: the dock's animated extent is 0 dp after selection, retained labels are not hit-testable, and reopening restores 54 dp with the selected destination visible and tappable. No production navigation or animation code was changed; the original close-after-selection behavior from PHASE63.21 remains intact.

### Failure 2 — Movies/Series automatic recovery test

`test/home_screen_test.dart`, test `Movies and Series recover automatically after network connectivity returns`.

The test iterated Movies and Series by calling `pumpWidget` twice with the same `HomeScreen` widget type at the same tree position. Flutter therefore reused the existing State. `HomeScreen.initialFilter` is intentionally read on first initialization (`_started` guard); changing the constructor parameter on the reused State does not create a fresh filter session. The second iteration consequently observed the first iteration's completed error state instead of a new cold-load skeleton.

The test now supplies `ValueKey<HomeFilter>(filter)`, which gives Movies and Series independent HomeScreen State instances and accurately tests the two independent initial-load cases. No production Home loading or reconnect behavior was changed.

## Formatter patch

Applied the supplied CI Dart-format patch successfully. It normalizes five Dart source files:

- `lib/manga/mihon/mihon_source_browser_screen.dart`
- `lib/manga/ui/manga_reader_screen.dart`
- `lib/manga/ui/manga_work_screen.dart`
- `lib/screens/common/quickjs_source_settings_dialog.dart`
- `lib/screens/common/source_repositories_screen.dart`

## Scope of changes

- Updated only the two failing widget tests to assert the actual lifecycle and visual contract.
- Applied the formatter patch provided with the CI diagnostics.
- Preserved the original report, focused test log, formatter patch, environment and dependency logs under `docs/build-reports/2026-11-15-phase63.21-run-43738500315/`.
- Added this phase report under `phases/`.
- No production runtime behavior was changed in this repair phase.

## Validation status

- Supplied formatter patch: applied successfully to all five target files.
- Focused CI report and test log: inspected; both failure causes mapped to their exact source/test locations.
- Static review of the corrected expectations: completed.
- Flutter tests and APK build: not run in this editing environment because Flutter/Dart SDK executables are not installed here. GitHub Actions must confirm the corrected test gate and continue through the Mihon ABI test and APK build.

PHASE63.22 is a test-gate repair candidate, not a confirmed successful APK build.
