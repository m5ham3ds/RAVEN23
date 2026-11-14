# Phase 48 — Pluto TV Live Adapter Report

**Date:** 2026-11-08  
**Status:** **Implementation Prepared — CI Pending**  
**Runtime disposition:** **Experimental / Unavailable in RAVEN23; official external handoff only**

## Outcome

Phase48 is implemented according to the Blueprint's explicit fallback: when a lawful, documented third-party channel interface cannot be verified, the provider remains Experimental/Unavailable rather than claiming compatibility. Pluto now appears in the shared Live TV provider list on Mobile and Android TV, has an isolated database namespace, explains why in-app channel playback is unavailable, and opens the official Pluto TV website externally.

## Why no channel/stream adapter was fabricated

The supplied source snapshot contains only an index record for `plutotv` marked `movie`; the referenced `providers/plutotv.js` source script was not included in the project files. Official Pluto terms restrict alternate interfaces, unauthorized scraping, and geo/access-control circumvention. No written partner authorization, public third-party channel API contract, or credentials were supplied. Pluto's official platform list includes Android and Android TV in supported markets, so an external handoff is the appropriate user-facing route.

## Delivered

- Shared provider registration: `pluto-tv`.
- Experimental badge in provider label and metadata.
- Isolated namespace: `pluto_tv_experimental`.
- Fail-closed catalogue and stream resolution with a typed unavailable state.
- No channel, metadata, EPG, stream URL, VOD or token extraction.
- Mobile and Android TV official website handoff pinned to HTTPS `pluto.tv`.
- Focused service/manager contract tests and 26-file CI suite configuration.
- Six phase documents and updates to the master blueprint/tracker.

## Validation limits

The archive and static workflow checks are performed separately during packaging. Flutter Analyze, Dart formatting, focused tests, GitHub Actions, Release APK creation, and device testing have not been executed in this pass. The Phase46/47 validation gates remain pending as well. Do not consider this phase CI-passed or live-playback verified.

## Next phase

The next planned phase is **Phase49 — XMLTV / EPG**, which should generalize programme-guide parsing without assuming that every Live TV provider has an EPG. Pluto should remain without guide metadata unless an authorized source later becomes available.

## Official references checked on 2026-11-08

- Terms of Use: https://legal.paramount.com/us/en/plutotv/terms-of-use
- Authorized platforms: https://cbsi.my.salesforce-sites.com/CBSi/articles/en_US/Knowledge/PTV-Authorized-Pluto-TV-Platforms
- Live-streaming partner requirements: https://www.paramount.com/pluto-tv-live-stream-specifications
