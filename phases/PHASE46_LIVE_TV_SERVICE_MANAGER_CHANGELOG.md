# Phase 46 — Changelog

## Added

- `lib/services/live_tv_service_manager.dart` — unified standard registry and provider/stream validation.
- Six Phase46 planning, audit, implementation, testing, changelog and report documents under `phases/`.
- `test/live_tv_service_manager_test.dart`
- `test/ethio_sports_service_test.dart`
- `tool/format_phase37_46_dart.sh` as the Phase37–46 bounded formatter target list.

## Modified

- `lib/services/daddylive_service.dart` — HTTP status preservation through non-JSON/API/watch-page failures; expiry metadata is now retained for discovered variants.
- `lib/services/ethio_sports_service.dart` — optional EPG behavior, robust HTTP status handling, and variant expiry preservation.
- `lib/models/live_tv.dart` — variant expiry parsing for ISO and epoch timestamps.
- `lib/screens/common/live_player.dart` — accepts the validated expiry and re-resolves from the provider manager instead of trying known-stale backups after expiry.
- `lib/screens/common/live_tv_screen.dart` — manager registration/selection, provider-scoped storage, manager-backed playback/channel switching, first-use sports preference per provider, and EPG capability gating.
- `lib/tv/screens/tv_live_screen.dart` — matching Android TV integration.
- `test/live_tv_service_manager_test.dart` — provider namespace/health plus stream URL, expiry, headers, media type and ClearKey validation coverage.
- `test/ethio_sports_service_test.dart` — optional EPG, stream metadata, variant expiry and HTTP status coverage.
- `.github/workflows/android-ci.yml` — Phase46 tests/artifact/report integration; bounded suite expanded from 19 to 21 explicit files.
- `tool/format_phase37_46_dart.sh` — explicit formatting coverage for every Dart file changed/added for this phase.
- `phases/IMPLEMENTATION_TRACKER_PHASE36_56.md` — latest CI success evidence and Phase46 state.
- `phases/README_MASTER_IMPLEMENTATION.md` — Phase46 documentation index and latest status.

## Preserved

- Existing `LiveTvService` and playback semantics remain compatible. `LiveStreamVariant` and `LivePlayer` receive additive optional expiry fields; existing constructors remain source-compatible.
- DaddyLive provider ID, default selection, share/focus link semantics, existing `daddylive_*` database keys and EPG.
- Stream headers, expiry, media type, ClearKey metadata and variants are preserved where valid; unsupported header names, malformed DRM key pairs, invalid URLs and expired links/variants are rejected or removed before playback.
- No DRM bypass, provider auto-verification, IPTV/M3U functionality or Phase47 work.

## Inventory

- Against the Phase44/45 baseline: 1,420 original files retained, 10 new files, 9 modified files, zero deleted files.

## Rollback

Revert the Phase46 application/test/workflow files listed above and remove the Phase46 documentation. Existing DaddyLive persisted state is not migrated or deleted; no one-time destructive data migration is required.
