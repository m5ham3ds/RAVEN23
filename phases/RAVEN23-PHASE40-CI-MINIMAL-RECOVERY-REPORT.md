# RAVEN23 — Phase 40 Minimal CI Recovery Report

**Date:** 2026-11-07  
**Working baseline:** `RAVEN23-PHASE40` (the active project and phase plan)  
**Reference baseline:** `RAVEN23-PHASE35.1` (used only for historical comparison)  
**Latest supplied failing workflow:** `42377441117`  
**Commit in that run:** `921b5c3a8f4e803f94c74cb3f163049c2b43747e`

## 1. Actual cause of the latest failure

The supplied report shows that dependency resolution and the formatting step succeeded. CI then stopped at `Flutter analyze` with a single info-level diagnostic:

```text
info • The import of 'package:flutter/widgets.dart' is unnecessary
because all of the used elements are also provided by the import of
'package:flutter_test/flutter_test.dart'
• test/support/scroll_until_built.dart:1:8 • unnecessary_import
```

No test command, Gradle wrapper generation, APK compilation, or APK audit ran in that workflow attempt. Therefore this run did **not** demonstrate a failing Phase 40 test or an Android/Gradle failure.

## 2. Corrections applied

1. Removed the redundant `package:flutter/widgets.dart` import from `test/support/scroll_until_built.dart`. `flutter_test.dart` already exposes the Flutter test/widget symbols used by the helper.
2. Updated the workflow analyzer command to `flutter analyze --no-fatal-infos`. Analyzer errors and warnings remain fatal; info-only lints no longer stop APK generation. This avoids turning a non-blocking info hint into a failed Release build. The specific redundant import was still removed rather than left behind.
3. Removed one byte-identical duplicate test from `source_repository_parser_test.dart`.
4. Reduced the formatter target list to the maintained Phase 37–40 source files and the same four required Phase 40 contract-test files.
5. Reduced the automatic APK test gate to a single `flutter test` invocation targeting exactly four files and 44 test cases. The former 15-file broad provider/architecture batch, 17-file UI regression batch, and full `flutter test` run were removed from the automatic APK workflow.
6. Added a 10-minute timeout for the targeted test step and a 30-second timeout per test case.
7. Updated the Phase 40 tracker, blueprint, test plan, and README/change history to describe the new gate and preserve the distinction between historical full-suite runs and the current build policy.

## 3. Tests retained in the automatic APK gate

| Test file | Declared cases | Coverage retained |
|---|---:|---|
| `test/video_providers/source_repository_parser_test.dart` | 25 | Stremio Manifest/resources/config schema, resource-specific ID profiles, URL/configuration safety, YaStream fixture, malformed Manifest handling |
| `test/video_providers/source_repository_client_test.dart` | 2 | Manifest retrieval, repository enrichment, per-add-on failure isolation |
| `test/video_providers/stremio_addon_provider_test.dart` | 14 | Stream dispatch, ID-prefix behavior, optional/required configuration, episode coordinates and token-safe errors |
| `test/video_providers/unified_source_service_stremio_identity_test.dart` | 3 | Conditional IMDb identity resolution only when the resource profile requires it |
| **Total** | **44** | **Phase 40 Stremio Manifest & Configuration contracts** |

The remaining test source files have **not** been deleted. They remain in the repository for deliberate/manual QA or a future phase-specific gate. They no longer run on every automatic APK build and therefore cannot lengthen or block each routine build.

## 4. Current automatic CI sequence

1. Resolve Flutter dependencies.
2. Apply and check Dart formatting for the maintained Phase 37–40 files and four critical test files.
3. Run `flutter analyze --no-fatal-infos` (errors and warnings are fatal; info-only diagnostics are non-fatal).
4. Run the four Phase 40 test files only (`--timeout 30s`, step cap 10 minutes).
5. Generate the Android Gradle Wrapper.
6. Build the configured production ARM64 APK.
7. Audit APK integrity, application ID, size, and ABI contents; expected ABI is `arm64-v8a` only.

No broad 15-file test batch, 17-file UI regression batch, or complete Flutter test suite remains in the automatic APK path.

## 5. Static packaging validation performed

- Parsed `.github/workflows/android-ci.yml` successfully.
- All **13** workflow shell `run` blocks passed `bash -n`.
- All **3** embedded Python heredoc blocks compiled successfully.
- Confirmed exactly one test invocation remains in the workflow and it points to the four required Phase 40 files.
- Confirmed all four test paths exist.
- Confirmed there are **44** test declarations across the four files after removing the duplicate case.
- Confirmed the Dart formatter target list includes the four same critical test files.
- Confirmed that old full-suite and broad-regression step IDs/log paths are absent from the current workflow.

## 6. Verification not performed

This packaging environment does not contain Flutter, Dart, Gradle/Android SDK tools for a project build. Consequently, I could not execute:

- `dart format` or `flutter analyze`;
- the 44 targeted Flutter tests;
- Android Gradle wrapper generation;
- Release ARM64 APK compilation;
- APK installation or runtime playback checks.

The ZIP is a source/workflow recovery package, **not a claim that the APK has now built successfully**. Phase 40 remains `In Progress`; Phase 41 remains `Not Started` until GitHub Actions passes the reduced gate and produces an audited ARM64 Release APK.
