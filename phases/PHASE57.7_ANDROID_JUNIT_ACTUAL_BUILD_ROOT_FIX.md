# PHASE57.7 — Android JUnit actual build-root correction (2026-11-11)

## Input run

- CI run: `42943537695`
- Commit: `91a2b6fac9fa2fd43a74b71f0743d0fbe709a043`
- Previous source package: PHASE57.6

## Actual CI evidence

The run completed all prerequisites:

- `flutter pub get`: success.
- Scoped formatting: 23 files checked, zero changes; the formatter patch is empty.
- `flutter analyze --no-fatal-infos`: `No issues found!`.
- The five focused Manga/Mihon Flutter files: **17 tests passed, zero failed**.
- Gradle Wrapper generation: `BUILD SUCCESSFUL`.
- `:app:testProdReleaseUnitTest --tests com.m5ham3ds.raven23.mihon.MihonExtensionLoaderAbiTest`: **BUILD SUCCESSFUL** and the Gradle console reported all three selected cases as `PASSED`:
  - `androidFloatRepresentationOfSixteenIsAcceptedAndCanonicalized`
  - `exactSupportedVersionsRemainAccepted`
  - `unsupportedVersionsAndNonFiniteValuesRemainRejected`

The CI job nevertheless marked the Android test step failed after the Gradle task had succeeded. This was a CI path bug, not a failed ABI test.

## Root cause

`android/build.gradle` redirects every Android subproject build directory:

```groovy
rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
```

Therefore the Android app module's actual build directory is repository-root `build/app`, not `android/app/build`.

PHASE57.6's verification and cleanup logic incorrectly used paths under `android/app/build`. It consequently:

- removed stale reports from the wrong directory;
- searched the wrong directory for `TEST-*.xml`;
- rejected the step when the real report directory had not been inspected;
- uploaded the wrong report paths.

The supplied Gradle log independently proves that the selected class ran and all three methods passed. The job did not reach APK build because the later report-path assertion returned a non-zero status.

## PHASE57.7 changes

1. Use `../build/app` from the workflow's `android` working directory as the actual module build root.
2. Clean only the real module test-result/report directories before the test task, preventing a stale report from satisfying this run.
3. Search `../build/app/**/TEST-*.xml` and parse the exact selected test class and its three methods.
4. Keep a strict Gradle-console fallback only when XML is not materialized. It requires:
   - a successful `BUILD SUCCESSFUL` marker;
   - exactly one `PASSED` event for each of the three expected test method names;
   - no selected-class `FAILED` or `SKIPPED` event;
   - no unexpected selected-class pass event.
5. Set `--console=plain` so the per-test event lines are stable and machine-checkable.
6. Upload reports from `build/app/test-results`, `build/app/outputs/test-results`, and `build/app/reports/tests`, matching the actual centralized build directory.
7. Extend the Markdown CI report to include the three per-test console events and actual JUnit paths when present.

JUnit XML remains preferred. The console fallback is not a source-name check: Gradle's configured per-test logging emits each `PASSED` event only after the test case completes, and the overall Gradle task must also return success.

## Scope preserved

- No app runtime source changes.
- No Flutter, Dart, Java, Gradle, AGP, Kotlin or dependency version changes.
- No Mihon ABI policy changes; only 1.4 and 1.6 remain supported.
- No test source files deleted, renamed or modified.
- Routine gate remains five focused Flutter test files and the three-case Android ABI test class.
- The other 254 Flutter test files and nine Android test source files remain in the project for owner-led manual/deeper regression.
- Manga/Home UI, video sources, BetterPlayer, streaming engines, splash assets and signing policy remain untouched.

## Verification performed while preparing this archive

- The uploaded run's actual Gradle log was replayed through the new console verifier: all three expected `PASSED` events and `BUILD SUCCESSFUL` were detected.
- Negative verifier cases were checked for a missing method, duplicate method, unexpected method, `FAILED`, `SKIPPED`, and missing `BUILD SUCCESSFUL`; each must fail.
- GitHub Actions YAML parsing, Bash syntax, embedded Python compilation, report-path consistency and ZIP CRC are checked before packaging.
- Flutter, Gradle and Android SDK execution are not available in this editing environment. No new APK or new CI pass is claimed.

## Acceptance

- [x] Diagnose the exact failed CI run and recover the positive Android test evidence from its log.
- [x] Identify the module build directory redirection in `android/build.gradle`.
- [x] Correct result cleanup, search, validation and artifact upload paths.
- [x] Retain strict validation of the exact three ABI cases, with a verified Gradle-console fallback.
- [x] Preserve all app and test source files.
- [ ] Confirm a new GitHub Actions run passes the Android gate and produces the ARM64 APK.
- [ ] Confirm APK install and Team X extension installation on the owner's device.

**Status:** PHASE57.7 CI path correction prepared; GitHub Actions and device acceptance pending.
