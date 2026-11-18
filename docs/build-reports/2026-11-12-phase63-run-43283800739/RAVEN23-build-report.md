# RAVEN23 — Comprehensive CI Build Report

- **Overall job status:** `FAILURE`
- **Build mode:** `RELEASE`
- **Started (UTC):** `2026-11-12T18:49:27Z`
- **Elapsed time until report generation:** `00:02:33`
- **Finished (UTC):** `2026-11-12T18:52:00Z`
- **Workflow:** `RAVEN23 Local Android APK Build`
- **Actor:** `m5ham3ds`
- **Workflow run:** [Open GitHub Actions run](https://github.com/m5ham3ds/RAVEN23/actions/runs/43283800739)
- **Run ID / attempt:** `43283800739` / `1`
- **Trigger:** `push`
- **Repository:** `m5ham3ds/RAVEN23`
- **Ref:** `refs/heads/main`
- **Commit:** `5115fe26b4c82e843295c0b7b7352d62afa84888`

## 1. Execution summary

- Steps marked failed: **1**
- Steps skipped/not reached: **5**
- Steps cancelled: **0**
- APK present: **No**

### Failed steps

- `Flutter analyze`

### Skipped steps (not configured or not reached after a prerequisite failure)

- `Focused Manga/Home/Anime/Mihon Flutter pre-build tests (8 files)`
- `Generate Android Gradle Wrapper after required checks`
- `Focused Mihon ABI Android unit test (1 class)`
- `Build APK`
- `APK size/ABI audit`

### Cancelled steps

- None.

## 2. Step-by-step result

| Stage | Result |
|---|---|
| Capture workflow start time | `success` |
| Checkout | `success` |
| Initialize diagnostics | `success` |
| Set up Java 17 | `success` |
| Set up Gradle 8.14 | `success` |
| Restore CI signing key cache | `success` |
| Ensure CI signing key exists | `success` |
| Set up Flutter 3.35.7 | `success` |
| Set up Android SDK | `success` |
| Resolve Flutter dependencies | `success` |
| Scoped Manga/Home/Anime Dart format fix + strict check | `success` |
| Capture formatter patch | `success` |
| Capture environment details | `success` |
| Flutter analyze | `failure` |
| Focused Manga/Home/Anime/Mihon Flutter pre-build tests (8 files) | `skipped` |
| Generate Android Gradle Wrapper after required checks | `skipped` |
| Focused Mihon ABI Android unit test (1 class) | `skipped` |
| Build APK | `skipped` |
| APK size/ABI audit | `skipped` |
| Upload APK artifact | `success` |
| Upload focused pre-build test diagnostics | `success` |
| Upload formatter patch | `success` |

## 3. Runner and toolchain

```text
UTC capture time: 2026-11-12T18:51:16Z
Runner: Linux / X64
Kernel: Linux runnervmwuk1x 7.0.0-1019-azure #20-Ubuntu SMP PREEMPT Mon Oct 19 22:41:16 UTC 2026 x86_64 GNU/Linux
Repository: m5ham3ds/RAVEN23
Ref: refs/heads/main
Commit: 5115fe26b4c82e843295c0b7b7352d62afa84888

### flutter
Flutter 3.35.7 • channel stable • https://github.com/flutter/flutter.git
Framework • revision adc9010625 (1 year, 1 month ago) • 2025-10-21 14:16:03 -0400
Engine • hash 6b24e1b529bc46df7ff397667502719a2a8b6b72 (revision 035316565a) (12 months ago) • 2025-10-21 14:28:01.000Z
Tools • Dart 3.9.2 • DevTools 2.48.0

### dart
Dart SDK version: 3.9.2 (stable) (Wed Aug 27 03:49:40 2025 -0700) on "linux_x64"

### java
openjdk version "17.0.21" 2026-10-20
OpenJDK Runtime Environment Temurin-17.0.21+9 (build 17.0.21+9)
OpenJDK 64-Bit Server VM Temurin-17.0.21+9 (build 17.0.21+9, mixed mode, sharing)

### gradle

Welcome to Gradle 8.14!

Here are the highlights of this release:
 - Java 24 support
 - GraalVM Native Image toolchain selection
 - Enhancements to test reporting
 - Build Authoring improvements

For more details see https://docs.gradle.org/8.14/release-notes.html


------------------------------------------------------------
Gradle 8.14
------------------------------------------------------------

Build time:    2025-04-25 09:29:08 UTC
Revision:      34c560e3be961658a6fbcd7170ec2443a228b109

Kotlin:        2.0.21
Groovy:        3.0.24
Ant:           Apache Ant(TM) version 1.10.15 compiled on August 25 2024
Launcher JVM:  17.0.21 (Eclipse Adoptium 17.0.21+9)
Daemon JVM:    /usr/lib/jvm/temurin-17-jdk-amd64 (no JDK specified, using current Java home)
OS:            Linux 7.0.0-1019-azure amd64


### sdkmanager
WARNING: The SDK Manager CLI tool (sdkmanager) is deprecated. Use Android CLI instead.
The 'android' binary can also be found in the cmdline-tools directory, and 'android sdk' is the replacement for 'sdkmanager'.
To learn more about the Android CLI and how to use it, see the documentation (https://d.android.com/tools/agents/android-cli)

22.0


### adb
Android Debug Bridge version 1.0.41
Version 37.0.1-15733141
Installed as /usr/local/lib/android/sdk/platform-tools/adb
Running on Linux 7.0.0-1019-azure (x86_64)

### python3
Python 3.14.4

ANDROID_HOME: /usr/local/lib/android/sdk
ANDROID_SDK_ROOT: /usr/local/lib/android/sdk
FLUTTER_ROOT: /opt/hostedtoolcache/flutter/stable-3.35.7-x64/flutter
```

### Build configuration

- Flutter: `3.35.7` (stable channel); Dart is the SDK bundled with this Flutter version.
- Java: `17` (Temurin).
- Gradle: `8.14` (compatible with AGP 8.11.1; generated Android Wrapper matches the checked-in distribution URL).
- Android SDK: `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`, `ndk;28.2.13676358`.
- Flavor: `prod`; target: `lib/main.dart`.
- ABI target: `android-arm64` (expected APK ABI: `arm64-v8a` only).
- Build defines: `ENABLE_FIREBASE=false`, `LOCAL_DEV_MODE=true`.
- Expected application ID: `com.m5ham3ds.raven23`.

### Run context

```text
Workflow: RAVEN23 Local Android APK Build
Run ID: 43283800739
Run attempt: 1
Event: push
Actor: m5ham3ds
Repository: m5ham3ds/RAVEN23
Ref: refs/heads/main
Commit: 5115fe26b4c82e843295c0b7b7352d62afa84888
Build mode: release
```

## 4. Commands and build switches

- Dependency resolution: `flutter pub get`.
- Formatting: scoped Manga/Home/Anime and PHASE63 work-detail/reader/translation Dart targets via `bash tool/format_phase57_dart.sh --fix` / `--check` (50 files).
- Static analysis: `flutter analyze --no-fatal-infos`; it starts only after dependency resolution and formatting succeed.
- Required pre-build tests: eleven focused Manga/Home/Anime/Mihon Flutter test files, including PHASE62 Manga details/reader-source persistence tests, and one Android `MihonExtensionLoaderAbiTest` class (three ABI boundary cases). Other Flutter and Android test sources remain preserved for owner-led manual/deeper regression; they are not all part of the routine APK gate. Dedicated PHASE52/53 test files remain retired after owner-confirmed acceptance.
- Live Laravel smoke/E2E tests are not pre-build gates; their source files are preserved for explicit manual/staging validation after APK creation. The write-enabled E2E test still requires a disposable staging backend and explicit write consent.
- Wrapper generation: `gradle wrapper --gradle-version 8.14 --distribution-type all`.
- APK build: `flutter build apk --${BUILD_MODE} --flavor prod --target lib/main.dart --target-platform android-arm64 -Pdisable-abi-filtering=true --dart-define=ENABLE_FIREBASE=false --dart-define=LOCAL_DEV_MODE=true`.
- APK audit: inspect archive CRC/listing, native ABI directories, package name and payload sizes.

### Routine pre-build test gate

```text

    Routine pre-build Flutter gate runs exactly these eight files:

    test/manga/manga_repository_manager_test.dart
    --covers: first-use seed, add/edit/remove, HTTP(S) .pb validation,
              fragment normalization, duplicate prevention and stale updates
    test/manga/phase55_manga_catalogue_test.dart
    --covers: All/JP/KR/CN filters, title metadata and catalogue shelves
    test/manga/phase55_mihon_pb_index_test.dart
    test/manga/phase56_manga_regression_test.dart
    --covers: gzip Protobuf decoding, extension mapping, raw repo.json parsing, strict signer trust and install eligibility
    test/manga/phase57_manga_home_parity_test.dart
    --covers: every Manga/Manhwa/Manhua catalogue shelf survives aggregation
    test/anime_media_classification_test.dart
    --covers: Japanese animation is Anime; non-Japanese Animation and Japanese live action are not
    test/home_catalog_test.dart
    --covers: Anime and Series Continue Watching remain isolated
    test/home_screen_test.dart
    --covers: Anime feed uses Home rows; Anime stays out of Series; Manga All aggregation, Skeleton and See All behavior

    Android gate: `:app:testProdReleaseUnitTest --tests com.m5ham3ds.raven23.mihon.MihonExtensionLoaderAbiTest`
    --covers: Float widening (1.6f), exact supported versions (1.4/1.6), and unsupported/non-finite values

    All other test sources remain in the repository for manual/deeper regression; CI does not delete or disable them.
    
```

## 5. Warnings, errors and diagnostics

Counts below are extracted from the command logs captured by this workflow. Setup/action internals are represented by their step outcome; open the workflow run for the action-owned console output.

| Log | Warning occurrences (unique messages) | Notices | Analyzer info | Error/failure markers |
|---|---:|---:|---:|---:|
| Dependency resolution | 0 (0 unique) | 0 | 0 | 0 |
| Scoped Manga/Home/Anime Dart formatting | 0 (0 unique) | 0 | 0 | 0 |
| Formatter patch capture | 0 (0 unique) | 0 | 0 | 0 |
| Flutter analyze | 2 (2 unique) | 0 | 30 | 2 |

### Warning and deprecation excerpts

- **Flutter analyze:** `info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre • lib/manga/ui/manga_reader_screen.dart:991:29 • deprecated_member_use`
- **Flutter analyze:** `info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre • lib/manga/ui/manga_reader_screen.dart:1018:29 • deprecated_member_use`

### Notices

- No notice markers found in captured command logs.

### Error and failure excerpts

- **Flutter analyze:** `error • The getter 'caption' isn't defined for the type 'AppType' • lib/manga/ui/manga_reader_screen.dart:554:36 • undefined_getter`
- **Flutter analyze:** `error • The getter 'caption' isn't defined for the type 'AppType' • lib/manga/ui/manga_reader_screen.dart:1044:44 • undefined_getter`

## 6. APK size and ABI report

APK audit did not produce `apk-size-report.md`; inspect the APK audit step outcome and log.

## 7. Generated diagnostic artifacts

- `build-artifacts/ci-context.txt` — 224 bytes
- `build-artifacts/ci-environment.txt` — 2,431 bytes
- `build-artifacts/ci-started-at.txt` — 21 bytes
- `build-artifacts/dart-format-summary.txt` — 822 bytes
- `build-artifacts/dart-format.patch` — 151,014 bytes
- `build-artifacts/dependency-resolution.log` — 7,728 bytes
- `build-artifacts/flutter-analyze.log` — 5,476 bytes
- `build-artifacts/format-patch.log` — 601 bytes
- `build-artifacts/phase57-dart-format.log` — 808 bytes
- `build-artifacts/RAVEN23-build-report.md` and root `RAVEN23-build-report.md` — this generated report.

## 8. Interpretation notes

- A step marked `skipped` was not executed; this includes later build stages blocked by a prerequisite failure and must not be interpreted as a pass.
- The routine APK gate intentionally runs eleven focused Manga/Home/Anime/Mihon Flutter files and the three-case Android Mihon ABI class. The full Flutter and Android test inventories remain untouched in the source tree for manual/deeper regression after the owner installs the APK. Laravel live tests are also retained for explicit staging validation and are not pre-build gates.
- Setup actions (checkout/tool installers/cache) expose their detailed output in the linked GitHub Actions run; their success/failure outcome is recorded above.
- This report describes this individual run only. It does not mark a RAVEN23 phase accepted unless all required CI and runtime acceptance gates pass.

---
_Generated automatically by `.github/workflows/android-ci.yml` at 2026-11-12T18:52:00Z._
