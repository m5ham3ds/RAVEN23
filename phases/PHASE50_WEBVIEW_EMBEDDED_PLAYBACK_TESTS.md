# Phase 50 — WebView & Embedded Playback Tests

**Date:** 2026-11-08

## Added focused contract tests

`test/video_providers/phase50_embedded_playback_test.dart` now contains six focused cases covering:

1. Embedded marker and manual-verification metadata survive serialization/copying.
2. HTML embed pages are omitted from BetterPlayer URL/format/header maps.
3. An early embedded-only result does not prevent a later direct provider result from being selected.
4. An embedded-only unified result is a browser handoff candidate but not a direct stream success.
5. Legacy embedded links remain outside the unified direct-stream list and preserve manual-verification state.
6. The first embedded-only result is retained as fallback only after the queue has no direct stream.

## Configured CI coverage

- The automatic CI contract gate is extended from 28 to 29 explicit test files.
- `tool/format_phase37_50_dart.sh` lists 91 unique existing Dart files, including all Phase50 Dart implementation and test files.
- Existing Phase37–49 tests remain in the gate.

## Execution status

Dart/Flutter SDKs are unavailable in this packaging environment. No `dart format`, `flutter analyze`, `flutter test`, Kotlin/Gradle compilation or APK build was executed here. The CI gate is configured but its result is pending.

## Manual device checks still required

- Verify provider pages that require first-party cookies and user interaction on Android Mobile and Android TV.
- Verify focus/remote navigation for each provider's embedded controls.
- Confirm WebView destruction on route exit and that no resolver continues loading indefinitely.
- Confirm supported sources do not require blocked third-party cookies or mixed HTTP content; unsupported pages must fail clearly rather than weaken the network policy.
