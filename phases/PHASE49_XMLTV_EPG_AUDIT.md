# Phase 49 — XMLTV / EPG Audit

**Date:** 2026-11-08  
**Base:** `RAVEN23-PHASE48.zip`  
**Status:** `Implementation Prepared — CI Pending`

## Existing integration points

- `lib/models/live_tv.dart` contains the shared `Channel` type and legacy `DaddyLiveEpg` / `DaddyLiveEpgEvent` schedule model.
- `lib/services/daddylive_service.dart` defines the `LiveTvService` catalog contract consumed by the common Live TV screens.
- `lib/services/iptv/m3u_playlist_parser.dart` already parses `tvg-id`, logo and group metadata, but did not previously retain EPG header URLs.
- `lib/services/iptv/m3u_live_tv_service.dart` converts playlist entries to shared `Channel` records; before this phase it discarded `tvg-id` and returned an empty legacy guide.
- The shared mobile/TV schedule UI consumes `DaddyLiveEpg`; replacing that model outright would broaden the phase and risk existing providers.
- `xml` is already a project dependency, and existing HTTP / SharedPreferences / crypto packages are available; no new package was required.

## Gaps found

1. No provider-neutral XMLTV channel/programme representation or bounded XMLTV parser existed.
2. M3U header EPG URLs were not extracted.
3. The `Channel` model did not retain `tvg-id`, so exact XMLTV identity could not survive service conversion.
4. IPTV catalogs exposed no Now/Next or programme schedule.
5. There was no per-feed XMLTV HTTP/cache lifecycle, TTL or explicit stale marker.
6. EPG failure isolation was not represented by a tested contract.

## Design decisions

- Add separate `XmlTvGuide`, `XmlTvChannel`, `XmlTvProgramme` and load-result models; retain `DaddyLiveEpg` as an adapter target.
- Use exact channel IDs only. Display names and fuzzy matching are deliberately not fallbacks.
- Normalize explicit `Z` / `±HHMM` offsets to UTC. Offsetless timestamps use UTC deterministically because no trusted station timezone is included in the supplied XMLTV contract.
- Convert event display times using device-local time, matching the current schedule UI. A separate IANA station-timezone feature is not inferred.
- Ignore stale cached guides for UI enrichment, even when the repository returns them for diagnostics/recovery.
- Keep XMLTV retrieval optional and failure-isolated from catalog and playback operations.
- Reuse `SourceHostPolicy` for URL validation and redirect revalidation.

## Known limitations to carry forward

- No station-specific IANA timezone database is introduced; explicit timestamp offsets are authoritative, offsetless values are UTC, and the current view displays device-local time.
- Exact `tvg-id` matching intentionally leaves unmatched channels without EPG.
- Local playlists do not receive a filesystem-relative XMLTV path unless they provide a valid absolute feed URL.
- Successful parser/cache fixtures do not prove that an external EPG server is online or that a channel is playable on a device.
