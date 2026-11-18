# PHASE57.4 — Pub Resolution Recovery & Splash Generator Isolation

**Date:** 2026-11-11  
**Input CI run:** `42927816064`  
**Failing commit:** `c63b4d07dd91067e0b8ab06d7894f5bd198f5cdb`  
**Status:** Source and CI correction prepared; GitHub Actions rerun and device acceptance pending.

## 1. Exact failure

The supplied CI report shows that the workflow stopped at `Resolve Flutter dependencies`. No formatter, analyzer, Flutter test, Gradle test, APK build, or APK audit was reached.

The dependency solver output was:

```text
flutter_test from Flutter SDK pins meta 1.16.0
flutter_native_splash 2.4.8 requires meta ^1.18.0
therefore flutter_test and flutter_native_splash cannot be solved together
```

This is a dependency-constraint conflict, not a formatting, analyzer, Android, or test failure. The uploaded Dart format patch is empty because the formatter step never ran.

## 2. Why the Phase57.3 dependency change was the wrong integration boundary

Phase57.3 upgraded `flutter_native_splash` from the previously locked 2.4.4 to 2.4.8 to avoid the old Android plugin registration that had caused a missing `FlutterNativeSplashPlugin` Java class during `compileProdReleaseJavaWithJavac`.

The 2.4.8 release removes unnecessary native plugin declarations, but it also raises its `meta` dependency to `^1.18.0`. The project's pinned Flutter 3.35.7 SDK supplies `flutter_test` with `meta 1.16.0`; consequently the new package version cannot be part of the application's dependency graph under that toolchain.

The project does not import `package:flutter_native_splash` or call `FlutterNativeSplash` from application/test Dart code. The package is used only to generate static native splash resources. The generated Android resources are already committed:

- `android/app/src/main/res/drawable*/launch_background.xml`
- `android/app/src/main/res/drawable*/splash.png`
- `android/app/src/main/res/drawable*/android12splash.png`
- `android/app/src/main/res/values*/styles.xml`

Therefore the generator does not need to be a dependency of the app or appear in Flutter's plugin graph.

## 3. Corrective implementation

1. Removed `flutter_native_splash` from root `dev_dependencies`.
2. Removed its package entry from `pubspec.lock`; Flutter's next successful `pub get` will prune any now-unreachable transitive lock entries.
3. Moved the unchanged splash configuration to the standalone root file `flutter_native_splash.yaml`.
4. Kept the generator configuration in `flutter_native_splash.yaml`, outside the application dependency graph. No global activation script is shipped: the generator depends on the Flutter SDK and should not be advertised as a generic standalone global executable.
5. Added a CI assertion after `flutter pub get`: `.flutter-plugins-dependencies` must exist and must not contain `flutter_native_splash`. This guards against accidentally reintroducing the tool as an Android app plugin.
6. Kept Flutter 3.35.7, Dart 3.9.2, Java 17, Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20, SDK 36 and NDK 28.2.13676358 unchanged. No broad SDK/toolchain upgrade and no `dependency_overrides` were introduced.
7. Preserved all generated splash/launch resources byte-for-byte; no visual redesign or manual edit to generated registrant code was made.

### Optional future splash regeneration

The existing committed Android resources are already generated, so this is not part of normal builds. If the source logo/configuration changes and resources must be regenerated under Flutter 3.35.7, temporarily add the compatible generator version `2.4.7` as a dev dependency, run `dart run flutter_native_splash:create`, then remove the package and resolve dependencies again before any Android build:

```bash
flutter pub add --dev 'flutter_native_splash:=2.4.7'
dart run flutter_native_splash:create
flutter pub remove flutter_native_splash
flutter pub get
! grep -q flutter_native_splash .flutter-plugins-dependencies
```

Do not build the app while the temporary generator dependency is present: its legacy Android plugin declaration must not enter the production app plugin graph. The CI guard enforces this boundary.

## 4. Test and CI scope retained

The minimal routine APK gate is unchanged:

- Five focused Flutter test files covering Manga repository management, catalogue/index parsing, trust/install eligibility and home shelf parity.
- The Android `MihonExtensionLoaderAbiTest` class with its three ABI boundary cases.
- Full-project `flutter analyze`.
- ARM64 Release APK build and APK audit, gated on all preceding required steps.

The other 254 Flutter test files and nine Android unit-test files remain in the repository for owner-led/manual deeper regression. No test was deleted, marked passed, or converted to skipped as part of this correction.

## 5. Validation and limitations

Static checks performed while preparing this correction:

- `pubspec.yaml`, `pubspec.lock`, and `flutter_native_splash.yaml` parse as YAML.
- The splash-generation script passes `bash -n`.
- The Android splash resource files referenced by the configuration exist.
- No application Dart source imports `flutter_native_splash` or references `FlutterNativeSplash`.
- The CI dependency guard is placed immediately after `flutter pub get`; later gates remain sequential.
- Existing Flutter/Android test inventories remain intact.
- ZIP integrity and local documentation links are checked before packaging.

Flutter and Dart executables are unavailable in the editing environment. Therefore `flutter pub get`, `flutter analyze`, the focused tests, Gradle tests, the Release APK and physical-device installation have not been executed here. Run `flutter pub get` in CI to confirm the updated dependency graph; only then can downstream gates be considered.

## 6. Next acceptance gates

1. `flutter pub get` succeeds and the plugin manifest contains no `flutter_native_splash`.
2. Scoped formatting and full-project analyzer succeed.
3. The five focused Flutter test files pass.
4. The Android ABI test class reports all three cases executed with zero failures/errors.
5. The `prod` ARM64 Release APK builds and passes CRC/package/ABI audit.
6. Owner installs the APK and manually verifies trusted Team X (extensions-lib 1.6), other selected Mihon extensions, and Manga/Manhwa screens.

**Phase57.4 is superseded by Phase57.5. Its dependency-removal decision remains valid; the global activation-script approach was removed because the generator is Flutter-SDK-dependent.**
