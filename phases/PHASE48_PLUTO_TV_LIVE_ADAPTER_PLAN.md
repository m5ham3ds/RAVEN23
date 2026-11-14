# Phase 48 — Pluto TV Live Adapter Plan

**Date:** 2026-11-08  
**Base:** RAVEN23-PHASE47  
**Dependencies:** Phase46 Live TV manager; Phase47 IPTV/M3U and service boundaries  
**Implementation status:** Experimental / external-only — CI pending

## Objective

Register Pluto TV as an explicit Live TV option without misclassifying its linear channels as VOD. The phase must use a documented and authorized integration contract if one is available. If no such contract can be verified, the required outcome is an honestly documented Experimental/Unavailable provider, not a speculative scraper.

## Findings that constrain implementation

- The supplied `SOURCE_REPOSITORY_SNAPSHOT.json` contains a Spyhell index record with ID `plutotv`, name `Pluto TV`, type `movie`, and path `providers/plutotv.js`; the actual provider JavaScript is not present in the RAVEN23 project tree, so its behavior cannot be treated as inspected or validated.
- The checked official Pluto TV terms prohibit use of interfaces other than Pluto's own, unauthorized scraping/automated collection, and circumvention of geo-filtering or other access controls. No authorized public third-party live-channel API or partner contract was supplied or verified during this phase.
- Pluto's official support page lists Android mobile and Android TV among its supported platform families, but availability and device eligibility remain controlled by Pluto and vary by market/device.
- Pluto's published live-streaming technical specification is a partner delivery/onboarding specification; it is not a consumer-facing channel discovery/playback API contract.

## Scope

1. Add Pluto TV to the shared `LiveTvServiceManager` provider registry.
2. Give Pluto a separate database namespace, independent from DaddyLive, EthioSports, IPTV/M3U, and Spyhell Live.
3. Mark it Experimental and provide a verified HTTPS link to Pluto's official website.
4. Implement a fail-closed Live TV service that reports an explicit unavailable state until an authorized third-party API/partner agreement is available.
5. Add Mobile and Android TV UI guidance and an external handoff to the official website; do not frame Pluto content inside RAVEN23.
6. Add deterministic tests proving no catalogue or stream is fabricated and the manager reports the unavailable state.
7. Keep Pluto completely outside Movies/Series/Anime VOD repositories and search.

## Explicit exclusions

- No calls to undocumented `api.pluto.tv`, `boot.pluto.tv`, stitcher, guide, or other private endpoints.
- No token harvesting, cookie replay, reverse engineering, automated scraping, or geo/DRM/authentication bypass.
- No fabricated channels, logos, categories, stream URLs, headers, expiry, or EPG data.
- No VOD activation from the Spyhell index record.
- No claim that Pluto plays through `LivePlayer` until an authorized channel API and a real device playback test exist.

## Acceptance

The registry exposes Pluto as `Experimental`; its own data namespace is isolated; attempted in-app catalogue/stream resolution returns `Unavailable` with a clear explanation and no HTTP status; the UI opens only `https://pluto.tv/` externally; no Pluto data reaches VOD; and targeted tests cover those contracts. If an authorized API is later provided by Pluto, a subsequent implementation can replace the unavailable adapter without changing provider identity or namespace.

## Official references

- Pluto TV Terms of Use: https://legal.paramount.com/us/en/plutotv/terms-of-use
- Pluto TV authorized platforms: https://cbsi.my.salesforce-sites.com/CBSi/articles/en_US/Knowledge/PTV-Authorized-Pluto-TV-Platforms
- Pluto TV Live Streaming Technical Requirements: https://www.paramount.com/pluto-tv-live-stream-specifications

These sources were checked on 2026-11-08. This is an engineering scope decision, not legal advice.
