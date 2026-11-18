# Phase 45 — Implementation Record

## Implemented

- Added `SourceExecutionPolicy` with bounded global and per-engine concurrency.
- Added a FIFO semaphore with permit transfer to waiters to prevent exceeding the configured engine limit.
- Added hash-only last-working-source persistence with an in-process fallback when platform preferences are unavailable.
- Reworked `UnifiedSourceService.search()` into a bounded primary/fallback scheduler. It reserves a fallback worker when possible, starts fallback after eight seconds or primary completion, and preserves deterministic attempt ordering.
- Added `onFirstPlayable`, invoked at the first playable completion without waiting for the remaining sources. Ongoing work continues unless the caller cancels.
- Added health ranking inside equal manifest-priority groups after at least two observations per provider; failure rate precedes average latency, with stable source key as the final tie-breaker.
- Added in-memory LRU result cache. A result is cached only if all returned streams declare a future expiry; the cache is bounded and never invents TTL.
- Added temporary circuit breaker for retryable network/timeout failures; it uses cooldown and a single half-open probe. Non-retryable/empty responses do not add to the breaker count.
- Added cancellation checks before dispatch and before callbacks; late results are discarded after cancellation.
- Added bounded, privacy-safe execution metrics with source ID, hashed source identity, engine, latency, result count, failure category, optional HTTP class, cache-hit flag and UTC timestamp.
- Added coarse HTTP status classes (`4xx`/`5xx`) where Dio exposes a response status; no URL or response payload is recorded.

## Existing player behavior preserved

Movie and episode loading continues to use `ProviderScanSession`, which already supports an 8-second fallback head-start and first-playable return for the individual `VideoProvider` entries. This phase supplies equivalent bounded scheduling and first-result behavior to the unified service facade, without replacing current BetterPlayer adapters or reducing returned stream choices.

## Privacy and safety

- Persistent last-working state contains only SHA-256 digests of media identity and stable source identity.
- Resolved URLs and headers remain in process memory only and are discarded at their explicit expiry.
- Metrics never retain media title, request URI, stream URL, header or token.
- Circuit breaker is temporary; it does not uninstall or permanently disable a source.


## Player scan integration

The existing `ProviderScanSession` remains the source of truth for the mobile/TV player: it still returns the first playable provider, continues gathering alternatives/qualities, and opens Web Embed fallback after its existing 8-second head-start (or earlier when the primary queue is exhausted). Its worker scheduler now checks per-engine capacity before claiming a provider. The unified service's multi-source scheduler applies the same availability-aware selection to each candidate queue. A worker skips currently saturated engine queues and can claim a ready provider from another engine, preventing QuickJS waiters from occupying all three playback workers. The shared `SourceExecutionPolicy` limits are therefore enforced both at the player scan boundary and inside the unified service for grouped/direct callers.

Cache identity includes playback identity plus sorted external IDs/episode air date, a SHA-256 fingerprint of the source version/engine descriptor/configuration, and normalized preferred audio language. Changing language or updating a source descriptor therefore cannot reuse a still-unexpired link from a different request context. Health ranking excludes cache hits, cancellations and circuit-open preflight attempts so waiting on the breaker does not count as a new source failure or zero-latency success.
