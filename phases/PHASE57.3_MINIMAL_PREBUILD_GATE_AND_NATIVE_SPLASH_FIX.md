# PHASE57.3 — Minimal Pre-build Test Gate & Native Splash Plugin Fix

**Date:** 2026-11-11  
**Input CI:** `42913766313`  
**Commit in failing CI:** `53a9ddc7b4a9cb9dac7e962bb5034e877f30d8e5`  
**Status:** Source/CI prepared; rerun and device acceptance pending.

## 1. What failed

The supplied run passed dependency resolution, Dart formatting and project-wide Flutter analysis. The full Flutter suite then ran all 259 discovered test files and ended with **2,278 passed, 3 failed and 11 skipped**. The failures were:

1. `test/data/banner_placements_test.dart`: the test expects a dynamic key containing `${adBase}`, while the production implementation uses `${base}`. The failure is a stale source-contract expectation; it does not demonstrate a broken runtime banner placement.
2. `test/discover_screen_test.dart`: the finder could not locate `anime_status` through the test's lazy-scroll path.
3. `test/home_screen_test.dart`: the test expects `top_rated_anime` while Series is selected, although the application renders the anime-specific shelves only in the Anime branch.

These three files remain intact. They are not part of the routine APK gate, and no production behavior was changed merely to satisfy those stale/brittle test assumptions. They can be reviewed manually or in a separate expanded regression session.

The Android step failed earlier than test execution. Gradle stopped in `:app:compileProdReleaseJavaWithJavac` because the generated registrant referenced:

```text
net.jonhanson.flutter_native_splash.FlutterNativeSplashPlugin
```

No Kotlin ABI test was run in that CI attempt.

## 2. Android compilation root cause and fix

`pubspec.yaml` declared `flutter_native_splash: ^2.4.2`, while `pubspec.lock` pinned version `2.4.4`. That release still exposes the legacy native Android plugin declaration which led Flutter to generate a registrant entry for `FlutterNativeSplashPlugin`. The current upstream stable release is **2.4.8**. Its changelog records removal of unnecessary native code, and upstream PR #828 describes the removal of plugin declarations.

- Upgraded the dev dependency to `flutter_native_splash: ^2.4.8`.
- Updated the lockfile package version and verified published SHA-256: `9db4b80b044e9af17cc4b1272137fc7ace0054d879ef8210a76adc34aaf4cdff`.
- Retained the `flutter_native_splash:` configuration in `pubspec.yaml` and all existing Android splash/launch resources.
- Did not manually edit generated `GeneratedPluginRegistrant.java`; the correct fix is to stop the obsolete plugin declaration entering Flutter's plugin metadata.

Upstream references: [2.4.8 changelog](https://pub.dev/packages/flutter_native_splash/changelog), [PR #828 — remove unnecessary native code and plugin declarations](https://github.com/jonbhanson/flutter_native_splash/pull/828), [2.4.8 package metadata](https://pub.dev/packages/flutter_native_splash/versions/2.4.8).

## 3. Smaller routine APK test gate

The normal APK workflow no longer discovers and runs all 259 Flutter test files or all 10 Android unit-test source files. It runs five files directly related to the current Manga/Mihon phase:

| Flutter file | Coverage retained in the APK gate |
|---|---|
| `test/manga/manga_repository_manager_test.dart` | First-use repository seed, add/edit/remove, `.pb` URL validation, normalization, duplicate and stale-update handling |
| `test/manga/phase55_manga_catalogue_test.dart` | All/JP/KR/CN categorization, metadata and shelf behavior |
| `test/manga/phase55_mihon_pb_index_test.dart` | Compressed Protobuf index decoding and malformed/truncated index rejection |
| `test/manga/phase56_manga_regression_test.dart` | Regional aggregation/deduplication, raw `repo.json` parsing, strict signer metadata and install eligibility |
| `test/manga/phase57_manga_home_parity_test.dart` | Preservation of all Manga/Manhwa/Manhua shelves after aggregation |

The Android gate runs only:

```text
com.m5ham3ds.raven23.mihon.MihonExtensionLoaderAbiTest
```

It contains three focused cases: Android's `1.6f` widened-to-Double representation canonicalizes to 1.6; exact supported versions 1.4 and 1.6 remain accepted; unsupported values, near misses and non-finite values remain rejected. Gradle still compiles the Android application sources before executing this selected test class, so it also catches main-source/registrant Java compile errors. The workflow requires a non-empty JUnit report with all three cases executed and zero failures/errors.

## 4. What was not removed

No test source files were deleted. The remaining **254 Flutter test files** and **nine Android unit-test source files** are still present and can be explicitly run by the owner after the APK is built/installed, or in a separate broad regression workflow. Laravel live smoke and write-enabled staging E2E test sources are also preserved, but are not pre-build APK gates; the E2E path continues to require a disposable staging backend and explicit write authorization. Existing PHASE52/53 retired-test decisions are unchanged.

The three full-suite test failures listed in section 1 are still in the repository, not marked as passed and not hidden by expectation changes. They are excluded from this routine APK gate because the owner requested manual/deeper checks after a successful build.

## 5. Strict sequential CI order

1. Resolve dependencies (`flutter pub get`).
2. Apply/check the 23-file scoped Dart formatter list.
3. Run `flutter analyze --no-fatal-infos` across the complete project.
4. Run the five focused Manga/Mihon Flutter test files.
5. Generate the Android Gradle Wrapper.
6. Run the selected Android `MihonExtensionLoaderAbiTest` class and validate JUnit XML.
7. Build the production APK for `arm64-v8a`.
8. Audit APK CRC, package ID, ABI directories and payload size.

Each validation step is conditional on all prior required steps succeeding. The APK audit is conditioned on APK build success. Diagnostic artifacts and the Markdown report continue to upload with `always()` so failures remain inspectable; diagnostic uploads are not test steps.

## 6. Manual device validation after the APK is available

- Install the APK and confirm a clean first launch and navigation.
- Install trusted Team X (`extensions-lib` 1.6) and another selected Mihon extension; confirm the signer check and source loading.
- Confirm invalid signer fingerprints/package IDs remain rejected and no install occurs without confirmation.
- Inspect Manga All, Japanese Manga, Manhwa and Manhua, their hero/banner and all shelves.
- Open a Manga title, load chapters and test the reader.
- Manually exercise any other selected Home, Search/Discover, movie/series/anime playback, TV, authentication and backend flows.

## 7. Validation limits and acceptance

Packaging-time checks confirm that the five selected test files and the Kotlin test class exist, the workflow YAML is syntactically valid, Bash blocks parse, embedded Python blocks compile, JSON/locale files parse and the ZIP archive is structurally valid. Flutter, Dart and Gradle were unavailable in the archive-editing environment. No claim is made that `flutter pub get`, the selected tests, the Release APK or physical-device installation succeeded locally.

Phase57.3 is accepted only after the next CI run passes dependency resolution, formatting, analysis, the five Flutter files, all three ABI test cases, ARM64 Release assembly and APK audit, followed by owner device verification.


## Superseding correction — CI run 42927816064

The proposed root `dev_dependencies` entry for `flutter_native_splash ^2.4.8` did not resolve with the pinned Flutter 3.35.7 SDK: `flutter_test` pins `meta 1.16.0`, while `flutter_native_splash 2.4.8` requires `meta ^1.18.0`. CI stopped at `flutter pub get`, so no later Phase57.3 checks ran.

Phase57.4/57.5 supersede the dependency-integration part of this document. `flutter_native_splash` is a static resource generator and is not imported by application Dart code. It has been removed from the app dependency graph; its configuration remains in `flutter_native_splash.yaml`, and no global activation script is shipped. Existing generated Android splash resources are retained. CI verifies the package is absent from both the lockfile and `.flutter-plugins-dependencies`, preventing the legacy Android plugin registration and `meta` conflict. Optional future regeneration is documented in Phase57.5 using a temporary compatible 2.4.7 dev dependency that must be removed before building. No Flutter SDK upgrade or dependency override is used.
