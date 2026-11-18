# Phase 44 — Changelog

- Added `lib/video_providers/unified/quickjs_source_catalog_profile.dart`.
- Modified `lib/video_providers/unified/source_manifest.dart` and `source_repository_parser.dart` for safety declaration state and repository-specific catalog roles.
- Modified `lib/screens/common/source_repositories_screen.dart` to show source qualification warnings and roles.
- Updated generated/localization resources in `assets/translations/{en,ar,es,hi}.json` and `lib/translations/codegen_loader.g.dart`.
- Added `test/video_providers/phase44_quickjs_catalog_test.dart`.
- Updated the Phase 37–45 format target script and targeted CI file list after Phase 45 preparation.

No catalog source is auto-installed, auto-activated, deleted, or marked playback-verified by these changes.

## CI recovery follow-up — 2026-11-08

- Fixed Zangetsu `sources` parsing to retain upstream Beta `status` values (0–3), explicit `fallback` booleans and fallback tags instead of silently defaulting every entry to status 1.
- Preserved declared source tags alongside RAVEN23-derived catalog tags.
- Expanded the focused Beta/fallback regression test to assert both states independently.
- CI run `42424422614` had passed analyze/format but reported this regression test among four failures. The correction is prepared; CI rerun is pending.
