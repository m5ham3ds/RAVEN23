# RAVEN23 — Comprehensive CI Build Report

- **Overall job status:** `SUCCESS`
- **Build mode:** `RELEASE`
- **Started (UTC):** `2026-11-16T00:16:07Z`
- **Elapsed time until report generation:** `00:18:33`
- **Finished (UTC):** `2026-11-16T00:34:40Z`
- **Workflow:** `RAVEN23 Local Android APK Build`
- **Actor:** `m5ham3ds`
- **Workflow run:** [Open GitHub Actions run](https://github.com/m5ham3ds/RAVEN23/actions/runs/43779340866)
- **Run ID / attempt:** `43779340866` / `1`
- **Trigger:** `push`
- **Repository:** `m5ham3ds/RAVEN23`
- **Ref:** `refs/heads/main`
- **Commit:** `b561bd368656c8c10c8c7a1bfbde0bb0dc4dddd9`

## 1. Execution summary

- Steps marked failed: **0**
- Steps skipped/not reached: **0**
- Steps cancelled: **0**
- APK present: **Yes — 47,533,758 bytes (45.33 MiB)**

### Failed steps

- None reported by step outcomes.

### Skipped steps (not configured or not reached after a prerequisite failure)

- None.

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
| Flutter analyze | `success` |
| Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests | `success` |
| Generate Android Gradle Wrapper after required checks | `success` |
| Focused Mihon ABI Android unit test (1 class) | `success` |
| Build APK | `success` |
| APK size/ABI audit | `success` |
| Upload APK artifact | `success` |
| Upload focused pre-build test diagnostics | `success` |
| Upload formatter patch | `success` |

## 3. Runner and toolchain

```text
UTC capture time: 2026-11-16T00:17:58Z
Runner: Linux / X64
Kernel: Linux runnervmccnms 7.0.0-1019-azure #20-Ubuntu SMP PREEMPT Mon Oct 19 22:41:16 UTC 2026 x86_64 GNU/Linux
Repository: m5ham3ds/RAVEN23
Ref: refs/heads/main
Commit: b561bd368656c8c10c8c7a1bfbde0bb0dc4dddd9

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
Run ID: 43779340866
Run attempt: 1
Event: push
Actor: m5ham3ds
Repository: m5ham3ds/RAVEN23
Ref: refs/heads/main
Commit: b561bd368656c8c10c8c7a1bfbde0bb0dc4dddd9
Build mode: release
```

## 4. Commands and build switches

- Dependency resolution: `flutter pub get`.
- Formatting: scoped Manga/Home/Anime/Mihon, PHASE63 work-detail/reader/translation and source-priority Dart targets via `bash tool/format_phase57_dart.sh --fix` / `--check` (146 files).
- Static analysis: `flutter analyze --no-fatal-infos`; it starts only after dependency resolution and formatting succeed.
- Required pre-build tests: eighteen focused Manga/Home/Anime/Mihon/mobile-navigation/reader/source-priority Flutter test files, including PHASE62 Manga details/reader-source persistence tests, and one Android `MihonExtensionLoaderAbiTest` class (three ABI boundary cases). Other Flutter and Android test sources remain preserved for owner-led manual/deeper regression; they are not all part of the routine APK gate. Dedicated PHASE52/53 test files remain retired after owner-confirmed acceptance.
- Live Laravel smoke/E2E tests are not pre-build gates; their source files are preserved for explicit manual/staging validation after APK creation. The write-enabled E2E test still requires a disposable staging backend and explicit write consent.
- Wrapper generation: `gradle wrapper --gradle-version 8.14 --distribution-type all`.
- APK build: `flutter build apk --${BUILD_MODE} --flavor prod --target lib/main.dart --target-platform android-arm64 -Pdisable-abi-filtering=true --dart-define=ENABLE_FIREBASE=false --dart-define=LOCAL_DEV_MODE=true`.
- APK audit: inspect archive CRC/listing, native ABI directories, package name and payload sizes.

### Routine pre-build test gate

```text

    Routine pre-build Flutter gate runs exactly these eighteen files:

    test/manga/anilist_catalogue_cache_test.dart
    --covers: AniList persistent catalogue cache, fresh/stale retention, clear and restart/offline reads
    test/data/tmdb_network_test.dart
    --covers: TMDB stale cache fallback and background revalidation across offline/restart scenarios
    test/video_providers/source_priority_manager_test.dart
    --covers: unlimited primary/backup priority lists, uniqueness, legacy migration, reorder and repository cleanup
    test/manga/manga_repository_manager_test.dart
    --covers: first-use seed, add/edit/remove, HTTP(S) .pb validation,
              fragment normalization, duplicate prevention and stale updates
    test/manga/manga_reader_crop_test.dart
    --covers: flat scan-margin detection, untouched artwork and invalid input safety
    test/manga/mihon_source_browser_screen_test.dart
    --covers: unified available/installed extension directory, screenshot-matched row actions, orphaned installed sources and removal support
    test/manga/mihon_default_extension_installer_test.dart
    --covers: exact ten-name selection, pinned Keiyoushi signing fingerprint, Arabic package preference and strict name normalization
    test/manga/phase55_manga_catalogue_test.dart
    --covers: All/JP/KR/CN filters, title metadata and catalogue shelves
    test/manga/phase55_mihon_pb_index_test.dart
    test/manga/phase56_manga_regression_test.dart
    --covers: gzip Protobuf decoding, extension mapping, raw repo.json parsing, strict signer trust and install eligibility
    test/manga/phase57_manga_home_parity_test.dart
    --covers: every Manga/Manhwa/Manhua catalogue shelf survives aggregation
    test/manga_detail_metadata_test.dart
    --covers: AniList detail metadata, characters/staff, relations, tags and optional-field fallbacks
    test/manga_reading_store_test.dart
    --covers: source pins, chapter progress, reading status and per-work reader preferences
    test/manga_source_matcher_test.dart
    --covers: strict whole-title matching, aliases and chapter-number parsing
    test/mobile/mobile_nav_bar_test.dart
    --covers: Phosphor destination icons, blank menu-caption alignment, simultaneous Home/secondary selection and shared press feedback
    test/anime_media_classification_test.dart
    --covers: Japanese animation is Anime; non-Japanese Animation and Japanese live action are not
    test/home_catalog_test.dart
    --covers: Anime and Series Continue Watching remain isolated
    test/home_screen_test.dart
    --covers: Progressive Home/Movies/Series/Anime first paint, partial offline cache, empty/error states, Manga All aggregation and shared rows

    Android gate: `:app:testProdReleaseUnitTest --tests com.m5ham3ds.raven23.mihon.MihonExtensionLoaderAbiTest`
    --covers: Float widening (1.6f), exact supported versions (1.4/1.6), and unsupported/non-finite values

    All other test sources remain in the repository for manual/deeper regression; CI does not delete or disable them.
    
```

## 5. Warnings, errors and diagnostics

Counts below are extracted from the command logs captured by this workflow. Setup/action internals are represented by their step outcome; open the workflow run for the action-owned console output.

| Log | Warning occurrences (unique messages) | Notices | Analyzer info | Error/failure markers |
|---|---:|---:|---:|---:|
| Dependency resolution | 0 (0 unique) | 0 | 0 | 0 |
| Scoped Manga/Home/Anime/Mihon Dart formatting | 0 (0 unique) | 0 | 0 | 0 |
| Formatter patch capture | 0 (0 unique) | 0 | 0 | 0 |
| Flutter analyze | 2 (2 unique) | 0 | 40 | 0 |
| Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests | 2755 (77 unique) | 1 | 0 | 0 |
| Gradle wrapper generation | 4 (4 unique) | 0 | 0 | 0 |
| Focused Mihon ABI Android unit test | 44 (43 unique) | 0 | 0 | 0 |
| Android APK build | 0 (0 unique) | 0 | 0 | 2 |
| APK size and ABI audit | 0 (0 unique) | 0 | 0 | 0 |

### Warning and deprecation excerpts

- **Flutter analyze:** `info • 'translate' is deprecated and shouldn't be used. Use translateByVector3, translateByVector4, or translateByDouble instead • lib/manga/ui/manga_reader_screen.dart:2496:9 • deprecated_member_use`
- **Flutter analyze:** `info • 'scale' is deprecated and shouldn't be used. Use scaleByVector3, scaleByVector4, or scaleByDouble instead • lib/manga/ui/manga_reader_screen.dart:2497:9 • deprecated_member_use`
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [tv_continue_movie] not found[0m` _(repeated 71 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [all] not found[0m` _(repeated 21 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_type_manga] not found[0m` _(repeated 31 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_type_manhwa] not found[0m` _(repeated 35 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_type_manhua] not found[0m` _(repeated 31 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m` _(repeated 146 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [search] not found[0m` _(repeated 146 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga] not found[0m` _(repeated 25 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_read_action] not found[0m` _(repeated 7 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_install_sources] not found[0m` _(repeated 7 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_top_10] not found[0m` _(repeated 18 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_recently_released] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [trending] not found[0m` _(repeated 18 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [popular] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [top_rated] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_upcoming] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_completed] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [action] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [adventure] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [comedy] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [drama] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [fantasy] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [horror] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [mystery] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [romance] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [sci_fi] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [supernatural] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [slice_of_life] not found[0m` _(repeated 8 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m` _(repeated 417 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [see_all] not found[0m` _(repeated 189 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [manga_catalogue_empty] not found[0m`
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [something_went_wrong] not found[0m` _(repeated 14 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [retry] not found[0m` _(repeated 14 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [streaming_services] not found[0m` _(repeated 40 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [continue_watching] not found[0m` _(repeated 31 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [top_10_movies_today] not found[0m` _(repeated 31 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [top_10_series_today] not found[0m` _(repeated 32 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [trending_movies_week] not found[0m` _(repeated 31 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [trending_series_week] not found[0m` _(repeated 32 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [trending_anime] not found[0m` _(repeated 28 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [my_list] not found[0m` _(repeated 43 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [new_movies] not found[0m` _(repeated 31 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [new_episodes_series] not found[0m` _(repeated 32 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [new_episodes_anime] not found[0m` _(repeated 28 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [popular_movies] not found[0m` _(repeated 31 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [popular_series] not found[0m` _(repeated 32 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [popular_anime] not found[0m` _(repeated 28 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [popular_series_on] not found[0m` _(repeated 32 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [top_rated_movies] not found[0m` _(repeated 31 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [top_rated_series] not found[0m` _(repeated 32 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [top_rated_anime] not found[0m` _(repeated 28 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [upcoming_movies] not found[0m` _(repeated 31 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [top_10_anime] not found[0m`
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [popular_movies_on] not found[0m` _(repeated 3 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [filter_all] not found[0m` _(repeated 63 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [movies] not found[0m` _(repeated 63 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [series] not found[0m` _(repeated 64 times)_
- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [live_tv] not found[0m` _(repeated 63 times)_
- _66 additional unique warning messages are retained in the raw log artifacts._

### Notices

- **Focused Manga/Home/Anime/Mihon/mobile-navigation/reader Flutter pre-build tests:** `00:23 +108: /home/runner/work/RAVEN23/RAVEN23/test/home_screen_test.dart: update notice stays below filters and above the hero`

### Error and failure excerpts

- **Android APK build:** `Caught exception: Already watching path: /home/runner/work/RAVEN23/RAVEN23/android`
- **Android APK build:** `Info: Class com.google.firebase.auth.AuthKt has malformed kotlin.Metadata: java.lang.IllegalArgumentException: Provided Metadata instance has version 2.3.0, while maximum supported version is 2.2.0. To support newer versions, update the kotlin-metadata-jvm library.`

### Focused Flutter pre-build test summary

Focused Flutter pre-build test files: 18
- `00:29 +144: All tests passed!`

#### Last 100 lines of focused Flutter test log

```text
[34m[🌎 Easy Localization] [WARNING] Localization key [my_list] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [next_episode] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [more_options] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [see_all] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [search] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [see_all] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series_one] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series_one] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series_one] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [see_all] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [see_all] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series_one] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series_one] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [next_episode] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [episodes] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [remove_from_row] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [play_episode] not found[0m
00:29 +143: /home/runner/work/RAVEN23/RAVEN23/test/home_screen_test.dart: targets are 48 dp and labelled
[34m[🌎 Easy Localization] [WARNING] Localization key [tv_continue_movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [tv_untitled_movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [filter_all] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movies] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [live_tv] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [categories] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [search] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [tv_continue_movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [tv_untitled_movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [continue_watching] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [top_10_movies_today] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [top_10_series_today] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [trending_movies_week] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [trending_series_week] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [trending_anime] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [my_list] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [new_movies] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [new_episodes_series] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [new_episodes_anime] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [popular_movies] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [popular_series] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [popular_anime] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [popular_series_on] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [streaming_services] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [top_rated_movies] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [top_rated_series] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [top_rated_anime] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [upcoming_movies] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [filter_all] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movies] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [live_tv] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [categories] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [search] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [search] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [continue_watching] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [resume_title] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [my_list] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [time_left] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [more_options] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [see_all] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [movie] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [see_all] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series_one] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series_one] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [series_one] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [details] not found[0m
00:29 +144: All tests passed!

Focused Flutter pre-build tests exit code: 0
```

### Android unit-test summary

Selected Android test class: com.m5ham3ds.raven23.mihon.MihonExtensionLoaderAbiTest
- `BUILD SUCCESSFUL in 4m 38s`
- `Executed Mihon ABI cases: 3; failures: 0; errors: 0; skipped: 0`

#### Focused ABI case evidence

- `MihonExtensionLoaderAbiTest > androidFloatRepresentationOfSixteenIsAcceptedAndCanonicalized PASSED`
- `MihonExtensionLoaderAbiTest > exactSupportedVersionsRemainAccepted PASSED`
- `MihonExtensionLoaderAbiTest > unsupportedVersionsAndNonFiniteValuesRemainRejected PASSED`

#### Android JUnit report discovery

- `build/app/test-results/testProdReleaseUnitTest/TEST-com.m5ham3ds.raven23.mihon.MihonExtensionLoaderAbiTest.xml`

## 6. APK size and ABI report

# APK size and ABI audit

- Artifact: `RAVEN23-apk.apk`
- Build mode: **RELEASE**
- APK size: **45.33 MiB** (47,533,758 bytes)
- Native ABIs found: **arm64-v8a**
- Required native ABIs: **arm64-v8a only**
- Build target: `android-arm64` (single APK; no split-per-ABI)

## Native library payload by ABI

| ABI | .so files | Compressed in APK | Uncompressed |
|---|---:|---:|---:|
| `arm64-v8a` | 6 | 18.93 MiB | 44.52 MiB |

## Payload by category

| Category | Compressed in APK | Uncompressed |
|---|---:|---:|
| Native libraries (arm64-v8a) | 18.93 MiB | 44.52 MiB |
| DEX bytecode | 14.82 MiB | 39.87 MiB |
| Flutter/assets | 6.18 MiB | 7.30 MiB |
| Android resources | 4.95 MiB | 5.95 MiB |
| Other | 0.03 MiB | 0.11 MiB |
| META-INF | 0.02 MiB | 0.05 MiB |

## Largest native libraries

| ABI | Library | Compressed | Uncompressed |
|---|---|---:|---:|
| `arm64-v8a` | `libapp.so` | 6.85 MiB | 16.69 MiB |
| `arm64-v8a` | `libtranslate_jni.so` | 6.47 MiB | 15.60 MiB |
| `arm64-v8a` | `libflutter.so` | 4.93 MiB | 10.53 MiB |
| `arm64-v8a` | `libfastdev_quickjs_runtime.so` | 0.41 MiB | 1.00 MiB |
| `arm64-v8a` | `libzstd-kmp.so` | 0.26 MiB | 0.70 MiB |
| `arm64-v8a` | `libdatastore_shared_counter.so` | 0.00 MiB | 0.01 MiB |

## Largest APK entries

| Entry | Compressed | Uncompressed |
|---|---:|---:|
| `lib/arm64-v8a/libapp.so` | 6.85 MiB | 16.69 MiB |
| `lib/arm64-v8a/libtranslate_jni.so` | 6.47 MiB | 15.60 MiB |
| `lib/arm64-v8a/libflutter.so` | 4.93 MiB | 10.53 MiB |
| `classes4.dex` | 3.45 MiB | 8.67 MiB |
| `classes.dex` | 3.11 MiB | 8.58 MiB |
| `classes6.dex` | 3.04 MiB | 8.34 MiB |
| `classes5.dex` | 2.92 MiB | 7.84 MiB |
| `classes7.dex` | 2.19 MiB | 6.18 MiB |
| `resources.arsc` | 2.22 MiB | 2.22 MiB |
| `lib/arm64-v8a/libfastdev_quickjs_runtime.so` | 0.41 MiB | 1.00 MiB |
| `assets/flutter_assets/assets/images/logo.png` | 0.86 MiB | 0.86 MiB |
| `assets/flutter_assets/assets/images/splash_logo.png` | 0.86 MiB | 0.86 MiB |
| `assets/flutter_assets/assets/images/grid_final.jpg` | 0.78 MiB | 0.78 MiB |
| `lib/arm64-v8a/libzstd-kmp.so` | 0.26 MiB | 0.70 MiB |
| `assets/flutter_assets/assets/images/warner_bros.png` | 0.28 MiB | 0.28 MiB |
| `assets/flutter_assets/assets/images/404.png` | 0.28 MiB | 0.28 MiB |
| `assets/flutter_assets/assets/images/series.png` | 0.28 MiB | 0.28 MiB |
| `classes3.dex` | 0.11 MiB | 0.26 MiB |
| `assets/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf` | 0.11 MiB | 0.25 MiB |
| `assets/flutter_assets/assets/images/sample_frame.jpg` | 0.23 MiB | 0.23 MiB |
| `assets/flutter_assets/assets/translations/hi.json` | 0.04 MiB | 0.22 MiB |
| `res/3o1.png` | 0.21 MiB | 0.21 MiB |
| `res/5l.png` | 0.21 MiB | 0.21 MiB |
| `res/AE.png` | 0.21 MiB | 0.21 MiB |
| `assets/flutter_assets/assets/translations/ar.json` | 0.04 MiB | 0.17 MiB |

## 7. Generated diagnostic artifacts

- `build-artifacts/aapt-badging.txt` — 7,363 bytes
- `build-artifacts/android-apk-build.log` — 3,798 bytes
- `build-artifacts/android-mihon-abi-test.log` — 67,413 bytes
- `build-artifacts/apk-audit.log` — 10,181 bytes
- `build-artifacts/ci-context.txt` — 224 bytes
- `build-artifacts/ci-environment.txt` — 2,431 bytes
- `build-artifacts/ci-started-at.txt` — 21 bytes
- `build-artifacts/dart-format-summary.txt` — 41 bytes
- `build-artifacts/dart-format.patch` — 0 bytes
- `build-artifacts/dependency-resolution.log` — 7,728 bytes
- `build-artifacts/flutter-analyze.log` — 6,531 bytes
- `build-artifacts/flutter-prebuild-tests.log` — 255,028 bytes
- `build-artifacts/format-patch.log` — 31 bytes
- `build-artifacts/gradle-wrapper.log` — 1,898 bytes
- `build-artifacts/phase57-dart-format.log` — 166 bytes
- `build-artifacts/RAVEN23-build-report.md` and root `RAVEN23-build-report.md` — this generated report.

## 8. Interpretation notes

- A step marked `skipped` was not executed; this includes later build stages blocked by a prerequisite failure and must not be interpreted as a pass.
- The routine APK gate intentionally runs eighteen focused Manga/Home/Anime/Mihon/mobile-navigation/reader/source-priority Flutter files and the three-case Android Mihon ABI class. The full Flutter and Android test inventories remain untouched in the source tree for manual/deeper regression after the owner installs the APK. Laravel live tests are also retained for explicit staging validation and are not pre-build gates.
- Setup actions (checkout/tool installers/cache) expose their detailed output in the linked GitHub Actions run; their success/failure outcome is recorded above.
- This report describes this individual run only. It does not mark a RAVEN23 phase accepted unless all required CI and runtime acceptance gates pass.

---
_Generated automatically by `.github/workflows/android-ci.yml` at 2026-11-16T00:34:40Z._
