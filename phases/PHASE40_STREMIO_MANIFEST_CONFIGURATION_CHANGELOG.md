# Phase 40 — Stremio Manifest & Configuration Engine — Changelog

**Base:** `RAVEN23-PHASE39-QUICKJS-SETTINGS-IMPLEMENTATION-PENDING-CI.zip`  
**تاريخ العمل:** 2026-11-07

## ملفات التطبيق المعدّلة

- `lib/video_providers/unified/source_repository_parser.dart` — validation وStremio config/catalog/resource profiles/Configuration URL.
- `lib/video_providers/unified/stremio_addon_provider.dart` — type-specific ID rules، optional/required config gate، configuration redirect validation.
- `lib/video_providers/unified/unified_source_service.dart` — conditional IMDb identity resolution وفق resource profile.
- `lib/screens/common/source_repositories_screen.dart` — حالة config وزر فتح الصفحة الرسمية للإضافة.
- `lib/video_providers/unified/source_engine.dart` — مراجعة وإزالة تعارض تعريف type-check المكرر الذي ظهر أثناء تدقيق تكامل المحرك.
- `assets/translations/ar.json`
- `assets/translations/en.json`
- `assets/translations/es.json`
- `assets/translations/hi.json`
- `lib/translations/codegen_loader.g.dart` — مزامنة مفاتيح مخازن الترجمة المولدة مع أصول JSON.
- `assets/translations/es.json`, `assets/translations/hi.json`, and their generated maps — restored the pre-existing missing `provider_media_type_unsupported` key so the existing locale-key equality test can pass.
- `.github/workflows/android-ci.yml` — إضافة parser/provider/client/identity suites وملفات Phase 40 إلى بوابات format/test الموجودة.

## ملفات الاختبار المضافة/المعدّلة

- `test/fixtures/stremio/yastream_manifest.json` — جديد.
- `test/video_providers/unified_source_service_stremio_identity_test.dart` — جديد.
- `test/video_providers/source_repository_parser_test.dart`.
- `test/video_providers/source_repository_client_test.dart` — verify that one unavailable add-on manifest does not suppress another healthy add-on.
- `test/video_providers/stremio_addon_provider_test.dart`.

## وثائق المرحلة

- `PHASE40_STREMIO_MANIFEST_CONFIGURATION_PLAN.md`
- `PHASE40_STREMIO_MANIFEST_CONFIGURATION_AUDIT.md`
- `PHASE40_STREMIO_MANIFEST_CONFIGURATION_IMPLEMENTATION.md`
- `PHASE40_STREMIO_MANIFEST_CONFIGURATION_TESTS.md`
- `PHASE40_STREMIO_MANIFEST_CONFIGURATION_CHANGELOG.md`
- `PHASE40_STREMIO_MANIFEST_CONFIGURATION_REPORT.md`

## الحفاظ / عدم التغيير

- لا حذف لملفات baseline.
- لا إنشاء محرك Stremio أو manager موازٍ.
- لم يتغير Application ID أو package name أو signing configuration أو إعداد Release/ARM64.
- لم يتغير مشغل الفيديو أو عقد تسليم `UnifiedStreamOption`.
- لا migration لبيانات المستخدم ولا credentials جديدة.

## Rollback

إرجاع ملفات التطبيق والاختبارات والترجمات وWorkflow المذكورة إلى نسخ Phase 39، وحذف Fixture وملفات Phase 40 الستة. لا يتطلب التغيير ترحيلاً عكسياً لتخزين المستخدم.


## إصلاح فشل بوابة التنسيق بعد أول CI

- `tool/format_phase37_40_dart.sh` — جديد؛ قائمة موحدة للملفات الـ36 ذات الصلة، مع نمطي تطبيق التنسيق والفحص الصارم.
- `.github/workflows/android-ci.yml` — يستبدل الفحص check-only المنفرد بخطوتي apply ثم strict check، ويلتقط ويُحمّل patch التنسيق باسم Artifact مستقل.
- `PHASE40_STREMIO_MANIFEST_CONFIGURATION_REPORT.md`, `PHASE40_STREMIO_MANIFEST_CONFIGURATION_TESTS.md`, `PHASE40_CI_FORMAT_RECOVERY.md`, و`IMPLEMENTATION_TRACKER_PHASE36_56.md` — توثيق السبب والإصلاح وحالة إعادة تشغيل CI.

## CI Analyze recovery follow-up — 2026-11-07

- Applied the uploaded canonical Dart formatting patch (`RAVEN23-dart-format-patch.zip`) to the project baseline.
- Corrected the seven analyzer/compile errors reported by the subsequent GitHub Actions `flutter analyze` run.
- Cleaned all analyzer warnings and infos listed in the supplied report, including deprecated Flutter API use, invalid regex flags, unnecessary imports/null assertions, control-flow braces, string interpolation and pubspec sorting.
- Added `PHASE40_CI_ANALYZE_RECOVERY.md` and updated `PHASE40_CI_FORMAT_RECOVERY.md` and `IMPLEMENTATION_TRACKER_PHASE36_56.md`.
- This is a prepared fix set only; Analyze/tests/Release must be rerun in GitHub Actions before Phase 40 is accepted.


### CI analyzer follow-up — 2026-11-07

- Applied the newly supplied `dart-format.patch` to the four test files it targets.
- Fixed seven `prefer_adjacent_string_concatenation` findings in the player quality labels using a single `${height}p` interpolation.
- Fixed the OpenStream and Stremio ID quote-style findings.
- Reordered `flutter_js` and `pointycastle` alphabetically in `pubspec.yaml`; no dependency version changed.
- Kept strict analysis enabled; pending a fresh GitHub Actions run.


## CI focused-test recovery — 2026-11-07

- `lib/video_providers/unified/source_repository_parser.dart`: detect malformed Stremio manifests by their identifying fields even when `resources` is missing; remove URI fragment components without retaining an empty `#`; preserve query/path on runtime endpoint; clear query from `/configure`.
- `lib/video_providers/unified/source_repository_client.dart`: remove fragments from derived manifest/base endpoint URLs while preserving configured query data.
- `test/video_providers/source_repository_parser_test.dart`: assert direct endpoint and configure URL do not contain fragment components.
- `test/video_providers/source_repository_client_test.dart`: assert derived HTTP requests are fragment-free while retaining source query parameters.
- `.github/workflows/android-ci.yml`: use expanded reporter for targeted and full Flutter tests to retain actionable assertion details.
- Added `PHASE40_CI_STREMIO_TEST_RECOVERY.md`.
- Dart/Flutter test execution remains pending; no passing status is claimed.


## CI empty-query delimiter recovery — 2026-11-07

- Latest supplied focused-test run: 140 passed / 5 failed; all five failures expected configuration URLs without `?`, while actual URLs ended with an empty `?`.
- `_stremioConfigurationUrl` now reconstructs the URL from scheme, host, explicit port and path segments, omitting query/fragment by construction.
- `_stremioBaseUrl` preserves non-empty runtime query parameters, removes fragment, and drops an explicitly empty query delimiter.
- Added regression coverage for an input Manifest URL ending in `?#fragment`; maintained coverage for preserving non-empty runtime query while omitting it from `/configure`.
- CI rerun remains required; no Dart/Flutter pass is claimed locally.


## Full Flutter suite / TV widget diagnostic recovery — 2026-11-07

- The latest visible CI excerpt reached the full test suite and stopped while reporting `tv_sport_picker_test.dart`; the supplied excerpt did not include a terminal exception or stack trace, so the exact cause is not marked confirmed.
- Replaced the two unbounded `pumpAndSettle()` calls in `test/tv_sport_picker_test.dart` with two deterministic 250 ms pumps to cover the existing focus-scroll/scale transitions without waiting for global frame quiescence.
- Added a 30-second per-test timeout to each of the three TV sport picker widget tests.
- Added `test/tv_sport_picker_test.dart` to the canonical Dart formatter target list (41 total targets).
- Changed the full-suite CI command to a 60-second per-test timeout, tee expanded output to `build-artifacts/full-flutter-test.log`, and upload that log with `if: always()` as `RAVEN23-full-flutter-test-log`.
- No production TV widget behavior was modified. Flutter/Dart execution remains pending; this is a test-harness and diagnostics recovery, not a claimed test pass.


## Comprehensive CI build report — 2026-11-07

- `.github/workflows/android-ci.yml`: added a start-time capture and a final `if: always()` Markdown report generator. Every run creates `RAVEN23-build-report.md` at the workspace root and `build-artifacts/RAVEN23-build-report.md`, appends it to the GitHub Step Summary, and uploads it with raw diagnostics as `RAVEN23-build-report-and-diagnostics` (30-day retention).
- Added step outcome reporting for checkout, tool installation, dependency resolution, formatting, analysis, focused/full tests, wrapper generation, APK build, APK audit and existing diagnostic uploads.
- Captured command output while preserving non-zero exit codes; the report extracts warnings/deprecations, notices, analyzer infos, errors, test assertions and the last 100 lines of the complete test log.
- Included UTC timeline/duration, runner/toolchain versions, build switches, APK/ABI audit and diagnostic artifact inventory. The workflow keeps all strict validation gates enabled.
- Added `PHASE40_CI_COMPREHENSIVE_BUILD_REPORTING.md`; updated tracker and master documentation.
- Static validation: YAML parse, Bash syntax, inline Python compilation, unique step IDs and synthetic report-generation smoke test passed. No real GitHub run was triggered; artifact upload and actual build report remain pending CI.
- `.gitignore`: added ignore entries for CI-generated `build-artifacts/`, `RAVEN23-build-report.md`, `apk-size-report.md` and `RAVEN23-apk.apk`; workflow artifact uploads still include these files explicitly.

## Full-suite CI failure analysis and provider scan completion fix — 2026-11-07

- Reviewed report artifact and the 1.3 MB expanded full Flutter test log for CI run `42328559177` / commit `e0bd14ddf418162a979afe0d26a9f512166746d4`.
- Observed gates: dependency resolution, format, analyze, and focused source/Stremio suite passed; full suite reported 2,143 passed, 34 failed, 11 skipped. Gradle Wrapper, APK build and APK audit were not reached.
- Confirmed 11 `provider_background_scan_test.dart` timeouts shared one lifecycle cause: `ProviderScanSession._run()` awaited the single-subscription updates stream's close future before completing its scan future. Dart documents that a non-broadcast stream close future does not complete if there is no listener; it also buffers events until a listener attaches.
- `lib/video_providers/provider_loader.dart`: close the updates stream without awaiting observer consumption, then resolve `session.completed` after worker completion. This decouples scan completion from whether a UI observer subscribes, while preserving late single-listener event delivery.
- `test/provider_background_scan_test.dart`: add regression coverage that completion resolves without an updates listener and that a listener attached after completion receives the buffered start/completion events.
- `.github/workflows/android-ci.yml`: full build report now inventories every unique expanded `[E]` test failure, lists nearby assertion/timeout details, counts timeouts, and recognizes `[WARNING]` localization messages. Warning lines are deduplicated in the excerpt while retaining occurrence counts.
- Added `PHASE40_CI_FULL_TEST_SUITE_FAILURE_ANALYSIS.md` with all 34 observed failing test names and the 23 non-timeout failures requiring separate triage.
- Static checks and report-generator smoke test passed in the packaging environment. Flutter/Dart tests and Release ARM64 build have not been rerun; Phase 40 remains In Progress.
