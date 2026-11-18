# Phase 45 — Tests and Validation

## Added focused scheduler tests

File: `test/video_providers/unified_source_service_execution_test.dart`

1. First playable callback fires before a slower primary source completes.
2. A fallback source gets a reserved worker after the head-start window.
3. Returned attempts remain in deterministic priority order despite out-of-order completion.
4. Last successful source is promoted to the head of the next scan.
5. Only streams with explicit future expiry are cached.
6. Streams with no declared expiry are not cached.
7. Repeated retryable network failures open the circuit temporarily; a post-cooldown half-open probe is permitted.
8. Cache entries are isolated by preferred audio language.
9. Cache entries are invalidated when a source descriptor/revision changes.
10. Per-engine semaphore limits are respected.
11. Metrics retain only the coarse HTTP status class.
12. Cancellation prevents late results and callbacks from being delivered.
13. Grouped source search skips saturated QuickJS slots for other ready engines. The separate `test/video_providers/provider_scan_engine_fairness_test.dart` verifies that a saturated QuickJS queue does not occupy all player-scan workers while a ready Stremio provider is available.

## Combined bounded CI gate

The automatic APK workflow is updated to a curated 19-file test set spanning deferred Phase 37–43 dependencies plus Phase 44 and Phase 45. It does not run the complete Flutter test tree or broad unrelated widget batches. Test timeout remains 30 seconds per test, four test processes maximum, and the focused job cap remains 10 minutes.

## Not claimed

No test in the packaging environment was executed because Flutter/Dart SDK executables are unavailable. Formatting/analyze/test/Release ARM64 and Android device playback remain pending. The 8-second value is the established fallback policy from the current app flow; policy limits still require real CI/device timing review. Cache keys include playback identity, source descriptor fingerprint and preferred audio language so language or repository updates cannot reuse stale links.

## CI fixture note — 2026-11-08

The standard registry retains strict DNS validation by default. Tests that use fake `.example` endpoints and a mocked Dio adapter inject `SourceHostPolicy(resolveDns: false)` explicitly; this is test-only and does not alter production host validation.
