# Phase 37 — Unified Source Architecture

**Project:** RAVEN23 / CINESTREAM-PRO-N  
**Date:** 2026-11-06  
**Status:** `In Progress — implementation drafted; automated validation pending`  
**Base:** `RAVEN23-PHASE36-COMPREHENSIVE-SOURCE-AUDIT.zip`

## 1. Purpose

Phase 37 establishes additive, shared source contracts above the existing repository manager and engine registry. It does not replace the current engine adapters, alter player hand-off, activate new third-party sources, or migrate persisted source keys.

## 2. Release baseline gate

Before these Phase 37 edits, the repository's GitHub Actions workflow showed a successful default Release APK build:

- Workflow run: `https://github.com/m5ham3ds/RAVEN23/actions/runs/42142404064`
- Commit: `a9d414d` (`Initial commit`)
- Date shown by GitHub: 2026-11-06
- Workflow default: Release (`BUILD_MODE` defaults to `release` for push events)
- Artifact: `RAVEN23-apk`, 24.9 MB

This verifies the remote baseline build for that commit. The workflow run did not run `flutter analyze` or `flutter test`; it performed the Release build and APK audit. It is a baseline result, not validation of the new Phase 37 changes.

## 3. Implemented contract layer

### 3.1 Identity separation — `source_contracts.dart`

Added independent identity representations:

- `SourceRepositoryIdentity`: a canonical comparison identity for an HTTP(S) repository URL; it retains the original untrimmed URL in a private field solely to reproduce the exact legacy key. The comparison key removes URL user-info, query and fragment from its visible URI, while a SHA-256 fingerprint preserves distinction between URLs with different private user-info/query material. This avoids placing raw credentials or tokens in the identity key. The legacy key remains private-sensitive and must not be logged.
- `SourceIdentity`: repository identity plus source ID.
- `SourceEngineIdentity`: engine adapter kind plus normalized and character-allowlisted raw engine type; unusual values collapse to `custom`, and per-source endpoint values are never exposed in diagnostics.
- `SourceContentIdentity`: a normalized local content identity derived from the existing `MediaIdentity` fields, including season/episode and external IDs.

Compatibility rule: `SourceManifest.stableKey` was not changed. `SourceIdentity.legacyStableKey` returns the old repository-url/source-id shape for comparison. No preferences or installed-source records are migrated.

### 3.2 Declarative capability profile

Added `SourceCapability` and `SourceCapabilityProfile` to normalize existing manifest tags and provider-type metadata into the following descriptive capabilities:

- movie
- series
- anime
- live TV
- subtitles
- multiple audio
- universal / multi-content

Profiles preserve a distinction between explicitly declared capabilities and older manifests with no recognized capability tags. Missing legacy tags remain permissive in the descriptive `supportsMedia` helper. Metadata-only declarations (subtitles/multiple audio) do not accidentally block VOD, while a Live-TV-only capability is not eligible for VOD. The `movies-and-series` tag maps to those two capabilities rather than being widened to universal/live-TV support. Anime feature films remain on the movie route but are eligible for a source declaring the anime or movie capability.

Important: the capability profile is not yet wired into source dispatch. Existing `SourceManifest.supportsMedia` behavior remains unchanged in Phase 37. Phase 38 must reconcile anime-series semantics and fixture coverage before the normalized profile becomes an enforcement gate. A manifest declaration is not runtime or playback verification.

### 3.3 Orthogonal lifecycle flags

Added `SourceLifecycleFlag` and `SourceLifecycleSnapshot`. Lifecycle facts are independent flags, not a single mutually exclusive status: for example, an installed source may also be enabled and experimental. A source is not marked `validated` by default; callers must provide an explicit successful validation result.

Supported flags:

`discovered`, `validated`, `installed`, `enabled`, `disabled`, `experimental`, `incompatible`, `failed`, `duplicate`.

Added `SourceRepositoryManager.lifecycleOf(...)` to derive an additive snapshot from existing installation preferences. It respects default-installed sources and the existing disabled-default key list. It does not change the install/uninstall schema.

### 3.4 Execution result / diagnostic separation

Extended `UnifiedSourceResult` with an optional `failureKind`, preserving its existing streams, error message, elapsed time, and constructor compatibility.

Added:

- `SourceFailureKind`
- `SourceAttemptStage`
- `SourceAttemptDiagnostics`

`UnifiedSourceAttempt` now carries optional diagnostics separately from the engine result. The registry records attempt start/end timestamps, elapsed time, engine adapter identity, a classified failure (when present), and retryability. Preflight failures are distinguished from failures returned after an engine starts. Diagnostic labels are categorical and do not duplicate provider exception text, which may contain signed URLs or credentials; the legacy result keeps its original user-facing error message.

The legacy player adapter still consumes the same `result.streams` and `result.errorMessage`; it does not require or interpret diagnostic metadata.

Common failure classification now handles disabled sources, repository-down sources, unsupported engines, cancellation, timeout, network errors, invalid responses, and empty responses. Dio and FormatException mapping is additive. Unsupported engine messages and diagnostic engine identifiers use an allowlisted identity rather than echoing arbitrary raw manifest values. Existing per-engine timeout values are retained; Phase 37 does not impose a new global timeout that could terminate unrelated queued sources.

### 3.5 Cancellation contract

The existing `CancelToken` remains the shared cancellation input to `resolveMany` and each engine. Phase 37 does not create a second cancellation mechanism or alter caller-owned tokens. Engines continue to receive the token; stale UI work prevention remains dependent on the screen/service caller cancelling its token when its request is no longer current. This should receive explicit regression tests in Phase 45.

## 4. Files changed

### Application code

- `lib/video_providers/unified/source_contracts.dart` — new additive identity, capability, and lifecycle contracts.
- `pubspec.lock` — corrected the existing `crypto` lock entry from transitive to direct-main to match its already-declared direct dependency in `pubspec.yaml`; package version and checksum are unchanged.
- `lib/video_providers/unified/source_engine.dart` — typed failure classification and per-attempt diagnostics.
- `lib/video_providers/unified/source_repository_manager.dart` — lifecycle snapshot helper based on existing preferences.
- `lib/video_providers/unified/quickjs_source_engine.dart` — structured empty/network/exception failure kinds.
- `lib/video_providers/unified/openstream_web_embed_engine.dart` — structured empty/bridge/exception failure kinds.
- `lib/video_providers/unified/openstream_anime_engine.dart` — structured network/exception failure kinds.

### Tests added/extended

- `test/video_providers/source_contracts_test.dart` — repository/source/engine identity, exact legacy-key preservation, credential/query fingerprinting, safe engine diagnostic identity, capability normalization, metadata-only and Live-TV-only capability behavior, anime movie/series classification, `movies-and-series` scope, legacy permissive behavior and explicit lifecycle validation.
- `test/video_providers/source_engine_contract_test.dart` — successful result diagnostics, preflight-disabled/unsupported-engine classification, sanitized unsupported-engine messages, retryable timeout diagnostics, generic diagnostic labels and Dio/format failure mapping.
- `test/video_providers/source_repository_manager_test.dart` — default installation and explicit disablement lifecycle behavior.

## 5. Compatibility guarantees retained

- `SourceManifest.stableKey` unchanged.
- Existing SharedPreferences keys and schema unchanged.
- `SourceRepositoryManager` install, uninstall, sync, cache, seed and import/export behavior unchanged except for the additive read-only `lifecycleOf` helper.
- `pubspec.yaml` dependency declarations unchanged; the existing `crypto` direct dependency is now accurately reflected as direct in the lock metadata without changing the locked version or checksum.
- `SourceEngineRegistry` registration, engine selection, priority ordering and default sequential execution unchanged.
- `UnifiedStreamOption` and player stream hand-off unchanged.
- Legacy adapters continue reading the existing result fields.
- `MediaKind` and `UnifiedMediaType` enums unchanged.
- No edits to player UI, Live TV UI/services, repository parser, Stremio manifest logic, VidKing filtering, QuickJS settings injection, source activation, or third-party scripts.

## 6. Validation state

| Check | State | Notes |
|---|---|---|
| Base Release CI | Passed | GitHub run `42142404064`, commit `a9d414d`, before Phase 37 edits |
| Source diff review | Completed | Targeted additive changes; URL privacy fingerprints, safe engine identities, capability-scope edge cases, explicit validation state and legacy whitespace key preservation are covered in test source |
| Persisted key compatibility review | Completed | Existing `stableKey` and preference key names unchanged |
| Dependency lock metadata review | Completed | Existing `crypto 3.0.6` direct dependency now correctly marked direct-main; version and checksum unchanged |
| `dart format` | Not run | Dart SDK unavailable in the working container |
| `flutter analyze` | Not run | Flutter SDK unavailable in the working container |
| `flutter test` | Not run | Flutter SDK unavailable in the working container |
| Post-change Release CI | Pending | Must run on the Phase 37 archive/commit; baseline success is not a substitute |
| Runtime/playback smoke tests | Not run | No external sources activated in this phase |

## 7. Deferred to later phases

- Enforcing normalized capabilities and mapping `MediaKind` / `UnifiedMediaType`: Phase 38.
- Strict season/episode matching: Phase 38.
- QuickJS user settings schema, persistence and runtime injection: Phase 39.
- Stremio `configurable` / `configurationRequired`: Phase 40.
- VidKing audio-language / quality separation: Phase 41.
- Repository version pins, content hashes, duplicate resolution and permission review: Phase 42.
- Broad OpenStream and Zangetsu/Spyhell source activation: Phases 43–44.
- Concurrency, ranking, circuit breaker and fallback policy: Phase 45.
- Unified Live TV manager and IPTV: Phases 46–49.
- WebView session lifecycle: Phase 50.

## 8. Phase 37 acceptance decision

The additive architecture contracts are implemented in the working project and targeted tests have been authored. Phase 37 is **not marked Passed/Accepted** until formatting, analysis, tests and a post-change Release build succeed. Do not begin broad source activation on the basis of the baseline Release run alone.

## 9. Rollback

Revert the six application-code files, three test files, and the `pubspec.lock` direct/transitive metadata correction. No persisted-key or SharedPreferences migration is required.
