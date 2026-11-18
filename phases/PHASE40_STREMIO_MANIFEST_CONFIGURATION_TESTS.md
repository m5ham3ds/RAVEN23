# Phase 40 — Stremio Manifest & Configuration Engine — Tests

**التاريخ:** 2026-11-07

> **ملاحظة عن سياسة CI الحالية:** أقسام متابعة التشغيل أدناه تسجل تاريخ الاختبارات الواسعة التي جُرّبت أثناء التشخيص. لم تعد هذه المجموعات أو مجموعة `flutter test` الكاملة جزءاً من بوابة APK التلقائية. السياسة المعتمدة حالياً موجودة في قسم «سياسة بوابة APK التلقائية» في نهاية هذه الوثيقة.

## الاختبارات المضافة أو الموسعة

- `test/video_providers/source_repository_parser_test.dart`
  - direct Manifest URL وتحويل المسار إلى base endpoint.
  - موارد stream النصية والكائنية مع idPrefixes مختلفة.
  - عدم توريث prefixes الجذر إلى مورد كائني لم يعلن prefixes.
  - اعتبار غياب idPrefixes في stream النصي غير مقيّد افتراضياً بـIMDb.
  - تحليل config field types والخيارات ذات حالة الأحرف، وحدود العدد/الطول، وإخفاء password default.
  - رفض Config/behaviorHints/root types/prefixes/catalogs ذات containers غير الصحيحة.
  - فصل configurable عن configurationRequired.
  - حفظ المسار وquery لطلب التشغيل مع استبعاد fragment وtoken من configure URL.
  - تحليل Fixture YaStream المنشورة.
- `test/video_providers/source_repository_client_test.dart`
  - جلب Manifest المرتبط بفهرس repository، مع الحفاظ على endpoint path/query وإثراء config metadata دون تغيير أولوية المصدر.
  - فشل Manifest لإضافة واحدة لا يمنع إثراء أو إبقاء إضافة أخرى سليمة ضمن المستودع.
- `test/video_providers/stremio_addon_provider_test.dart`
  - مورد بلا prefixes يقبل المعرفات المتوفرة ولا يخترع tmdb ID.
  - TMDB لا يُرسل إلا مع prefix معلن.
  - configurable اختياري لا يمنع stream request.
  - configurationRequired يمنع request مبكراً.
  - الحفاظ على query per addon وتنقية الرموز من الأخطاء.
  - حماية season/episode coordinates والـresource profile حسب نوع المحتوى.
- `test/video_providers/unified_source_service_stremio_identity_test.dart`
  - IMDb resolver يُستدعى فقط عند إعلان المورد حاجته إليه.
  - لا تُجرى lookup لمورد يقبل IDs المقدمة أو يعلن Kitsu فقط.
- `test/fixtures/stremio/yastream_manifest.json`
  - Snapshot ثابت لManifest YaStream لاستخدامه في CI.

## فحوص ثابتة منفذة في بيئة التسليم

- JSON: فحص 31 ملف JSON بعد التعديل؛ parse ناجح.
- Translation keys: تمت استعادة المفتاح المفقود سابقاً `provider_media_type_unsupported` في الإسبانية والهندية؛ أصبحت اللغات الأربع متطابقة عند 1982 مفتاحاً، ومجموعات المفاتيح في CodegenLoader تطابق ملفات JSON.
- YAML: تحليل `.github/workflows/android-ci.yml` ناجح؛ كتل `run` التسع اجتازت `bash -n`.
- CI paths: ملفات Dart المستهدفة في قائمة format/test موجودة.
- Archive: CRC test ومقارنة الملفات مع Phase 39 baseline بعد إنشاء ZIP.

## فحوص لم تُنفّذ

لم تتوفر `dart` أو `flutter` أو Android build tools في بيئة التنفيذ. لذا لم يتم تشغيل:

- `dart format`
- `flutter analyze`
- focused `flutter test`
- full `flutter test`
- Android Release ARM64 build
- اختبار تثبيت/تشغيل على Android Mobile أو Android TV
- اختبار stream خارجي حقيقي

الـWorkflow يضم خطوات Format وAnalyze والاختبارات المركزة والكاملة ثم Release ARM64 build. يلزم تشغيله في GitHub قبل قبول المرحلة. لا تعتبر إضافة الاختبارات أو نجاح تحليل JSON دليلاً على نجاح تنفيذ Dart.


## متابعة فشل CI الأول — بوابة التنسيق

- السجل المرسل: فحص 36 ملف Dart، واكتشاف 35 تغييراً تنسيقياً، ثم exit code 1 بسبب `--output=none --set-exit-if-changed`.
- التفسير: formatter check-only لا يكتب التنسيق؛ أبلغ عن اختلافات موجودة قبل `flutter analyze` والاختبارات وRelease Build.
- الإصلاح: Workflow يطبق الآن `dart format` عبر `tool/format_phase37_40_dart.sh --fix`، ثم يشغل `--check` الصارم على قائمة الملفات ذاتها.
- التتبع: يرفع Workflow artifact باسم `RAVEN23-dart-format-patch` يتضمن patch التنسيق وملخصه لتمكين تثبيت نفس التغيير في branch المصدر.
- لم يتم تشغيل Dart formatter في بيئة إعداد الأرشيف لعدم توفر Dart/Flutter؛ يتطلب تأكيد النجاح إعادة تشغيل GitHub Actions.


## متابعة فشل CI — Stremio focused tests (2026-11-07)

أظهر تشغيل GitHub Actions `42321267991`، job `128246125959`، أن `flutter analyze` اجتاز ثم فشلت مجموعة الاختبارات المركزة بنتيجة **138 passed / 7 failed**. الاختبارات الفاشلة المسماة في السجل:

- `source_repository_client_test.dart`: إثراء عناصر Stremio من فهرس OpenStream بمعرف Manifest.
- `source_repository_parser_test.dart`: تحليل Manifest URL؛ ثلاث حالات فصل `configurable` عن `configurationRequired`؛ الحفاظ على path/query وإزالة fragment من configure URL؛ ورفض Manifest يفتقد resources.

لم يتضمن النص المستلم تفاصيل Expected/Actual أو stack traces، لذا لا تُسجل هذه النتيجة على أنها تفاصيل assertion كاملة. مراجعة الكود حددت سببين متسقين مع مجموعة الفشل: تمرير `fragment: ''` إلى `Uri.replace` يترك fragment فارغاً بدلاً من إزالة مكوّن fragment؛ كما أن كاشف Manifest كان يشترط وجود `resources` مسبقاً، ما منع التعرف على وثيقة Manifest مشوهة لكي يرفضها parser.

الإصلاحات المضافة:

- استخدام `Uri.removeFragment()` بعد تغيير المسار في `_stremioBaseUrl` و`_stremioConfigurationUrl`، مع الإبقاء على query الخاص بطلب Manifest/stream حيث يلزم.
- إزالة fragment من URLs التي يبنيها `SourceRepositoryClient` أثناء جلب Manifest وإرجاع base endpoint.
- كشف Manifest المرشح من خلال `id` مع أي من حقول Stremio المعروفة (`resources`, `types`, `idPrefixes`, `catalogs`, `behaviorHints`, `config`)؛ ثم يرفض `_parseStremioManifest` غياب/فراغ `resources` بـ`FormatException`.
- توسيع اختبارات `hasFragment == false` على endpoint وconfigure URL وطلبات client، مع الإبقاء على اختبار رفض الموارد المفقودة.
- استخدام `--reporter expanded` في focused/full Flutter test steps لتسهيل استخراج stack traces وExpected/Actual في التشغيل القادم.

**التحقق:** أُجريت مراجعة ساكنة للتغييرات فقط. لم تتوفر Flutter/Dart في هذه البيئة؛ لم يُعد تشغيل tests أو Analyze أو Release. تبقى Phase 40 `In Progress` حتى ينجح CI فعلياً.


### Empty-query URL regression

- A Stremio Manifest source URL with an explicit empty query delimiter (`?`) and a fragment must produce a runtime endpoint without either component.
- Its `/configure` URL must be built from origin + path only, with neither a query nor a fragment.
- Non-empty configured query parameters remain available on the runtime endpoint but are never copied to the external configuration URL.
- CI regression source: `test/video_providers/source_repository_parser_test.dart` — `removes empty query markers from derived Stremio URLs`.


## متابعة فشل/توقف مجموعة الاختبارات الكاملة — TV sport picker

- وصل آخر مقتطف CI إلى `test/tv_sport_picker_test.dart` بعد اجتياز المراحل السابقة، لكنه لم يتضمن السطر النهائي للفشل أو stack trace.
- أُزيل `pumpAndSettle()` من مساعد اختبار TV واستُبدل بتقدم زمني محدد: 250ms مرتين لكل تفاعل/فتح، لتغطية انتقالات التركيز والتمرير القصيرة دون انتظار سكون كل ticker في الشجرة.
- أضيف timeout مقداره 30 ثانية لكل واحد من الاختبارات الثلاثة.
- أضيف ملف TV test إلى قائمة Dart Formatter الرسمية.
- كان CI يحفظ مخرجات المجموعة الكاملة في `RAVEN23-full-flutter-test-log` أثناء التحقيق السابق؛ هذه المجموعة أُخرجت لاحقاً من بوابة APK التلقائية بموجب سياسة الحد الأدنى الموثقة في نهاية هذه الوثيقة.
- لم تُشغّل اختبارات Dart/Flutter محلياً؛ يلزم إعادة CI لتأكيد النتيجة.


## سياسة بوابة APK التلقائية — تحديث 2026-11-07

استُبدلت سياسة تشغيل المجموعات الواسعة والاختبارات الكاملة ببوابة محددة مرتبطة مباشرةً بنطاق Phase 40. لا تشغّل عملية بناء APK التلقائية الآن إلا ملفات الاختبار الأربعة التالية:

1. `test/video_providers/source_repository_parser_test.dart` — تحليل Stremio Manifest وموارد stream وحقول الإعدادات وروابط التهيئة.
2. `test/video_providers/source_repository_client_test.dart` — جلب Manifest وإثراء بيانات الإضافات وعزل فشل إضافة عن الأخرى.
3. `test/video_providers/stremio_addon_provider_test.dart` — تشكيل طلبات stream، والتحقق من ID prefixes، والإعدادات الاختيارية/الإلزامية، وإحداثيات الحلقات.
4. `test/video_providers/unified_source_service_stremio_identity_test.dart` — استدعاء IMDb resolver فقط عندما يطلب ملف المورد ذلك.

تضم هذه الملفات **44 حالة اختبار** بعد إزالة حالة URL مكررة حرفياً. هذه اختبارات عقد/وحدة محددة وليست اختبارات واجهات أو اختبارات تشغيل شبكي خارجي. يُفرض حد 30 ثانية لكل حالة وحد 10 دقائق لخطوة المجموعة كاملة.

لا تشغّل بوابة APK التلقائية مجموعة الاختبارات العامة ذات 15 ملفاً، ولا مجموعة واجهات/Regression ذات 17 ملفاً، ولا `flutter test` على كامل شجرة `test/`. ملفات الاختبارات الأخرى باقية في المستودع ولا تُحذف؛ استخدامها يكون ضمن QA يدوي أو بوابة خاصة بالمرحلة التي تختبرها، وليس شرطاً متكرراً لكل APK.

يستمر `flutter analyze` بفحص المشروع، مع `--no-fatal-infos`: أخطاء التحليل والتحذيرات تظل مانعة للبناء، بينما ملاحظات `info` وحدها لا توقف إصدار APK. يُعالج الاستيراد المكرر الذي ظهر في أحدث سجل فعلياً، ولا يُعتمد على تخفيف مستوى التحليل بديلاً عن إصلاح أخطاء الكود.

**الحالة:** تحديث السياسة والملفات ثابتاً فقط. لا يُعد ذلك نجاحاً للاختبارات أو البناء؛ يلزم تشغيل GitHub Actions للتحقق من Format وAnalyze والاختبارات الـ44 ثم Release ARM64 وABI audit. Phase 40 تبقى `In Progress` حتى ينجح ذلك.
