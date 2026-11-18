# PHASE63.18 — build and validation notes

## Scope

RAVEN23-only work: offline skeleton visibility, automatic retry for Home/Movies/Series/Manga cold failures, retry-on-tab-return, Android resume connectivity refresh and stable opaque backdrop during mobile navigation.

## Static validation

- Scoped formatter list: 79 unique targets; all exist; no duplicates.
- Workflow YAML: parsed successfully (see packaging validation).
- `tool/format_phase57_dart.sh`: shell syntax verified with `bash -n`.
- Changed Dart files and PHASE63.18-added documentation lines: trailing-whitespace scan passed. No Git diff was available because the extracted source package does not contain a `.git` directory.
- Archive integrity: verified after packaging.

## Not run

Dart format, Flutter analyze, widget tests, Android unit tests, Gradle/Kotlin build, APK build and device-level network/GPU tests were not run because the Dart and Flutter SDK executables are absent from the editing environment. Do not treat this as CI/build acceptance.

## External references

- https://pub.dev/packages/connectivity_plus
- https://api.flutter.dev/flutter/widgets/TickerProviderStateMixin/didChangeDependencies.html
- https://api.flutter.dev/flutter/widgets/FadeTransition-class.html
- https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html
