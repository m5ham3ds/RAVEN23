# Phase 49 — XMLTV / EPG Plan

**Date:** 2026-11-08  
**Base:** `RAVEN23-PHASE48.zip`  
**Status:** `Implementation Prepared — CI Pending`

## Objective

Add provider-neutral XMLTV programme data to IPTV/M3U without making an electronic programme guide a prerequisite for channel discovery or playback. Keep the existing `LiveTvService` and `DaddyLiveEpg` screen contract working through a compatibility adapter while establishing independent XMLTV models, parsing, fetching and caching.

## Scope derived from the master blueprint

1. Parse XMLTV channels and programmes with strict byte, item and text bounds; do not process entity declarations or external DTDs.
2. Normalize explicit XMLTV UTC offsets into UTC instants. Display schedule times in the device's local time through the current UI contract.
3. Interpret timestamps without an explicit offset as UTC; do not guess a channel timezone from the device or from untrusted metadata.
4. Match programmes to M3U channels only by exact, case-sensitive `tvg-id` / XMLTV channel `id` equality.
5. Read EPG feed URLs from supported `#EXTM3U` header attributes and allow a small bounded set of feeds per catalog.
6. Cache each namespace/URL independently, use HTTP validators where available, mark stale fallback data explicitly and never present stale entries as Now/Next.
7. Calculate Now/Next from programme start/stop instants rather than XML document order; define deterministic overlap handling.
8. Treat EPG as optional enrichment. Feed, parser, cache or mapping failures must not make M3U channel loading or stream resolution fail.
9. Adapt matched XMLTV events to the legacy schedule model until a separately planned UI migration replaces that contract.

## Resource and network limits

- XMLTV response/parser input: 8 MiB maximum.
- Parser limits: 10,000 channels, 100,000 programmes and 8,192 characters per text field.
- Compressed cache body: 4 MiB maximum; encoded cache value is length-checked before decoding.
- Redirects: at most four, with host policy revalidation at each hop.
- HTTP: bounded request and inter-chunk timeouts; only public HTTP(S) endpoints without embedded credentials.
- Per catalog: at most four distinct EPG URLs, fetched in batches of no more than two concurrently.
- Cache freshness: six-hour TTL; stale fallback retention: up to three days, tagged stale and excluded from display.

## Acceptance criteria

- M3U `tvg-id` survives parsing and conversion to the shared `Channel` model.
- `url-tvg`, `x-tvg-url` and `tvg-url` headers can provide EPG sources.
- Valid XMLTV shows accurate Now/Next for exact ID matches, including explicit timezone offsets and overlapping intervals.
- Non-matching IDs and stale guides do not populate current/next data.
- A missing or failing EPG feed does not block channel listing or playback.
- Existing DaddyLive/EthioSports schedule behaviour remains on the legacy model.
- CI, Analyzer, test and Release evidence is recorded separately from source preparation.
