# Phase 40 — Full Flutter Test Suite / TV Widget Timeout Recovery

**Date:** 2026-11-07  
**Status:** Recovery patch prepared; CI rerun required.  
**Scope:** Test harness and CI diagnostics only; no TV production behavior changed.

## Observed CI evidence

The latest user-provided run reached `flutter test --reporter expanded` after earlier formatting, analysis, and focused source-contract gates. The visible log advanced through `app_palette_test.dart`, `stream_feedback_test.dart`, and then `tv_sport_picker_test.dart`, where the supplied excerpt stops during repeated remote-key interactions. The excerpt does not include the final failing test name, timeout exception, or process exit detail. Therefore the exact terminal cause cannot be confirmed from the supplied excerpt alone.

## Bounded test harness adjustment

`test/tv_sport_picker_test.dart` previously used `pumpAndSettle()` after every remote key press and after opening the dialog. The TV focus widgets schedule finite scale/fill transitions and `Scrollable.ensureVisible` animations. `pumpAndSettle()` waits for the entire widget tree to stop scheduling frames, which can stall a test when an unrelated or recurring frame source is present.

The test helper now advances fake time in two deterministic 250 ms pumps after UI/key interactions. This exceeds the known 220 ms focus-scroll and 150 ms focus-scale transitions while avoiding an unbounded wait for global frame quiescence. Each of the three widget tests also has a 30-second test timeout so a future regression reports promptly.

No production widget behavior, navigation behavior, remote key mapping, or sport-selection semantics were changed.

## CI diagnostics

The complete Flutter test command now uses `--timeout 60s` and tees the expanded reporter output to `build-artifacts/full-flutter-test.log`. A dedicated `if: always()` artifact upload retains that complete log even when the test step fails. This is intended to expose the exact failure and stack trace in subsequent runs.

## Validation status

- Source inspection confirms both unbounded `pumpAndSettle()` calls were removed from `tv_sport_picker_test.dart`.
- All three widget tests have explicit 30-second timeouts.
- `test/tv_sport_picker_test.dart` is included in the canonical Phase 37–40 Dart formatter target list.
- Workflow captures the expanded full-suite log and uploads it on failure.
- YAML/format/analyze/test/release execution has **not** been run locally because Flutter and Dart SDKs are unavailable in this environment.
- The visible user-provided excerpt does not include a final exception, so this patch is a bounded-test/diagnostics recovery rather than a claim that a reproduced assertion failure was fixed.

## Next acceptance gate

Rerun GitHub Actions. Require `flutter analyze`, focused tests, the complete Flutter suite, and ARM64 Release build to pass. If the full suite still fails, use the `RAVEN23-full-flutter-test-log` artifact to identify the exact failing test and stack trace before changing application code.
