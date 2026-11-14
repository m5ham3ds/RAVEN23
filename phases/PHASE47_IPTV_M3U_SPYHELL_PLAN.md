# Phase 47 — IPTV / M3U Engine & Spyhell Live Adapters

**Date:** 2026-11-08  
**Baseline:** `RAVEN23-PHASE46`  
**Dependency:** Phase 46 — Unified Live TV Service Manager  
**Status:** Implementation prepared — CI pending

## Objective

Add user-provided IPTV playlists and the curated Spyhell live-channel adapters to the existing Live TV service architecture. These are linear channels and must not be added to the Unified Movies/Series/Anime catalog or its VOD resolver.

## Scope

1. Parse `#EXTM3U` / `#EXTINF`, including quoted attributes, channel name, `tvg-id`, `tvg-logo` and `group-title`.
2. Distinguish IPTV channel lists from HLS media/master playlists. An HLS stream manifest must never be indexed as a channel catalog.
3. Build stable channel IDs scoped to the playlist/provider. Prefer `tvg-id`; otherwise derive a deterministic identity from channel metadata and URL. De-duplicate within one source while retaining provider separation.
4. Support user-selected local M3U files and remote HTTP(S) playlists. Copy local imports to app-private storage; never retain an assumed external device path.
5. Bound playlist size/count/channel count/line length; use refresh/cache and HTTP validators (`ETag` / `Last-Modified`) where provided; use a limited stale cache after remote failure.
6. Restrict stream headers to a small allow-list and reject malformed URLs, unsupported schemes and embedded URL credentials.
7. Add a dedicated Spyhell `getHome()` → Live TV adapter and resolve streams through the existing QuickJS runtime. Execute only sources already installed and enabled by the user.
8. Restrict adapters to the 15 audited IDs in the Spyhell `zangetsu-experiment-repo`; isolate their Live TV database namespace.
9. Map known groups to RAVEN23 Live TV categories, preserve useful unknown provider labels, and treat Movies/Series/Animation Live TV groups as linear channels.
10. Expose IPTV playlist management in both Mobile and Android TV screens and route all playback through the existing `LiveTvService` / `LivePlayer` compatibility boundary.

## Explicit exclusions

- No VOD routing or VOD catalog changes for Spyhell live-channel sources.
- No automatic installation or execution of uninstalled JavaScript sources.
- No DRM circumvention, geo-restriction bypass, token harvesting, or claims of rights/access not established by the provider.
- No changes to the successful Phase45 backup archive.
- No build/test/analyze execution as part of this multi-phase editing pass.

## Acceptance gates

- M3U parsing and category mapping fixtures pass.
- HLS media playlists are rejected as channel catalogs.
- Local and remote repository/cache/validator/redirect behavior passes focused tests.
- Live TV services return valid `DaddyLiveCatalog` / `DaddyLiveStream` data for supported contracts.
- Spyhell adapters remain excluded from VOD and execute only if installed and enabled.
- Mobile and TV use the same service registry and playlist manager.
- A real Android/TV playback smoke test and external-provider availability check remain required before marking the phase passed.
