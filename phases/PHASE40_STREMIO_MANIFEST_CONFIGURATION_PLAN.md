# Phase 40 — Stremio Manifest & Configuration Engine — Plan

**التاريخ:** 2026-11-07  
**الحالة:** Implementation added; Dart/Flutter CI and dependency acceptance pending  
**المرجع:** `MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md` / Phase 40

## الهدف

تحسين تفسير Stremio Manifest الحالي وتوسيع المحول القائم، دون إنشاء محرك Stremio ثانٍ أو تغيير `SourceEngineRegistry` أو مسار المشغل. المطلوب الفصل بين إمكانية فتح صفحة الإعداد وبين كون الإعداد شرطاً لتشغيل الإضافة، مع احترام تعريفات `resources`, `types`, `idPrefixes`, `catalogs`, و`config` لكل Manifest.

## نطاق التنفيذ

1. تفسير `behaviorHints.configurable` و`configurationRequired` كقيمتين منفصلتين.
2. السماح بالتشغيل عندما تكون `configurable=true` و`configurationRequired=false`.
3. منع التشغيل قبل الشبكة فقط عندما يصرح Manifest بأن الإعداد مطلوب، أو عندما يكشف رد التشغيل إعادة توجيه مؤكدة إلى صفحة `/configure` مع HTML.
4. تحليل موارد Stremio النصية والكائنية مع احترام اختلاف قواعد `types` و`idPrefixes`.
5. دعم ملف `config` التعريفي للحقول المعروفة بحدود عددية وأطوال آمنة، مع عدم حفظ default الخاص بكلمة المرور.
6. التحقق من Catalogs وExtra fields وإزالة التكرار دون تغيير حالة الأحرف في الخيارات ومعرفات الموارد.
7. إنشاء رابط `/configure` وفق مسار الإضافة، مع عدم نقل query المحتوي على token إلى المتصفح.
8. بناء طلبات Streams وفق النوع المطلوب والبادئات المعلنة، وعدم توليد IMDb/TMDB أو معرفات خارجية غير مدعومة.
9. الحفاظ على query/path الخاصين بكل Manifest في طلبات التشغيل؛ هذه القيم لا تُعرض في رسائل الخطأ.
10. استخدام Fixture YaStream حقيقية المصدر محلياً، واختبار عزل الإضافات المعطوبة عبر سلوك Repository Client الحالي.

## الملفات المتوقعة

- `lib/video_providers/unified/source_repository_parser.dart`
- `lib/video_providers/unified/stremio_addon_provider.dart`
- `lib/video_providers/unified/unified_source_service.dart`
- `lib/screens/common/source_repositories_screen.dart`
- `lib/video_providers/unified/source_engine.dart` عند الحاجة إلى تدقيق dispatch الموجود فقط.
- `assets/translations/{ar,en,es,hi}.json`
- `lib/translations/codegen_loader.g.dart`
- اختبارات Parser / Client / Provider / identity وFixture YaStream.
- `.github/workflows/android-ci.yml`
- وثائق هذه المرحلة داخل `phases/`.

## شروط القبول

- `configurable` لا يتحول تلقائياً إلى `configurationRequired`.
- Manifest الذي يعلن `configurationRequired=true` لا يرسل طلب stream قبل الإعداد.
- إعداد الصفحة لا يُفتح إلا على HTTP(S) صالح، وبيانات الاعتماد تُدخل في موقع الإضافة لا في التطبيق.
- موارد `stream` تُطابق النوع والبادئات وفق نطاق المورد الصحيح.
- لا يتم اصطناع `tmdb:` ما لم يعلن المورد هذه البادئة صراحة.
- لا يتم استخدام IMDb resolver إلا عندما يحتاج المورد إلى IMDb فعلياً.
- إعداد كل إضافة ومسارها لا يختلط بإضافة أخرى، ولا يتسرب token إلى URL الخاص بصفحة الإعداد أو رسائل الخطأ.
- Manifest مكسور أو غير متاح لا يعطل الإضافات الأخرى.
- اجتياز Format / Analyze / focused tests / full tests / Release ARM64 CI قبل قبول المرحلة.

## خارج النطاق

- إنشاء Stremio player جديد.
- دعم Torrent / YouTube / external-link resolvers؛ يقتصر هذا المحول على Direct HTTP(S) streams القابلة للتشغيل بالمحرك الحالي.
- إنشاء نموذج إعداد عام جديد داخل التطبيق أو تخزين كلمات مرور Stremio محلياً؛ تُدار الإعدادات من صفحة `/configure` الرسمية ويُعاد إدخال Manifest المُهيأ عند توفره.
- تفعيل كل الإضافات تلقائياً أو تجاوز المصادقة أو DRM أو القيود الجغرافية.
