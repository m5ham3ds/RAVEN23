# Phase 43 — OpenStream Sources Integration Plan

**Base:** `RAVEN23-PHASE42-IMPLEMENTATION-PENDING-CI.zip`  
**Status:** Implementation prepared; CI pending.  
**Start decision:** The user explicitly requested proceeding to the next phase without waiting for Phase 42 CI. This is a sequencing decision, not acceptance of Phase 41 or Phase 42.

## Goal

Integrate and validate the OpenStream entries against the existing RAVEN23 source architecture. Reuse `SourceRepositoryParser`, `SourceEngineRegistry`, the existing VidKing Direct adapter, OpenStream Web Embed adapter, OpenStream Anime adapter, and `UnifiedStreamOption`. Do not create a second source registry or change the player engine.

## Live upstream index checked 2026-11-07

`https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json`

The retrieved index contains 30 entries:

| Engine family | Entries | Upstream status | Runtime path |
|---|---:|---|---|
| `vidking-direct` | 9 | status 1 (OK) | `VidkingDirectSourceEngine` |
| Native anime (`anikoto`, `reanime`, `animepahe`, `fouranimo`, `animegg`) | 5 | status 3 (Beta) | `OpenStreamAnimeSourceEngine` |
| `stremio` | 5 | status 3 (Beta) | `StremioSourceEngine` |
| `web-embed` | 10 | status 3 (Beta), fallback | `OpenStreamWebEmbedSourceEngine` |
| `vidking-webview` | 1 | status 2 (Slow), fallback | `OpenStreamWebEmbedSourceEngine` |

Counts are per entry, not globally deduplicated by hostname or stream provider.

## Work scope

1. Check the live index against the local fixture, `sourceEngineKindFrom`, and `SourceEngineRegistry.standard`.
2. Preserve every upstream source id, route, media declaration, priority, install-default flag and status. Do not silently reorder or alter upstream metadata.
3. Keep the nine VidKing Direct routes distinct. Yoru/Cypher/Breach/Neon retain the first-priority order; Omen/Raze remain later alternatives; Vyse/Fade/Killjoy retain Phase 41's independent audio-language compatibility behavior.
4. Keep five native anime engine types separately identifiable through their raw engine ids, even though they share `SourceEngineKind.animeSite`.
5. Preserve Beta/Slow/fallback lifecycle metadata and upstream installation defaults (including default Anikoto/Re:Anime). Beta means experimental, not disabled; only explicit status 0 is down.
6. Exercise movie and exact season/episode request contracts using deterministic Dio interceptors; exercise anime S2E4 and anime-film mapping using deterministic ani.zip/AniList fixtures.
7. Preserve quality, audio language/type, subtitles, request headers, and explicit provider expiry metadata in `UnifiedStreamOption`.
8. Never claim `Playback Verified` from fixture responses. Device playback with actual URLs is a separate acceptance gate.

## Explicit exclusions

- No player/BetterPlayer/Media3 engine changes.
- No rewrite of `ProviderLoader` ranking or fallback scheduling.
- No automatic promotion of Beta sources to status 1.
- No attempt to bypass Cloudflare/Turnstile for AnimePahe; unsupported interactive challenges remain visible as a limitation.
- No new extension families from Zangetsu/Spyhell; those belong to Phase 44.

## Acceptance criteria

- The fixture parses all 30 entries with the expected engine family counts.
- Every VidKing id maps to its exact upstream route, and movie/series requests use the right query coordinates.
- Native anime raw engine identifiers remain distinct and the tested Re:Anime adapter maps the supported episode/movie identities correctly.
- Web Embed movie and TV templates remain present and correctly parameterized.
- Beta/Slow/fallback states survive parsing and lifecycle classification.
- Explicit expiry metadata is forwarded only when supplied by the source; no TTL is invented.
- The focused 15-file dependency/source CI gate, Analyze, formatter and Release ARM64 build pass.
- Live playback remains unverified until an actual URL plays on a supported Android device.
