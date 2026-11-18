# Phase 49 — XMLTV / EPG Changelog

**Date:** 2026-11-08  
**Base:** `RAVEN23-PHASE48.zip`  
**Status:** `Implementation Prepared — CI Pending`

## Added files

- `lib/models/xmltv_epg.dart`
- `lib/services/iptv/xmltv_epg_parser.dart`
- `lib/services/iptv/xmltv_epg_repository.dart`
- `lib/services/iptv/xmltv_epg_mapper.dart`
- `test/services/iptv/xmltv_epg_parser_test.dart`
- `test/services/iptv/xmltv_epg_repository_test.dart`
- `tool/format_phase37_49_dart.sh`
- Six Phase49 documents in `phases/` (plan, audit, implementation, tests, changelog and report).

## Modified application/test/CI files

- `lib/models/live_tv.dart` — optional `Channel.tvgId` JSON field and copy propagation.
- `lib/services/iptv/m3u_playlist_parser.dart` — XMLTV header attributes and BOM-safe header parsing.
- `lib/services/iptv/m3u_live_tv_service.dart` — optional XMLTV load, exact-ID enrichment, legacy schedule adapter and lifecycle closure.
- `lib/services/live_tv_service_manager.dart` — M3U optional EPG capability.
- `lib/screens/common/live_tv_screen.dart` — do not show sports-preference prompt for generic IPTV EPG.
- `test/services/iptv/m3u_playlist_parser_test.dart`
- `test/services/iptv/m3u_live_tv_service_test.dart`
- `test/live_tv_service_manager_test.dart`
- `.github/workflows/android-ci.yml` — Phase49 test step/log/artifact naming and 28-file contract gate.
- `tool/format_phase37_48_dart.sh` — compatibility invocation of the maintained Phase49 format list.
- `phases/MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_56.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/README_CHANGED_FILES.txt`

No source repository scripts, third-party providers, playback engine, dependency manifests, Android build configuration or Pluto experimental fallback were intentionally modified for this phase.
