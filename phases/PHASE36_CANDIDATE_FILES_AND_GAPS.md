# Phase 36 — Candidate Files, Contracts & Change Boundaries

هذه القائمة تمنع التعديلات العشوائية عند بدء Phase 37–51. المسارات أدناه مرشحة للمراجعة أو التعديل في المراحل اللاحقة؛ لم تتغير في Phase 36.

## 1. Existing source architecture — preserve and extend

| المسار | الحالة التي وجدها التدقيق | المرحلة المحتملة |
|---|---|---|
| `lib/video_providers/unified/source_engine.dart` | SourceEngine / SourceEngineRegistry / resolveMany؛ أقصى توازٍ قابل للضبط والافتراضي 1 | 37، 45 |
| `lib/video_providers/unified/source_manifest.dart` | SourceManifest، SourceEngineDescriptor، SourceEngineKind، stableKey=`repositoryUrl::id` | 37، 38، 42 |
| `lib/video_providers/unified/source_repository_manager.dart` | add/remove/install/disable/sync، cache 5m، seeded OpenStream only | 37، 42 |
| `lib/video_providers/unified/source_repository_client.dart` | جلب الفهارس وإثراء بعض Stremio entries؛ file scripts تُحمّل لاحقاً من runtime | 37، 42 |
| `lib/video_providers/unified/source_repository_parser.dart` | OpenStream/Zangetsu/Stremio؛ type mapping وnsfw defaults وconfigurable handling | 37، 40، 42 |
| `lib/video_providers/unified/quickjs_source_engine.dart` | getInfo → type gate → search → detail/episodes → streams | 38، 44 |
| `lib/video_providers/unified/quickjs/quickjs_provider_runtime.dart` | تحميل وإدارة runtime provider وnetwork bridge | 39، 42، 44 |
| `lib/video_providers/unified/quickjs/js_bootstrap.dart` | `__settings` وgetSettings bridge exposed؛ لا user settings injection found | 39 |
| `lib/video_providers/unified/quickjs/quickjs_stream_mapper.dart` | mapping stream/audio/subtitle metadata | 38، 39، 44 |
| `lib/video_providers/unified/stremio_addon_provider.dart` | Stremio stream resolver وID prefixes | 40 |
| `lib/video_providers/unified/vidking_direct_provider.dart` | quality filter plus audio-language derivation from qualityFilter | 41 |
| `lib/video_providers/unified/openstream_anime_engine.dart` | Native Anime engine + existing Anime mappings | 43 (preserve) |
| `lib/video_providers/unified/openstream_web_embed_engine.dart` | Web Embed engine | 43، 50 |
| `lib/video_providers/unified/unified_source_service.dart` | ترتيب وتوجيه المحركات وmaxConcurrency:1 في المسار الحالي | 45 |

## 2. Existing Live TV architecture — preserve data compatibility

| المسار | الحالة | المرحلة |
|---|---|---|
| `lib/services/daddylive_service.dart` | `LiveTvService` contract + DaddyLive implementation | 46 |
| `lib/services/ethio_sports_service.dart` | EthioSports implements LiveTvService | 46 |
| `lib/models/live_tv.dart` | Channel + DaddyLiveCatalog/Stream/EPG models | 46–49 |
| `lib/controllers/live_tv_database_controller.dart` | namespace-aware DB keys | 46–49 |
| `lib/screens/common/live_tv_screen.dart` | DaddyLive directly constructed; Ethio selector code commented | 46 |
| `lib/tv/screens/tv_live_screen.dart` | DaddyLive directly constructed; Ethio selector code commented | 46 |
| `lib/screens/common/live_player.dart` | existing LivePlayer hand-off | 46–49 |

Do not rename or migrate existing `daddylive` storage keys without a tested migration. Any generic model change should be additive/adapter based.

## 3. Existing fixtures and tests to extend

- `test/fixtures/openstream_official_repo.json` — only full checked-in repository fixture among the six.
- `test/video_providers/source_repository_parser_test.dart` — parser contracts; add normalized fixtures for each of the five Zangetsu feeds.
- `test/video_providers/source_repository_client_test.dart` — remote index and Stremio enrichment path.
- `test/video_providers/source_repository_manager_test.dart` — stable keys, install/disable/default seed; add cross-repo duplicate advisory tests.
- `test/video_providers/stremio_addon_provider_test.dart` — add Manifest behaviorHints matrix at parser/client level.
- `test/video_providers/quickjs_stream_mapper_test.dart` and `test/video_providers/unified/quickjs_stream_mapper_test.dart` — metadata mapping.
- `test/video_providers/vidking_payload_cipher_test.dart` — cipher regression tests; add quality/language separation tests elsewhere.
- `test/live_tv_error_test.dart` — basic Live TV error coverage; add service manager/M3U/EPG contract fixtures.

## 4. Files explicitly out of scope for Phase 36

No files in `lib/`, `test/`, `assets/`, `android/`, `.github/`, `pubspec.yaml`, or `pubspec.lock` were edited. The audit only adds/updates documentation in `phases/`.

## 5. Required safeguards before editing

- Capture a clean CI run for the Phase35.1 baseline or record and resolve its exact failure before merging implementation.
- Add local JSON fixtures from each retrieved index (sanitize only if required; preserve source ids and versions) and pin their observed snapshot date.
- Do not commit raw source scripts or auto-install them by default until their capability, license/permissions, adult classification, runtime, and playback behavior are reviewed.
- Keep external source availability tests out of deterministic CI; use fixtures for stable tests and an explicitly separate live smoke-test workflow.
- Compare all file changes against this base archive and report exact changed paths in each phase.
