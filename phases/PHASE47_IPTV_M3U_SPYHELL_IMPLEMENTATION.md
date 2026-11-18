# Phase 47 — Implementation

**Status:** Implementation prepared — CI pending.

## M3U parser and identity

`lib/services/iptv/m3u_playlist_parser.dart` parses `#EXTM3U` / `#EXTINF`, quoted attributes, `tvg-id`, `tvg-logo`, `group-title`, channel names and URLs. It supports `#EXTGRP` and a deliberately narrow `#EXTVLCOPT` header allow-list. It rejects unsupported schemes, URL credentials and unresolved relative links. Relative stream/logo paths are resolved against a remote playlist base URI; imported local files currently require absolute HTTP(S) channel URLs because their original external path is deliberately not persisted as a resolver base. `#EXT-X-*` manifests are classified as HLS media playlists and never emitted as channel lists. IDs are deterministic and scoped by playlist namespace; `tvg-id` is preferred, and duplicate entries within a playlist are removed.

## Playlist repository

`lib/services/iptv/m3u_playlist_repository.dart` persists up to eight playlist definitions. Local files are copied to app-private `iptv_playlists` storage; the external picker path is not kept. Remote retrieval uses `SourceHostPolicy`, disables automatic redirects, validates every redirect destination, limits redirects to four, enforces a 4 MiB body limit and request timeout, and validates the fetched content before replacing the cache. It stores `ETag` and `Last-Modified` validators, uses a 20-minute fresh cache, and can fall back to a cache no older than seven days on a fetch failure.

## Live TV services

- `M3uLiveTvService` converts imported playlists into `Channel` objects and resolves a selected channel back to its current playlist entry, headers and HLS/DASH media hint.
- `SpyhellLiveTvService` is a dedicated adapter for 15 curated Spyhell Live IDs. It reads `getHome()` channel groups, maintains stable IDs per source, resolves the opaque channel locator through `getVideoSources()`, and maps supported stream URL/header/expiry/container metadata into the existing Live TV stream contract.
- Both services use their own database namespaces (`iptv_m3u` and `spyhell_live`) through the manager/screen storage boundary.
- `live_tv_category_mapper.dart` maps the planned categories (World, Sports, News, Documentary, Entertainment, Movies, Series, Animation, Kids, Music, Travel, Comedy, Cooking and Education) and preserves unknown source group names.

## Manager and UI integration

`LiveTvServiceManager.standard()` registers IPTV/M3U and Spyhell Live alongside DaddyLive and EthioSports. Public manager methods provide remote/local playlist add, list and remove operations. The Mobile and TV Live screens show the same playlist manager for the M3U provider and installation guidance for Spyhell adapters. The sports/EPG prompt is shown only for services that advertise EPG support.

## VOD isolation

The curated source profile continues to set `requiresLiveTvAdapter: true`; `SourceManifest.supportsMedia()` continues returning false for these sources. The catalog role now identifies the adapters as `live-channel-adapter`, and the repository UI labels them as Live TV rather than pending adapters. This is a routing label only, not a live-playback verification claim.

## CI gate

`tool/format_phase37_47_dart.sh` maintains formatting targets for Phase37–47. `.github/workflows/android-ci.yml` keeps the existing explicit contract tests and adds the M3U parser, local Live TV service, remote repository/cache and Spyhell guard tests. The current list contains 25 explicit test files; the workflow still excludes the full Flutter suite and unrelated widget batches.

## Remaining limits

- Spyhell source scripts can change upstream; each adapter is only eligible when the source is installed/enabled and matches the curated repository identity.
- Live provider availability, account/region eligibility and rights are external and are not guaranteed by parsing or adapter registration.
- A returned stream contract is not proof that the native player can decode every provider stream or that it will play on every Android/TV device.
- Analyzer, Dart format, tests, CI, ARM64 Release build and real-device playback remain pending.
