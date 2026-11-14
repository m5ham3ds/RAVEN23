# Phase52 Test Selection Remediation — Run 42553710801

## Observed result

- `flutter analyze`: passed.
- Dart formatting: passed, 16 targets checked, zero changes.
- Phase52 source-priority policy suite: 15 tests passed.
- The next targeted test group exited 79 with `No tests ran` / `No tests match`.
- Gradle Wrapper, Android Release build and APK audit were not reached.

## Root cause

The CI command passed several test names separated by `|` to Flutter's `--plain-name` option. That option performs a plain-text substring match; it does not interpret alternation as a regular expression. The targeted tests exist in the referenced files, but the selector therefore matched none of them.

## Fix

- Changed only the three multi-name selectors (unified source execution, QuickJS catalog, and QuickJS episode contract) from `--plain-name` to `--name`, which supports regex alternation.
- Kept the single-name parser selector on `--plain-name`.
- Kept the Phase52 scope unchanged: 25 selected tests across five files.
- Did not change application source, source eligibility, priority ordering, language policy, Release settings, or historical tests.

## Acceptance status

This correction fixes the CI selector. It has not been executed with Flutter in the packaging environment. Phase52 remains CI-pending until the next GitHub Actions run confirms all 25 tests and the Release/APK audit.
