# PHASE57.5 — Splash Generator Removed from the Application Dependency Graph

**Date:** 2026-11-11  
**Input CI run:** `42927816064`  
**Input commit:** `c63b4d07dd91067e0b8ab06d7894f5bd198f5cdb`  
**Status:** Source and CI correction prepared; all CI and device acceptance pending.

## 1. Failure classification

The CI run failed in `Resolve Flutter dependencies` (`flutter pub get`). The pub solver reported that the pinned Flutter 3.35.7 `flutter_test` SDK package requires `meta 1.16.0`, while `flutter_native_splash 2.4.8` requires `meta ^1.18.0`. The dependency constraints cannot be satisfied together.

The accompanying Dart formatter patch is empty because the formatter step is downstream of dependency resolution and did not execute. No analyzer, Flutter test, Android test, Gradle build or APK step was reached. Therefore this run contains no test failures.

## 2. Why the generator is removed from the app

A source scan of `lib/`, `test/` and `android/` found no Dart imports of `package:flutter_native_splash`, no `FlutterNativeSplash` API calls and no direct references to its old Android plugin class. The package is only a resource-generation tool. The Android launch/splash resources are already committed in `android/app/src/main/res/drawable*` and `values*`. Keeping the generator in the root app dependency graph provides no runtime value and risks adding an Android plugin registration.

## 3. Changes in this correction

1. Keep `flutter_native_splash` absent from root `dev_dependencies` and `pubspec.lock`.
2. Retain the unchanged generator settings in root `flutter_native_splash.yaml`.
3. Remove `tool/generate_native_splash.sh`; using `flutter pub global activate` for this Flutter-SDK-dependent generator was not an appropriate isolated execution path.
4. Keep the CI guard after `flutter pub get`: `.flutter-plugins-dependencies` must be present and must not contain `flutter_native_splash`; the lockfile must also have no package entry for it.
5. Keep Flutter 3.35.7, Dart 3.9.2, Java 17, Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20, Android SDK 36 and NDK 28.2.13676358 unchanged.
6. Preserve every existing generated Android splash resource; no visual assets, launch XML or style resource is regenerated or altered.
7. Preserve the five focused Flutter test files and the single Android ABI test class. The rest of the 259 Flutter and 10 Android test source files remain present for manual/deeper regression.

## 4. Optional future splash-resource regeneration

No generator is needed for the current build because resources are already committed. If a future logo/config change requires regeneration under the pinned Flutter 3.35.7 toolchain, temporarily add the meta-compatible 2.4.7 generator as a dev dependency, regenerate, then remove it and refresh dependency/plugin metadata before building:

```bash
flutter pub add --dev 'flutter_native_splash:=2.4.7'
dart run flutter_native_splash:create
flutter pub remove flutter_native_splash
flutter pub get
! grep -q flutter_native_splash .flutter-plugins-dependencies
```

Do not run an Android build before removing the temporary dependency. The old generator's Android plugin declaration must not enter the app's build graph.

## 5. Validation limits

Validated statically: YAML parsing for `pubspec.yaml`, `pubspec.lock`, `flutter_native_splash.yaml` and `.github/workflows/android-ci.yml`; lockfile retains `meta 1.16.0` and does not list `flutter_native_splash`; root `dev_dependencies` do not include the generator; CI clears generated plugin manifests before dependency resolution and checks the resulting manifest; all referenced splash resources exist; no application/test/Android source references the generator; all existing test source files remain present.

Flutter, Dart and Gradle were not available in the editing environment. Therefore `flutter pub get`, analyzer, tests, APK assembly and device installation have not been executed here. CI must confirm the solver and downstream gates.

## 6. Required acceptance sequence

1. `flutter pub get` succeeds under Flutter 3.35.7 and the plugin manifest excludes `flutter_native_splash`.
2. Scoped Dart format and full-project analysis pass.
3. All five focused Flutter Manga/Mihon test files pass.
4. The Android ABI test class executes all three cases with zero failures.
5. ARM64 production Release APK assembles and passes APK audit.
6. Owner verifies extension installation and Manga/Manhwa behavior on-device.

**Phase57.5 remains unaccepted until CI and device gates pass.**
