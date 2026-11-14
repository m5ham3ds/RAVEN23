# Phase 51 — Test Matrix

The Android CI gate now contains 39 explicit test files:

## Existing Phase37–50 source contract tests (29)

These remain unchanged and cover source contracts/engines, repository manager/parser/client/revision/host policy, QuickJS runtime/settings/security, Stremio identity, VidKing language/quality, episode identity, provider scan fairness, Live TV manager/EthioSports, M3U parser/service/repository, Spyhell adapters, Pluto experimental behavior, XMLTV parser/repository, and Embedded WebView playback.

## Added cross-feature regression tests (10)

1. `test/player_route_handoff_test.dart`
2. `test/player_next_episode_policy_test.dart`
3. `test/player_subtitle_configuration_test.dart`
4. `test/adaptive_quality_scanner_test.dart`
5. `test/offline_download_test.dart`
6. `test/settings_subtitle_language_migration_test.dart`
7. `test/tv_remote_navigation_test.dart`
8. `test/tv_back_dispatcher_test.dart`
9. `test/tv_settings_screen_test.dart`
10. `test/provider_loader_test.dart`

## Execution status

All ten added paths were verified to exist. The complete 39-file list is configured in GitHub Actions. None of these tests was executed in the packaging environment because Flutter/Dart are unavailable. Full Flutter suite execution and physical device smoke tests remain separate evidence requirements.

## First CI attempt — execution record

- Workflow `42486996579` reached `flutter analyze` and failed on one nullable-access error plus one unused-import warning.
- The analyzer's 12 informational curly-brace lints were also corrected as cleanup; CI explicitly uses `--no-fatal-infos`.
- The 39-file Flutter test command was **skipped** because the analyzer step failed first. No test result may be inferred from the absence of a log.
- Gradle Wrapper generation, ARM64 Release APK build, and APK audit were also skipped.
- The source fixes are prepared in this archive; a new workflow run is required to establish whether analyzer, tests, and build pass.



## Follow-up regression additions — 2026-11-08

The existing selected `test/services/iptv/spyhell_live_tv_adapter_test.dart` now also covers cached Spyhell channels where `Channel.watchUrl` is null or empty. Both cases expect the service's controlled `DaddyLiveException` (`no playable locator`) and must exit before repository sync or QuickJS provider execution. The workflow still selects 39 test files; this adds cases within the existing selected file.

These tests are authored but have not run in the observed failed CI attempt because Analyze stopped the workflow first.


## Third CI attempt — run 42497050504

- Flutter Analyze passed with `No issues found`; canonical formatting passed for all 91 Dart targets with 0 changes.
- All 39 configured test files were executed. Result: **301 passed, 1 failed**. The sole failure was the Live TV expiry timestamp parser test: numeric epoch milliseconds encoded as a string were sent to `DateTime.tryParse` first and parsed as an extended year.
- The existing test now explicitly asserts ISO-8601, epoch seconds and epoch milliseconds. The parser change recognizes integer/whole-number epochs before ISO parsing.
- The CI test inventory remains 39 files; no test files were removed or skipped within this test command.
- Gradle Wrapper generation, ARM64 Release APK build and APK audit were skipped because the test command failed.
- The emitted TV cache-clearing exception is expected by the negative-path widget test. Localization warnings refer to keys present in each shipped locale file and did not fail assertions.

The parser remediation is prepared but not locally executed because Flutter/Dart are unavailable in the packaging environment. A fresh CI run must establish a clean 39-file test result before proceeding to Gradle and APK validation.


## CI run 42501508059 evidence

The configured 39-file integration/regression command completed successfully with **302 passed, 0 failed**. The test step returned exit code 0. The overall workflow later failed during Android Kotlin compilation, after Gradle Wrapper generation; this is not a test failure. See `docs/build-reports/2026-11-08-phase51-run-42501508059/phase51-integration-regression-tests.log`.
