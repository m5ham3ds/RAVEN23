# Phase 48 — Pluto TV Live Adapter Changelog

## Added

- Typed `LiveTvProviderUnavailableException`.
- `PlutoTvExperimentalLiveTvService`, deliberately network-free and fail-closed.
- Shared Live TV provider metadata for experimental status and official external destination.
- Pluto TV registry entry with its own namespace.
- Mobile and Android TV explanatory UI and official external handoff.
- Focused Pluto service tests.
- Phase48 bounded formatter/CI test integration.
- Six Phase48 planning, audit, implementation, tests, changelog and report documents.

## Modified

- Live TV service manager and its existing registry test.
- Mobile Live TV screen.
- Android TV Live TV screen.
- Android CI workflow and maintained formatter target list.
- Master blueprint, implementation tracker, source compatibility matrix and master implementation README.

## Preserved

- The Phase45 and Phase47 archive baselines are unchanged.
- Existing DaddyLive, EthioSports, IPTV/M3U and Spyhell Live provider IDs, services and namespaces.
- Original Spyhell snapshot classification (`plutotv` remains as indexed upstream metadata only); no VOD activation.
