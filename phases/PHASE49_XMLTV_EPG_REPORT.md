# Phase 49 — XMLTV / EPG Report

**Date:** 2026-11-08  
**Base archive:** `RAVEN23-PHASE48.zip`  
**Output:** `RAVEN23-PHASE49.zip`  
**Status:** `Implementation Prepared — CI Pending`

## Delivered

Phase49 adds a provider-neutral XMLTV model, bounded parser, secure bounded fetch/cache repository, exact M3U `tvg-id` mapping, Now/Next interval calculation, and a compatibility adapter into the current `DaddyLiveEpg` schedule surface. Header feed URLs are read from supported M3U metadata. EPG failures are intentionally isolated from channel discovery and stream resolution.

## Static packaging checks

The packaging checks confirm the intended explicit CI test list contains 28 unique existing Dart test paths. The formatter script contains 81 unique existing Dart source/test paths. Workflow YAML, embedded Python and shell syntax are checked at packaging time; archive integrity is checked separately after ZIP creation.

## Verification limits

- Dart/Flutter SDKs are unavailable in this packaging environment.
- `dart format` / `flutter analyze` / `flutter test` were not executed here.
- No Android Debug/Release APK was built.
- No external XMLTV server, IPTV channel or physical-device playback was live-verified.
- Phase46, Phase47, Phase48 and Phase49 remain CI-pending, regardless of the successful pre-change run `42428688859` which covers only Phases37–45.

## Acceptance snapshot

| Requirement | Source implementation | Local runtime evidence |
|---|---|---|
| Bounded XMLTV parse | Prepared | Not run |
| Offset-aware UTC normalization | Prepared | Not run |
| Exact `tvg-id` mapping | Prepared | Not run |
| Now/Next by time intervals | Prepared | Not run |
| Fresh cache + stale marker | Prepared | Not run |
| EPG failure isolated from M3U playback | Prepared contract test | Not run |
| Mobile and Android TV existing schedule surface | Shared adapter path | Device check pending |
| CI / Analyze / Release | Configured 28-file gate | Pending |

## Next planned phase

**Phase50 — WebView & Embedded Playback Integration**, according to the master blueprint. Phase51 remains the integration, regression and release gate.
