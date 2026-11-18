# Phase 49 — XMLTV / EPG Implementation

**Date:** 2026-11-08  
**Base:** `RAVEN23-PHASE48.zip`  
**Status:** `Implementation Prepared — CI Pending`

## Models and parser

- Added `lib/models/xmltv_epg.dart` with provider-neutral channel, programme, guide, Now/Next and load-result models.
- All programme boundaries are stored as UTC `DateTime` values.
- Added `lib/services/iptv/xmltv_epg_parser.dart`; it validates the `<tv>` root, rejects entity declarations and internal DTD subsets, strips external DOCTYPE declarations before XML parsing, validates time ranges, drops duplicate/invalid entries and bounds input bytes/item counts/text fields.
- Supported programme metadata includes title, subtitle, description, category, language, episode number and a validated HTTP(S) icon.
- XMLTV timestamps with `Z` or numeric offsets are normalized to UTC. Offsetless timestamps are treated as UTC, rather than applying an unverified device offset.

## Fetching and cache

- Added `lib/services/iptv/xmltv_epg_repository.dart` with HTTP client injection, `SourceHostPolicy` validation on the original URL and each redirect, bounded redirects, response size, timeouts, and compressed SharedPreferences cache.
- Cache key is a SHA-256 digest over namespace and URL; the original URL is not written into cache metadata.
- Sends `If-None-Match` / `If-Modified-Since` when cached validators exist and handles `304 Not Modified`.
- Freshness TTL is six hours. A prior successful response can be returned for up to three days after refresh failure, but the result is explicitly `isStale` and is not passed to the UI mapper.
- Cache body and encoded preference value are independently size-limited.

## M3U and UI integration

- M3U `#EXTM3U` header metadata now reads `url-tvg`, `x-tvg-url` and `tvg-url` (maximum eight values at parser level); relative URLs are resolved only when a trusted remote playlist base URI exists.
- `Channel.tvgId` now survives JSON serialization and `copyWith`, preserving backwards compatibility when older data has no field.
- `M3uLiveTvService` considers up to four distinct feed URLs and fetches in batches of two. Broken EPG feeds are ignored while the channel catalog and `getStream` continue normally.
- `XmlTvEpgMapper` applies only exact, case-sensitive `tvg-id` matches. It calculates Now/Next from intervals and adapts matched programmes to `DaddyLiveEpg` for the existing schedule UI.
- Stale feeds are retained by the repository but excluded from channel enrichment and schedule rendering.
- The existing shared Mobile/Android TV views continue using the service-manager and legacy schedule surface; no separate playback pipeline was added.

## Operational behaviour

- `M3uLiveTvService.close()` closes the XMLTV repository as part of service lifecycle.
- EPG is optional; it is not consulted by `getStream`.
- EPG URLs and icons require HTTP(S), no embedded user-info, and pass the shared public-host policy before retrieval.
- The M3U header parser strips an optional UTF-8 BOM so an otherwise valid header does not lose its EPG URL attributes.

## CI gate

- Added parser and repository fixture tests; expanded the existing M3U parser and service tests; updated the manager capability assertion.
- The required combined gate now lists 28 unique, explicit test files covering Phases 37–49.
- Formatter target script contains 81 unique Dart files; the prior `format_phase37_48_dart.sh` is retained as a compatibility wrapper that invokes the Phase49 list.
- These commands are configured in CI but have not been run in this packaging environment.
