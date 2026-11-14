# Phase 35 Implementation Report

**Project:** RAVEN23 / CINESTREAM-PRO-N  
**Phase:** 35 — Dynamic Anime Home Feeds and Studio / Network Catalogs  
**Base:** User-supplied `RAVEN23-PHASE34-PHASE32-ANIME-PRESERVED-PLAYER-TEXT12.zip`

## Delivered

1. Added Warner Bros. and Nickelodeon brand catalog cards, using the supplied PNG assets already present in the project.
2. Separated company and network catalog identifiers from watch-provider identifiers; company and network catalogs query TMDB Discover with the matching filter types.
3. Added Trending Anime, Popular Anime, and New Episodes Anime to phone Home and Android TV Home. Renamed the Series episode row to New episodes series.
4. Reworked Anime trending to use TMDB weekly TV trending plus popularity-ranked Japanese Animation discovery, without title allowlists or manually injected names.
5. Added a seven-day Anime episode-air-date query and retained the Phase 11 Anime classifier.
6. Kept general Series rows and See all collections separate from Anime, including the phone and TV catalog pages.
7. Updated English, Arabic, Spanish, and Hindi localization and the related Home / catalog tests.

## TMDB filter map

- Nickelodeon Movies: company `2348`; Nickelodeon TV network: `13`.
- Warner Bros. Entertainment: company `17`; Warner Bros. Pictures: company `174`; Warner Bros. Television: company `1957`.
- Anime identity: genre `16` and original language `ja`.
- Anime episode window: `air_date.gte` / `air_date.lte` for the seven days ending on the current date.

## Preservation

The prior phases were reviewed before editing. Anime remains episodic TV (`MediaKind.series`); no playback type, player behavior, subtitle defaults, source-provider logic, or watch-progress format was intentionally modified. Phase 34's protected Phase 32 implementation was extended rather than replaced.

## Validation status

Translation JSON, duplicate-key checks, generated localization-key counts, pubspec YAML, image byte equality, and archive structure are checked. The environment does not have Flutter or Dart installed; formatter, analyzer, automated Flutter tests, and APK assembly remain unexecuted and are not claimed as passed.
