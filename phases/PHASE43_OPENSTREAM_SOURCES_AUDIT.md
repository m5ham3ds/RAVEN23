# Phase 43 — OpenStream Sources Audit

## Evidence reviewed

- Live OpenStream official `extensions/index.json` retrieved on 2026-11-07.
- Checked-in fixture: `test/fixtures/openstream_official_repo.json`.
- `source_manifest.dart`, `source_repository_parser.dart`, `source_engine.dart`, `vidking_direct_provider.dart`, `openstream_web_embed_engine.dart`, `openstream_anime_engine.dart`, `stream_option.dart`, and `source_contracts.dart`.
- Existing Phase 37/38/40/41/42 contracts and CI gate.

## Index findings

The live index reports 30 entries: 9 VidKing Direct, 5 native Anime, 5 Stremio, 10 Web Embed and 1 VidKing WebView. The parser already recognizes all listed engine types and the standard registry already wires each family to an adapter.

### VidKing Direct

| Source id | Route | Priority | Status | Default installation |
|---|---|---:|---:|---|
| yoru | `cdn/sources-with-title` | 0 | 1 | yes |
| cypher | `downloader2/sources-with-title` | 1 | 1 | yes |
| breach | `m4uhd/sources-with-title` | 2 | 1 | yes |
| neon | `vsrc/sources-with-title` | 3 | 1 | yes |
| vyse | `hdmovie/sources-with-title` | 4 | 1 | yes |
| killjoy | `meine/sources-with-title` | 5 | 1 | no explicit default |
| fade | `hdmovie/sources-with-title` | 6 | 1 | no explicit default |
| omen | `lamovie/sources-with-title` | 7 | 1 | no explicit default |
| raze | `superflix/sources-with-title` | 8 | 1 | no explicit default |

**Metadata discrepancy retained, not silently fixed:** the blueprint stages Vyse/Fade/Killjoy after Phase 41, but the live upstream index explicitly sets `installedByDefault: true` on Vyse. The parser preserves upstream metadata. Phase 41 CI is still pending, so this archive does not claim that the staged language-source activation has been verified. Fade and Killjoy do not carry that default flag in the current index.

### Native anime

Anikoto, Re:Anime, AnimePahe, FourAnimo and AnimeGG each use their own raw engine type, while the runtime shares the `animeSite` engine kind. All are status 3 (Beta) and advertise anime/sub/dub. The live index sets Anikoto and Re:Anime as installed-by-default; AnimePahe, FourAnimo and AnimeGG do not carry that flag. AnimePahe requires Android WebView Cloudflare clearance; an interactive Turnstile challenge may remain unsupported. Anime feature-film mapping is explicitly handled by AniList's first episode slot, while source-specific actual film availability remains dependent on each provider.

### Other families

- Five Stremio add-ons retain Stremio engine identity and upstream Beta status.
- Ten Web Embed sources preserve `fallback: true`, Beta status, movie URL templates and TV URL templates.
- The VidKing WebView fallback remains status 2 (Slow) and a fallback source.

## Code gaps addressed

- Existing fixture assertions were too aggregate: they checked counts but did not bind every VidKing id to its route or all lifecycle states. Those contracts are now asserted.
- Existing tests did not exercise all nine VidKing route request paths. A deterministic request-routing test now covers each route and exact TV coordinates.
- Existing tests did not exercise the AniList/ani.zip mapping used by the anime engine. A deterministic Re:Anime mapping test now covers S2E4 and movie-to-episode-1 mapping.
- `UnifiedStreamOption` already carries expiry, but VidKing Direct, native Anime and Web Embed capture paths did not consistently forward explicit provider expiry fields. A parser now forwards known explicit expiry values without inventing a TTL.
- FourAnimo's copy from the common stream object omitted `expiresAt`; that metadata is now retained.

## Known limitations / not claimed

- Deterministic test responses are not real source responses and do not prove a stream is playable.
- The VidKing route test intentionally returns HTTP 503 after recording the requested route; it validates dispatch only.
- The Re:Anime fixture intentionally returns HTML without a player id; it validates mapping and route construction only.
- AnimePahe challenge behavior requires supported Android WebView/device testing.
- Host policy validation and provider HTTP fixture tests do not prove all live DNS, redirects, CDN hosters or playback combinations work in production.
- No Flutter/Dart SDK is available in the packaging environment; the new Dart tests and code have not been run here.
