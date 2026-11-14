# Phase 52 — Source Repository Audit

**Review date:** 2026-11-09  
**Base:** `RAVEN23-LIVE-TV-SETUP-FIX1` (successful 4.3.1+11 working baseline)  
**Target package version:** `4.4.0+12`

## Repositories reviewed

All six current raw indexes were rechecked. They contain 142 discovery records before cross-repository duplicate analysis; this is a catalog count, not a count of playable servers.

| Repository | Index records | Phase52 treatment |
|---|---:|---|
| OpenStream Official | 30 | 7 stable-status direct Movie/Series sources; Beta Movie/Series and Anime adapters demoted to backup; embedded routes excluded from direct priority. |
| Spyou Zangetsu Providers | 9 | 2 English Movie sources and 2 English + 1 Chinese Anime sources selected. HDHub4u rejected for index/script language mismatch. |
| Serenity-MIST Zangetsu Sources | 5 | 3 English Anime sources; StreamPlay and CineStream selected for Movies and, after exact script-contract review, Series. |
| Spyhell Experiment | 89 | 2 Movie and 5 Anime direct candidates selected; 8 additional bounded backup sources; Live TV adapters and torrent-only providers excluded. |
| Spyou Additional Providers | 5 | NetPrime kept as a best-effort direct backup only; Hindi entries excluded. |
| Spyhell Latin Sources | 4 | Spanish-language entries excluded from the requested language lanes. |

## Priority lanes

### Movies — 13 entries

1. OpenStream: Yoru, Cypher, Breach, Neon, Vyse, Omen, Raze (7).
2. Spyou/Zangetsu: 4K HDHub, UHD Movies (2).
3. Serenity: StreamPlay, CineStream (2).
4. Spyhell Experiment: Filmzie, Internet Archive (2).

The OpenStream Movie/Series priority sources currently carry upstream status 1. The selected Serenity, Spyou and Spyhell records do not all expose an equivalent status field; they are shown as `Unrated`, not as independently stable. Filmzie's reviewed source is a free ad-supported catalog with HTTP HLS outputs. Internet Archive is a public/archive VOD candidate; its catalog presence does not guarantee every item has a playable media file.

### Series — 9 entries

1. OpenStream: Yoru, Cypher, Breach, Neon, Vyse, Omen, Raze (7).
2. Serenity: StreamPlay, CineStream (2).

HDHub and YaStream are Beta and remain in the backup tier rather than first-pass priority. StreamPlay and CineStream are a narrow, source-specific exception: their live scripts implement `getDetail`/`getEpisodes` and a `getVideoSources` episode path even though current index/getInfo metadata says `movie`. The parser marks only these exact two IDs with `seriesCapabilityVerified`; QuickJS still requires an exact season and episode match. No general Movie-to-Series override is enabled. TheNkiri and Dramacool were not promoted because their current episode identity contracts could not be proven to provide the exact season/episode identity required by RAVEN23.

### Anime — 11 entries

1. Spyou/Zangetsu: AniKoto, HiAnime, AnimeCube (3; AnimeCube is Chinese/Donghua).
2. Serenity: AniKoto, AnimeKai, AniWave (3).
3. Spyhell Experiment: AnimeSuge, AnimeX, Anikage, WcoFlix, DonghuaNation (5; DonghuaNation is Chinese/Donghua).

OpenStream's five Anime adapters are currently marked Beta and remain in the direct-backup tier rather than the first-pass lane. Anikage replaces SubsPlease in the priority list because the reviewed Anikage script exposes HTTP(S) server adapters, while SubsPlease returns torrent/magnet results unsupported by the current RAVEN23 playback mapper.

## Bounded automatic activation

The union of all priority lanes and the curated backup allow-list is deduplicated by stable source identity and limited to 15 unique records per repository:

| Repository | Expected unique activation candidates |
|---|---:|
| OpenStream Official | 14 |
| Spyou Zangetsu Providers | 5 |
| Serenity-MIST | 5 |
| Spyhell Experiment | 15 |
| Spyou Additional | 1 |
| Spyhell Latin | 0 |

A multi-category source can appear in more than one lane but is activated only once. These are policy selection counts, not a promise that all external scripts will resolve every title.

## Exclusions and review decisions

- HDHub4u: its index says English while the current script's `getInfo()` says Hindi.
- AniLibria: index metadata says English but the provider describes Russian voice-over.
- SubsPlease, Nyaa, AnimeTosho and other torrent/magnet-only entries: unsupported by the current HTTP(S)-only source mapper.
- NetPrime: backup only; its own implementation notes browser-computed signed tokens and IP-bound embeds as best-effort.
- Live TV-only adapters: excluded from VOD, even if a generic or stale index type says Movie.
- Adult/NSFW entries, credential-review sources and languages outside the user policy: excluded.
- Hindi, Spanish, Portuguese, French, German and other non-allowed languages are not automatically activated.
- Japanese and Chinese declarations are accepted only in the Anime lane. `Multi` is treated as a declared multilingual source; it does not guarantee English audio for every result.

## Status and stability semantics

- Upstream status `1`: Listed OK.
- Upstream status `2`: Slow.
- Upstream status `3`: Beta.
- Upstream status `0`: Unavailable.
- Missing status: Unrated.

These are upstream metadata fields, not independent uptime checks. The ordering is a static compatibility-based initial recommendation, not a measured reliability ranking. No live playback probe of all 142 records was run in this packaging session; device/provider verification remains necessary.
