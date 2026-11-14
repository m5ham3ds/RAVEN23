# Phase 44 — Zangetsu & Spyhell QuickJS Integration Plan

**Base:** `RAVEN23-PHASE43-IMPLEMENTATION-PENDING-CI.zip`  
**Execution decision:** Start Phase 44 immediately at the user's explicit direction; Phase 41/42/43 CI acceptance remains pending.  
**Status:** Implementation prepared; CI/runtime validation deferred until Phase 44 and 45 are both prepared.

## Scope

1. Reuse the already registered QuickJS runtime and six bundled repository URLs. Do not duplicate repositories or auto-install catalog entries.
2. Parse Zangetsu `sources[]` entries without rewriting upstream `type`, `version`, language or install state.
3. Keep `movie`, `series`, `anime` and `all` declarations distinct. A source that declares `movie` is not promoted to `all` or `series` because its script contains suggestive helper code.
4. Surface missing `nsfw` declarations as **unknown**, not as an explicit safe declaration. Preserve explicit `true`/`false` values.
5. Classify known Spyhell `getHome()` channel-group entries as Live TV candidates and prevent dispatch through VOD Movie/Series resolution. The dedicated Live TV adapter remains Phase 46/47 scope.
6. Label known archive catalog candidates separately. This label is not a legal-rights clearance or a playback verification.
7. Flag account-backed/credential-requiring candidates for review; do not fabricate credentials or auto-enable them.
8. Keep duplicate candidates visible and reviewable; never delete or silently deactivate an alternative.

## Source review baseline (2026-11-07)

Six bundled catalogs were checked directly:

- OpenStream Official: 30 records.
- Spyou Zangetsu Providers: 9 records.
- Serenity-MIST Zangetsu Sources: 5 records.
- Spyhell Experiment: 89 records.
- Spyou Additional Providers: 5 records.
- Spyhell Latin Sources: 4 records.

These 142 index records are discovery metadata, not 142 playback-verified providers. The Spyhell Experiment index does not declare an `nsfw` value on its entries; the parser therefore reports that safety declaration as unknown.

## Explicit source-contract cautions

- The inspected 4K HDHub and UHD Movies scripts declare `getInfo().type = movie`; neither is silently upgraded to Series.
- Serenity CineStream's current script declares Movie even though its source contains hints of series paths. Series stays blocked until a separate tested contract override is prepared.
- HiAnime, AnimeSuge, AnimeX and AnimeSalt are anime candidates, but source-index presence or static code inspection does not prove their remote extraction hosts work today.
- Spyhell channel-group IDs (`worldlivetv`, `livetvindia`, `sportslivetv`, `movieslivetv`, `newslivetv`, `documentarylivetv`, `entertainmentlivetv`, `serieslivetv`, `animationlivetv`, `musictv`, `kidstv`, `comedytv`, `travellivetv`, `cookinglivetv`, `educationlivetv`) are routed away from VOD dispatch for the dedicated Live TV phase.
- AnimeAV1, AnimeJL, JKanime and AnimeYTX remain catalog candidates. Duplicate JKanime entries must be compared by repository/script identity before any user-facing selection is changed.

## Acceptance boundary

The local changes in this phase qualify and route catalog candidates safely. They do not install all entries, execute every remote script, test search with live accounts, verify playable streams, grant rights to archive titles, or implement Live TV. Those checks remain explicit CI/device/source qualification gates.
