# RAVEN23 — Comprehensive CI Build Report

- **Overall job status:** `FAILURE`
- **Build mode:** `RELEASE`
- **Started (UTC):** `2026-11-08T15:53:15Z`
- **Elapsed time until report generation:** `00:02:21`
- **Finished (UTC):** `2026-11-08T15:55:36Z`
- **Workflow:** `RAVEN23 Local Android APK Build`
- **Actor:** `m5ham3ds`
- **Workflow run:** [Open GitHub Actions run](https://github.com/m5ham3ds/RAVEN23/actions/runs/42497050504)
- **Run ID / attempt:** `42497050504` / `1`
- **Trigger:** `push`
- **Repository:** `m5ham3ds/RAVEN23`
- **Ref:** `refs/heads/main`
- **Commit:** `d7aad358400fb3a93742ac534ace9c81100b38cb`

## 1. Execution summary

- Steps marked failed: **1**
- Steps skipped/not reached: **3**
- Steps cancelled: **0**
- APK present: **No**

### Failed steps

- `Phase 36–50 contracts and Phase51 integration regression tests`

### Skipped steps (not reached after an earlier failure)

- `Generate Android Gradle Wrapper`
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
| Set up Gradle 8.7 | `success` |
| Restore CI signing key cache | `success` |
| Ensure CI signing key exists | `success` |
| Set up Flutter 3.35.7 | `success` |
| Set up Android SDK | `success` |
| Resolve Flutter dependencies | `success` |
| Dart format fix + strict check | `success` |
| Capture formatter patch | `success` |
| Capture environment details | `success` |
| Flutter analyze | `success` |
| Phase 36–50 contracts and Phase51 integration regression tests | `failure` |
| Generate Android Gradle Wrapper | `skipped` |
| Build APK | `skipped` |
| APK size/ABI audit | `skipped` |
| Upload APK artifact | `success` |
| Upload required source-contract test log | `success` |
| Upload formatter patch | `success` |

## 3. Runner and toolchain

```text
UTC capture time: 2026-11-08T15:54:37Z
Runner: Linux / X64
Kernel: Linux runnervmwuk1x 7.0.0-1019-azure #20-Ubuntu SMP PREEMPT Mon Oct 19 22:41:16 UTC 2026 x86_64 GNU/Linux
Repository: m5ham3ds/RAVEN23
Ref: refs/heads/main
Commit: d7aad358400fb3a93742ac534ace9c81100b38cb

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

Welcome to Gradle 8.7!

Here are the highlights of this release:
 - Compiling and testing with Java 22
 - Cacheable Groovy script compilation
 - New methods in lazy collection properties

For more details see https://docs.gradle.org/8.7/release-notes.html


------------------------------------------------------------
Gradle 8.7
------------------------------------------------------------

Build time:   2024-03-22 15:52:46 UTC
Revision:     650af14d7653aa949fce5e886e685efc9cf97c10

Kotlin:       1.9.22
Groovy:       3.0.17
Ant:          Apache Ant(TM) version 1.10.13 compiled on January 4 2023
JVM:          17.0.21 (Eclipse Adoptium 17.0.21+9)
OS:           Linux 7.0.0-1019-azure amd64


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
- Gradle: `8.7` (global CI Gradle and generated Android Wrapper).
- Android SDK: `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`, `ndk;28.2.13676358`.
- Flavor: `prod`; target: `lib/main.dart`.
- ABI target: `android-arm64` (expected APK ABI: `arm64-v8a` only).
- Build defines: `ENABLE_FIREBASE=false`, `LOCAL_DEV_MODE=true`.
- Expected application ID: `com.m5ham3ds.raven23`.

### Run context

```text
Workflow: RAVEN23 Local Android APK Build
Run ID: 42497050504
Run attempt: 1
Event: push
Actor: m5ham3ds
Repository: m5ham3ds/RAVEN23
Ref: refs/heads/main
Commit: d7aad358400fb3a93742ac534ace9c81100b38cb
Build mode: release
```

## 4. Commands and build switches

- Dependency resolution: `flutter pub get`.
- Formatting: `bash tool/format_phase37_50_dart.sh --fix` followed by `--check` (maintained format target list includes Phase 44–50 changes).
- Static analysis: `flutter analyze`.
- Required automated tests: the exact Phase 37–50 contract set listed below. No unrelated widget regression batch or full Flutter suite runs in the APK build workflow.
- Wrapper generation: `gradle wrapper --gradle-version 8.7 --distribution-type all`.
- APK build: `flutter build apk --${BUILD_MODE} --flavor prod --target lib/main.dart --target-platform android-arm64 -Pdisable-abi-filtering=true --dart-define=ENABLE_FIREBASE=false --dart-define=LOCAL_DEV_MODE=true`.
- APK audit: inspect archive CRC/listing, native ABI directories, package name and payload sizes.

### Required Phase 37/38/39/40/41/42/43/44/45/46/47/48/49/50 contract test files (29 explicit files)

```text
test/video_providers/source_contracts_test.dart
test/video_providers/source_engine_contract_test.dart
test/video_providers/source_repository_manager_test.dart
test/video_providers/unified/quickjs_source_engine_test.dart
test/video_providers/source_repository_parser_test.dart
test/video_providers/source_repository_client_test.dart
test/video_providers/stremio_addon_provider_test.dart
test/video_providers/source_repository_revision_test.dart
test/video_providers/source_host_policy_test.dart
test/video_providers/quickjs_bridge_security_test.dart
test/video_providers/vidking_direct_provider_test.dart
test/video_providers/vidking_audio_quality_normalizer_test.dart
test/settings_vidking_audio_language_test.dart
test/video_providers/unified/episode_identity_normalizer_test.dart
test/video_providers/unified_source_service_stremio_identity_test.dart
test/video_providers/quickjs_extension_settings_test.dart
test/video_providers/phase44_quickjs_catalog_test.dart
test/video_providers/unified_source_service_execution_test.dart
test/video_providers/provider_scan_engine_fairness_test.dart
test/live_tv_service_manager_test.dart
test/ethio_sports_service_test.dart
test/services/iptv/m3u_playlist_parser_test.dart
test/services/iptv/m3u_live_tv_service_test.dart
test/services/iptv/m3u_playlist_repository_test.dart
test/services/iptv/spyhell_live_tv_adapter_test.dart
test/pluto_tv_experimental_service_test.dart
test/services/iptv/xmltv_epg_parser_test.dart
test/services/iptv/xmltv_epg_repository_test.dart
test/video_providers/phase50_embedded_playback_test.dart
```

## 5. Warnings, errors and diagnostics

Counts below are extracted from the command logs captured by this workflow. Setup/action internals are represented by their step outcome; open the workflow run for the action-owned console output.

| Log | Warning occurrences (unique messages) | Notices | Analyzer info | Error/failure markers |
|---|---:|---:|---:|---:|
| Dependency resolution | 0 (0 unique) | 0 | 0 | 0 |
| Dart formatting | 0 (0 unique) | 0 | 0 | 0 |
| Formatter patch capture | 0 (0 unique) | 0 | 0 | 0 |
| Flutter analyze | 0 (0 unique) | 0 | 0 | 0 |
| Phase 36–50 contracts and Phase51 integration regression tests | 12 (8 unique) | 0 | 0 | 5 |

### Warning and deprecation excerpts

- **Phase 36–50 contracts and Phase51 integration regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m` _(repeated 5 times)_
- **Phase 36–50 contracts and Phase51 integration regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_provider] not found[0m`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_provider_description] not found[0m`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_resolution] not found[0m`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [download_from_provider] not found[0m`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [quality_fhd] not found[0m`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [size_unknown] not found[0m`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [quality_hd] not found[0m`

### Notices

- No notice markers found in captured command logs.

### Error and failure excerpts

- **Phase 36–50 contracts and Phase51 integration regression tests:** `00:15 +184 -1: /home/runner/work/RAVEN23/RAVEN23/test/live_tv_service_manager_test.dart: parses Live TV expiry timestamps as ISO, seconds or milliseconds [E]`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `Expected: DateTime:<2030-01-01 00:00:00.000Z>`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `Actual: DateTime:<189349-11-30 00:00:00.000>`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `TV cache clearing failed: Exception: Failed to clear cache`
- **Phase 36–50 contracts and Phase51 integration regression tests:** `00:29 +301 -1: Some tests failed.`

### Phase51 integration/regression test summary

- `00:29 +301 -1: Some tests failed.`

#### Failed test markers

- `00:15 +184 -1: /home/runner/work/RAVEN23/RAVEN23/test/live_tv_service_manager_test.dart: parses Live TV expiry timestamps as ISO, seconds or milliseconds [E]`
- `00:29 +301 -1: Some tests failed.`

#### Last 80 lines of required source-contract test log

```text
00:22 +250 -1: /home/runner/work/RAVEN23/RAVEN23/test/adaptive_quality_scanner_test.dart: uses the HLS NAME attribute when RESOLUTION is not declared
00:22 +251 -1: /home/runner/work/RAVEN23/RAVEN23/test/adaptive_quality_scanner_test.dart: requests an adaptive manifest with the provider request headers
00:22 +252 -1: /home/runner/work/RAVEN23/RAVEN23/test/adaptive_quality_scanner_test.dart: parses DASH Representation heights
00:22 +253 -1: /home/runner/work/RAVEN23/RAVEN23/test/adaptive_quality_scanner_test.dart: sniffs extensionless HLS masters and follows nested variant playlists
00:22 +254 -1: /home/runner/work/RAVEN23/RAVEN23/test/adaptive_quality_scanner_test.dart: infers a variant height from explicit HLS rendition path segments
00:22 +255 -1: /home/runner/work/RAVEN23/RAVEN23/test/adaptive_quality_scanner_test.dart: sniffs an extensionless DASH manifest from its response content type
00:22 +256 -1: /home/runner/work/RAVEN23/RAVEN23/test/adaptive_quality_scanner_test.dart: ignores a media playlist with no variant stream declarations
00:23 +257 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: offlineEnqueueErrorMessage names the title when it is already downloaded
00:23 +258 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: offlineEnqueueErrorMessage never shows the raw platform exception
00:23 +259 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: download source identity saves API quality and server independently of duplicate display labels
00:23 +260 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: download source identity does not invent recovery metadata for missing or ambiguous sources
00:23 +261 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: OfflineDownload decodes progress, metadata, and state from the platform map
00:23 +262 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: OfflineDownload normalizes invalid platform progress
00:23 +263 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: OfflineDownload estimates adaptive stream size while content length is unknown
00:23 +264 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: OfflineDownload encodes every source field needed by the native downloader
00:23 +265 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: streaming and downloads share provider header inference
00:23 +266 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: OfflineDownloadProvider loads, sorts, and receives live progress updates
00:23 +267 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: OfflineDownloadProvider forwards queue controls to the platform gateway
00:23 +268 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: downloads page displays progress and exposes pause control
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
00:23 +269 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: downloads page displays progress and exposes pause control
00:23 +270 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: downloads page displays progress and exposes pause control
00:23 +271 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: downloads page displays progress and exposes pause control
00:23 +272 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: downloads page displays progress and exposes pause control
00:23 +273 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: downloads page displays progress and exposes pause control
00:23 +274 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: downloads page displays progress and exposes pause control
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
00:24 +275 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: completed download exposes external player and save actions
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
00:24 +276 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: status chips are neutral, except a failure in the error colour
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
00:24 +277 -1: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: download sheets return the selected provider and resolution
[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_provider] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_provider_description] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_resolution] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [download_from_provider] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [quality_fhd] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [size_unknown] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [quality_hd] not found[0m
00:25 +278 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_remote_navigation_test.dart: (setUpAll)
00:25 +278 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_remote_navigation_test.dart: content grid enters predictably and contains edge navigation
00:26 +279 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_back_dispatcher_test.dart: last Back layer asks before exiting the TV app
00:26 +280 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_back_dispatcher_test.dart: last Back layer asks before exiting the TV app
00:26 +281 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_back_dispatcher_test.dart: last Back layer asks before exiting the TV app
00:26 +282 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_remote_navigation_test.dart: app mode can be changed in both directions with a remote
00:26 +283 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_remote_navigation_test.dart: app mode can be changed in both directions with a remote
00:26 +284 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_remote_navigation_test.dart: subtitle settings are D-pad navigable and persist choices
00:27 +285 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +286 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +287 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +287 -1: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: skips only anime-exclusive providers for live-action movies
[PlaybackSources][SKIPPED] provider=Anikoto reason=anime-only media=movie
[PlaybackSources][SELECTED] provider=Multi provider index=1 directLinks=1
00:27 +288 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +288 -1: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: anime feature films keep movie identity while enabling anime-only providers
[PlaybackSources][SELECTED] provider=Anime Movie Source index=0 directLinks=1
00:27 +289 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +290 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +290 -1: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: keeps anime-exclusive providers eligible for anime episodes
[PlaybackSources][SELECTED] provider=Re:Anime index=0 directLinks=1
00:27 +291 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +291 -1: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: first provider success never starts backup requests
[PlaybackSources][SELECTED] provider=Provider 0 index=0 directLinks=1
00:27 +292 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +292 -1: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: each fallback waits for the previous provider to fail
[PlaybackSources][SELECTED] provider=Provider 3 index=3 directLinks=1
00:27 +293 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +293 -1: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: exceptions and empty successful results fall through in order
[PlaybackSources][SELECTED] provider=Provider 4 index=4 directLinks=1
00:27 +294 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +295 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +296 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +297 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:28 +298 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: subtitle languages scroll with the remote and reopen on selection
00:28 +299 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: clear cache removes both directories and ignores repeat presses
00:28 +300 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: cache failure still clears temporary files and reports failure
TV cache clearing failed: Exception: Failed to clear cache
00:29 +301 -1: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: (tearDownAll)
00:29 +301 -1: Some tests failed.
```

## 6. APK size and ABI report

APK audit did not produce `apk-size-report.md`; inspect the APK audit step outcome and log.

## 7. Generated diagnostic artifacts

- `build-artifacts/ci-context.txt` — 224 bytes
- `build-artifacts/ci-environment.txt` — 2,321 bytes
- `build-artifacts/ci-started-at.txt` — 21 bytes
- `build-artifacts/dart-format-summary.txt` — 41 bytes
- `build-artifacts/dart-format.log` — 126 bytes
- `build-artifacts/dart-format.patch` — 0 bytes
- `build-artifacts/dependency-resolution.log` — 7,585 bytes
- `build-artifacts/flutter-analyze.log` — 119 bytes
- `build-artifacts/format-patch.log` — 31 bytes
- `build-artifacts/phase51-integration-regression-tests.log` — 55,286 bytes
- `build-artifacts/RAVEN23-build-report.md` and root `RAVEN23-build-report.md` — this generated report.

## 8. Interpretation notes

- A step marked `skipped` was not executed, normally because an earlier step failed. It is not a successful test result.
- Required Phase 37–50 contract-test output is retained in the `RAVEN23-phase51-integration-regression-test-log` artifact. The selected Phase 37–43 dependency tests, Phase 44/45 regression tests, focused Phase 46 Live TV manager tests, Phase 47 IPTV/Spyhell tests, Phase 48 Pluto experimental-provider guard tests, and Phase 49 XMLTV parser/cache/mapping tests and Phase 50 embed lifecycle/routing tests are included; unrelated widget/full-suite tests remain excluded from the automatic APK gate. Live external-provider availability and Android-device playback are not established by mocked contract tests.
- Setup actions (checkout/tool installers/cache) expose their detailed output in the linked GitHub Actions run; their success/failure outcome is recorded above.
- This report describes this individual run only. It does not mark a RAVEN23 phase accepted unless all required CI and runtime acceptance gates pass.

---
_Generated automatically by `.github/workflows/android-ci.yml` at 2026-11-08T15:55:36Z._
