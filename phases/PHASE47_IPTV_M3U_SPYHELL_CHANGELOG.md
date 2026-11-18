# Phase 47 — Changelog

## Added

- `lib/services/iptv/m3u_playlist_parser.dart`
- `lib/services/iptv/m3u_playlist_repository.dart`
- `lib/services/iptv/m3u_live_tv_service.dart`
- `lib/services/iptv/spyhell_live_tv_service.dart`
- `lib/services/iptv/live_tv_category_mapper.dart`
- `lib/screens/common/iptv_playlist_manager_dialog.dart`
- `test/services/iptv/m3u_playlist_parser_test.dart`
- `test/services/iptv/m3u_live_tv_service_test.dart`
- `test/services/iptv/m3u_playlist_repository_test.dart`
- `test/services/iptv/spyhell_live_tv_adapter_test.dart`
- Six Phase47 records: Plan, Audit, Implementation, Tests, Changelog and Report.

## Modified

- `lib/services/live_tv_service_manager.dart` — registered M3U and Spyhell Live providers and playlist management APIs.
- `lib/screens/common/live_tv_screen.dart` — shared M3U management UI, Spyhell install guidance and optional-EPG prompt guard.
- `lib/tv/screens/tv_live_screen.dart` — matching TV controls and optional-EPG prompt guard.
- `lib/video_providers/unified/quickjs_source_catalog_profile.dart` — Live TV adapter role for the 15 curated Spyhell IDs.
- `lib/video_providers/unified/source_manifest.dart` — documents and retains VOD exclusion for dedicated Live TV adapters.
- `lib/screens/common/source_repositories_screen.dart` — labels marked adapters as Live TV.
- `test/live_tv_service_manager_test.dart` — four provider registry and namespace expectations.
- `tool/format_phase37_47_dart.sh` — maintained formatter target list.
- `.github/workflows/android-ci.yml` — 25-file Phase37–47 contract gate, renamed test step/output and artifact log.
- `phases/IMPLEMENTATION_TRACKER_PHASE36_56.md` — Phase47 status and current CI scope.
- `phases/README_MASTER_IMPLEMENTATION.md` — Phase47 outputs and truthful validation state.
- `phases/MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md` — dated implementation snapshot only; planned scope/dependencies are unchanged.

## Preserved boundaries

- `RAVEN23-PHASE45.zip` was not extracted for editing, overwritten or rebuilt.
- The current code is based on the supplied `RAVEN23-PHASE46` archive.
- No VOD eligibility was enabled for Spyhell Live IDs.
- No build or test command was executed.
