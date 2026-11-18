# Phase 45 — Source Execution, Ranking & Fallback Plan

**Base:** Phase 44 implementation worktree.  
**User direction:** Prepare Phase 44 and then Phase 45 before uploading/running the deferred phase validation gates.  
**Status:** Implementation prepared; combined CI pending.

## Requirements

1. Preserve `ProviderScanSession` as the player-facing scan coordinator and its 8-second fallback head-start; add engine-aware slot selection so a saturated QuickJS queue cannot occupy all global workers while other engines are ready. The unified service retains a bounded all-sources scheduler for direct/grouped callers without replacing the existing player adapter.
2. Add a bounded execution policy by engine kind, with no unbounded parallel source requests.
3. Deliver the first playable source immediately through a callback while the remaining scan continues.
4. Keep final result ordering deterministic: explicit manifest priority first, measured health/latency only after repeated observations, stable source key as tie-breaker.
5. Remember the last successful source using a hash-only preference key/value; never persist a source URL or playback title.
6. Cache resolved links in memory only and only when every cached link has an explicit future `expiresAt`; no inferred TTL. Cache keys are salted by the media identity (including external IDs and episode air date), source descriptor/revision fingerprint, and preferred audio language.
7. Circuit-break repeated network/timeout failures temporarily (default 5 failures / 2-minute cooldown); empty results and content mismatches do not permanently disable providers.
8. Respect cancellation and suppress progress/first-result callbacks after cancellation.
9. Keep bounded in-memory metrics for latency, result count, failure category, HTTP status class when known, cache hits and timestamps. Do not send stream URLs, tokens, headers or titles to analytics.
10. Preserve alternative servers, language/subtitle/header metadata and user selection through the current stream adapter.

## Default policy

- Maximum concurrent source workers: 3.
- Per-engine limits: QuickJS 1; Anime 2; Stremio 2; VidKing Direct 2; Web Embed/WebView 1; native/legacy/unsupported 1.
- Fallback head-start: 8 seconds, or earlier when primary providers finish.
- Circuit breaker: 5 retryable failures, 2-minute cooldown, one half-open probe.
- In-memory source-result cache: maximum 120 identities; cache expiry is the earliest explicit source-provided expiry.
- In-memory diagnostic ring: maximum 200 records.

These are bounded defaults and are constructor-configurable. They are not claims of measured production-optimal timings; the next CI/device runs will provide first timing evidence.
