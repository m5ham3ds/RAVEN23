# RAVEN23 — PHASE63.5: Focused pre-build navigation test repair

**Date:** 2026-11-13  
**Input CI run:** `43417262025` (attempt 1)  
**Commit tested by CI:** `0e178540f36ee77d856d9045072d42f83d66e1f8`  
**Build mode:** Release / `prod` / `android-arm64`

## 1. Actual CI result and blocker

The supplied run completed dependency resolution, the 53-target scoped Dart formatter, environment capture, and `flutter analyze --no-fatal-infos` successfully. The focused Flutter gate then executed all **12 configured test files** and stopped with **94 passing tests and one failing test**. The only failing test was:

`test/mobile/mobile_nav_bar_test.dart` — `menu toggle shows the selected secondary destination and restores list`.

The assertion at the previous test line 58 expected `find.byIcon(PhosphorIcons.video(PhosphorIconsStyle.fill))` to match exactly one widget. CI found two matching icons:

1. the selected Movies destination in the secondary navigation dock; and
2. the center menu-toggle icon, which intentionally mirrors the currently selected secondary destination.

This is the intended PHASE63.4 behavior, not a production navigation defect. The test used a global icon finder and incorrectly assumed the same icon could appear only once in the complete widget tree.

The analyzer and all preceding pre-build stages passed. The Flutter test step failed, so Gradle wrapper generation, the Mihon Android unit test, ARM64 Release APK assembly, and APK audit were correctly skipped. The supplied run did not produce an APK.

## 2. Correction applied

- Kept the PHASE63.4 navigation implementation unchanged.
- Scoped the selected-destination assertion to the widget with key `mobile-nav-menu-toggle`, then checked the actual `Icon.icon` value under that control.
- Verified the menu toggle begins with `list`, changes to the filled `video` icon after Movies is selected, and returns to `list` after returning Home.
- Kept the separate destination-dock icon coverage intact. The test now permits the expected duplicate `video` icon elsewhere in the tree while still proving the center toggle displays the correct icon.
- Updated the CI workflow's failed-step label from the stale eight-file count to the actual twelve-file gate and added the four previously omitted tests (metadata, reading store, source matcher and mobile navigation) to the generated report's gate inventory.
- Updated the workflow step/log labels to include mobile navigation.

No app behavior, routing, Phosphor icon mapping, Home content, Manga features, source priorities, player/provider logic, dependency versions, or Android build configuration was changed.

## 3. Files changed

- `test/mobile/mobile_nav_bar_test.dart`
- `.github/workflows/android-ci.yml`
- Applied the exact CI formatter patch to `lib/manga/translation/manga_translation_platform.dart`, `lib/manga/ui/manga_reading_store.dart`, `lib/manga/ui/manga_source_matcher.dart`, `lib/manga/ui/manga_work_screen.dart`, `lib/mobile/app/mobile_nav_bar.dart`, `test/manga_reading_store_test.dart`, and `test/manga_source_matcher_test.dart`; the navigation test was formatted while integrating the corrected assertion.
- `phases/PHASE63.5_CI_PREBUILD_NAVIGATION_TEST_FIX.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/README_CHANGED_FILES.txt`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_58.md`

## 4. Verification and remaining gates

Evidence from the supplied CI run:

- `flutter pub get`: passed.
- Scoped Dart formatting (53 targets): passed.
- `flutter analyze --no-fatal-infos`: passed.
- Focused Flutter test gate: 94 passed, 1 failed; failure mapped to the global icon finder described above.
- Gradle wrapper generation: skipped after the failed Flutter test gate.
- Mihon Android unit test: skipped.
- ARM64 Release APK build and APK audit: skipped; no APK was generated.

Static checks performed for this repair:

- The CI run itself confirms that all 53 scoped Dart targets were formatted and that the formatting/check step passed; its captured formatter patch was applied to the seven non-navigation-test files listed above, and the navigation test was kept in the same formatter layout.
- All 53 scoped formatter paths exist and are unique.
- The 12 configured focused Flutter test paths exist.
- The workflow's report now names all 12 files and uses the correct count in the failed-step label.
- The navigation test scopes its icon assertion to the keyed center menu-toggle control.
- Local packaging checks: workflow YAML parsed; all 14 workflow Bash run blocks passed `bash -n`; the formatter shell script passed `bash -n`; all 53 format targets and 12 focused tests exist; and the generated CI test inventory exactly matches the configured list.

Flutter, Dart, Gradle and Android SDK are not installed in this repair container. Therefore the updated widget test, analyzer, Android unit test, Release APK build and APK audit have **not** been rerun here. This is a targeted source/CI repair, not a successful-build claim. A fresh GitHub Actions run is required to confirm that the fixed gate passes and that CI proceeds through the Mihon Android test, ARM64 APK assembly and APK audit.

## 5. Preserved CI evidence

The supplied raw report, environment/context snapshot, dependency-resolution log, analyzer log, formatter log/patch/summary and complete focused Flutter test log are retained under:

`docs/build-reports/2026-11-13-phase63.4-run-43417262025/`

This preserves the evidence for the exact run and keeps the historical failing test output available after the source correction.

## 6. Acceptance

- [x] Read the current project phase records and latest CI report/logs.
- [x] Identify the sole failing pre-build test and map the exact assertion to the intended duplicate navigation icons.
- [x] Correct the widget test without changing app behavior.
- [x] Correct the stale eight-versus-twelve test inventory in the CI report generator.
- [x] Preserve all twelve focused test files and all unrelated source/test files.
- [ ] Fresh GitHub Actions run passes all 12 focused Flutter test files.
- [ ] Mihon Android unit test passes.
- [ ] ARM64 Release APK build and ABI/package audit pass.
- [ ] Owner installs the generated APK and verifies mobile/tablet navigation on-device.

**Status:** PHASE63.5 source and CI correction prepared; fresh CI and device acceptance are still required. The earlier “pending build” notes in historical phase snapshots do not override later owner-confirmed successful runs; the current run `43417262025` is the latest evidence and failed only at the focused Flutter test gate.
