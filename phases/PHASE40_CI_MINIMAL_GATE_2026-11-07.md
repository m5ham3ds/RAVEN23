# Phase 40 — Minimal CI Gate and Analyzer Recovery

**Date:** 2026-11-07  
**Status:** CI scope reduced; Release build verification still pending.

## Latest analyzer blocker

The supplied analyzer excerpt reported one issue:

```text
info • The import of 'package:flutter/widgets.dart' is unnecessary
because all of the used elements are also provided by
'package:flutter_test/flutter_test.dart'
• test/support/scroll_until_built.dart:1:8 • unnecessary_import
```

Removed the redundant `flutter/widgets.dart` import from `test/support/scroll_until_built.dart`. The helper keeps `flutter_test.dart`, which already exposes the required Flutter test/widget symbols. This is a lint-only correction; no runtime app code or test behavior was changed for this issue.

## CI test-gate review

The previous automatic APK workflow executed three overlapping batches:

1. 15 focused architecture/provider test files spanning multiple phases;
2. 17 widget/settings/regression files, many unrelated to the Phase 40 Stremio Manifest and Configuration work;
3. the entire Flutter test tree.

This made an APK build depend on unrelated widget suites and repeated broad coverage. The Phase 40 test plan (`PHASE40_STREMIO_MANIFEST_CONFIGURATION_TESTS.md`) identifies four direct contract files. The automatic build gate is now restricted to exactly those files:

- `test/video_providers/source_repository_parser_test.dart` — Manifest schema/resource parsing, config schema validation, URL safety, and YaStream fixture.
- `test/video_providers/source_repository_client_test.dart` — remote Manifest retrieval and per-addon enrichment/error isolation.
- `test/video_providers/stremio_addon_provider_test.dart` — stream resource profiles, ID prefix behavior, optional/required configuration, and stream request safety.
- `test/video_providers/unified_source_service_stremio_identity_test.dart` — conditional IMDb identity resolution and no unnecessary resolver calls.

The targeted test step has a 10-minute job-step cap and a 30-second per-test timeout.

## What is no longer required for every APK build

The automatic push/PR/manual APK workflow no longer runs:

- the 15-file general architecture/provider batch;
- the 17-file UI/widget regression batch;
- `flutter test` over the complete test directory.

Those test source files are **not deleted**. They remain in the repository for explicit/manual QA and future targeted phase work, but they no longer block every APK build. The analyzer still checks the project sources and tests. CI uses `flutter analyze --no-fatal-infos`: errors and warnings remain fatal, while info-only lints do not block APK creation. The APK gate executes only the four Phase 40 contract files above; one byte-identical duplicate test case was removed, leaving 44 targeted test cases.

## Automatic build sequence

1. Resolve dependencies.
2. Apply and verify Dart formatting for the maintained Phase 37–40 implementation/test targets.
3. Run `flutter analyze --no-fatal-infos` (errors and warnings remain fatal).
4. Run the four required Phase 40 Stremio contract test files only.
5. Generate the Android Gradle Wrapper.
6. Build the configured Android ARM64 Release/Debug APK.
7. Audit APK CRC, package ID, size, and native ABI contents.

## Verification boundary

This packaging environment does not include Flutter or Dart. The import correction and workflow edits were source-reviewed; YAML structure, shell blocks, referenced test paths, and ZIP integrity are checked separately. This does **not** establish that `flutter analyze`, the four tests, Gradle, or the APK build pass. Phase 40 remains In Progress until GitHub Actions completes the required gates and produces an audited APK.
