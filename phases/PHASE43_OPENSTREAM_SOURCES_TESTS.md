# Phase 43 — Required Tests

## Minimal automatic APK gate

The CI step runs 15 explicit files (the union of required dependency and current-phase contracts). It does not run `flutter test` over the full project or broad widget batches.

1. `test/video_providers/source_contracts_test.dart` — source identity/capability contracts (Phase 37).
2. `test/video_providers/source_engine_contract_test.dart` — registry and dispatch (Phase 37).
3. `test/video_providers/source_repository_manager_test.dart` — repository lifecycle (Phase 37.1).
4. `test/video_providers/unified/quickjs_source_engine_test.dart` — episode/QuickJS boundary (Phase 38).
5. `test/video_providers/unified/episode_identity_normalizer_test.dart` — exact episode identity (Phase 38).
6. `test/video_providers/source_repository_parser_test.dart` — 30-entry OpenStream fixture, engine kinds, endpoint routes, Beta/fallback states and source lifecycle.
7. `test/video_providers/source_repository_client_test.dart` — manifest enrichment and descriptor preservation.
8. `test/video_providers/stremio_addon_provider_test.dart` — Stremio stream contracts (Phase 40).
9. `test/video_providers/unified_source_service_stremio_identity_test.dart` — Stremio service identity routing (Phase 40).
10. `test/video_providers/source_repository_revision_test.dart` — versioning and rollback (Phase 42).
11. `test/video_providers/source_host_policy_test.dart` — SSRF/network policy plus deterministic Re:Anime movie/episode mapping (Phase 42/43).
12. `test/video_providers/quickjs_bridge_security_test.dart` — QuickJS bridge restrictions (Phase 42).
13. `test/video_providers/vidking_direct_provider_test.dart` — VidKing route dispatch, exact movie/series request coordinates, audio priority and expiry parser (Phase 41/43).
14. `test/video_providers/vidking_audio_quality_normalizer_test.dart` — language/quality independence (Phase 41).
15. `test/settings_vidking_audio_language_test.dart` — persisted audio preference (Phase 41).

## New deterministic Phase 43 cases

- Each of the nine official VidKing `sourceId` entries issues the exact route from its manifest; the test uses a mocked 503 and does not assert playback.
- A VidKing TV request includes exact season and episode coordinates.
- Re:Anime maps a TMDB TV S2E4 to the fixture's AniList episode 8.
- Re:Anime routes an AniList-mapped film to episode slot 1.
- The official fixture retains Beta/Slow/Experimental and fallback distinctions.
- Provider expiry parser keeps explicit ISO and epoch values and ignores unknown/missing expiry.

## Static packaging checks

The workflow YAML parses successfully, all 13 embedded Bash run blocks pass `bash -n`, all 3 embedded Python heredocs compile, all 15 test paths exist and are unique, and each modified Dart source/test file is covered by the explicit 48-file formatter list. These are structural checks only; they do not execute Dart/Flutter tests.

## Time constraints

- Test step: 10 minutes maximum.
- Individual test timeout: 30 seconds.
- Concurrency: 4.
- Formatting target list is explicit and includes every modified Dart file.
- No complete Flutter suite and no unrelated widget batch.

## Interpretation

A passing mocked contract test is `Contract Verified`, not `Playback Verified`. A source may be called playback verified only after a real, valid stream URL has been observed playing on a supported Android device, with headers/subtitles/quality/expiry behavior recorded.

**Execution:** Flutter/Dart SDK is unavailable in the packaging environment. These tests are prepared but have not been executed locally; GitHub Actions must validate them.
