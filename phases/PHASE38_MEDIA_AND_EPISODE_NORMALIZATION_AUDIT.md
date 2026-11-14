# Phase 38 — Pre-implementation Audit

**Date:** 2026-11-06  
**Base archive:** `RAVEN23-PHASE37.1-VALIDATION-GATES-AND-AUDIT.zip`

## 1. Scope inspected

Inspection was limited to the Phase 38 file boundaries and the direct identity/engine/test dependencies described in the Blueprint. The project was not re-audited as a whole.

## 2. Existing contracts reused

- `lib/catalog/media_item.dart`: application `MediaKind` is already limited to `movie` and `series`.
- `lib/video_providers/unified/media_identity.dart`: `MediaIdentity` already carries TMDB ID, nullable season and episode, episode TMDB ID, air date, and an external-ID map for provider IDs.
- `lib/video_providers/unified/media_identity_resolver.dart`: existing IMDb enrichment calls the TMDB movie/TV external-ID endpoint.
- `lib/video_providers/unified/source_contracts.dart`: Phase 37 already introduced source/content identity and capability profiles.
- `lib/video_providers/unified/source_manifest.dart`: existing source compatibility checks distinguish anime-only providers and multi-content providers.
- `lib/video_providers/unified/quickjs_source_engine.dart`: QuickJS already separates search, details/episodes, and stream extraction. Its previous episode loop allowed a missing provider season to match a requested season and accepted a number-only episode match.
- `lib/video_providers/unified/stremio_addon_provider.dart`: Stremio routes by `movie`/`series` and builds episode IDs from season + episode, but lacked an early completeness guard.
- `lib/video_providers/unified/vidking_direct_provider.dart`: series requests previously substituted `1` for missing season/episode values.
- `lib/video_providers/unified/openstream_anime_engine.dart`: existing AniList/ani.zip mapper already distinguishes `MOVIE` from TV mappings and has a content-type-specific in-memory cache key.
- `lib/video_providers/unified/openstream_web_embed_engine.dart`: existing Web Embed templates already have separate movie and TV paths.
- `lib/video_providers/provider_loader.dart`: existing identity factories were the centralized construction points for movie and episode playback identities.

## 3. Confirmed gaps

1. QuickJS's previous condition treated a missing provider season as compatible with any requested season.
2. Its number parser could extract a numeric fragment from a field and truncate fractional values, making ambiguous metadata eligible.
3. `UnifiedMediaType.anime` appeared in the source identity layer despite the app-level `MediaKind` correctly using `series` for episodic content.
4. Anime/Donghua/Animation were not represented as separate editorial classifications in `MediaIdentity`.
5. Stremio and VidKing did not reject incomplete series coordinates before their network paths.
6. VidKing populated missing episode and season query parameters with `1` for all media kinds.
7. `SourceManifest` recognized `anime` but not `donghua` when determining explicitly anime-exclusive JavaScript providers.

## 4. Preservation checks

- No need to replace `SourceEngineRegistry`, `SourceRepositoryManager`, QuickJS runtime, Stremio adapter, VidKing implementation, OpenStream Anime engine, Web Embed bridge, or player.
- AniList/MAL/IMDb identifiers remain in `externalIds`; TMDB and episode identifiers remain in their existing fields.
- Anime feature films continue to use the Movie path; only episodic anime/donghua uses Series.
- No user-data migration is required by the Phase 38 contract. The normalized playback-stream cache key will distinguish the new normalized type and classification; prior cache entries may naturally miss.

## 5. Dependency gate

The latest archive's Tracker still records Phase 37 and 37.1 as pending post-change validation. Phase 38 changes may be reviewed and tested in the worktree, but acceptance remains blocked until those prerequisite gates produce real CI evidence. No Phase 39 work is started.
