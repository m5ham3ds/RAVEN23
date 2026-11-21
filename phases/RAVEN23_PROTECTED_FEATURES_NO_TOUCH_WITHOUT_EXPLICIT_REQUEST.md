# RAVEN23 — Protected Features / No-Touch Rule

**Status:** ACTIVE — binding project-maintenance rule  
**Effective baseline:** main at 6d12023e446db3d444716c3b407572a89cf545be (GitHub Actions #249 passed)  
**Purpose:** prevent unrelated regressions caused by changing features that the project owner has already reviewed and accepted.

## 1. Absolute authorization rule

No protected feature, behavior, UI, file group, API contract, configuration, test gate, or implementation may be modified unless the owner explicitly names that feature and directly requests the change in the current instruction.

A request to work on another feature does not grant permission to:
- refactor, modernize, clean up, rename, reorganize, replace, or reformat protected code;
- alter protected defaults, priorities, ordering, fallbacks, timing, state, storage paths, or user-visible behavior;
- change tests, CI expectations, or documentation in a way that silently changes the protected contract;
- make an adjacent change merely because it appears technically convenient.

A general instruction such as “improve subtitles”, “fix playback”, “review the project”, or “make it better” is not authorization to change every related subsystem. Only the explicitly named task is in scope.

If the requested task cannot be completed without changing a protected feature, stop before that change. Explain the exact dependency and request direct authorization for that specific protected part. Do not silently widen the scope.

## 2. Protected and accepted feature groups

The following groups are frozen unless the owner explicitly reopens the exact group.

### A. Accepted offline player and episode-list behavior
- The shared player surface and the existing online-player behavior.
- Offline playback using the accepted player path.
- Full episode cards in the offline episode list, matching the online card fields and presentation: episode artwork, title, rating, runtime, and overview where metadata exists.
- Offline season selection and switching among seasons that have completed local downloads.
- The stored episode/season metadata contract used to reconstruct those cards.
- Local episode selection and transitions.

### B. Accepted video download, cache, and phone-save behavior
- Current download source selection and download identity.
- Download queue, progress, pause/resume, recovery, and storage-reserve behavior.
- The existing validated offline export and DCIM/RAVEN23 video-copy behavior.
- Existing cache identity, HLS/DASH request headers, signed-link recovery, and completed-file validation.

### C. Deferred video-plus-subtitle phone export
- Copying a selected subtitle sidecar beside the exported video under DCIM/RAVEN23/<title>/SUBTITLE.
- The intended same-stem naming and subtitle extension.
- This item is explicitly DEFERRED because the owner says the subtitle sidecar is still not working and has chosen to postpone it.
- Do not reopen, retry, redesign, or change this deferred export path during unrelated subtitle-provider work. It may be changed only after a later direct request explicitly asks to resume the video-plus-subtitle phone-export issue.

### D. Accepted online playback and source-selection behavior
- Active stream/provider stability while background scans run.
- Provider catalog membership and provider identity.
- PRIMARY and BACKUP ordering and priority policy.
- Quality catalog, quality-selection policy, selected source identity, and HLS/DASH source handling.
- Signed URL refresh and recovery behavior.
- Existing video/audio track behavior.

### E. Other accepted application areas
- Home, Movies, Series, Anime, Manga, navigation, and their accepted page layouts and interactions.
- Firebase, authentication, backend API contracts, Laravel/Render/Cloudflare integration, and related rules.
- Build configuration, ABI targeting, and unrelated CI gates.

## 3. Rules for any future authorized change

1. State the exact requested feature and its allowed file scope before editing.
2. Read this rule and the relevant phase documents before touching code.
3. Make the smallest implementation that satisfies the explicit request.
4. Do not combine unrelated fixes, refactors, formatting sweeps, or opportunistic cleanups in the same change.
5. Keep protected behavior unchanged and add regression tests for the boundary that must remain stable.
6. Before committing, compare the complete changed-file list against the explicit scope. Revert every unrelated change.
7. If a protected file must be touched for an explicitly authorized task, explain why in the phase record and test that its unrelated behavior remains unchanged.
8. Do not weaken, skip, delete, or rename tests to obtain a passing build.
9. A successful CI build proves only the checks it actually executed; skipped checks must never be reported as passing.

## 4. Required declaration in every future phase

Every new implementation phase must include a “Protected-scope impact” section declaring:
- the exact protected group(s) that were not changed;
- any protected file that was necessarily touched and the directly authorized reason;
- the regression tests proving unrelated behavior remained intact;
- the exact changed-file list.

A phase that does not provide this declaration is not ready for implementation review.

## 5. Current work boundary

The current new work is limited to researching and planning improvements to Arabic external subtitle discovery, matching, synchronization, and provider fallback. It does not authorize changes to the protected offline player, episode-list UI, download/export behavior, phone-save behavior, provider-video ordering, quality policy, navigation, Firebase, or backend contracts.

The deferred video-plus-subtitle DCIM export problem remains closed until the owner explicitly reopens it.

**This rule takes precedence over assumptions, inferred scope, and convenience. A direct owner instruction is the only way to reopen a protected feature.**
