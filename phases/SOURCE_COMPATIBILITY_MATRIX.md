# Phase 36 — Source Compatibility Matrix

**Snapshot date:** 2026-11-06 · **Total index records:** 142 · **Playback verified:** none in this audit.

## State legend

- **Index Retrieved:** entry exists in the current live index.
- **Script Inspected:** linked JavaScript was statically inspected.
- **Contract Verified (static):** the declared type and visible source functions were compared with RAVEN23's current engine contract.
- **Runtime Verified / Playback Verified:** not achieved in Phase 36; must not be inferred from static inspection.
- **Blocked (current contract):** current engine rejects or cannot route the declared behavior correctly.
- **Experimental:** requires additional environment, server, or interactive validation.

## Per-repository matrix

| Repository | Source / family | Index claim | Static assessment | Phase 36 disposition |
|---|---|---|---|---|
| OpenStream | Yoru, Cypher, Breach, Neon | Movies + Series, VidKing Direct | Registered by current OpenStream parser path; their language/quality model needs careful interpretation | Index Retrieved; runtime/playback pending |
| OpenStream | Vyse, Fade | language-specific VidKing Direct | Index uses `qualityFilter: English/Hindi`; current provider also interprets it as audio language | Known metadata mismatch; Phase 41 |
| OpenStream | Omen, Raze, Killjoy | VidKing Direct variants | No selected live script run in Phase36; keep advertised status/priority | Index Retrieved; runtime pending |
| OpenStream | Re:Anime, FourAnimo, Anikoto, AnimeGG, AnimePahe | Native Anime Site | Existing native Anime engine is present; Beta is an upstream status, not a failed RAVEN23 runtime result | Index Retrieved; engine integration/runtime pending; AnimePahe Experimental |
| OpenStream | HdHub, YaStream, Zeus, FrostStream, FenixFlix | Stremio endpoint | Parser enrichment exists; Stremio config flag issue requires Phase40 fixtures | Index Retrieved; Manifest/config verification pending |
| OpenStream | Jett, Sage, Sova, Phoenix, Reyna, Viper, Skye, Astra, Harbor, Gekko | Web Embed | Existing Web Embed engine; per-endpoint movie/tv URL templates need separate tests | Index Retrieved; runtime/playback pending |
| Spyou Zangetsu | HiAnime | Anime | `getInfo` says anime; search/detail/episode/server and stream/subtitle paths are present | Script Inspected; contract static; runtime/playback pending |
| Spyou Zangetsu | AnimeCube | Anime, zh | `getInfo` says anime; Chinese catalogue and embed/HLS path | Script Inspected; specialist language source; runtime/playback pending |
| Spyou Zangetsu | 4K HDHub | Movie | Index and `getInfo` agree on movie | Script Inspected; movie only under current declared contract |
| Spyou Zangetsu | UHD Movies, HDHub4u, VegaMovies, MultiMovies, TorBox | Movie | Index declares movie; their host/auth contracts were not fully inspected in Phase36 | Index Retrieved; candidate only |
| Spyou Zangetsu | AniKoto | Anime | Index declares anime; duplicate candidate with OpenStream/Serenity/Spyhell copies | Index Retrieved; compare scripts before enabling duplicate copies |
| Serenity-MIST | Anikoto, AnimeKai, AniWave | Anime | Index declares anime | Index Retrieved; runtime pending; Anikoto duplicate candidate |
| Serenity-MIST | CineStream | Movie in index/getInfo | Script has movie+series paths, but `TYPE` and `getInfo` declare movie; QuickJS type gate rejects series request before search | **Blocked for Series by current contract**; movie contract only pending runtime |
| Serenity-MIST | StreamPlay | Movie in index/getInfo | Same mismatch: series code exists but `getInfo` declares movie | **Blocked for Series by current contract**; movie contract only pending runtime |
| Spyhell Experiment | AnimeSuge | Anime | `getInfo` says anime; server/extractor and stream metadata in script | Script Inspected; runtime/playback pending |
| Spyhell Experiment | AnimeX, AnimeTosho, SubsPlease, GoGoAnime, AnimeAni, Archive Anime etc. | Mostly Anime | Index claims type; some sources may be torrent/catalog-only or require unsupported handoff; inspect per file | Index Retrieved; not enabled as a blanket group |
| Spyhell Experiment | Nyaa, AnimeTosho, torrent-oriented entries | Anime/catalog | Torrent/Magnet cannot be treated as HTTP/HLS stream by current generic player pipeline | Blocked unless explicit supported resolver exists; do not add magnet to player |
| Spyhell Experiment | World Live TV, Sports/News/Documentary/Entertainment/Movies/Series/Animation/Kids/etc. Live TV | index uses generic `movie` | World Live TV script uses `getHome()`, custom `worldtv://` channel IDs and channel HLS; current QuickJS VOD flow is not the Live TV adapter | **Blocked from VOD route; Live TV adapter required** |
| Spyhell Experiment | Pluto TV | Movie in repository index | Referenced provider script is absent from the supplied project tree; official Terms restrict alternate interfaces, unauthorized scraping and geo/access-control circumvention; no authorized public channel API contract was supplied | **Phase48: Experimental/Unavailable external-only**; no VOD, channel scrape or stream resolver; official website handoff only |
| Spyhell Experiment | ARTE TV, NHK World, Internet Archive, Prelinger, Wikimedia, Library of Congress, PeerTube | Movie in index | VOD/archive/federated endpoints differ; licensing and direct stream behavior are per-title/per-host | Candidate; validate rights/stream/metadata per source |
| Spyhell Experiment | Adult-oriented providers | Anime/movie index records; no `nsfw` field present | Current parser defaults missing `nsfw` to false | **Safety Blocker:** no auto-install/enable until explicit safe classification policy |
| Spyou Additional | AnimeSalt | Anime | `getInfo` says anime; season/episode IDs and multi-audio HLS metadata present | Script Inspected; contract static; runtime/playback pending |
| Spyou Additional | AnimixStream, AnimeDrive | Anime | Index declares anime; no full script static verification in this phase | Index Retrieved; candidate only |
| Spyou Additional | AnimeLok | Anime | README reports Cloudflare-dependent path | Experimental; do not attempt bypass; explicit blocked state when challenge prevents access |
| Spyou Additional | NetPrime | Movie | README notes signed/IP-bound runtime tokens | Experimental/likely blocked in headless runtime; require legitimate session support |
| Spyhell Latin | AnimeAV1, AnimeJL, Jkanime, AnimeYTX | Anime, es | Index declares Spanish language | Index Retrieved; language/subtitle playback pending; Jkanime duplicate candidate |

## Confirmed engine-level blockers

### A. Series declared as Movie

`QuickJsSourceEngine.resolve()` reads `getInfo().type` before search. Declared `movie` can only serve `UnifiedMediaType.movie`. This is not merely UI filtering. Serenity's CineStream and StreamPlay visibly implement series/episode helpers but are rejected at this gate because `TYPE='movie'` and `getInfo()` returns it. Phase 38/44 must agree a verified capability contract, test both content types, and only then change the declaration/adapter.

### B. Ambiguous season matching

The current episode matcher accepts `itemSeason == null` as a match when `media.seasonNumber` is known. A missing season is ambiguous on a multi-season title. Phase38 must require exact season or an explicitly proven provider-specific season mapping; never infer by episode number alone.

### C. Live TV misclassification

Spyhell's World Live TV provides grouped channels through `getHome()` and a `worldtv://` identity. It is not an ordinary movie. `getHome()` being exposed in JS bootstrap does not connect the source to `LiveTvService`; a dedicated adapter and `Channel` conversion are required.

### D. Stremio optional configuration

Current parser blocks when `configurable` OR `configurationRequired` is true. Create four fixtures for `(false,false)`, `(true,false)`, `(true,true)`, `(false,true)` and then implement the contract-defined interpretation. Optional configuration must not be conflated with mandatory setup.

### E. NSFW missing metadata

Spyhell's manifest contains no explicit `nsfw` property, while the parser's default is false. Treat missing metadata as `unknown`, not safe, at least for source catalog installation/visibility. Preserve the user's adult-content preference and existing settings.

## Duplicate candidates (advisory, not automatic deletion)

- Anikoto across OpenStream, Spyou, Serenity, Spyhell.
- AnimeGG across OpenStream and Spyhell.
- CineStream across Serenity and Spyhell (distinct code; compare hashes/behavior).
- Jkanime across Spyhell Experiment and Spyhell Latin.

Do not deduplicate solely by display name. Compare normalized domains, script hashes, engine, settings schema, and playback behavior. Keep repository provenance and let user select alternate builds.

## Runtime test plan for later phases

1. Local deterministic QuickJS tests with stubbed network responses for the selected eight inspected scripts.
2. Contract checks for `getInfo`, `search`, `getDetail`, `getEpisodes`, `getVideoSources`, `getSettings`, and `getHome` as applicable.
3. Series tests where same episode number appears in two seasons.
4. Stremio config flags and optional-config test fixtures.
5. VidKing tests asserting language and quality remain independent.
6. Live TV adapter tests mapping `getHome` groups/channels to `Channel` and `LiveTvService.getStream`.
7. Only after deterministic tests, run live smoke tests on supported websites and device playback.


## Phase 38 implementation update — 2026-11-06

The Phase 36 finding in section **B. Ambiguous season matching** is addressed in the current worktree by `EpisodeIdentityNormalizer` and the QuickJS exact-match path: missing provider season metadata is no longer a wildcard, and only an explicit episode season, an unambiguous embedded season/episode identity, or an explicit non-conflicting parent season may qualify. Stremio and VidKing also reject incomplete series coordinates before network access.

This is an implementation update, **not a runtime/playback verification result**. Phase 38 fixtures were added but have not run because Dart/Flutter are unavailable in this environment. Phase 37/37.1 post-change CI acceptance also remains pending. Do not change the Phase 36 historical statuses above to Runtime Verified or Playback Verified until CI and device evidence exist.


## Phase 43 OpenStream integration update — 2026-11-07

- **VidKing Direct:** 9 official entries map to the existing Vidking Direct engine. Source ids, routes and status are fixture-asserted. Mock Dio tests assert dispatch for all nine routes and exact movie/TV request identity; live stream resolution/playback remains unverified.
- **Native Anime:** Anikoto, Re:Anime, AnimePahe, FourAnimo and AnimeGG keep separate raw engine ids and use the existing Anime adapter. All five retain upstream status 3 (Beta); they are marked experimental in lifecycle state, not implicitly disabled. Deterministic Re:Anime mapping covers exact S2E4 and anime film mapping to episode 1.
- **Stremio:** 5 entries retain `stremio` engine identity and upstream Beta status; Phase40 contracts remain in the focused gate.
- **Web Embed:** 10 entries retain movie and TV templates, status 3, and fallback state.
- **VidKing WebView:** one entry retains status 2 (Slow) and fallback state.
- **Stream metadata:** `UnifiedStreamOption` carries headers, quality, audio, subtitles and optional expiry. Provider-supplied expiry is now forwarded only when explicit metadata exists; no TTL is fabricated.
- **Validation level:** `Indexed` + static/contract test prepared. This update does not mark runtime against live provider endpoints or playback as verified; CI and Android device tests remain pending.
