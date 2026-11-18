# RAVEN23 PHASE63 — CI build failure repair

**Date:** 2026-11-12  
**Failed workflow:** `RAVEN23 Local Android APK Build`  
**Run:** `43283800739` (attempt 1)  
**Commit analyzed:** `5115fe26b4c82e843295c0b7b7352d62afa84888`  
**Build mode:** Release / `prod` / `android-arm64`

## 1. Actual failure point

Dependency resolution (`flutter pub get`) completed successfully. The scoped formatter step also completed successfully and formatted 50 targets (12 files changed). The next gate, `flutter analyze --no-fatal-infos`, failed with exactly two Dart errors:

- `lib/manga/ui/manga_reader_screen.dart` — undefined `AppType.caption` used for a reader-settings subtitle.
- `lib/manga/ui/manga_reader_screen.dart` — undefined `AppType.caption` used for the translation privacy/help note.

`AppType` is the application's typography token class in `lib/design/app_tokens.dart`. It defines `body`, `metadata`, `sectionHeader`, `cardTitle`, and other styles, but does not define `caption`. The two affected strings are secondary/helper text, so both references are corrected to `AppType.metadata`. The line numbers shown in the CI log refer to the formatted working tree in the runner; applying the exact formatter patch changes the source line numbers compared with the packaged pre-format archive.

The analyzer also emitted informational lints, including two deprecated `DropdownButtonFormField.value` usages and redundant imports. These were not the cause of the failed gate. For cleanup, the two dropdown fields now use `initialValue`, and three imports explicitly reported as unnecessary by the same analyzer run were removed.

## 2. Changes applied

- Applied the exact `dart-format.patch` captured by run `43283800739`; `git apply --check` passed against the PHASE63 archive before application.
- Kept the lockfile updates produced by the successful dependency-resolution step (`flutter pub get`).
- Replaced both undefined `AppType.caption` references with `AppType.metadata`.
- Replaced the two deprecated dropdown `value` initializers with `initialValue` (Flutter 3.35.7 / Dart 3.9.2 toolchain used by CI).
- Removed redundant imports from `manga_reader_screen.dart`, `manga_translation_platform.dart`, and `manga_work_screen.dart`, matching the analyzer's diagnostics.
- Preserved the existing Manga work-detail, Mihon, OCR/translation, reader and chapter-progress implementation; no feature flow or data model was intentionally changed by this repair.

## 3. Verification performed in this repair environment

- The supplied formatter patch applied cleanly to the PHASE63 project archive.
- The two `AppType.caption` references were replaced; a repository scan finds no remaining `AppType.caption` references under `lib/`.
- The scoped formatter script passes `bash -n`.
- All 50 paths listed by `tool/format_phase57_dart.sh` exist in the project.
- The two `DropdownButtonFormField` instances in the reader use `initialValue`.
- Archive and changed-source packaging checks are performed for this repair bundle.

## 4. What remains unverified

The uploaded CI run stopped at Analyze. It did **not** run the focused Flutter pre-build tests, Android Mihon ABI unit test, Gradle wrapper generation, Release APK build, or APK/ABI audit. The current repair container also has no `flutter`, `dart`, or Android SDK executable available, so the repaired source could not be re-run through `flutter analyze`, `flutter test`, Kotlin/Gradle compilation, or APK assembly here.

Therefore this is a **source-level remediation**, not a successful-build claim. A fresh GitHub Actions run on the repaired commit is required. Its order is unchanged: dependency resolution → formatter check → analyzer → focused Flutter tests → Android unit test → ARM64 Release APK → APK audit.

## 5. Original diagnostics

The unmodified CI report and the exact captured dependency, formatter, environment, analyzer and formatter-patch artifacts are retained in:

`docs/build-reports/2026-11-12-phase63-run-43283800739/`
