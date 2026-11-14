# Phase 40 — CI Dart Format Recovery

**Date:** 2026-11-07  
**Trigger:** GitHub Actions run `42313561006`, job `128220605361`, step 10.

## Observed failure

The workflow ran:

```bash
dart format --output=none --set-exit-if-changed <36 Phase 37–40 Dart targets>
```

The log reported 35 files as `Changed`, summarized `Formatted 36 files (35 changed)`, and exited with status 1. This is the expected result of a check-only formatter invocation when source files do not match `dart format`; `--output=none` prevents the formatter from writing the canonical formatting. The failure occurred before `flutter analyze`, tests, and Android APK assembly. It is not evidence of a Dart compilation error or Android build failure.

## Recovery implemented

- Added `tool/format_phase37_40_dart.sh` with the exact same 36 target paths as the previous workflow check.
- `--fix` runs `dart format` in write mode.
- `--check` reruns `dart format --output=none --set-exit-if-changed` as the strict verification gate.
- `.github/workflows/android-ci.yml` runs `--fix` followed by `--check` before Analyze/tests/build.
- CI captures the formatter's exact `git diff` and uploads it as `RAVEN23-dart-format-patch`, allowing the source branch to receive the same formatting changes. CI does not commit or push changes automatically.

## Verification state

Static checks performed while preparing this recovery: workflow YAML parsed; each shell `run` block passed `bash -n`; the formatter script passed `bash -n`; mock execution confirmed both modes pass the exact 36 paths; target paths were compared against the original CI format list with no missing or extra entries.

The actual Dart formatter could not be executed in the packaging container because Dart/Flutter SDKs are unavailable. Therefore, this is a workflow recovery implementation, not a claim that the formatter or later CI gates have already passed. A rerun of GitHub Actions is required. The first failed run did not reach Analyze, tests, or Release APK build.


## Follow-up: analyze run after formatter recovery — 2026-11-07

The supplied GitHub Actions output demonstrates that the formatter recovery advanced the workflow past the format gate and into `flutter analyze`. Analyze then reported 62 diagnostics, including seven compile/analyzer errors across four tests, plus warnings and infos. The uploaded `RAVEN23-dart-format-patch.zip` was applied to the Phase 40 recovery baseline. The reported test/API/lint findings were corrected in the project tree and documented in `PHASE40_CI_ANALYZE_RECOVERY.md`. No local Flutter SDK is available to rerun Analyze, so the corrective change set is pending a new GitHub Actions run; no passing Analyze, tests, or APK build is claimed.
