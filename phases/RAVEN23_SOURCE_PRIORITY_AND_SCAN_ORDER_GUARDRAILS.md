# RAVEN23 Source Priority and Scan Order Guardrails

Status: Mandatory repository invariant
Applies to: Choose Source Priority, Check Server Status, Movies, Series, Anime, provider playback scans and stream-quality presentation
Change authority: Only a direct, explicit user request may authorize changing these rules.

## Non-negotiable source-order rules

1. Never reorder, replace, auto-rank, auto-sort, append to, promote or demote a user's saved PRIMARY or BACKUP entries because of health results, response time, quality count, successful extraction, failure count or availability.
2. The complete user-defined ordering in each category is meaningful. Do not protect only the first 12 Movies/Series entries or first 14 Anime entries while silently rebuilding the tail.
3. The built-in category defaults, including existing Movies/Series and Anime source positions, are not tuning targets. Do not alter the default SourcePriorityPolicy or SourcePriorityManager behavior unless explicitly requested.
4. Do not change StreamHostPriorityManager.defaultOrder, the saved host order or its default positions as part of health checks, speed tests or quality filtering.
5. Check Server Status is diagnostic. It may display each source's result and measured latency, but it must not write measured order back to source priority storage.
6. Continue excluding and uninstalling sources explicitly blocked by the repository's existing safety policy. This safety filtering is not permission to reorder any remaining safe entries.

## Scan-order rules

- The initial check sequence is the exact order of the safe source catalogue supplied to the probe service.
- Results must be written back to the matching original source position; completion order must never become display or priority order.
- A playback scan has a global budget of three concurrent providers (or fewer only when fewer than three are eligible).
- Supported engines must not silently reduce the default three-source budget to one or two. All three worker slots remain available to primary sources while deferred fallbacks wait behind their existing head-start gate.
- Different QuickJS provider namespaces may run concurrently on Android's dedicated JS isolate. Calls to the same provider remain serialized, and per-source network cancellation remains isolated.
- Unsupported engines may continue to be reported as unsupported and do not consume a source-extraction slot.

## Quality-list rules

- A resolution may appear only once in a user-facing quality list.
- When several servers expose the same resolution, keep the actively playing exact source; otherwise choose from measured playback reliability, failure ratio and startup time, using the existing configured host order as the deterministic fallback.
- Deduplicating a visible resolution row must not erase the underlying provider/server alternatives used for recovery, source switching or diagnostics.
- Quality presentation must not mutate PRIMARY/BACKUP priorities or the initial source-scan order.

## Required regression coverage

- Keep tests proving that health results cannot reorder the complete Movies, Series or Anime PRIMARY list.
- Keep a test proving three same-engine sources can be active at once in the global scan.
- Test that all supported execution engines can use the three scan slots.
- Test one visible row per resolution, active-source preference and stable host selection.
- Any future change to these invariants requires a direct user request and a test that records the newly authorized behavior.

## Recent correction

A measured-health ranker previously preserved the fixed prefix but rebuilt the remaining PRIMARY tail from health results. That still changed user-owned ordering. It has been disabled: safe existing entries retain their exact relative order; health results remain diagnostic only.
