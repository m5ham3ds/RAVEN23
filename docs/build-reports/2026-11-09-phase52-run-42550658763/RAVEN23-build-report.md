# RAVEN23 — Comprehensive CI Build Report

- **Overall job status:** `FAILURE`
- **Build mode:** `RELEASE`
- **Started (UTC):** `2026-11-09T02:23:31Z`
- **Elapsed time until report generation:** `00:03:07`
- **Finished (UTC):** `2026-11-09T02:26:38Z`
- **Workflow:** `RAVEN23 Local Android APK Build`
- **Actor:** `m5ham3ds`
- **Workflow run:** [Open GitHub Actions run](https://github.com/m5ham3ds/RAVEN23/actions/runs/42550658763)
- **Run ID / attempt:** `42550658763` / `1`
- **Trigger:** `push`
- **Repository:** `m5ham3ds/RAVEN23`
- **Ref:** `refs/heads/main`
- **Commit:** `835f6ef55d003aed17708feb8c1485909c5b76de`

## 1. Execution summary

- Steps marked failed: **1**
- Steps skipped/not reached: **3**
- Steps cancelled: **0**
- APK present: **No**

### Failed steps

- `Phase 36–51 contracts and Phase52 source-priority regression tests`

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
| Phase 36–51 contracts and Phase52 source-priority regression tests | `failure` |
| Generate Android Gradle Wrapper | `skipped` |
| Build APK | `skipped` |
| APK size/ABI audit | `skipped` |
| Upload APK artifact | `success` |
| Upload required source-contract test log | `success` |
| Upload formatter patch | `success` |

## 3. Runner and toolchain

```text
UTC capture time: 2026-11-09T02:25:19Z
Runner: Linux / X64
Kernel: Linux runnervmwuk1x 7.0.0-1019-azure #20-Ubuntu SMP PREEMPT Mon Oct 19 22:41:16 UTC 2026 x86_64 GNU/Linux
Repository: m5ham3ds/RAVEN23
Ref: refs/heads/main
Commit: 835f6ef55d003aed17708feb8c1485909c5b76de

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
Run ID: 42550658763
Run attempt: 1
Event: push
Actor: m5ham3ds
Repository: m5ham3ds/RAVEN23
Ref: refs/heads/main
Commit: 835f6ef55d003aed17708feb8c1485909c5b76de
Build mode: release
```

## 4. Commands and build switches

- Dependency resolution: `flutter pub get`.
- Formatting: `bash tool/format_phase37_50_dart.sh --fix` followed by `--check` (maintained target list includes Phase 44–52 changes).
- Static analysis: `flutter analyze`.
- Required automated tests: the exact Phase 37–52 contract set listed below, including source-priority policy and orchestration. No unrelated widget regression batch or full Flutter suite runs in the APK build workflow.
- Wrapper generation: `gradle wrapper --gradle-version 8.7 --distribution-type all`.
- APK build: `flutter build apk --${BUILD_MODE} --flavor prod --target lib/main.dart --target-platform android-arm64 -Pdisable-abi-filtering=true --dart-define=ENABLE_FIREBASE=false --dart-define=LOCAL_DEV_MODE=true`.
- APK audit: inspect archive CRC/listing, native ABI directories, package name and payload sizes.

### Required Phase 37/38/39/40/41/42/43/44/45/46/47/48/49/50/51/52 contract test files (40 explicit files)

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
test/player_route_handoff_test.dart
test/player_next_episode_policy_test.dart
test/player_subtitle_configuration_test.dart
test/adaptive_quality_scanner_test.dart
test/offline_download_test.dart
test/settings_subtitle_language_migration_test.dart
test/tv_remote_navigation_test.dart
test/tv_back_dispatcher_test.dart
test/tv_settings_screen_test.dart
test/provider_loader_test.dart
test/video_providers/source_priority_policy_test.dart
```

## 5. Warnings, errors and diagnostics

Counts below are extracted from the command logs captured by this workflow. Setup/action internals are represented by their step outcome; open the workflow run for the action-owned console output.

| Log | Warning occurrences (unique messages) | Notices | Analyzer info | Error/failure markers |
|---|---:|---:|---:|---:|
| Dependency resolution | 0 (0 unique) | 0 | 0 | 0 |
| Dart formatting | 0 (0 unique) | 0 | 0 | 0 |
| Formatter patch capture | 0 (0 unique) | 0 | 0 | 0 |
| Flutter analyze | 0 (0 unique) | 0 | 0 | 0 |
| Phase 36–51 contracts and Phase52 source-priority regression tests | 13 (9 unique) | 0 | 0 | 31 |

### Warning and deprecation excerpts

- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Warning: At least one test in this suite creates an HttpClient. When running a test suite that uses`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m` _(repeated 5 times)_
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_provider] not found[0m`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_provider_description] not found[0m`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_resolution] not found[0m`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [download_from_provider] not found[0m`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [quality_fhd] not found[0m`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [size_unknown] not found[0m`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `[34m[🌎 Easy Localization] [WARNING] Localization key [quality_hd] not found[0m`

### Notices

- No notice markers found in captured command logs.

### Error and failure excerpts

- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:12 +147 -1: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_stremio_identity_test.dart: resolves IMDb only when the stream resource for this type advertises it [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Expected: <1>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Actual: <0>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:12 +148 -2: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_stremio_identity_test.dart: does not resolve IMDb when a resource profile accepts any supplied ID [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:12 +148 -3: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_stremio_identity_test.dart: does not perform IMDb lookup when a type-specific profile only accepts Kitsu [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Expected: <1>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Actual: <0>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:15 +171 -4: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: first playable callback fires before the slower source completes [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:17 +201 -5: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: a saturated QuickJS queue does not block another engine worker [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:18 +212 -6: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: returned attempts remain priority ordered despite completion order [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Expected: ['priority-first', 'priority-second']`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Actual: MappedListIterable<UnifiedSourceAttempt, String>:[]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:19 +222 -7: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: only streams with explicit future expiry enter the result cache [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Expected: <1>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Actual: <0>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:20 +233 -8: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: cached streams are isolated by preferred audio language [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Expected: ['English', 'Hindi']`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Actual: []`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:21 +236 -9: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: cache is invalidated when the same repository source is revised [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Expected: <2>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Actual: <0>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:22 +252 -10: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: results without source-declared expiry are never cached [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Expected: <2>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Actual: <0>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:23 +252 -11: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: circuit breaker cools a provider after repeated retryable failures [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:24 +269 -12: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: per-engine semaphore enforces the configured request limit [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Expected: <2>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `Actual: <0>`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:25 +273 -13: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: metrics retain only coarse HTTP status class [E]`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `TV cache clearing failed: Exception: Failed to clear cache`
- **Phase 36–51 contracts and Phase52 source-priority regression tests:** `00:31 +312 -13: Some tests failed.`

### Phase51/52 integration/regression test summary

- `00:31 +312 -13: Some tests failed.`

#### Failed test markers

- `00:12 +147 -1: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_stremio_identity_test.dart: resolves IMDb only when the stream resource for this type advertises it [E]`
- `00:12 +148 -2: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_stremio_identity_test.dart: does not resolve IMDb when a resource profile accepts any supplied ID [E]`
- `00:12 +148 -3: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_stremio_identity_test.dart: does not perform IMDb lookup when a type-specific profile only accepts Kitsu [E]`
- `00:15 +171 -4: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: first playable callback fires before the slower source completes [E]`
- `00:17 +201 -5: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: a saturated QuickJS queue does not block another engine worker [E]`
- `00:18 +212 -6: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: returned attempts remain priority ordered despite completion order [E]`
- `00:19 +222 -7: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: only streams with explicit future expiry enter the result cache [E]`
- `00:20 +233 -8: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: cached streams are isolated by preferred audio language [E]`
- `00:21 +236 -9: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: cache is invalidated when the same repository source is revised [E]`
- `00:22 +252 -10: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: results without source-declared expiry are never cached [E]`
- `00:23 +252 -11: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: circuit breaker cools a provider after repeated retryable failures [E]`
- `00:24 +269 -12: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: per-engine semaphore enforces the configured request limit [E]`
- `00:25 +273 -13: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: metrics retain only coarse HTTP status class [E]`
- `00:31 +312 -13: Some tests failed.`

#### Last 80 lines of required source-contract test log

```text
  
00:24 +269 -12: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: downloads page displays progress and exposes pause control
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
00:25 +270 -12: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: metrics retain only coarse HTTP status class
00:25 +270 -12: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: completed download exposes external player and save actions
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
00:25 +271 -12: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: metrics retain only coarse HTTP status class
00:25 +271 -12: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: status chips are neutral, except a failure in the error colour
[34m[🌎 Easy Localization] [WARNING] Localization key [downloads] not found[0m
00:25 +272 -12: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: metrics retain only coarse HTTP status class
00:25 +272 -12: /home/runner/work/RAVEN23/RAVEN23/test/offline_download_test.dart: download sheets return the selected provider and resolution
[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_provider] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_provider_description] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [download_choose_resolution] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [download_from_provider] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [quality_fhd] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [size_unknown] not found[0m
[34m[🌎 Easy Localization] [WARNING] Localization key [quality_hd] not found[0m
00:25 +273 -12: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: metrics retain only coarse HTTP status class
00:25 +273 -13: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: metrics retain only coarse HTTP status class [E]
  Bad state: No element
  dart:core                                                               _Array.single
  test/video_providers/unified_source_service_execution_test.dart 607:43  main.<fn>
  
00:25 +273 -13: /home/runner/work/RAVEN23/RAVEN23/test/video_providers/unified_source_service_execution_test.dart: cancellation suppresses callbacks and discards late source results
00:26 +274 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_remote_navigation_test.dart: content grid enters predictably and contains edge navigation
00:27 +275 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_back_dispatcher_test.dart: last Back layer asks before exiting the TV app
00:27 +276 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_back_dispatcher_test.dart: last Back layer asks before exiting the TV app
00:27 +277 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +278 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +279 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +280 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +280 -13: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: skips only anime-exclusive providers for live-action movies
[PlaybackSources][SKIPPED] provider=Anikoto reason=anime-only media=movie
[PlaybackSources][SELECTED] provider=Multi provider index=1 directLinks=1
00:27 +281 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +281 -13: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: anime feature films keep movie identity while enabling anime-only providers
[PlaybackSources][SELECTED] provider=Anime Movie Source index=0 directLinks=1
00:27 +282 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +283 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +283 -13: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: keeps anime-exclusive providers eligible for anime episodes
[PlaybackSources][SELECTED] provider=Re:Anime index=0 directLinks=1
00:27 +284 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +284 -13: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: first provider success never starts backup requests
[PlaybackSources][SELECTED] provider=Provider 0 index=0 directLinks=1
00:27 +285 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +285 -13: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: each fallback waits for the previous provider to fail
[PlaybackSources][SELECTED] provider=Provider 3 index=3 directLinks=1
00:27 +286 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +286 -13: /home/runner/work/RAVEN23/RAVEN23/test/provider_loader_test.dart: exceptions and empty successful results fall through in order
[PlaybackSources][SELECTED] provider=Provider 4 index=4 directLinks=1
00:27 +287 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +288 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:27 +289 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:28 +290 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: TV remote cannot manually enable the TMDB proxy
00:28 +291 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_remote_navigation_test.dart: app mode can be changed in both directions with a remote
00:29 +292 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +293 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +294 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +295 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +296 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +297 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +298 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +299 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +300 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +301 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +302 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +303 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +304 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +305 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +306 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +307 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +308 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: remote choices persist and TV buffer reflects its effective cap
00:29 +309 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: subtitle languages scroll with the remote and reopen on selection
00:31 +310 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: clear cache removes both directories and ignores repeat presses
00:31 +311 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: cache failure still clears temporary files and reports failure
TV cache clearing failed: Exception: Failed to clear cache
00:31 +312 -13: /home/runner/work/RAVEN23/RAVEN23/test/tv_settings_screen_test.dart: (tearDownAll)
00:31 +312 -13: Some tests failed.
```

## 6. APK size and ABI report

APK audit did not produce `apk-size-report.md`; inspect the APK audit step outcome and log.

## 7. Generated diagnostic artifacts

- `build-artifacts/ci-context.txt` — 224 bytes
- `build-artifacts/ci-environment.txt` — 2,321 bytes
- `build-artifacts/ci-started-at.txt` — 21 bytes
- `build-artifacts/dart-format-summary.txt` — 123 bytes
- `build-artifacts/dart-format.log` — 192 bytes
- `build-artifacts/dart-format.patch` — 920 bytes
- `build-artifacts/dependency-resolution.log` — 7,585 bytes
- `build-artifacts/flutter-analyze.log` — 119 bytes
- `build-artifacts/format-patch.log` — 92 bytes
- `build-artifacts/phase51-integration-regression-tests.log` — 67,591 bytes
- `build-artifacts/RAVEN23-build-report.md` and root `RAVEN23-build-report.md` — this generated report.

## 8. Interpretation notes

- A step marked `skipped` was not executed, normally because an earlier step failed. It is not a successful test result.
- Required Phase 37–52 contract-test output is retained in the `RAVEN23-phase51-integration-regression-test-log` artifact. The selected Phase 37–43 dependency tests, Phase 44/45 regression tests, Phase 46 Live TV manager tests, Phase 47 IPTV/Spyhell tests, Phase 48 Pluto guard tests, Phase 49 XMLTV tests, Phase 50 embedded playback tests, and Phase 52 source-priority policy/execution tests are included; unrelated widget/full-suite tests remain excluded. Live provider availability and Android-device playback are not established by mocked contract tests.
- Setup actions (checkout/tool installers/cache) expose their detailed output in the linked GitHub Actions run; their success/failure outcome is recorded above.
- This report describes this individual run only. It does not mark a RAVEN23 phase accepted unless all required CI and runtime acceptance gates pass.

---
_Generated automatically by `.github/workflows/android-ci.yml` at 2026-11-09T02:26:38Z._
