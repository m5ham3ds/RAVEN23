# Phase 46 — Unified Live TV Service Manager

## Source of truth

This phase follows the Phase 46 section of `MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md` without expanding into Phase 47 IPTV/M3U work.

## Goal

Complete the existing Live TV subsystem by selecting and owning providers through one manager rather than wiring the Mobile and Android TV screens directly to DaddyLive.

## Preserve existing public contracts

- `LiveTvService`
- `DaddyLiveService`
- `EthioSportsService`
- `Channel`
- `DaddyLiveStream`
- `DaddyLiveCatalog`
- `LiveTVDatabaseController`
- `LivePlayer`

The existing `LiveTvService` and DaddyLive-shaped catalog/stream models remain compatibility contracts for the current player. A new service must adapt to them until a future phase explicitly requires a broader model migration.

## Phase scope

1. Restore the provider selector on Mobile and Android TV and identify why EthioSports was dormant.
2. Add `LiveTvServiceManager`, selecting providers by stable ID and owning lazy service instances/lifecycle.
3. Expose a shared contract for provider registration, selected catalog, categories, stream resolution, refresh, close and health state.
4. Keep provider-specific persistence: DaddyLive retains its current `daddylive_*` keys; EthioSports receives a separate namespace.
5. Route screens and `LivePlayer` channel switching through the manager.
6. Keep EPG optional and provider-capability based; DaddyLive's existing guide must continue working.
7. Validate channel metadata at the manager boundary: HTTP(S) URL, non-expired link, bounded allow-listed headers, normalized HLS/DASH media type, valid ClearKey pair and eligible variants. Preserve valid expiry through playback recovery. Do not bypass DRM or alter protected playback policy.
8. Distinguish Loading, Empty, Error, Unavailable and Blocked states.

## Provider defaults and compatibility

- New installs and invalid persisted selections fall back to DaddyLive.
- A saved valid provider choice is restored on later visits.
- Existing DaddyLive channel/share/focus links continue to resolve against DaddyLive because their legacy IDs do not encode a provider.
- Provider IDs are stable: `daddylive` and `ethiosports`.
- Database namespaces are unique and may not be shared between registered providers.

## Acceptance

- DaddyLive remains the default and keeps its current IDs, database keys, EPG and player path.
- EthioSports can be selected on both Mobile and Android TV.
- EthioSports channel IDs cannot collide with DaddyLive IDs or favorites/history.
- Optional EPG failure does not hide a usable channel catalog.
- Manager lifecycle closes each created service once.
- Provider health reports safe status categories without leaking upstream URLs or raw secrets.
- The explicit Phase 46 tests pass with Analyze and ARM64 Release CI.
- Real external uptime/playback remains a separate device/runtime verification; mocked tests do not prove it.
