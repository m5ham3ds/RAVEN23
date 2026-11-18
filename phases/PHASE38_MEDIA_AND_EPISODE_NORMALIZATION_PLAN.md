# Phase 38 — Media & Episode Normalization

**Project:** RAVEN23 / CINESTREAM-PRO-N  
**Phase:** 38  
**Date:** 2026-11-06  
**Status:** Implementation in progress — acceptance blocked by Phase 37 / 37.1 post-change validation.

## 1. Goal

Normalize the media identity passed to source engines and make episode selection require an unambiguous season + episode pair. Keep the application's existing `MediaKind.movie` / `MediaKind.series` model and keep each source on its existing engine.

## 2. In-scope requirements

1. Document and enforce the mapping between application media kinds, `UnifiedMediaType`, and editorial classifications.
2. Keep TMDB, IMDb, AniList, MAL, episode TMDB ID, and episode air date in their existing identity fields/maps. Do not fabricate identifiers.
3. Treat season and episode as independent nullable integers. Negative and fractional coordinates are invalid.
4. Parse only unambiguous identifiers: `S02E08`, `Season 2 Episode 8`, Arabic `الموسم 2 الحلقة 8`, and `2x08`.
5. Accept an explicitly declared season on the parent response as context for its episode list; do not infer season from episode number or title alone.
6. Reject conflicting explicit season aliases, episode aliases, embedded coordinates, and parent/child season values.
7. Require exact season + episode matching in QuickJS. Do not match on episode number alone.
8. Reject incomplete series identities before Stremio or VidKing performs network work.
9. Preserve OpenStream Anime, AniList/ani.zip mapping, movie-vs-series mapping cache separation, and anime feature-film movie routing.
10. Add deterministic fixtures for Japanese, Korean, Chinese, Arabic, and Latin titles.

## 3. Explicit mapping contract

| Application / source identity | Normalized playback kind | Classification |
|---|---|---|
| Movie | `UnifiedMediaType.movie` | `general`, or an editorial classification such as `anime` for an anime feature film |
| Series | `UnifiedMediaType.series` | `general` |
| Anime episodic work | `UnifiedMediaType.series` | `anime` |
| Donghua episodic work | `UnifiedMediaType.series` | `donghua` |
| General animation | `UnifiedMediaType.series` | `animation` |
| Documentary series | `UnifiedMediaType.series` | `documentary` |

`UnifiedMediaType.anime` remains accepted as a legacy identity input during the transition, but engine dispatch, Stremio type, external-ID lookup, source identity, and playback cache use its normalized `series` value. `MediaKind` itself is not expanded.

## 4. Matching contract

A provider episode is eligible only when both requested coordinates are known and the provider item resolves to the exact same pair. A missing season is not a wildcard. The only permitted inherited season is an explicit, non-conflicting season field on the parent response containing the episode list. Ambiguous, malformed, negative, fractional, or conflicting values are rejected.

## 5. Dependencies and gate

The Blueprint lists Phase 38 dependencies as Phase 36 and Phase 37. The Phase 37 and Phase 37.1 post-change format/analyze/test/Release CI evidence is not available in this execution environment. Code and fixtures are therefore recorded as implementation work, but Phase 38 cannot be marked accepted and Phase 39 must not begin until the prerequisite validation gate is closed.

## 6. Out of scope

- Replacing source engines or adding parallel engine registries.
- Enabling or bulk-installing repository sources.
- Changing catalog `MediaKind`, TMDB catalog behavior, UI design, player implementation, application ID, package name, signing identity, or Release build configuration.
- Guessing season/episode or creating manual catalog records to compensate for missing metadata.
- DRM, Cloudflare, authentication, or geographic-restriction bypasses.
