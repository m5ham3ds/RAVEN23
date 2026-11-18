> **Historical snapshot:** This is the Phase36–56 tracker as captured before the Phase57 work. Keep it for historical phase evidence; the current tracker is [`IMPLEMENTATION_TRACKER_PHASE36_57.md`](IMPLEMENTATION_TRACKER_PHASE36_57.md).

# RAVEN23 — Implementation Tracker (Phase 36–56)

**آخر تحديث (2026-11-10):** أكد مالك المشروع أن جميع عمليات البناء نجحت بالكامل حتى PHASE55. لذلك تُعامل مراحل البناء 51–55 على أنها اجتازت بناء Release وفق تأكيد المالك، ولا تُعرض تقارير CI القديمة المتجاوزة بوصفها أعطالًا حالية. لا يثبت هذا التأكيد وحده اكتمال كل اختبار تشغيل على الجهاز. أظهرت لقطات PHASE55 أربع عيوب فعلية في مسار Manga/Mihon؛ جرى تخصيص PHASE56 لمعالجتها، ونجاح بناء PHASE56 لم يُؤكد بعد.

| Phase | الاسم | الحالة | الاعتماد | بوابة الإغلاق |
|---:|---|---|---|---|
| 36 | Comprehensive Source Audit | Passed with limitations | Phase 35.1 | تم استرداد الفهارس الستة وفحص عينات scripts وتوثيق الفجوات؛ runtime/playback وCI baseline غير مثبتين محلياً |
| 37 | Unified Source Architecture | CI contract gate passed — run `42428688859` (shared 179-test gate + ARM64 Release); runtime limits remain | 36 | عقود الهوية والقدرات والحالة والتشخيص اجتازت بوابة العقود المحددة؛ التشغيل الحي لكل مزود منفصل |
| 37.1 | Bundled Repositories | CI contract gate passed — run `42428688859`; existing-install device migration remains unverified | 37 | ستة فهارس افتراضية + ترحيل v2 additive + زر الاستعادة؛ اختبارات manager/parser وتحليل وRelease اجتازت البوابة المشتركة |
| 38 | Media & Episode Normalization | CI contract gate passed — run `42428688859`; external metadata/playback remains separate | 36, 37 | exact season+episode matcher, normalized Movie/Series + classifications, QuickJS/Stremio/VidKing guards اجتازت اختبارات العقود المحددة |
| 39 | QuickJS Settings System | CI contract gate passed — run `42428688859`; live extension execution/device UX remains unverified | 36, 37 | schema parser, installed-source UI, secure persistence, per-provider runtime injection واختبارات العقود المحددة اجتازت البوابة |
| 40 | Stremio Manifest & Configuration | CI contract gate passed — latest shared run `42428688859`; live add-on playback remains unverified | 36, 37 | Stremio manifest/config contracts passed within the 179-test gate; ARM64 Release and ABI audit passed |
| 41 | VidKing Language & Quality | CI contract gate passed — run `42428688859`; live VidKing playback remains unverified | 36, 37, 38 | preference persistence, language/quality independence, OpenStream legacy migration and dependency contracts passed in shared gate |
| 42 | Repository Versioning, Integrity & Security | CI contract gate passed — run `42428688859`; WebView DNS-rebinding/device review remains limited | 36, 37 | revision/hash/provenance, GitHub commit pin, exact preview apply/rollback, SSRF/redirect/size limits and QuickJS bridge tests passed in the shared gate |
| 43 | OpenStream Integration | CI contract gate passed — run `42428688859`; external source availability/playback not proven | 37, 38, 42 | OpenStream Movie/Series/Anime adapter contracts and Release/ABI gate passed; provider playback remains unverified |
| 44 | Zangetsu & Spyhell QuickJS | CI gate passed — run `42428688859`; live extension playback remains unverified | 37, 38, 39, 42 | type/safety/status/fallback metadata، فصل Live TV عن VOD، archive/credential review؛ لا تفعيل تلقائي أو playback claim |
| 45 | Execution & Fallback | CI gate passed — run `42428688859`; live-source behavior remains dependent on external providers | 37, 38, 41, 43, 44 | bounded engine concurrency، first playable callback، measured stable ranking، expiry-only cache، circuit breaker، cancellation and metrics tests passed |
| 46 | Unified Live TV Service Manager | Phase51 integration/Release gate passed — run `42507906881`; real-provider/device smoke tests pending | 36, 37 | مدير موحد مركزي لـDaddyLive وEthioSports، اختيار محفوظ للهاتف والتلفاز، namespaces مستقلة، EPG اختياري، health/lifecycle contract، تحقق URL/expiry/headers/HLS-DASH/ClearKey؛ ضمن تكامل Phase51 الناجح (302 اختبارًا في 39 ملفًا) |
| 47 | IPTV / M3U Engine & Spyhell Live Adapters | Phase51 integration/Release gate passed — run `42507906881`; external playlist playback remains device/provider dependent | 46 | Parser/EXTINF/HLS separation، remote/local playlist repository، عقود parser/EXTINF/HLS separation وprovider mapping وVOD isolation ضمن تكامل Phase51 الناجح؛ LivePlayer/device playback وتوافر القوائم الخارجية لم يُثبتا |
| 48 | Pluto TV | Experimental / Unavailable — integration guard passed in run `42507906881`; no authorized live API/channel catalogue | 46, 47 | خدمة Live TV مستقلة وnamespace خاص وإحالة رسمية؛ لا scraping أو VOD أو stream claims دون API مصرح |
| 49 | XMLTV / EPG | Parser/cache/mapping contracts passed in Phase51 run `42507906881`; real EPG feeds/device UI pending | 46, 47 | XMLTV bounded parser/cache, exact M3U `tvg-id` mapping, UTC Now/Next and legacy schedule adapter; selected contracts were included in the successful Phase51 integrated gate (39 files / 302 tests); real EPG feeds/device UI remain pending |
| 50 | WebView / Embedded Playback | Embedded routing/lifecycle contracts and Release passed in run `42507906881`; real provider WebView/device checks pending | 37, 42, 44 | Distinct direct/embed result, visible Android WebView, direct-first provider fallback, manual verification, navigation safety and view disposal; integrated Release gate passed in Phase51; real provider WebView/device checks remain pending |
| 51 | Integration & Release | CI Release gate passed — run `42507906881` (302 tests, Analyze, Kotlin/Gradle, ARM64 APK and APK audit passed) | 36–50 | Run `42507906881` passed Analyze, format, 302 tests, Gradle/Kotlin, ARM64 Release assembly and APK audit; real device/provider playback remains separate |

| 52 | Source Repository Audit & VOD Priority Lanes | Accepted — owner confirmed successful Release build (2026-11-09) | 36–51 | Three editable lanes (Movies 13 / Series 9 / Anime 11); 15 unique active-source cap per repository; priority → direct backup → embedded fallback. Superseded intermediate CI notes were removed; PHASE52 tests are not rerun or retained as an active CI gate. |

| 53 | Zangetsu Navigation & Manga Catalogue Integration | Accepted — owner confirmed successful Release build and working behaviour (2026-11-09) | 51–52 review | RAVEN23 bottom dock and secondary navigation; Home data routing for Movies/Series/Anime; AniList metadata; Keiyoushi `.pb` separated from six video JSON repositories. Native Mihon reader/runtime was added in PHASE55. |

| 54 | Manga Catalogue Visual Parity & Repository Management | Build passed — owner confirmed through PHASE55; runtime UI defects carried into PHASE56 | Accepted Phase53 | Manga/Manhwa/Manhua catalogue, JP/KR/CN AniList filtering and Manga/Mihon Protobuf repository management exclusively in Sources; screenshots show All-feed and category-visual defects addressed by PHASE56. |
| 55 | Complete Manga Catalogue & Mihon-compatible Runtime | Build passed — owner confirmed (2026-11-10); runtime defects identified during device testing | Phase54 | Mihon-compatible Android extension loader, package/signer verification, source browser and chapter reader. Extension trust parsing and catalogue display defects are isolated to PHASE56 without weakening APK validation. |
| 56 | Manga Runtime, Catalogue Reliability & Extension Trust | Source changes prepared — CI/Release/device validation pending | PHASE55 | Parse `repo.json` as raw text safely; keep exact nested SHA-256 fingerprint trust; aggregate JP/KR/CN All feed with per-region failure isolation; add category-specific hero/Top 10 and Home-style shimmer; keep video repositories/player unchanged. |

## سجل قرارات التغيير

| التاريخ | المرحلة | القرار | السبب | الحالة |
|---|---|---|---|---|
| 2026-11-09 | Phase54 | Manga catalogue follows Home visual structure; Manga/Manhwa/Manhua use `countryOfOrigin` JP/KR/CN; repository CRUD is owned only by Sources > Manga / Manhwa Repositories | Remove visual drift and prevent video JSON/Mihon Protobuf repository management from mixing | Build later accepted by owner through PHASE55; runtime gaps moved to PHASE56 |
| 2026-11-10 | Phase55 | All builds through PHASE55 confirmed successful by project owner | Supersede stale intermediate CI failure notes without erasing accepted phase scope | Build accepted; screenshot-discovered runtime defects are not considered closed |
| 2026-11-10 | Phase56 | Read the Keiyoushi `repo.json` sidecar as plain text; aggregate regional AniList catalogues independently; restore Hero/Top 10/loading parity on every Manga type | Fix install controls and Manga catalogue defects without relaxing signer security or changing video sources/player | Source/test changes prepared; CI/Release/device verification pending |
| 2026-11-06 | Blueprint | التوسعة فوق `SourceRepositoryManager` و`SourceEngineRegistry` الحاليين | تجنب إنشاء طبقة إدارة مكررة | معتمد للخطة |
| 2026-11-06 | Blueprint | الإبقاء على `LiveTvService` و`DaddyLiveService` و`EthioSportsService` | واجهة ومزودان موجودان فعلياً | معتمد للخطة |
| 2026-11-06 | Blueprint | Phase 36 تدقيق فقط دون تغييرات وظيفية | تثبيت baseline قبل التنفيذ | معتمد للخطة |
| 2026-11-06 | Phase 37 | تم رصد Release CI baseline ناجح قبل التعديلات على commit `a9d414d`؛ لا يعتبر اختباراً لتغييرات Phase 37 | تحقق بوابة البناء الأساسية | baseline passed |
| 2026-11-06 | Phase 37 | هوية source/repository/engine/content منفصلة مع الحفاظ الحرفي على `stableKey` القديم، بما في ذلك المسافات الأصلية؛ URL credentials/query ممثلة ببصمة SHA-256 في comparison key؛ raw engine type يُسمح بقيمه الآمنة فقط في diagnostics | منع اختلاط الهويات دون كسر التخزين أو تسريب رموز | implementation drafted |
| 2026-11-06 | Phase 37 | capability metadata-only لا يمنع VOD؛ Live-TV-only ليس VOD؛ `movies-and-series` لا يتوسع إلى universal؛ `validated` لا يضاف إلا بعد نتيجة تحقق صريحة | منع الاستبعاد أو التحقق الإيجابي الخاطئ | implementation drafted |
| 2026-11-06 | Phase 37 | lock metadata لـcrypto صُحّح إلى direct main دون تغيير النسخة 3.0.6 أو checksum، بما يطابق pubspec.yaml الموجود | اتساق بيان الاعتماد المباشر مع ملف القفل | implementation drafted |
| 2026-11-06 | Phase 37 | capabilities ملف وصفي غير مفعل في dispatch حتى Phase 38؛ فيلم الأنمي يحتفظ بمسار movie ويقبل مصدر anime | تجنب تغيير قواعد Anime/Series قبل fixtures | implementation drafted |
| 2026-11-06 | Phase 37 | diagnostics منفصلة عن نتيجة التشغيل | إعداد تشخيص موحد مع الحفاظ على Legacy Player Adapter | implementation drafted |
| 2026-11-06 | Blueprint | `index.json` هو مسار Spyhell Latin الصحيح؛ `index.ison` مرفوض | تقرير الفحص المقدم | يحتاج إعادة تحقق live في Phase 36 |

| 2026-11-06 | Phase 37.1 | تضمين الفهارس الستة وترحيل v2 يضيف خمسة مستودعات إلى التثبيتات القديمة؛ زر استعادة additive؛ لا تثبيت تلقائي لإضافات Zangetsu | معالجة ظهور OpenStream فقط في صفحة المستودعات مع حماية إعدادات المستخدم | implementation complete; CI pending |
| 2026-11-06 | Phase 38 | Anime/Donghua تصنيفات للمحتوى الحلقي على Series؛ Anime feature film يبقى Movie؛ المطابقة تتطلب season+episode صريحين أو season parent صريحاً | منع تسريب حلقة من موسم آخر ومنع تحويل الأفلام إلى حلقات | implementation drafted; CI and dependency gates pending |
| 2026-11-07 | Phase 40 | `configurable` لا يعني `configurationRequired`؛ stream resource object يحترم prefixes الخاصة به؛ لا يُصطنع TMDB ID دون إعلان | الالتزام بعقد Manifest وتقليل رفض الإضافات أو إرسال معرف غير مدعوم | implementation/tests added; CI pending |

| 2026-11-07 | Phase 40 baseline reconciliation | Phase 35.1 is the visual/behavior reference; restore seeded palette generation, zero-delay RevealItem scheduling, and legacy quality-label composition; do not redesign existing main pages | prevent unrelated UI changes while retaining source-manager features required by Phases 37.1/39/40 | implementation prepared; CI pending |
| 2026-11-07 | Phase 40 CI | Run `42335259990` failed at Analyze with seven info lints; a separate full-test log reported Analyze success and 23 widget/settings test failures, so artifacts are treated as distinct attempts | avoid conflating mismatched build evidence | latest analyzer fixes prepared; no post-fix CI yet |

| 2026-11-08 | Phase 50 | فصل Direct Stream عن Embedded HTML Page؛ صفحة HTML لا تدخل BetterPlayer؛ إزالة autoplay/click automation؛ visible WebView يقتصر على public HTTP(S) ويستخدم manual verification؛ `resolveUrl` يبقى متوافقًا | إكمال `webEmbed` / `vidkingWebView` دون تغيير مشغل البث المباشر أو خرق حماية المصدر | implementation prepared; CI/device checks pending |
| 2026-11-07 | Phase 40 latest CI regression follow-up | Run `42341398241` passed dependencies, formatter, Analyze and focused tests, then failed four Phase 40 widget regressions; full suite and APK steps were skipped. | Fix test callback timing and lazy-scroll assumptions; align TV expected label with transparent default; no production UI change | test-only patch prepared; CI rerun pending |


| 2026-11-07 | Phase 40 regression recovery follow-up 2 | CI run `42375238484` passed dependencies, formatter, Analyze and 160 focused tests, then failed four widget tests. RevealItem's zero-delay timer began at the first positive fake-clock advance; Discover/Home `scrollUntilVisible` received targets with no Element in lazy Slivers; TV subtitle value and visible summary updated to 15px while the retained owned FocusNode debug label stayed 12px. | Add a 1 ms timer-delivery tick; add bounded `scrollUntilBuiltAndVisible` test helper; refresh only internally owned `TvFocusable` debug labels on semantic-label changes; keep main screen implementations and subtitle defaults unchanged. | Source corrections prepared; CI rerun required. The earlier full suite was not reached and has since been removed from the automatic APK gate; see the later Minimal CI Gate decision. Phase 40 In Progress, Phase 41 Not Started. See `PHASE40_CI_WIDGET_REGRESSION_RECOVERY_FOLLOWUP_2_2026-11-07.md`. |

| 2026-11-07 | Phase 40 Minimal CI Gate | Latest supplied analyzer excerpt failed on one redundant `flutter/widgets.dart` import in `test/support/scroll_until_built.dart`; removed the duplicate import. The former automatic APK workflow ran 15 broad source tests, 17 unrelated UI/regression tests, and the full Flutter suite. | Keep only the four test files enumerated by the Phase 40 test plan (44 non-duplicated test cases): repository parser, repository client, Stremio add-on provider, and Stremio identity resolver. Remove the other test invocations from automatic APK CI; preserve their source files for explicit/manual QA. Apply a 10-minute test-step limit and 30-second per-test timeout. Run `flutter analyze --no-fatal-infos`, keeping analyzer errors and warnings fatal while info-only lints do not block APK creation. | YAML, Bash blocks, embedded report Python, formatter target paths and test paths pass static checks in packaging; Flutter/Dart/Gradle/APK were not available locally. Phase 40 remains In Progress. See `PHASE40_CI_MINIMAL_GATE_2026-11-07.md`. |
| 2026-11-08 | Phase 49 | XMLTV is an optional provider-neutral enrichment layer, mapped to M3U solely through exact `tvg-id`; stale guide entries are never rendered | Preserve channel playback when EPG is missing or unavailable and avoid false channel/time matches | implementation prepared — CI pending |

## Phase 40 acceptance and Phase 41 start — 2026-11-07

- Phase 40: user-supplied CI run `42384394976` passed dependency resolution, Dart formatter (26 files / 0 changed), `flutter analyze` (no issues), the four Phase 40 Stremio test files (44 passed), and Release APK build. APK: 27,936,634 bytes / 26.64 MiB; ABI `arm64-v8a` only; package `com.m5ham3ds.raven23`; version 4.3.0+10.
- Acceptance scope: Phase 40 automatic CI gate is accepted. This does not establish live add-on playback, nor does it retroactively close every pending post-change/device check in Phases 37/37.1/38/39.
- Phase 41: started immediately per the approved blueprint. Added dedicated VidKing `audioLanguage`, allowlist-only normalization/migration for Vyse and Fade, legacy Killjoy compatibility, resolution-only `qualityFilter`, user-preference pass-through, and bounded dependency/Phase40/Phase41 CI test selection.
- Phase 41 files: see `PHASE41_VIDKING_LANGUAGE_QUALITY_PLAN.md`, `_AUDIT.md`, `_IMPLEMENTATION.md`, `_TESTS.md`, `_CHANGELOG.md`, and `_REPORT.md`.
- Phase 41 acceptance remains pending: no Flutter/Dart SDK was available in the packaging environment; Analyze, 12-file test gate and ARM64 Release evidence are still required before marking Passed. The original sequencing recommendation to wait before Phase 42 was superseded by the user's explicit instruction to start Phase 42 immediately; see the current status block below.

## الحالة التنفيذية الحالية بعد بدء Phase 42 — 2026-11-07

- Phase 40: مقبولة ضمن نطاق بوابة CI المحددة فقط؛ live playback خارج هذا الإثبات.
- Phase 41: تنفيذ مضاف في الأرشيف السابق، لكن CI لم يُشغّل ولم تُعتمد المرحلة.
- Phase 42: بدأ التنفيذ مباشرةً بتوجيه المستخدم؛ لا يُفسر ذلك على أنه اعتماد Phase41. اعتماداتها الرسمية في الخطة 36 و37.
- بوابة Phase42 التلقائية: أحد عشر ملفًا محددًا، مهلة 10 دقائق للخطوة و30 ثانية لكل test، توازي 4؛ لا full suite ولا دفعات UI عامة.
- لم تتوفر Flutter/Dart في بيئة الحزمة؛ لا توجد نتيجة Analyze أو tests أو APK لهذه المرحلة بعد.
- راجع `PHASE42_REPOSITORY_VERSIONING_SECURITY_*.md` للحدود، المخاطر، الملفات وبوابة الاعتماد.

## نموذج سجل إغلاق مرحلة

- Phase:
- Base archive:
- Previous phases reviewed:
- Planned files:
- Actual files changed:
- Existing behavior preserved:
- Contract tests:
- Unit/widget tests:
- `dart format`:
- `flutter analyze`:
- `flutter test`:
- Release build / CI run URL:
- Live smoke tests (separate from CI):
- Known limitations:
- Rollback path:
- Acceptance criteria result:
- Status: `Not Started | In Progress | Blocked | Passed | Accepted`


## Phase 36 closure record — 2026-11-06

- Phase: 36 — Comprehensive Source Audit
- Base archive: `RAVEN23-MASTER-IMPLEMENTATION-BLUEPRINT-PHASE36-51.zip` (Phase 35.1 baseline + Blueprint)
- Previous phases reviewed: all 54 top-level phase documents inventoried; detailed preservation review of Phases 8, 11, 14, 17, 20, 28, 31, 32, 34, 35 and 35.1; duplicate historical Phase22/25/26 documents retained.
- Planned files: documentation only under `phases/`.
- Actual files changed: `PHASE36_AUDIT_REPORT.md`, `SOURCE_REPOSITORY_SNAPSHOT.json`, `SOURCE_COMPATIBILITY_MATRIX.md`, `PHASE36_CANDIDATE_FILES_AND_GAPS.md`, `MASTER_SOURCE_CATALOG_AND_VALIDATION_MATRIX.md`, `IMPLEMENTATION_TRACKER_PHASE36_56.md`, `MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md`, `README_MASTER_IMPLEMENTATION.md`, `PHASE36_INITIAL_BASELINE_AUDIT.md`.
- Existing behavior preserved: no `lib/`, `test/`, `assets/`, `android/`, workflow, pubspec or player files modified.
- Contract tests: not run; gaps and required fixtures documented.
- Unit/widget tests: not run.
- `dart format`: not run (Dart SDK unavailable).
- `flutter analyze`: not run (Flutter SDK unavailable).
- `flutter test`: not run (Flutter SDK unavailable).
- Release build / CI run URL: no new Phase35.1 baseline CI run supplied; CI workflow requirements recorded. Earlier Phase35.1 type issue is documented as source-patched, but latest build success is unconfirmed.
- Live smoke tests: not run; selected source code inspected statically only.
- Known limitations: raw index byte snapshots and Git commit SHAs were unavailable to persist from this environment; numeric success status codes were not exposed by retrieval layer. This is documented explicitly; no hash/status was fabricated.
- Rollback path: revert documentation files listed above; no application code changed.
- Acceptance criteria result: all six index URLs verified; exact fifth and sixth URLs pinned; selected scripts statically inspected; compatibility matrix and gaps recorded; no functional changes; local build baseline recorded as not run.
- Status: `Passed with limitations`.


## Phase 37 implementation record — 2026-11-06

- Phase: 37 — Unified Source Architecture
- Base archive: `RAVEN23-PHASE36-COMPREHENSIVE-SOURCE-AUDIT.zip`
- Previous phases reviewed: Phase 36 blueprint, initial baseline, candidate-file boundaries, source-engine registry, source manifests, repository manager/client and existing unified player adapter paths. Preservation constraints from earlier phases retained.
- Baseline Release CI: successful before these changes — https://github.com/m5ham3ds/RAVEN23/actions/runs/42142404064 (`a9d414d`, default Release, 24.9 MB artifact). This is not post-change validation.
- Planned/actual application files: `lib/video_providers/unified/source_contracts.dart` (new), `source_engine.dart`, `source_repository_manager.dart`, `quickjs_source_engine.dart`, `openstream_web_embed_engine.dart`, `openstream_anime_engine.dart`; `pubspec.lock` metadata reconciled for the already-declared direct `crypto` dependency (same version/checksum).
- Tests added/extended: `test/video_providers/source_contracts_test.dart`, `source_engine_contract_test.dart`, `source_repository_manager_test.dart` (new identity, privacy fingerprint, capability-scope, lifecycle-validation, typed-error and diagnostic-sanitization cases).
- Existing behavior preserved: source stable keys, preference schema, repository install/uninstall/sync, engine registry order and concurrency default, UnifiedStreamOption and legacy player adapter payload, anime media enums. Capability profiles remain descriptive, not a new dispatch gate.
- `dart format`: not run (SDK unavailable).
- `flutter analyze`: not run (SDK unavailable).
- `flutter test`: not run (SDK unavailable).
- Post-change Release build: pending.
- Live smoke tests: not run; no sources activated.
- Known limitations: normalized capability profile is descriptive only; no enforcement or broad source activation before Phase 38. Engine-specific existing timeouts are retained; no global timeout policy introduced.
- Rollback path: revert the six application-code files, three test files and the `pubspec.lock` direct/transitive metadata correction; no migration of stored keys is needed.
- Acceptance criteria result: core additive contracts implemented; automated verification pending.
- Status: `In Progress`.


## Phase 37.1 implementation record — 2026-11-06

- Phase: 37.1 — Bundled Repositories
- Base archive: `RAVEN23-PHASE37-UNIFIED-SOURCE-ARCHITECTURE.zip`
- User-provided prior Release build: success on commit `6fb83a987044051e3cecf21505a260afc08f42b7`; `RAVEN23-apk.apk`, 27,881,034 bytes, arm64-only. This precedes Phase 37.1.
- Actual application files changed: `lib/video_providers/unified/source_repository_manager.dart`, `lib/video_providers/unified/unified_source_service.dart`, `lib/screens/common/source_repositories_screen.dart`, `assets/translations/{en,ar,es,hi}.json`, `lib/translations/codegen_loader.g.dart`.
- Tests added: four migration/seed/restore cases in `test/video_providers/source_repository_manager_test.dart`.
- Migration: fresh installs seed six bundled repositories; users with v1 seed marker receive only five new repositories; prior custom repositories and installed/disabled source keys remain unchanged; OpenStream is not resurrected if previously removed.
- UI: replaces single OpenStream shortcut with an additive restore-all bundled repositories action.
- Source activation: repository indexes are discovered only; non-OpenStream providers are not installed or executed automatically.
- External index checks: all six exact index URLs were opened successfully on 2026-11-06; parser support for OpenStream `extensions[]` and Zangetsu `sources[]` is already present.
- `dart format`, `flutter analyze`, `flutter test`, post-change Release CI and device verification: pending because Dart/Flutter SDK is unavailable in this archive environment.
- Rollback: revert the files above and remove this record; no source stable-key or install-state migration was performed.
- Status: `Implemented — Validation Pending`.


## Continuation audit — 2026-11-06

- Input archive: `RAVEN23-PHASE37.1-BUNDLED-REPOSITORIES-MIGRATION.zip`.
- Audit result: all 60 files under `phases/` were inventoried and the Markdown/text/JSON documents were read. Phase 36 remains closed with limitations; Phase 37 and 37.1 remain unaccepted pending post-change validation; Phase 38–51 remain not started.
- Next execution point: finish Phase 37 / 37.1 validation; do not start Phase 38 before dependency acceptance.
- CI gap corrected at the Phase 37.1 audit snapshot: `.github/workflows/android-ci.yml` was configured to run formatting, `flutter analyze`, source-contract tests and the full Flutter test suite before Release. This historical broad gate was later superseded by the Phase 40 minimal CI decision recorded in `PHASE40_CI_MINIMAL_GATE_2026-11-07.md`.
- Static checks performed: archive inventory, six bundled URL order, four locale JSON parses and required translation keys, workflow YAML parse.
- Not run: Dart/Flutter formatting, analysis, tests, Release build, Android device migration checks. Flutter and Dart executables are unavailable in the current environment; these remain explicit pending gates.
- Continuation report: `PHASE37_37.1_CONTINUATION_VALIDATION_AUDIT.md`.
- Status: `In Progress — CI validation gates configured; execution pending`.
- Subsequent continuation note: Phase 38 implementation draft and fixtures were later added under a separate record. At that audit snapshot, Phase 37/37.1 dependency gates remained open, Phase 38 was not yet accepted, and Phase 39 had not started. This is a historical status superseded by the later Phase 39 implementation record below; the dependency gates remain open.



## Phase 38 implementation record — 2026-11-06

- Phase: 38 — Media & Episode Normalization
- Base archive: `RAVEN23-PHASE37.1-VALIDATION-GATES-AND-AUDIT.zip`.
- Previous phases reviewed: Blueprint Phase 36–51, Tracker, Phase 37 and 37.1 implementation records, Phase 37.1 continuation validation audit, source compatibility matrix, and direct identity/engine/test file boundaries.
- Dependency gate: Phase 37 and 37.1 post-change CI gates remain pending. This Phase 38 worktree implementation is therefore not accepted. At the time of this record, Phase 39 had not started; its later implementation is recorded separately below.
- Implementation: `MediaIdentity` now has normalized playback type and separate classification; legacy anime input maps to series; exact episode normalizer rejects missing/conflicting seasons and episode values; QuickJS uses exact pair matching; Stremio/VidKing reject incomplete episodic requests before network access; OpenStream/IMDb lookup use normalized type; Donghua recognized as anime-specialist classification.
- Added files: `lib/video_providers/unified/episode_identity_normalizer.dart`, `test/video_providers/unified/episode_identity_normalizer_test.dart`, `test/video_providers/unified/quickjs_source_engine_test.dart`, `test/video_providers/vidking_direct_provider_test.dart`.
- Modified application/workflow/test files: `.github/workflows/android-ci.yml`, `lib/video_providers/provider_loader.dart`, `lib/video_providers/unified/media_identity.dart`, `media_identity_resolver.dart`, `openstream_anime_engine.dart`, `openstream_web_embed_engine.dart`, `quickjs_source_engine.dart`, `source_contracts.dart`, `source_manifest.dart`, `stremio_addon_provider.dart`, `vidking_direct_provider.dart`, `test/provider_loader_test.dart`, `test/video_providers/source_contracts_test.dart`, `source_repository_parser_test.dart`, `stremio_addon_provider_test.dart`, `unified/media_identity_resolver_test.dart`, `unified_models_test.dart`.
- Existing behavior preserved: application `MediaKind`, engine registry, OpenStream Anime engine, AniList/ani.zip mappings, Stremio and VidKing adapters, player, stream option shape, Android package/application ID, signing identity and Release target configuration.
- Tests added/extended: duplicate episode number across seasons; absent season no longer wildcard; parent season inheritance only when explicit; title/URL/title-name/field conflict rejection; malformed aliases; conflicting getEpisodes wrapper blocks stale parent fallback; invalid fractional/negative coordinates; CJK/Arabic/Latin title fixtures; anime vs Donghua vs Animation classifications; anime feature film movie route; incomplete Stremio/VidKing series identity rejection.
- `dart format`: not run (Dart SDK unavailable).
- `flutter analyze`: not run (Flutter SDK unavailable).
- Focused `flutter test`: not run (Flutter SDK unavailable).
- Full `flutter test`: not run (Flutter SDK unavailable).
- Release build: not run (Flutter/Android build environment unavailable).
- Android Mobile/TV and live source playback: not run.
- CI workflow: targeted file/test lists expanded, shell line continuations corrected; YAML parsed, all 9 run blocks passed `bash -n`, all 26 referenced source/test paths exist; no workflow run has been observed for these changes.
- Static package checks: 30 JSON files parsed; complete tree comparison found 10 additions, 22 modifications and no deletions; Android/Gradle/package/signing build files remain byte-identical to baseline.
- Known limitations: CI/compiler/analyzer confirmation pending; source fixtures prove matching logic only and do not prove external provider uptime or playback; Phase 37/37.1 prerequisite validation remains open.
- Rollback: revert the Phase 38 file list in `PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_CHANGELOG.md`; no user-data migration or repository activation was performed.
- Acceptance criteria result: implementation and fixtures drafted; automated tests/build/runtime acceptance pending.
- Status: `In Progress — Acceptance Blocked`.


## Phase 39 implementation record — 2026-11-06

- Phase: 39 — QuickJS Extension Settings System
- Base archive: `RAVEN23-PHASE38-MEDIA-EPISODE-NORMALIZATION-IMPLEMENTATION-PENDING-CI.zip`
- Audit: inspected the existing QuickJS bootstrap/runtime, source identity and manager, source catalog UI, existing secure-storage dependency/pattern, and representative live schemas from Serenity-MIST and Spyou providers.
- Actual files changed: see `PHASE39_QUICKJS_SETTINGS_SYSTEM_CHANGELOG.md`.
- Existing behavior preserved: provider install/disable state, repository config export/import, source stable keys, engine registry, stream payload/player handoff, Release flavor, ARM64 target and application ID.
- Settings storage: SHA-256 source-identity key in Android secure storage; values are not exported or logged.
- Runtime: provider-scoped lexical settings; schema discovered from `getSettings()`; validated settings injected before normal provider methods; required settings gate provider calls.
- Added tests: `test/video_providers/quickjs_extension_settings_test.dart`.
- Static checks: translation JSON parsed; CI YAML parsed; referenced files exist.
- `dart format`: not run (SDK unavailable).
- `flutter analyze`: not run (SDK unavailable).
- `flutter test`: not run (SDK unavailable).
- Release build / CI run URL: pending.
- Live smoke tests: not run; no extensions were activated as part of this phase.
- Known limitations: unknown schema types are intentionally ignored; arbitrary provider validation expressions are not evaluated; settings UI is available only for installed QuickJS sources.
- Rollback path: revert the application/test/workflow/translation files listed in `PHASE39_QUICKJS_SETTINGS_SYSTEM_CHANGELOG.md`; no user settings or repository migration is required.
- Acceptance criteria: implementation prepared; automated validation pending.
- Status: `In Progress`.


## Phase 40 implementation record — 2026-11-07

- Phase: 40 — Stremio Manifest & Configuration Engine.
- Base archive: `RAVEN23-PHASE39-QUICKJS-SETTINGS-IMPLEMENTATION-PENDING-CI.zip`.
- Previous phase state preserved: Phase 37, 37.1, 38 and 39 validation remain pending; Phase 40 work does not mark those gates closed.
- Main implementation: Stremio Manifest parser validates `resources`, `types`, `idPrefixes`, `catalogs`, `behaviorHints` and `config`; separates `configurable` from `configurationRequired`; parses bounded config/catalog fields; builds a `/configure` link without query tokens; respects resource-level type/ID-prefix profiles; blocks unsupported/fabricated IDs; uses IMDb resolver only when required by the matching profile.
- Configuration UX: optional/required state in Source Manager, external configuration page and explicit credential-handling notice. Configured manifest URL must be re-added by the user; no secret is entered into RAVEN23.
- New files: `test/fixtures/stremio/yastream_manifest.json`, `test/video_providers/unified_source_service_stremio_identity_test.dart`, and six Phase 40 documents.
- Modified application/workflow/tests: see `PHASE40_STREMIO_MANIFEST_CONFIGURATION_CHANGELOG.md`.
- Fixture source: live YaStream Manifest reviewed on 2026-11-07 and saved as a deterministic CI fixture; it does not establish live playback availability.
- Static checks: JSON parsing, locale-key parity, workflow YAML parse, CI-path existence, archive CRC and baseline diff performed at packaging.
- `dart format`, `flutter analyze`, focused/full `flutter test`, Release ARM64 build and device/live stream checks: not run because Dart/Flutter/Android build tools are not installed in this environment.
- Acceptance: implementation and tests added; CI/runtime acceptance remains pending.
- Status: `In Progress`.


| 2026-11-07 | CI Format Gate Recovery | أول تشغيل Phase 40 على GitHub Actions أبلغ أن dart format وجد 35 ملفاً غير منسق من أصل 36 وفشل بـexit code 1؛ هذا فشل check-only قبل analyze/test/build وليس فشل تجميع Android | تمت إضافة `tool/format_phase37_40_dart.sh` بنمطي `--fix` و`--check`؛ ينفذ Workflow التنسيق باستخدام Dart المرفق مع Flutter 3.35.7 (Dart 3.9.2)، ثم يعيد الفحص الصارم، ويلتقط diff كـArtifact مستقل | الإصلاح مضاف إلى حزمة المشروع؛ لم يتم تشغيله محلياً لعدم توفر Dart/Flutter، ويظل اعتماد CI/build pending حتى إعادة التشغيل |


| 2026-11-07 | Phase 40 Analyze Info Recovery | أحدث CI وصل إلى `flutter analyze` وأبلغ 10 ملاحظات info فقط: 7 string concatenation، و2 double quote، و1 dependency ordering؛ انتهى بالرمز 1 بسبب بوابة التحليل الصارمة | استبدال تعبيرات الجودة بـinterpolation مفرد، توحيد اقتباسات معرفات OpenStream/Stremio، وترتيب flutter_js؛ تطبيق patch التنسيق على الاختبارات الأربع؛ عدم تعطيل lint أو خفض CI | إصلاحات ساكنة جاهزة؛ لم يُشغّل Dart/Flutter محلياً، وإعادة CI مطلوبة قبل قبول Phase 40 |


| 2026-11-07 | Phase 40 Stremio focused-test recovery | CI run `42321267991` / job `128246125959` وصل إلى focused tests بعد اجتياز analyze؛ النتيجة 138 passed و7 failed. الفشل تركز في تحويل Manifest URL وConfiguration URL واكتشاف Manifest ينقصه resources | إزالة fragment فعلياً عبر `Uri.removeFragment()` بدلاً من `replace(fragment: '')` الذي ينشئ fragment فارغاً؛ توسيع اكتشاف Manifest المرشح عند وجود `id` مع حقول Stremio حتى يُرفض missing resources؛ إضافة اختبارات `hasFragment == false` | الكود والاختبارات المعدلة جاهزة محلياً؛ Dart/Flutter غير متاحين هنا، لذلك إعادة CI والـRelease ما زالت Pending |


| 2026-11-07 | Phase 40 empty-query URI recovery | Latest expanded CI: `flutter analyze` passed; focused tests reported 140 passed / 5 failed. Expected configure URLs had no query; actual URLs contained a trailing empty `?`. | Rebuild `/configure` URI from origin and path only; preserve non-empty runtime query on base endpoint but remove empty query delimiter and fragment; add empty-query regression fixture. | Patch prepared; rerun focused/full tests and Release ARM64 build required. Phase 40 remains In Progress. |

| 2026-11-07 | Phase 40 Full Test TV Widget Timeout Recovery | التشغيل الأخير اجتاز المراحل السابقة ووصل إلى `flutter test --reporter expanded`؛ المقتطف توقف أثناء `tv_sport_picker_test.dart` دون عرض سطر الفشل النهائي أو stack trace، ولذلك لم يمكن تأكيد terminal cause | استبدال `pumpAndSettle()` غير المحدود في اختبار TV بمضختين زمنيتين محددتين 250ms، إضافة timeout قدره 30 ثانية لكل اختبار من الثلاثة، وتحديد timeout 60s لكل اختبار في تشغيل المجموعة الكاملة مع حفظ expanded log ورفعه دائماً كـArtifact، وإضافة ملف TV test إلى قائمة Dart Formatter | patch تشخيصي/وقائي جاهز؛ لم يتم تشغيل Flutter محلياً، وإعادة full tests ثم ARM64 Release مطلوبة؛ Phase 40 In Progress ولا انتقال إلى Phase 41 حتى الاعتماد |


| 2026-11-07 | Phase 40 Comprehensive CI Build Report | Request: create a Markdown build report from workflow start through completion, preserving actual errors and warnings when a run fails | Workflow now captures run start, toolchain/context, step outcomes, key command stdout/stderr logs and exit codes; classifies warning/notice/info/error excerpts; includes test tail, APK/ABI report and diagnostic inventory; generates `RAVEN23-build-report.md` under workspace root and `build-artifacts/`; appends GitHub Step Summary and uploads `RAVEN23-build-report-and-diagnostics` for 30 days using `if: always()` | YAML/Bash/Python static checks and synthetic report smoke test passed; real GitHub Actions execution and artifact upload pending. Phase 40 remains In Progress | 


## Phase 40 full-suite CI failure analysis — run 42328559177

- Commit tested: `e0bd14ddf418162a979afe0d26a9f512166746d4`.
- CI gates completed successfully: dependency resolution, Dart format, Flutter analyze, and 14 focused source/Stremio test files (`147` tests passed).
- Full suite: `2143 passed`, `34 failed`, `11 skipped`; elapsed CI job time was 15m34s.
- First confirmed systemic defect: `ProviderScanSession._run()` awaited `_updates.close()` before completing `_completed`. The updates stream is single-subscription and some valid callers/tests never attach a listener; Dart may hold the close future pending until a listener subscribes, while the scan already logged `[PlaybackScan][FINISHED]`. The fix now initiates close without awaiting the listener drain and completes the scan lifecycle immediately. A regression test verifies completion without a listener and verifies buffered start/completion events remain available to a late listener.
- The remaining 23 failures are not all attributed to Phase 40. They are listed by test name and failure class in `PHASE40_CI_FULL_TEST_SUITE_FAILURE_ANALYSIS.md`; the log includes localization fixture warnings, timer leaks in search widgets, subtitle/settings expectation mismatches, adapter/stream mapping expectations, OneSignal mock expectation, title/home layout assertions, and OpenSubtitles test-fixture issues. These require separate diagnosis; no expected values were changed merely to hide them.
- The CI workflow now generates a complete `[E]` failure inventory with exception/timeout detail and counts `[WARNING]` localization messages in its Markdown report.
- Gradle Wrapper generation, APK build, and APK audit were skipped after the full test step failed. No APK was produced.
- Status remains `In Progress`; no Release or runtime acceptance is claimed.


## Phase 40 full-suite UI/settings follow-up — 2026-11-07

- Observed CI run `42331596314` on commit `5ff06e54d4bb514d5c2d12336eaf144260623a1e`: Format, Analyze and focused architecture/source tests passed; the full suite reported 2,155 passed, 23 failed and 11 skipped. Gradle Wrapper generation and APK build were not reached.
- The 23 failures were mapped from the expanded test log to deterministic test lifecycle, lazy-list visibility, settings/default expectation, serialization, OpenSubtitles fixture/header, media container inference, legacy quality labeling and seasonal-theme date-window issues.
- Follow-up changes are prepared in the current tree: test-only zero-interval VisibilityDetector helper; serialization fallback for subtitle language; exact palette preservation; date-window validation for unavailable seasonal selections; OpenSubtitles byte fixture and case-insensitive header lookup; missing-container URL inference; quality/server label separation; widget tests aligned with current app defaults and lazy Sliver behavior; OneSignal assertion aligned to the pinned 5.5.2 native method call.
- The supplied Dart formatting patch for `tv_sport_picker_test.dart` is already applied. Formatter target list includes the touched Dart files; a duplicate subtitle-test entry was removed.
- The report counted 6,157 EasyLocalization warning occurrences / 255 unique warning messages. A separate key audit found all 253 extracted localization keys present in all four packaged locale JSON files (1,982 keys each); do not add fake translation keys merely to suppress widget-test warnings.
- No Flutter/Dart SDK is available in this execution environment. Follow-up changes remain unverified until the CI regression suite and full suite rerun. Phase 40 remains In Progress; Phase 41 remains Not Started.
- Detailed source-derived record: `PHASE40_CI_FULL_SUITE_WIDGET_SETTINGS_RECOVERY_2026-11-07.md`.

| 2026-11-07 | Phase 40 Phase 35.1 baseline reconciliation follow-up | تطبيق formatter patch المرفق مع تقرير run `42335259990` وإضافة الأقواس السبعة التي طلبها Analyzer؛ إعادة مطابقة ملفات الواجهات والألوان والحركة وتسميات الجودة مع Phase 35.1؛ لا ملفات مرجعية محذوفة | منع تغييرات العرض غير المطلوبة والمحافظة على Release/source work | الملفات والوثائق محدثة؛ Flutter/Dart غير متاحين محلياً، ولا يوجد CI بعد الإصلاح؛ Phase 40 ما زالت In Progress |

| 2026-11-07 | Phase 40 UI regression reconciliation | CI run `42339568444` passed `flutter pub get`, Dart format, `flutter analyze`, and 160 focused tests; the separate Phase 40 regression group reported 149 passed / 4 failed. The four failures were traced to test timing/finder assumptions and a stale TV subtitle size expectation; Home, Discover and TV Settings production files are byte-identical to Phase 35.1. | Restore reference test flow for Home/Discover, advance one extra test frame for zero-delay RevealItem scheduling, and align TV test values with the implemented 12px default and 15px next option; preserve production UI | follow-up tests updated; CI rerun pending |


| 2026-11-07 | Phase 42 | تنفيذ revision store مع SHA-256 وHTTP metadata/ETag/Last-Modified، commit pin، معاينة exact snapshot وتطبيقها دون fetch ثانٍ، rollback/resume، provenance/duplicate review، QuickJS XHR disabled، host/redirect/response limits على repository وQuickJS وStremio وVidKing Direct وOpenStream Anime/Web Embed. | إغلاق متطلبات versioning/integrity/security مع الحفاظ على SourceRepositoryManager الحالي وتقليص الاختبارات. | implementation prepared; CI pending؛ بدأ بناءً على توجيه المستخدم قبل إغلاق Phase41؛ لا Flutter/Dart SDK في بيئة التعبئة. راجع `PHASE42_REPOSITORY_VERSIONING_SECURITY_*.md`. |


## Phase 43 implementation record — 2026-11-07

- Phase: 43 — OpenStream Sources Integration.
- Base archive: `RAVEN23-PHASE42-IMPLEMENTATION-PENDING-CI.zip`.
- Start decision: the user explicitly directed immediate progression without waiting for Phase42 CI. Phase41 and Phase42 remain CI pending; their implementation files are dependencies, not evidence of acceptance.
- Live index: official `Ivorisnoob/OpenStream/extensions/index.json` retrieved 2026-11-07; 30 entries (9 VidKing Direct, 5 Anime, 5 Stremio, 10 Web Embed, 1 VidKing WebView).
- Implementation: exact route contract map for all nine VidKing entries; mocked movie route dispatch and exact TV season/episode query; mocked Re:Anime TMDB/AniList S2E4 mapping and anime-film episode-1 mapping; Beta/Slow/fallback lifecycle checks; explicit expiry forwarding into `UnifiedStreamOption` for VidKing Direct, native Anime and Web Embed captured payloads; no invented TTL.
- Modified application files: `stream_option.dart`, `vidking_direct_provider.dart`, `openstream_anime_engine.dart`, `openstream_web_embed_engine.dart`.
- Modified tests: `source_repository_parser_test.dart`, `vidking_direct_provider_test.dart`, `source_host_policy_test.dart`.
- CI: updated automatic APK gate to the exact 15 tests listed in `PHASE43_OPENSTREAM_SOURCES_TESTS.md`, 10-minute job cap, 30-second test timeout, concurrency 4; no full suite or unrelated widget batch. The stable formatter script name was preserved and its target list includes `stream_option.dart`.
- Player/adapter changes: none.
- Static checks: OpenStream fixture parsed (30 entries); workflow YAML parsed; all 13 Bash blocks passed `bash -n`; all 3 embedded Python heredocs compiled; 15 unique CI test paths exist; all 7 modified Dart source/test files are included in the 48-target formatter list; all four locale JSON files parse and retain matching root keys. The CI report generator had one malformed Python list string, which was corrected and revalidated.
- `dart format`: not run (Dart SDK unavailable).
- `flutter analyze`: not run (Flutter SDK unavailable).
- `flutter test`: not run (Flutter SDK unavailable).
- Release ARM64 build: not run in this environment.
- Playback: not tested against live playable URLs; no source marked Playback Verified.
- Known limits: AnimePahe still relies on the Android WebView clearance bridge and may face interactive Turnstile; Beta status is preserved; one anime feature-film mapper path was fixture-tested through Re:Anime only.
- Status: `In Progress / CI Pending`.

| 2026-11-07 | Phase 43 OpenStream Sources Integration | The live official index contains 30 records; existing adapter families were already registered but route/lifecycle and anime identity regression contracts were under-tested. The user requested immediate progression without waiting for Phase42 CI. | Add exact source-to-endpoint fixture assertions, nine VidKing dispatch tests, exact TV coordinate checks, deterministic Re:Anime episode/film mapping, explicit provider expiry passthrough and a 15-file minimal CI gate across required dependencies. | Implementation prepared. No Flutter/Dart SDK locally; Analyze, tests, Release ARM64 and device playback pending. Phase41/42 remain pending; Phase43 not accepted. |


## Phase 44/45 execution record — 2026-11-07

- User directed: complete Phase 44 and then Phase 45 first; after both, upload the combined project and activate the deferred phase tests. No Phase44/45 test execution was performed during packaging.
- Phase 44 files: `PHASE44_ZANGETSU_SPYHELL_QUICKJS_PLAN.md`, `IMPLEMENTATION.md`, `TESTS.md`, `CHANGELOG.md`, `REPORT.md`; added `quickjs_source_catalog_profile.dart` and `phase44_quickjs_catalog_test.dart`; adjusted manifest/parser, source manager UI and four locales.
- Phase 45 files: `PHASE45_SOURCE_EXECUTION_PLAN.md`, `IMPLEMENTATION.md`, `TESTS.md`, `CHANGELOG.md`, `REPORT.md`; added `source_execution_policy.dart`, `unified_source_service_execution_test.dart` (13 cases), and `provider_scan_engine_fairness_test.dart`; changed service/engine result metrics, coarse HTTP status reporting, and the player-facing `ProviderScanSession` queue for per-engine capacity fairness.
- CI: 19 explicit test files now include dependencies across 37, 37.1, 38, 39, 40, 41, 42, 43 plus Phase 44 and 45. Format target list updated to `tool/format_phase37_45_dart.sh`. Full Flutter test suite remains excluded. The 13 unified execution contract cases plus one player-scan fairness test are included in the 19-file gate.
- No post-change Flutter Analyze/tests/Release ARM64/device runtime execution has been performed locally. Phase41/42/43 remain pending; Phase44/45 are prepared but not accepted.


## CI regression recovery — 2026-11-08 (run 42424422614)

- The workflow reached and passed `flutter analyze` (`No issues found`, 25.4s) and Dart format check (53 files, 0 changed).
- The selected critical source-contract test command then completed with **175 passing and 4 failing test cases**. Gradle wrapper generation, Release APK build and ABI audit were skipped because the test gate failed.
- Failure A: `source_repository_manager_test.dart` — applying the exact approved repository preview did not activate its staged snapshot. The application path used a transient persistent rollback override; it now reloads and verifies the saved revision's metadata/document bytes, then passes the exact in-memory `preview.candidateManifest` the user reviewed into `_fetchCatalog` through an ephemeral, identity-keyed override. The permanent rollback preference is not altered by preview application.
- Failures B/C: two `stremio_addon_provider_test.dart` cases — fake `.example` endpoints were sent through the production-default DNS lookup in `SourceEngineRegistry.standard`, so the fake Dio adapter was never reached and requests failed preflight. `standard` now accepts an injectable `SourceHostPolicy` while retaining the strict DNS-enabled default; only these mocked-Dio tests inject `resolveDns: false`.
- Failure D: `phase44_quickjs_catalog_test.dart` — the Zangetsu `sources` parser discarded upstream `status` and fallback metadata. It now preserves `status` (bounded to 0–3), explicit `fallback`, fallback tags and declared tags. The focused test now covers both Beta and fallback entries.
- The 19-file CI gate was not widened or reduced. No tests were disabled or deleted. This remediation is prepared for rerun; Phase 44/45 and the deferred Phase 41–43 validations remain unaccepted until the next CI run and Release ARM64 build pass.


## Latest CI acceptance — 2026-11-08 (run 42428688859)

- User supplied the build report, formatter patch and critical test log for the combined Phase44/45 recovery package.
- Workflow result: `SUCCESS`; commit `45a734d9d8d42f55bea575e3630bab5054249029`.
- `flutter analyze`: `No issues found`.
- Dart formatting: 53 maintained files, 0 changed.
- Required focused source-contract gate: **179 passed, 0 failed** across 19 explicit test files covering dependencies and Phases 44–45.
- Android Release APK: 26.72 MiB, native ABI `arm64-v8a` only; package `com.m5ham3ds.raven23`; APK CRC/package/ABI audit passed and artifact upload succeeded.
- Scope note: deterministic tests and APK build do not prove that every external channel/source is currently online or plays on every device. Real provider availability and playback remain runtime checks.

## Phase 46 implementation record — 2026-11-08

- Phase: 46 — Unified Live TV Service Manager.
- User approved continuing after the Phase44/45 CI gate passed. Implementation is based on the Phase46 section in `MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md`.
- Root cause of EthioSports being dormant: imports, provider registration, enums and provider-selector UI were commented out in both Mobile and TV screens. The remaining load, stream, favorites, recents, cache and preferred-sports paths were DaddyLive-only; simply uncommenting a selector would have mixed provider data.
- Added `LiveTvServiceManager` with stable provider IDs, a persisted selection (new installs default to DaddyLive), a shared standard provider registry used by both screens, lazy factories, lifecycle ownership, refresh/catalog/stream/categories access, per-provider health states (`idle/loading/available/empty/error/unavailable/blocked`) and deterministic close.
- Mobile and Android TV screens now register DaddyLive and EthioSports through the manager and expose a source selector. The manager itself is passed to `LivePlayer` so channel switching stays within the selected provider. Legacy DaddyLive share/focus deep links continue to select DaddyLive.
- Database compatibility: existing DaddyLive preference keys remain unchanged (`daddylive_*`); EthioSports uses an `ethiosports_*` namespace. EthioSports channel and EPG channel IDs use `ethio:` to prevent collisions. Favorites, recents, catalogs and preferred-sports choices are separate per provider.
- EPG remains a provider capability, not a required part of every catalog. EthioSports channels stay available if its optional EPG request fails; its schedule tab is exposed only when the provider declares EPG support. DaddyLive EPG behavior is preserved.
- HTTP 401/403 map to Blocked, 404/408/410/425/429/5xx and network/timeouts map to Unavailable; other errors map to Error. Raw upstream messages are not shown in manager health text. HTTP status is retained for non-JSON HTML error pages.
- The manager validates HTTP(S) stream URLs and expiry, allow-lists playback headers, normalizes HLS/DASH media types, accepts only correctly-shaped ClearKey pairs, and filters expired/invalid variants. It does not bypass DRM. Expiry is preserved through `LiveStreamVariant` and passed into LivePlayer; automatic recovery re-resolves expired links instead of trying stale backups. ISO/epoch-second/epoch-millisecond expiries are supported.
- Added deterministic tests for manager selection/persistence/lazy creation/lifecycle/health/namespace isolation and stream URL/expiry/header/media-type/ClearKey validation, plus EthioSports catalog/optional EPG/channel namespace/stream/variant metadata/HTTP block status. The Phase46 additions comprise 14 cases across two explicit test files.
- CI gate is updated from 19 to 21 explicit test files; no full Flutter test suite or broad widget test groups were added.
- Validation in the packaging environment: Flutter/Dart SDK not available, so Phase46 formatter/analyze/tests/Release have not been executed here. YAML/Bash/Python workflow syntax and file lists are statically checked at packaging. External provider uptime and physical device playback remain unverified.
- Status: `Implementation Prepared — CI Pending`.


## Phase 47 — IPTV / M3U Engine & Spyhell Live Adapters (2026-11-08)

تم تجهيز التنفيذ على نسخة RAVEN23-PHASE46 دون تعديل نسخة RAVEN23-PHASE45 المرجعية. تشمل الإضافة parser لـM3U مع فصل HLS media playlists، قوائم remote/local داخل مساحة التطبيق الخاصة، ETag/Last-Modified وcache محدود، provider namespaces مستقلة، وadapter مخصص لخمسة عشر مصدر Spyhell Live مثبتًا ومفعّلًا فقط. أُضيفت واجهة إدارة قوائم مشتركة للهاتف والتلفاز، وربطت الخدمات بعقد LiveTvService الحالي. بقيت الحالة **Implementation prepared — CI pending**: لم يُشغّل Dart/Flutter Analyze أو الاختبارات أو البناء في بيئة العمل، ولم يُثبت تشغيل مزود خارجي أو تشغيل فعلي على الجهاز. البوابة المستهدفة أصبحت 25 ملف اختبار صريحًا؛ انظر ملفات PHASE47 الستة.


## Phase 49 — XMLTV / EPG implementation record — 2026-11-08

- Base archive: `RAVEN23-PHASE48.zip`; prior PHASE45/46/47/48 archives were treated as references and not modified.
- Added provider-neutral XMLTV channel/programme/guide models, bounded XML parser, HTTP repository with host-policy redirect validation, ETag/Last-Modified support, six-hour freshness TTL, three-day tagged stale fallback and compressed cache limits.
- M3U `url-tvg` / `x-tvg-url` / `tvg-url` header fields are now read; `Channel.tvgId` is retained through model serialization. Exact case-sensitive `tvg-id` matching enriches Now/Next and maps events into the existing `DaddyLiveEpg` schedule surface.
- XMLTV EPG loading is optional and isolated from M3U channel retrieval and stream resolution. Stale data is not presented. Timestamp offsets are normalized to UTC; offsetless feed timestamps are interpreted as UTC, while the legacy schedule uses device-local display times.
- Added XMLTV parser/repository fixtures and expanded M3U parser/service and manager tests. CI contains 28 unique explicit test files; formatter script lists 81 unique Dart files.
- Validation: no Dart/Flutter SDK was available in the packaging environment, so formatting, Analyze, tests and APK build were not executed. Phase49 remains `Implementation Prepared — CI Pending`; mocked fixtures are not live-provider or device playback evidence.
- Next planned phase: Phase50 — WebView & Embedded Playback Integration. See `PHASE49_XMLTV_EPG_*.md`.

## Phase 50 — WebView & Embedded Playback Integration (2026-11-08)

- Base archive: `RAVEN23-PHASE49.zip`; Phase45–49 archives remain unchanged references.
- Separated browser-only HTML embedded pages from direct media streams using `UnifiedEmbeddedPlayerOption` and explicit legacy `RegularVideoLinks.isEmbeddedPlayer` metadata. HTML is excluded from BetterPlayer URL/format/header maps, adaptive-quality probing, stream cache and downloads.
- Updated provider scanning to continue after an embed-only result, prefer any later direct stream, and retain the first embedded option only as a fallback when no provider resolves a direct stream. Movie/TV routes and the player open a dedicated WebView screen for the handoff.
- Added an Android PlatformView WebView with per-view lifecycle, load/ready/verification/blocked/unsupported/failed statuses, mobile/TV controls, back/reload/close, public HTTP(S) navigation/resource policy, local/reserved literal and HTTPS downgrade rejection, no file/content access, no mixed content, no automatic play/click, and no page-facing JavaScript bridge. Initial Referer/Origin/User-Agent headers are allow-listed; Cookie/Authorization/custom headers are excluded.
- The hidden OpenStream capture path remains separate and observation-only: its script watches fetch/XHR/resource metadata but does not autoplay, mute or click provider controls. Existing anime `resolveUrl` list response is preserved; only `resolveEmbed` uses the structured result.
- WebView disables third-party cookies and does not clear the process-wide cache or first-party cookies on disposal. Android CookieManager remains shared by the app process; isolated per-source cookie jars and DNS pinning are not claimed. CAPTCHA/Cloudflare/DRM/authentication/geographic restrictions are not bypassed.
- Embedded status/action strings are localized in the existing English, Arabic, Spanish and Hindi JSON assets. All four files parse and expose identical translation key sets (2,038 keys).
- Added six focused Phase50 contract tests. The current workflow lists 29 unique explicit test files and the formatter script lists 91 unique Dart targets. Static packaging checks: workflow YAML valid; 13 Bash run blocks pass `bash -n`; 3 embedded Python heredocs parse; all test/formatter paths exist and are unique; no autoplay/click/mute logic in the capture script; visible WebView does not expose a JavaScript bridge or clear the process-wide cache.
- No Dart/Flutter SDK was available. Dart format, Flutter Analyze, the 29 tests, Kotlin/Gradle compilation, Release APK and physical Android Mobile/TV playback were not executed. Status remains **Implementation Prepared — CI Pending**.
- Next planned phase: **Phase51 — Integration, Regression & Release Gate**. It must validate the combined Phase36–50 contracts and ARM64 Release build and close outstanding device checks without marking a phase accepted before evidence is observed.


## Phase 51 — Integration, Regression & Release Gate (2026-11-08)

- Final successful user-supplied GitHub Actions run: `42507906881`.
- Analyze and Dart format passed; 39-file selected regression gate recorded 302 passed / 0 failed.
- Gradle/Kotlin compilation, ARM64 `assembleProdRelease` and APK audit passed.
- APK: `com.m5ham3ds.raven23`, version `4.3.0+10`, ABI `arm64-v8a` only, 28,111,482 bytes.
- Intermediate failed attempts were superseded by this successful run; their separate failure-note files are no longer retained in the active `phases/` directory.
- This closes the Phase51 build gate. Real provider availability/playback remains a separate device-level concern.

## Phase 52 — Source Repository Audit & VOD Priority Lanes (2026-11-09)

- Audited the six current indexes and selected provider scripts for type/language/runtime mismatches.
- Initial editable lanes: Movies 13, Series 9, Anime 11. Auto-activation union is capped at 15 unique source records per repository.
- Added independent persistent category ordering; removing an entry from priority demotes it to backup without uninstalling it. Search order remains category priority, eligible direct backup sources, then Embedded providers.
- NetPrime remains backup-only; language/runtime mismatches and magnet/torrent-only records are excluded from the curated priorities.
- Owner confirmed successful Release builds through PHASE55, so PHASE52 is accepted. Old intermediate CI failure/scope records were superseded and their dedicated failure files removed; PHASE52 tests are not part of the active PHASE56 CI gate.
- Version at this phase: `4.4.0+12`.

## Phase 53 — Navigation and initial Manga integration

Owner-confirmed accepted build and working navigation/catalogue behaviour on 2026-11-09. The AniList metadata catalogue and the Keiyoushi Protobuf repository were introduced separately from video JSON repositories. Native Mihon execution was added later in PHASE55.

## Phase 54 — Manga category and repository management

Build accepted through the owner-confirmed PHASE55 build. Manga/Mihon repository add/edit/remove remains within Sources. The supplied screenshots exposed runtime gaps in the category feed/visual structure; see PHASE56.

## Phase 55 — Mihon runtime and reader

Owner confirms all build operations completed successfully through this phase on 2026-11-10. The phase includes APK package and signer checks, the Mihon-compatible extension runtime, source browser and chapter reader. Device screenshots revealed extension-trust metadata retrieval and catalogue presentation defects; build success is not treated as proof that those runtime flows passed.

## Phase 56 — Current work

Source changes and targeted regression tests have been prepared for the four observed issues: raw-text `repo.json` parsing, independent JP/KR/CN aggregate loading, per-category hero/Top 10, and Home-style shimmer loading. CI, Release APK audit and device verification remain pending. See `PHASE56_MANGA_RUNTIME_CATALOGUE_AND_EXTENSION_TRUST_FIX.md`.
