# Phase 40 — Stremio Manifest & Configuration Engine — Report

**التاريخ:** 2026-11-07  
**الحالة:** `In Progress — Implementation added; CI/runtime acceptance pending`

## النتيجة

تمت إضافة دعم Manifest/configuration إلى محول Stremio الموجود، مع فصل إمكانية الإعداد عن إلزاميته، وتفسير نطاق المورد ومعرفاته، والتحقق من Catalog/Config schema، وربط صفحة إعداد الإضافة الرسمية بإدارة المصادر. كما أضيفت اختبارات وFixture YaStream، وأدرجت اختبارات Stremio ضمن CI.

## شروط القبول وحالتها

| الشرط | الحالة |
|---|---|
| configurable لا يجعل الإعداد إلزامياً | Implementation + test added |
| configurationRequired يمنع streams قبل الشبكة | Implementation + test added |
| `/configure` يحترم base path ولا يكشف query token | Implementation + test added |
| الموارد وtypes وidPrefixes تُحل وفق النطاق الصحيح | Implementation + tests added |
| لا يتم اصطناع TMDB ID دون إعلان prefix | Implementation + tests added |
| IMDb lookup يحدث عند الحاجة فقط | Implementation + tests added |
| Catalog/config containers وlimits validated | Implementation + tests added |
| YaStream fixture محلية | Added; parser assertion added |
| مصدر فاشل لا يوقف بقية المصادر | Client error isolation موجود؛ أضيف اختبار لManifest متوقف بجانب إضافة سليمة |
| Dart format | First GitHub CI attempt failed on formatting drift (35 changed of 36); recovery workflow added, rerun pending |
| Flutter analyze / focused+full tests | Not reached in the failed first CI run; rerun pending |
| Release ARM64 build / device smoke | Not run — build environment unavailable |

## الملفات

راجع `PHASE40_STREMIO_MANIFEST_CONFIGURATION_CHANGELOG.md` للقائمة الدقيقة.

## القيود المتبقية

1. لا يمكن اعتبار Phase 40 مقبولة حتى ينجح GitHub Actions بعد التعديلات.
2. يجب اختبار YaStream وبقية الإضافات باختبارات تشغيل منفصلة؛ Manifest وحده لا يثبت عمل stream endpoint.
3. اعتماد Phase 37 و37.1 وPhase 38/39 ما زال معلقاً في Tracker، ولا يتم محو تلك التبعيات في هذه المرحلة.
4. لم يتم اختبار واجهة الإعداد خارجياً أو على Android Mobile/TV في هذه البيئة.

## فحوص ساكنة إضافية

- 31 ملف JSON اجتاز التحليل.
- مفاتيح الترجمات الأربع متطابقة (1982 مفتاحاً لكل لغة)، ومفاتيح CodegenLoader متطابقة مع أصول JSON.
- Workflow YAML صالح، وكتل أوامر التشغيل التسع اجتازت `bash -n`.
- ملفات المصدر والاختبارات المشار إليها في CI موجودة، ولا توجد ملفات baseline محذوفة.

## الخطوة التالية

Phase 41 — VidKing Direct Language & Quality Engine، وفق الـBlueprint. يبدأ العمل بها عند اختيار الاستمرار، مع إبقاء اختبارات اعتماد المراحل السابقة بوضع Pending حتى توفر نتائجها الفعلية.


## متابعة فشل أول CI — Dart format

أظهر سجل GitHub Actions المرسل أن خطوة `dart format --output=none --set-exit-if-changed` وجدت 35 ملفاً منسقاً بشكل مختلف (36 ملفاً مفحوصاً) وأنهت الخطوة بـexit code 1. بما أن `--output=none` يمنع الكتابة، فهذا فشل فحص تنسيق فقط، وحدث قبل `flutter analyze` والاختبارات والبناء؛ ولا يثبت فشل تجميع Android.

أضيفت آلية استرداد في `.github/workflows/android-ci.yml` تستخدم نسخة Dart نفسها المرفقة مع Flutter 3.35.7: `tool/format_phase37_40_dart.sh --fix` يطبق التنسيق القياسي على قائمة الملفات نفسها، ثم `--check` يعيد الفحص الصارم. وتصدر الخطوة `dart-format.patch` وملخصاً كـArtifact باسم `RAVEN23-dart-format-patch` حتى يمكن تطبيق التغييرات على branch المصدر. لا يقوم Workflow بعمل commit تلقائي، ولا يتم اعتبار البوابة ناجحة قبل إعادة تشغيل CI ومشاهدة نتيجتها.

**الحالة بعد هذا الإصلاح:** Workflow recovery authored and statically checked; formatter not executed in this container because Dart/Flutter SDK is unavailable; CI rerun, analyze, tests and Android Release build remain pending.


## متابعة CI — أخطاء flutter analyze (2026-11-07)

وصل التشغيل التالي إلى `flutter analyze` بعد تطبيق formatter patch، ثم توقف بسبب سبعة أخطاء تحليل/ترجمة في ملفات الاختبارات: constructor الخاص بـ`http.Response` كان ينقصه status code؛ اختبار New & Hot لم يستورد `CatalogController` مباشرة؛ اختبار background scan احتوى قوس إغلاق قائمة مكرراً؛ واختبار ProviderLoadingWidget وضع حالات غير-const داخل سياق const. كما أظهر السجل warnings وinfos عن imports غير مستخدمة، null assertions، regex flag غير صالح، `DropdownButtonFormField.value` المهمل، `withOpacity`، وتركيب if/string interpolation.

أضيفت إصلاحات لجميع findings المرفقة في `PHASE40_CI_ANALYZE_RECOVERY.md`. هذه إصلاحات معدة لإعادة CI وليست نتيجة Analyze ناجحة: لا تتوفر Flutter/Dart في بيئة إعداد الأرشيف، لذلك تظل Phase 40 `In Progress` حتى يظهر CI جديد يجتاز Analyze والاختبارات وبناء Release.


## متابعة CI — Stremio test failure and local correction (2026-11-07)

أظهر أحدث سجل متاح أن `flutter analyze` اجتاز، ثم فشلت مجموعة الاختبارات المركزة: 138 passed و7 failed. تركزت الحالات في URL normalization/Configuration hints واختبار رفض Manifest بلا `resources`. أُصلحت مشكلتان في التنفيذ: إزالة empty fragment باستخدام `Uri.removeFragment()`؛ والتعرف على Manifest المرشح من `id` مع بقية حقول Stremio حتى لا يفلت Manifest المكسور من التحقق. أضيفت assertions تمنع وجود fragment في الروابط الناتجة، وتم تفعيل reporter `expanded` لعرض تفاصيل أي فشل لاحق. لم تُشغّل Dart/Flutter في بيئة التسليم؛ لذا لم تُثبت إعادة نجاح الاختبارات أو Release Build. Phase 40 ما زالت `In Progress`.

## Follow-up: exact empty-query failure correction (2026-11-07)

The newest supplied expanded test log supersedes the previous 138/7 result: 140 tests passed and 5 failed. The assertion details show that the runtime/configuration URL values differed only by an empty trailing query delimiter (`?`). The five failures were the Client enrichment test and four Parser tests for configuration-required/configurable behavior and configured path handling. The previously failing malformed-manifest detection cases now pass.

The underlying defect was `Uri.replace(query: '')`: an empty string creates an explicit empty query component. `_stremioConfigurationUrl` now reconstructs the URL from scheme, host, explicit port, and path segments only. `_stremioBaseUrl` keeps non-empty runtime query values, removes fragments, and strips only an empty query delimiter. A regression test covers a source Manifest URL ending with `?#fragment`; existing tests cover preserving a non-empty runtime token while not copying it to `/configure`.

The correction has not been run under Dart/Flutter in the packaging environment. Phase 40 remains `In Progress`; focused/full tests and Release ARM64 CI must pass before acceptance.


## Latest full-suite CI result and continuation — run 42328559177

The latest comprehensive CI report and full Flutter log were reviewed. Format, analyze, and focused source/Stremio tests passed. The complete suite reported 2,143 passed, 34 failed, and 11 skipped. It did not proceed to Gradle Wrapper generation or APK build.

Eleven test failures were repeated 60-second timeouts in `provider_background_scan_test.dart`. Root cause: `ProviderScanSession._run()` awaited the single-subscription updates stream close before completing `session.completed`. If no listener subscribes, Dart can keep the close future pending even after all workers finish. The close is now initiated without awaiting listener drain, while the completion future is resolved as soon as the scan workers finish. A regression test covers completion with no listener and later delivery of buffered updates.

The other 23 failures across UI, preferences, OneSignal, external subtitles, and legacy adapters remain separately documented in `PHASE40_CI_FULL_TEST_SUITE_FAILURE_ANALYSIS.md`; they have not been silently waived or rewritten as passing. The CI Markdown report generator has also been enhanced to list every failed test, include nearby assertion/timeout details, and count `[WARNING]` localization diagnostics.

**Current status:** implementation patch prepared; Flutter/Dart are unavailable in this editing environment, so regression test, full suite, and Release ARM64 build remain pending a new GitHub Actions run. Phase 40 remains In Progress.
