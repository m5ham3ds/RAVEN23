# RAVEN23 — Phase 42: Repository Versioning, Integrity & Security

**التاريخ:** 2026-11-07  
**الحالة:** Implementation prepared — CI pending  
**نقطة العمل:** أرشيف Phase 41 الحالي، بناءً على توجيه المستخدم بالبدء مباشرةً دون انتظار اعتماد Phase 41.  
**الاعتمادات وفق الخطة:** Phase 36 وPhase 37. لم يُسجل نجاح بوابات ما بعد التغيير لكل اعتماد في هذه الحزمة؛ Phase 41 أيضًا ما زالت CI pending، ولا يُدّعى اعتمادها.

## الملفات الجديدة

- `lib/video_providers/unified/source_repository_revision.dart`
  - كائنات capture/revision/preview/provenance/duplicate.
  - تخزين app-private للوثائق والـ manifests ونسخ provider scripts.
  - SHA-256 وإعادة تحقق عند تحميل snapshot.
  - metadata لـ HTTP status وETag وLast-Modified ووقت الجلب والتحقق والـ commit/ref والـ previous hash.
  - تنقية userinfo ومفاتيح query الحساسة وبعض مفاتيح الأسرار داخل manifest config.
  - منع path traversal عند قراءة body files.
  - احتفاظ bounded: 20 revision للمستودع و20 script لكل مصدر؛ التحقق المتكرر من نفس المحتوى لا يستهلك slot جديدًا.
- `lib/video_providers/unified/source_host_policy.dart`
  - يسمح فقط بـ HTTP(S) دون credentials.
  - يرفض localhost/نطاقات local/private/reserved وIP literals غير العامة.
  - يفحص DNS ويغلق عند timeout أو رد مختلط يحتوي وجهة خاصة.
  - يعيد فحص كل redirect ويحدّه بأربع تحويلات.
  - يُحقن نفس policy في QuickJS وStremio وVidKing Direct وOpenStream Web Embed وAnime.

## الملفات المعدلة

- `source_repository_client.dart`: استقبال وثائق الفهرس والـ extension manifests، pin لعنوان GitHub Raw عند commit كامل، manual redirects، حظر HTTPS downgrade، وحد 8MiB لكل response مع إلغاء تدريجي أثناء الاستقبال، وسقف 32MiB لمجموع الوثائق الملتقطة للمستودع.
- `source_repository_manager.dart`: pin/unpin، revision history، preview/apply، rollback/resume، duplicate review، provenance، وتصدير schema v3 مع repository pins.
- `unified_source_service.dart`: تمرير واجهات revision والـ pin والـ preview والـ rollback إلى الشاشة.
- `quickjs_provider_runtime.dart`: policy لكل طلب/redirect، تنظيف headers الحساسة عبر origin، 8MiB للرد و1.5MiB للسكربت، وإلغاء تدريجي عند تجاوز الحد.
- `js_engine.dart`: قنوات المضيف العامة أربع فقط (`fetch`, `console`, `crypto`, `timer`) مع `kJsEnableNativeXhr = false` في in-process وisolate.
- `stremio_addon_provider.dart`: تطبيق redirect policy وحد 8MiB وإلغاء تدريجي على manifest/resources.
- `vidking_direct_provider.dart`: تمرير VidKing API عبر السياسة نفسها، مع redirects مفحوصة وحد 8MiB.
- `openstream_anime_engine.dart`: تمرير AniList/AniZip/AnimePahe وبقية GET عبر السياسة نفسها، ومنع إعادة تشغيل POST عند التحويل، وحد 8MiB.
- `openstream_web_embed_engine.dart` و`OpenStreamWebEmbedBridge.kt`: فحص URL الأولي وكل رابط stream/subtitle يعاد إلى Flutter، وفحص host/redirect في Dart ورفض private IP/local host وnon-HTTP(S) على تنقلات وموارد WebView. فحص DNS داخل WebView نفسه غير قابل للربط بمقبسها من الـbridge، وهذه المحدودية موثقة.
- `source_repositories_screen.dart`: عرض history/hash/last validated/ref/pin، معاينة واختيار تطبيقها، rollback/resume، provenance، ومراجعة duplicates دون حذف تلقائي.
- `.github/workflows/android-ci.yml` و`tool/format_phase37_42_dart.sh`: بوابة CI محددة بـ11 ملف اختبار، ولا full-suite ولا مجموعات UI العامة.

## ضمان المعاينة

تُخزن الوثائق المرشحة مؤقتًا بحد 16MiB وبعدد أقصى معاينتين pending. `applyPreviewedRepositoryUpdate` يتحقق من أن بصمة الوثائق المخزنة تطابق بصمة المعاينة، وينتظر refresh نشطًا، ثم يبني catalog من snapshot محلي عبر rollback override مؤقت؛ لا ينفذ إعادة تنزيل للشبكة بعد موافقة المستخدم. إذا انتهت صلاحية المعاينة أو استبدلت بمعاينة أحدث، يطلب النظام إعادة المعاينة.

## عدم تغيير السلوك

- لا تغيير لمحرك تشغيل الفيديو أو شكل `UnifiedStreamOption`.
- لا حذف/تعطيل تلقائي للمصادر المتشابهة.
- لا إضافة قدرات Filesystem/Android API إلى JavaScript.
- عدم تغيير ملفات Phase 41 الوظيفية كجزء من Phase 42 إلا ما يلزم لتوافق العقود المشتركة.
