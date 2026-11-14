# Phase 48 — Pluto TV Live Adapter Audit

**Audit date:** 2026-11-08  
**Working base:** RAVEN23-PHASE47  
**Disposition:** Experimental / Unavailable (external handoff only)

## Existing project state

- `LiveTvServiceManager` is the common registry used by the Mobile Live TV screen and Android TV Live screen.
- `LiveTvService` exposes `getCatalog()` and `getStream()` to the existing manager/LivePlayer boundary.
- The repository snapshot contains a Pluto TV Spyhell index entry with `type: movie`, but the linked `providers/plutotv.js` script is not present in the project tree or available for static inspection.
- No Pluto channel catalogue, official developer contract, partner API credentials, provider metadata fixture, or permitted stream resolver exists in the supplied working tree.
- Treating the snapshot's generic `movie` label as VOD support would be incorrect for this Live TV phase and would risk leaking Pluto into the VOD catalog.

## External constraints verified

The official Pluto TV Terms of Use prohibit accessing the service through an interface other than Pluto's own, unauthorized scraping/automated data collection, reverse engineering, and circumvention of geo-filtering/access-control measures. The official support page lists Android mobile and Android TV as platform families but does not grant RAVEN23 a third-party playback interface. The published live-streaming technical requirements describe partner stream delivery/onboarding, not a public API for third-party clients.

## Engineering decision

A private endpoint, web request sequence, token mechanism, region header, or unofficial community script is not a sufficient authorization or stability contract. Therefore Phase48 must not create channels or streams based on these mechanisms. The correct fallback explicitly allowed by the Blueprint is an Experimental/Unavailable provider with official external handoff.

## Files to be changed

- `lib/services/pluto_tv_experimental_service.dart` — fail-closed service contract.
- `lib/services/live_tv_provider_unavailable_exception.dart` — typed unavailable result.
- `lib/services/live_tv_service_manager.dart` — registration, isolated namespace, experimental metadata and safe failure state.
- `lib/screens/common/live_tv_screen.dart` — experimental guidance and official website handoff.
- `lib/tv/screens/tv_live_screen.dart` — equivalent Android TV guidance and handoff.
- `test/pluto_tv_experimental_service_test.dart` and `test/live_tv_service_manager_test.dart` — deterministic contract coverage.
- `.github/workflows/android-ci.yml` and `tool/format_phase37_48_dart.sh` — bounded Phase48 regression gate.

## Risks and limits

- Official website launch may resolve to a browser or the official app depending on device and Android app-link configuration; RAVEN23 does not force-install or target a package name.
- Availability, supported device models, and programme lineup remain region/provider controlled.
- The external handoff is not a Pluto channel playback integration in `LivePlayer`.
- CI, analyzer, formatter execution, APK build, and device behavior are not verified in this editing pass.
