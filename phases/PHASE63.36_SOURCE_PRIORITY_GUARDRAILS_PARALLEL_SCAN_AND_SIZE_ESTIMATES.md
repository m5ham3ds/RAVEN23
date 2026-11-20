# PHASE63.36 — Source Priority Guardrails, Unified Three-Worker Scan and Size Estimate Integrity

Date: 2026-11-20
Status: Code changes committed to main; CI verification pending
Scope: Only the source priority/scan-order, video-source scanning, download size-estimation and partial offline playback requirements raised by the project owner.

## Owner-confirmed source-priority intent

- PRIMARY is the preserved default/user execution order. It is not health-ranked or automatically sorted.
- BACKUP is a deliberately separate recovery lane designed to collect/promote useful sources when PRIMARY sources fail. The automatic BACKUP mechanism must remain enabled and must not be emptied or removed as a cleanup.
- Sustained real-playback evidence remains the promotion condition. Health-check reachability or a returned URL alone is not proof of playable video.
- Manually arranged BACKUP entries retain their exact relative positions. Automatically managed BACKUP entries may be ranked using actual playback reliability and startup evidence.
- BACKUP updates must never rewrite PRIMARY.
- The initial source-status scan uses the supplied safe catalogue order. Three probes run concurrently, but returned results and on-screen rows retain their original input positions.
- Playback and download must use the same ordered source list and the same three-worker scan mechanism.
- Do not change the configured category defaults, saved source lists, host defaults or unrelated screens without a direct user request.

## Implemented changes

1. Updated `RAVEN23_SOURCE_PRIORITY_AND_SCAN_ORDER_GUARDRAILS.md` to distinguish the protected PRIMARY order from the intentional automatic BACKUP recovery lane.
2. Updated `SourcePriorityManager` documentation to accurately describe PRIMARY and automatic BACKUP responsibilities; kept its verified playback promotion and automatic-only ranking implementation.
3. Updated `UnifiedSourceService.configureRecommendedSources`:
   - Removed the migration that detected an old auto-generated BACKUP list and cleared it.
   - Removed the PRIMARY migration side-effect that pruned/replaced BACKUP.
   - Removed first-run code that explicitly wrote an empty BACKUP list as part of initialization.
   - A missing lane may still be initialized as empty without modifying a lane that already exists; verified playback can continue to populate BACKUP through its established promotion path.
4. Replaced the sequential implementation behind the legacy `ProviderLoader.loadFirstSuccessful` entry point with the common `ProviderScanSession`, using a global maximum of three workers and the same fallback release behavior. Existing API shape remains for compatibility.
5. Updated provider-loader tests to assert that three source requests start together and that subsequent sources start after a failed batch.
6. Added a source-health probe regression test that deliberately completes probes out of order and verifies:
   - Exactly three probes start in the initial batch.
   - A fourth starts as a worker is released.
   - Returned results are still in the exact original source order.
7. Bound each quality catalog size-estimate cache key to the exact signed `sizeToken`, preventing reuse of an estimate when a URL/source quality is refreshed with a different token.
8. Validated backend `estimatedBytes`: zero, negative and malformed values remain unknown.
9. Applied the same positive-value check to the shared `StreamSizeEstimator`.
10. Added quality-catalog tests for token identity and missing-token behavior.
11. Updated `PHASE63.34_PARTIAL_OFFLINE_PLAYBACK_DESIGN.md` with a 2026-11-20 revalidation. The completed-state guard is deliberately retained because there is still no verified contiguous local timeline reader/bridge for HLS, DASH and progressive streams. Do not claim partial playback is implemented.

## Existing behavior verified by code inspection (not live device proof)

- `SourceHealthProbeService.checkVideoSources` already uses `min(3, sources.length)` workers and stores each result in the matching source index before returning the ordered result list.
- `SourceHealthSessionController` replaces a result by its stable source identity, not by completion order.
- `ProviderScanSession` already starts a bounded worker set with a maximum of three and preserves the submitted provider list as the source index basis.
- The quality catalogue already retains exact source alternatives internally while presenting one row per quality; this phase does not change the default host order.
- The download picker uses signed size tokens when available. Providers without usable tokens remain explicitly unknown.

## Not changed

- Source default PRIMARY order and its saved positions.
- StreamHostPriorityManager.defaultOrder or any saved host order.
- Hentai exclusion behavior or any safety list.
- Check Server Status probe category/health semantics.
- Download service storage safeguards and download formats.
- Completed-download offline playback implementation.
- Any unrelated UI, navigation, screens, assets, or backend configuration.

## Remaining acceptance boundary

- GitHub Actions must pass Flutter formatting/analyze, focused Flutter tests, Android offline-download/contract tests, ARM64 release build and APK audit on the final commit.
- Real-device checks are still needed for observed simultaneous network requests, actual BACKUP persistence across app restarts, signed size estimate correctness against the live API, and player/download UI behavior.
- Partial offline playback remains not implemented. It requires cache-only verification of a contiguous playable prefix and tests for HLS, DASH and progressive MP4 before the completed-state guard may be relaxed.
