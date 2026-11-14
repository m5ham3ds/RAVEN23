# Phase 40 — Stremio Manifest & Configuration Engine — Audit

**التاريخ:** 2026-11-07  
**Base archive:** `RAVEN23-PHASE39-QUICKJS-SETTINGS-IMPLEMENTATION-PENDING-CI.zip`

## النطاق الذي تمت مراجعته

تم الاقتصار على وثيقة Phase 40 داخل Master Blueprint وTracker ومصفوفة التوافق، ثم مسارات Stremio الحالية التي تستدعيها الوثيقة: parser، repository client، engine/registry، provider، identity resolver، صفحة إدارة المصادر، الترجمات واختباراتها ذات الصلة. لم يُجر فحص عام أو تعديل لبقية أنظمة التطبيق.

## نتائج التدقيق

1. يوجد `StremioAddonProvider` و`StremioSourceEngine` بالفعل؛ لم تكن هناك حاجة إلى محرك بديل.
2. كان يلزم ضمان أن `configurable` لا يُعامل كإعداد إلزامي؛ الشرط الصحيح هو `configurationRequired` أو إعادة توجيه تشغيل مؤكدة إلى صفحة الإعداد.
3. يحتاج Parser إلى حفظ تفاصيل الموارد كملفات تعريف منفصلة، لأن كل مورد قد يعلن `types` و`idPrefixes` خاصة به.
4. كان مسار توليد المعرفات يحتاج منع اختراع `tmdb:` عند عدم إعلان المورد له، واستخدام `MediaIdentityResolver` فقط عند الحاجة الفعلية إلى IMDb.
5. يحتاج Manifest إلى التحقق من أنواع containers الخاصة بـ`behaviorHints`, `config`, `catalogs`, `types`, و`idPrefixes` بدلاً من قبول أشكال JSON غير صحيحة بصمت.
6. يحتوي Stremio على تعريف للحقول `config`، لكن إعداد الحساب الفعلي يجري عبر صفحة الإضافة `/configure`. لذلك يعرض RAVEN23 رابطاً آمناً إلى الصفحة الخارجية ولا يطلب بيانات اعتماد الإضافة داخلياً.
7. رابط Manifest قد يتضمن path/query مخصصين للمستخدم؛ يجب الإبقاء على query في طلبات التشغيل، وعدم نسخه إلى صفحة configure أو سجلات الأخطاء.
8. يجب الحفاظ على اختلاف حالة الأحرف في `idPrefixes` وخيارات Catalog/Config؛ تُطبّع أنواع المحتوى فقط.
9. لا يجوز اعتبار موارد `stream` غير المعلنة لنوع Movie/Series قابلة للتشغيل.
10. YaStream مرشح اختبار أولي؛ أضيف Fixture من Manifest منشور، مع الفصل بين صحة Fixture وثبات الخدمة الحية.

## المرجعية الفنية

- Stremio Manifest response: https://stremio.github.io/stremio-addon-sdk/api/responses/manifest.html
- Stremio Add-on SDK: https://github.com/Stremio/stremio-addon-sdk
- YaStream Manifest snapshot: https://yastream.tamthai.de/manifest.json (تمت مراجعته في 2026-11-07؛ Fixture ثابتة للاختبارات، ولا تدل وحدها على توافر stream وقت التشغيل).

## حدود التدقيق

لا تم اختبار تشغيل Stream على جهاز Android، ولم تُفعّل مصادر جديدة. لا يُستنتج من صحة Manifest أن المصدر يوفر روابط HTTP مباشرة أو أن تلك الروابط ستعمل في كل منطقة/وقت. اختبارات CI وبيانات التشغيل الخارجية منفصلة.
