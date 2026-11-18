# Phase 46 — Unified Live TV Service Manager Report

## Status

**Implementation Prepared — CI Pending.**

## What was implemented

A central manager now owns DaddyLive and EthioSports services, persists provider selection, exposes catalog/stream/refresh/categories/health, and closes lazy-created services. Mobile and Android TV screens use the manager and can switch providers. The player receives the manager through the existing `LiveTvService` contract.

The original EthioSports selector was dormant because its registration and UI were commented out, while the active screen logic was bound to DaddyLive. The implementation restores selection without merging provider-specific cache, favorites, recents or preferred-sports data. The built-in provider registry now lives in the manager and is shared by Mobile and TV screens.

DaddyLive keeps the `daddylive` database namespace and existing link semantics. EthioSports uses `ethiosports` storage and `ethio:` channel identity. Optional EPG failure no longer prevents EthioSports channel discovery. Before playback, the manager validates the stream URL and expiry, allow-lists request headers, normalizes HLS/DASH media type, validates ClearKey metadata without bypassing DRM, and rejects expired variants. Link expiry is propagated to LivePlayer; expired current links trigger a fresh provider resolution rather than stale backup reuse.

## Checks performed in the packaging environment

- YAML parsing of the Android CI workflow.
- `bash -n` validation of every embedded Bash block and the new formatter script.
- Python AST compilation of embedded workflow report scripts.
- Verification that each of the 21 explicit CI test paths exists and is unique.
- Focused Phase46 coverage: 14 cases across manager/stream-contract and EthioSports adapter tests.
- Verification that each Dart file changed/added in this phase is included in the bounded formatter target list (62 unique targets).
- Diff inventory against the Phase44/45 baseline: 1,420 original files preserved, 10 new files, 9 modified files, 0 deletions.
- JSON/locale files remain parseable; no provider URL, app ID, signing configuration or unrelated player architecture was intentionally changed.

## Not run

Flutter and Dart executables are unavailable in this packaging environment. Therefore:

- `dart format` is pending;
- `flutter analyze` is pending;
- 21-file focused CI test gate is pending;
- Android Release ARM64 build and APK audit are pending;
- Android Mobile/TV live provider smoke tests are pending.

Mocked EthioSports tests cannot prove the external EthioSports endpoint is currently online. DaddyLive and EthioSports must be checked on a real device after CI.

## Next step

Run the updated GitHub Actions workflow. Review Analyze, the bounded 21-file test gate, Release ARM64 and APK audit. Then perform device smoke checks: open Live TV on Mobile and Android TV, switch DaddyLive/EthioSports, verify channel load/playback, switch channels inside LivePlayer, confirm favorites/recents remain separated after app restart, and verify that DaddyLive's EPG remains intact.
