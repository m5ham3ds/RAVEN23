> **Superseded by PHASE57.7:** The original PHASE57.6 report-path diagnosis did not account for `android/build.gradle` redirecting subproject outputs to repository-root `build/<module>`. The correct app-module report root is `build/app`, not `android/app/build`. Run `42943537695` later proved all three ABI cases passed and Gradle completed successfully; the job was blocked only by the incorrect discovery path. See [`PHASE57.7_ANDROID_JUNIT_ACTUAL_BUILD_ROOT_FIX.md`](PHASE57.7_ANDROID_JUNIT_ACTUAL_BUILD_ROOT_FIX.md).

# PHASE57.6 — Android JUnit report-path and focused ABI gate repair

**Date:** 2026-11-11  
**Input:** PHASE57.5 CI run `42934758078`, commit `0f82a35e6a6813c55e1db1ce91f964cb6f18506c`.

## CI diagnosis

The run reached and passed all earlier prerequisites:

- `flutter pub get` completed successfully; `flutter_native_splash` was absent from the root dependency and Android plugin graph.
- Scoped Dart formatting completed with 23 files and no formatter changes.
- `flutter analyze --no-fatal-infos` reported no issues.
- The five focused Manga/Mihon Flutter test files passed all 17 tests.
- Gradle wrapper generation completed successfully.
- The Android release unit-test task `:app:testProdReleaseUnitTest` reported `BUILD SUCCESSFUL`.

The workflow nevertheless marked the Android gate as failed because its post-test verification searched only:

`android/app/build/test-results/testProdReleaseUnitTest`

The Android Gradle Plugin's local unit-test result directory can instead be rooted under the module's `build/outputs/test-results/` directory. The report checker therefore assumed that no JUnit report existed solely because it inspected one hard-coded path. The supplied run artifact did not include the complete module build tree, so it did not independently establish the actual location of the generated XML in that run. The important facts are that the Gradle task returned success, the selected test source compiled, and the workflow's report-path assertion then failed. This is a CI result-discovery issue, not evidence that an ABI assertion failed.

## Changes

1. Pin Android local unit-test `resultsDir` to `android/app/build/test-results` and `reportDir` to `android/app/build/reports/tests`.
2. Enable JUnit XML reports and visible passed/skipped/failed test events for Android unit-test tasks.
3. Set `failOnNoMatchingTests = true` specifically on `testProdReleaseUnitTest`; a wrong class filter can no longer silently return a successful Gradle task.
4. Change the CI result verifier to search both `app/build/test-results` and `app/build/outputs/test-results`, with a fallback scan of the module build directory.
5. Validate exactly the three `<testcase>` entries whose `classname` equals `com.m5ham3ds.raven23.mihon.MihonExtensionLoaderAbiTest`; unrelated JUnit suites cannot satisfy the gate.
6. Reject missing, failed, errored, or skipped cases. Require exactly three selected cases before APK build.
7. Upload Android JUnit XML and HTML reports alongside the existing focused test logs for future diagnosis.
8. Run wrapper generation with `--no-watch-fs --no-daemon` to avoid the non-fatal `Already watching path` diagnostic observed during the previous wrapper invocation.

## Preserved scope

- No Flutter or Dart version changes.
- No dependency version changes.
- No application runtime code changes.
- No Mihon ABI policy changes: only 1.4 and 1.6 remain supported.
- No test sources were deleted or moved.
- The routine APK gate remains the five focused Flutter files (17 current cases) and the three selected Android ABI cases.
- The other Flutter and Android test sources remain available for owner-led/manual deeper regression.
- Video engines, player behavior, Manga UI, source repositories and signing checks remain untouched.

## Verification status

Static checks performed on this archive:

- GitHub Actions YAML parsed successfully.
- Bash run blocks passed `bash -n`.
- Embedded Python blocks compiled successfully.
- The report-validation logic was exercised against synthetic JUnit XML covering: exactly three matching passing cases; a missing case; a failing case; a skipped case; and unrelated test classes.
- ZIP integrity and unchanged test inventory were checked.

Flutter, Dart, Gradle and the Android SDK were not available in the editing environment. This phase therefore does **not** claim that the Android tests or APK were run here. The next CI run must confirm the report path, the three actual ABI cases, APK build, ARM64 audit and the owner's device installation.

## Acceptance

- [x] Diagnose run `42934758078` and distinguish Gradle task success from the failed report-path assertion.
- [x] Make the Android result and report directories explicit.
- [x] Make missing test discovery fail at the Gradle task, not only at a later Python check.
- [x] Search multiple AGP/Gradle result locations and verify the selected class and its three cases.
- [x] Preserve all test files and all application runtime code.
- [ ] Confirm the three ABI JUnit cases in GitHub Actions.
- [ ] Confirm ARM64 Release APK build and APK audit.
- [ ] Confirm installation and Mihon extension behavior on the owner's Android device.

**Status:** Phase57.6 CI/report-path repair prepared; GitHub Actions and device acceptance pending.
