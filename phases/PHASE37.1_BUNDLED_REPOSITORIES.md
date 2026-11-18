# RAVEN23 — Phase 37.1: Bundled Repositories

- **التاريخ:** 2026-11-06
- **المرحلة الأم:** Phase 37 — Unified Source Architecture
- **الحالة:** Implementation complete; post-change CI and device verification pending
- **Base:** `RAVEN23-PHASE37-UNIFIED-SOURCE-ARCHITECTURE.zip`

## 1. المشكلة المؤكدة

أظهرت لقطة المستخدم أن صفحة Source repositories تعرض مستودع OpenStream فقط (كتالوج 30 مصدراً). فحص `SourceRepositoryManager` أثبت أن `_seedDefaultRepositoryOnce()` كان يضيف `defaultOpenStreamRepository` وحده ويستخدم مفتاح تهيئة v1 يمنع أي seed لاحق.

لم تكن المشكلة في `SourceRepositoryParser`: المحلل الحالي يدعم بالفعل OpenStream عبر `extensions` ومستودعات Zangetsu عبر `sources` وحقول `file` النسبية.

## 2. المستودعات المضمّنة

تم تثبيت العناوين الدقيقة التالية في `SourceRepositoryManager.bundledRepositoryUrls`:

1. OpenStream Official — `https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json`
2. Spyou Zangetsu Providers — `https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json`
3. Serenity-MIST Zangetsu Sources — `https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json`
4. Spyhell Experiment — `https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json`
5. Spyou Additional Providers — `https://raw.githubusercontent.com/Spyou/Zangetsu-spyou-provider/main/index.json`
6. Spyhell Latin Sources — `https://raw.githubusercontent.com/Spyhell/spyou-latin-zan/main/index.json`

تم تثبيت رابط المستودع الخامس كما يظهر في المستودع الفعلي. لا يستخدم التطبيق رابط Spyhell Latin الخاطئ `index.ison`.

الفهارس الستة تستخدم شكلي الفهرس اللذين يدعمهما المحلل حالياً:
- OpenStream: `extensions[]` مع تعريف `engine`.
- Zangetsu-compatible indexes: `sources[]` مع `id`, `name`, `type`, `lang`, `file` وبيانات الشعار/الإصدار عند توفرها.

## 3. سلوك التهيئة والترحيل

### تثبيت جديد

عند أول `SourceRepositoryManager.sync()`، تُضاف روابط المستودعات الستة إلى قائمة المستودعات المفضلة.

### مستخدم سبق له تشغيل الإصدار القديم

إذا كان مفتاح v1 `unified_source_default_repository_seeded_v1` يساوي `true`، فهذا يعني أن التهيئة القديمة قد أضافت OpenStream. يضيف الترحيل الجديد المستودعات الخمسة الأخرى فقط، ولا يعيد OpenStream تلقائياً إن كان المستخدم قد حذفه سابقاً.

### المستخدمون الحاليون والبيانات المحفوظة

- الترحيل additive ولا يستبدل قائمة المستودعات الحالية.
- يحافظ على المستودعات المخصصة.
- يحافظ على مفاتيح تثبيت المصادر وتعطيل المصادر الافتراضية.
- يستخدم `unified_source_default_repository_seed_version_v2` كعلامة إتمام للترحيل.
- لا يعيد إضافة المستودعات في كل مزامنة بعد إتمام v2.
- إزالة المستودع تبقى فعالة ولا يعيده الترحيل تلقائياً بعد ذلك.

### الاستعادة اليدوية

أضيفت `addDefaultRepositories()` إلى `SourceRepositoryManager` وواجهة `UnifiedSourceService`. تضيف جميع المستودعات المضمّنة الناقصة فقط وتعيد عدد ما تمت إضافته. الزر في صفحة الإدارة أصبح **Add all bundled repositories**، ويمكن استخدامه لاستعادة أي مستودع مضمّن حذفه المستخدم لاحقاً. العملية idempotent وتحافظ على المستودعات المخصصة.

## 4. التثبيت والتنفيذ

إضافة مستودع إلى القائمة لا تثبت كل إضافاته ولا تنفذ ملفات JavaScript. بعد المزامنة:
- تظهر المستودعات في قسم Repositories.
- تظهر العناصر التي استطاع المحلل قراءتها في Source Catalog.
- يبقى تثبيت كل مصدر منفصلاً من زر التثبيت الحالي.
- لا يتم اعتبار وجود المصدر في الفهرس دليلاً على نجاح البحث أو استخراج رابط أو التشغيل.
- تبقى المصادر التي لم تُثبت خارج قائمة محاولات التشغيل.

هذا يحافظ على نموذج lifecycle الحالي ويمنع تفعيل 112 إضافة من مستودعات Zangetsu تلقائياً لمجرد إضافة فهارسها.

## 5. ملفات التطبيق المتغيرة

- `lib/video_providers/unified/source_repository_manager.dart`
  - قائمة الروابط الستة.
  - ترحيل v2 additive.
  - دالة استعادة المستودعات المضمّنة وإزالة التكرار.
- `lib/video_providers/unified/unified_source_service.dart`
  - تمرير دالة الاستعادة إلى واجهة التطبيق.
- `lib/screens/common/source_repositories_screen.dart`
  - زر استعادة جميع المستودعات المضمّنة.
- `assets/translations/en.json`
- `assets/translations/ar.json`
- `assets/translations/es.json`
- `assets/translations/hi.json`
- `lib/translations/codegen_loader.g.dart`
  - ترجمة عنوان الزر ورسالة التأكيد.

## 6. الاختبارات المضافة

`test/video_providers/source_repository_manager_test.dart`:
1. تثبيت جديد يزرع ستة مستودعات ويحلل fixture بصيغة OpenStream وZangetsu.
2. ترحيل مستخدم v1 يضيف خمسة مستودعات دون فقد المستودع المخصص أو مفاتيح التثبيت والتعطيل.
3. عدم إعادة OpenStream إذا سبق للمستخدم إزالته قبل الترحيل.
4. الاستعادة اليدوية additive وidempotent.

الاختبارات تستخدم Dio adapter محلياً؛ لا تعتمد على توفر GitHub لحظة تشغيل CI.

## 7. نتائج التحقق والقيود

- راجعت روابط الفهارس الستة الحية بتاريخ 2026-11-06 من واجهات raw.githubusercontent.com.
- راجعت أن صيغ OpenStream وZangetsu متوافقة مع فروع المحلل الحالية.
- تحققت من صلاحية JSON لملفات الترجمات وتناسق مفاتيحها في `codegen_loader.g.dart`.
- Flutter/Dart SDK غير متاح محلياً في بيئة إعداد الأرشيف؛ لذلك لم يتم ادعاء نجاح `dart format`, `flutter analyze`, `flutter test` أو Release Build بعد هذا التغيير.
- بناء Release الذي قدمه المستخدم ناجح على commit `6fb83a987044051e3cecf21505a260afc08f42b7`، وأنتج `RAVEN23-apk.apk` بحجم `27,881,034` bytes (26.59 MiB) لهدف `android-arm64`. هذا البناء يسبق هذا التغيير ولا يمثل تحققاً منه.
- المتوقع في واجهة الإدارة بعد تحديث التطبيق: ستة روابط في Repositories. عدد Source Catalog المتوقع من Snapshot Phase 36 هو 142 إدخالاً قبل أي تغيّر لاحق في الفهارس؛ العدد الفعلي يتبع محتوى الفهارس وتوافق parser وقت المزامنة.

## 8. شروط القبول بعد CI والجهاز

- يمر `dart format --output=none --set-exit-if-changed` على الملفات المعدلة.
- يمر `flutter analyze`.
- تمر اختبارات `source_repository_manager_test.dart` و`source_repository_parser_test.dart` ثم مجموعة الاختبارات الكاملة.
- ينجح `assembleProdRelease`.
- عند تثبيت التحديث فوق نسخة مستخدم قديمة، تظهر المستودعات الستة دون حذف custom repositories أو تغيير installed source keys.
- بعد فتح Source repositories وإتمام refresh، يظهر العدد 6 في قسم Repositories وتظهر المصادر المقروءة في Source Catalog.
- الضغط على Add all bundled repositories لا ينشئ تكرارات، ويعيد فقط ما حُذف صراحةً.
- لا يتم تثبيت كل الإضافات تلقائياً ولا تمريرها إلى محركات التشغيل دون تفعيل المستخدم.

## 9. Rollback

يمكن التراجع عن Phase 37.1 بإعادة الملفات الثمانية في قسم التطبيق والترجمات إلى نسخ Phase 37 السابقة، ثم إزالة هذا التقرير وتحديث Tracker. لا توجد إعادة كتابة لمفاتيح تثبيت المصادر أو مفاتيح التشغيل. مفتاح seed v2 الجديد غير ضار إذا عاد التطبيق إلى إصدار أقدم؛ الإصدار القديم يتجاهله ويستمر باستخدام مفاتيح v1.
