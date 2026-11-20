# RAVEN23 Source Priority and Scan Order Guardrails

Status: Mandatory repository invariant
Applies to: Choose Source Priority, Check Server Status, Movies, Series, Anime, provider playback scans and stream-quality presentation
Change authority: Only a direct, explicit user request may authorize changing these rules.

## Non-negotiable user source-priority rules

1. PRIMARY and BACKUP are two different, intentional parts of the user's source-selection system. Never delete, disable, empty, merge or replace either lane as a cleanup or health-check side effect.
2. PRIMARY is the fixed user-owned default/manual execution order. Preserve every saved entry and its exact relative position, including the complete tail. Do not auto-rank, auto-sort, append to, promote or demote PRIMARY based on health, speed, quality count, extraction, playback metrics or availability.
3. BACKUP is a separate automatic recovery lane intentionally designed to help when PRIMARY sources fail. It may automatically add/promote sources only after the existing real-playback verification policy is satisfied; automatically-managed BACKUP entries may be ranked using measured real playback reliability/startup evidence. This must never write to or reorder PRIMARY.
4. Preserve manually arranged BACKUP entries and their positions. Automatic ranking may affect only the auto-managed BACKUP portion, not user-pinned entries. Do not remove existing BACKUP entries or change its automatic role.
5. Health checks and extraction-only results are diagnostics; they are not proof of playable video and must not independently add a source to BACKUP. Keep the existing sustained real-playback verification threshold before automatic BACKUP promotion.
6. The built-in category defaults and their current positions are not tuning targets. Do not alter SourcePriorityPolicy defaults or the user's saved ordering unless explicitly requested.
7. Do not change StreamHostPriorityManager.defaultOrder, the saved host order or default positions as part of health checks, speed tests or quality filtering.
8. Check Server Status is diagnostic. It may display each source's result and measured latency, but must not write measured health order into PRIMARY, BACKUP, or the initial source-scan sequence.
9. Continue excluding sources explicitly blocked by the repository's existing safety policy. This safety filter may remove a blocked source from installed/saved lanes as required, but it is not permission to reorder any remaining safe entries.

## Scan-order rules

- The initial Check Server Status sequence is the exact order of the safe source catalogue supplied to the probe service.
- Results must be written back to the matching original source position; completion order must never become display or priority order.
- A playback scan has a global budget of three concurrent providers (or fewer only when fewer than three are eligible).
- Supported engines must not silently reduce the default three-source budget to one or two. All three worker slots remain available while existing deferred-fallback/head-start policy is respected.
- Different QuickJS provider namespaces may run concurrently on Android's dedicated JS isolate. Calls to the same provider remain serialized, and per-source network cancellation remains isolated.
- Unsupported engines may continue to be reported as unsupported and do not consume a source-extraction slot.
- Playback and download must use the same source discovery order and same three-worker scan policy. Download may continue collecting results until its quality catalog is ready, but it must not use a separate sequential first-success loop or reorder the source list.

## Quality-list rules

- A resolution may appear only once in a user-facing quality list.
- When several servers expose the same resolution, keep the actively playing exact source; otherwise use the established source/host selection rules for a deterministic choice.
- Deduplicating a visible resolution row must not erase the underlying provider/server alternatives used for recovery, source switching or diagnostics.
- Size display must be based on the link's signed size token and the configured size-estimation API. Never fabricate a size from resolution, runtime, transfer rate or a different quality entry. Preserve unknown state when no valid estimate is available, and ensure token-to-link association is exact.
- Quality presentation must not mutate PRIMARY/BACKUP priorities or the initial source-scan order.

## Partial offline playback rules

- Download byte percentage is not a playable timeline percentage.
- Partial playback may expose only a verified contiguous playable prefix from time zero; never infer a playable 40% timeline from 40% downloaded bytes.
- Verify manifest/init data and the required audio/video segments for HLS/DASH, or the progressive container's index and readable ranges.
- Playback of partial media must use only locally cached data, stop at the first missing segment/range, prevent seeking beyond the verified boundary and never fall through to network access.
- Preserve downloader writes while playback reads the verified cache prefix. Update the available range as contiguous segments arrive.
- Do not enable partial playback until the above cache-only and contiguous-timeline conditions are implemented and covered by tests for HLS, DASH and progressive files.

## Required regression coverage

- Keep tests proving health results cannot reorder the complete PRIMARY lists for Movies, Series or Anime.
- Keep tests proving automatic BACKUP promotion/ranking works as intended without changing PRIMARY or manually pinned BACKUP order.
- Keep a test proving three same-engine sources can be active at once in the global scan.
- Test that all supported execution engines can use the three scan slots.
- Test that playback and download use the same scan mechanism, source ordering and concurrency budget.
- Test stable source/result positions in Check Server Status under deliberately out-of-order completion.
- Test one visible row per resolution, exact link-size-token association and stable host selection.
- Test size-estimation API failures, missing tokens and mismatched/expired tokens remain safely unknown rather than showing a wrong size.
- Test partial playback's verified contiguous prefix and cache-only behavior before exposing it to users.
- Any future change to these invariants requires a direct user request and tests recording the newly authorized behavior.

## Clarification from the project owner

BACKUP automatic management is an intentional project feature. The guardrail protects PRIMARY from automatic changes; it does not disable the BACKUP recovery system. Automatic BACKUP additions and ranking remain allowed under the sustained real-playback verification rules, while manually configured BACKUP entries keep their pinned positions.
