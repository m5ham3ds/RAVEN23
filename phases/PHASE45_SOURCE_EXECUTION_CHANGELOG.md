# Phase 45 — Changelog

- Added `lib/video_providers/unified/source_execution_policy.dart`.
- Added bounded scheduling, first-playable callback, health-aware stable ordering, expiry-safe cache, circuit breaker and privacy-safe metrics to `lib/video_providers/unified/unified_source_service.dart`.
- Extended `UnifiedSourceResult` with optional coarse HTTP status class and populated it where Dio exposes status responses in VidKing, Stremio, QuickJS, OpenStream Anime and Web Embed adapters.
- Added `test/video_providers/unified_source_service_execution_test.dart` with 13 focused scheduler, cache, circuit, fairness, cancellation and concurrency cases.
- Added `tool/format_phase37_45_dart.sh` and updated `.github/workflows/android-ci.yml` to format and run the exact selected 19-file deferred-phase/Phase44/Phase45 gate before Android Release.
- Preserved the older formatter script for compatibility; the new workflow uses the Phase37–45 script.

- Updated the existing `ProviderScanSession` to select work by per-engine capacity, avoiding QuickJS head-of-line blocking while preserving the player-facing first-playable contract and 8-second fallback timer. Added a separate regression test for the actual player scan scheduler.

## CI recovery follow-up — 2026-11-08

- Added an injectable `SourceHostPolicy` parameter to `SourceEngineRegistry.standard`; its production default remains DNS-resolving and fail-closed.
- Updated only the two mocked-Dio Stremio registry tests to use `SourceHostPolicy(resolveDns: false)`, so fake `.example` hosts reach the test adapter without weakening application networking policy.
- The 13 dedicated `UnifiedSourceService` execution cases and player scan fairness case passed in CI run `42424422614`; the two Stremio registry cases failed during DNS preflight and are covered by this test-fixture correction.
