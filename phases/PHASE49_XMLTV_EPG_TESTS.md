# Phase 49 — XMLTV / EPG Tests

**Date:** 2026-11-08  
**Status:** `Implementation Prepared — CI Pending`

## Added XMLTV parser/mapper tests

`test/services/iptv/xmltv_epg_parser_test.dart` covers:

- Channel metadata and valid XMLTV programme parsing.
- Numeric timezone offset normalization into UTC.
- Now/Next calculated by interval rather than feed order.
- Deterministic overlap handling (latest active start wins).
- Duplicate and invalid programme intervals.
- DTD/entity rejection and malformed XML.
- Wrong root and maximum input size.
- Exact `tvg-id` / XMLTV channel-id matching without case-folding or fuzzy name matching.
- Adaptation of matched programmes to the legacy schedule model.

`test/services/iptv/xmltv_epg_repository_test.dart` covers:

- Download, parse and fresh compressed cache reuse.
- Stale cache explicitly marked when refresh fails.
- Redirect to a private/loopback address is rejected before a second request.
- Declared response length above the XMLTV limit is rejected.

## Expanded existing tests

- `test/services/iptv/m3u_playlist_parser_test.dart`: EPG header feed URL parsing.
- `test/services/iptv/m3u_live_tv_service_test.dart`: `tvg-id` preservation, current/next mapping, legacy schedule adaptation, and proof by contract that a failing EPG does not prevent catalog or stream resolution.
- `test/live_tv_service_manager_test.dart`: M3U provider now advertises optional EPG support.

## CI contract gate

` .github/workflows/android-ci.yml` enumerates 28 explicit and unique test paths (Phases 37–49). Both new XMLTV tests are included. The automatic APK workflow continues to exclude unrelated widget batches and the full Flutter suite.

The formatter script `tool/format_phase37_49_dart.sh` contains 81 unique file targets, including all Phase49 source and test files. `tool/format_phase37_48_dart.sh` remains as a compatibility wrapper.

## Not executed locally

Dart and Flutter executables are not installed in the packaging environment. Therefore no `dart format`, `flutter analyze`, `flutter test`, Release APK build or device playback result is claimed. The 28-file gate is a configured CI target, not a passing test report.
