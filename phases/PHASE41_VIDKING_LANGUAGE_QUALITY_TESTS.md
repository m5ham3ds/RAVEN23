# Phase 41 — Required Tests

## فلسفة CI

تظل بوابة APK محدودة إلى ملفات العقود المرتبطة مباشرة بالاعتمادات Phase 37/37.1 و38، وPhase 40، وPhase 41. لا تشغّل مسار APK مجموعة Flutter كاملة أو دفعات UI عامة لا ترتبط بهذا التغيير. ملفات الاختبارات غير المدرجة تبقى في المستودع للاستخدام اليدوي عند تعديل مجالها.

## ملفات الاختبار المطلوبة في CI

1. `test/video_providers/source_contracts_test.dart` — عقود تعريف المصدر وهوية/قدرات المحركات (Phase 37).
2. `test/video_providers/source_engine_contract_test.dart` — التسجيل والتوجيه وعقود dispatch (Phase 37).
3. `test/video_providers/source_repository_manager_test.dart` — مزامنة/تثبيت/إدارة المستودعات (Phase 37.1).
4. `test/video_providers/unified/episode_identity_normalizer_test.dart` — مطابقة هوية الفيلم/الحلقة والموسم (Phase 38).
5. `test/video_providers/unified/quickjs_source_engine_test.dart` — حواجز QuickJS للوسائط الحلقية (اعتماد Phase 38).
6. `test/video_providers/source_repository_parser_test.dart` — parser للمستودعات وfixture OpenStream الرسمي وترحيل Vyse/Fade وقراءة `audioLanguage` الصريح.
7. `test/video_providers/source_repository_client_test.dart` — إثراء manifest وحفظ حقول descriptor.
8. `test/video_providers/stremio_addon_provider_test.dart` — عقود Stremio (Phase 40).
9. `test/video_providers/unified_source_service_stremio_identity_test.dart` — هوية Stremio وتوجيهها (Phase 40).
10. `test/video_providers/vidking_direct_provider_test.dart` — حراسة معرفات الحلقات وتمرير أولوية اللغة من registry إلى VidKing.
11. `test/video_providers/vidking_audio_quality_normalizer_test.dart` — allowlist اللغة، aliases الجودة، المصفوفة 720p/1080p/4K × English/Hindi/Arabic، القيم غير المعروفة، وعدم تغيير المحركات الأخرى.
12. `test/settings_vidking_audio_language_test.dart` — قيمة Auto الافتراضية، حفظ واستعادة لغة الصوت المستقلة، وإمكانية الرجوع إلى Auto.

## قيود الوقت

- مهلة خطوة الاختبارات: 10 دقائق.
- مهلة الاختبار الواحد: 30 ثانية.
- concurrency: 4.
- لا تشغيل لـ`flutter test` على مجلد المشروع كاملًا داخل بوابة APK.
- يحفظ CI سجل الاختبارات باسم artifact `RAVEN23-phase41-critical-test-log`.

## معايير اختبار Phase 41

- صريح: `audioLanguage=Arabic` يبقى مستقلاً عن `qualityFilter=1080p`.
- OpenStream legacy Killjoy يحتفظ بـ`engine.language=german` دون نسخه إلى `audioLanguage`؛ قيمة الصوت الداخلية تصبح `German` ويستمر request query بصيغة `german`.
- تفضيل المستخدم يتقدم على مصدر مضبوط على Hindi، وبدون تفضيل يعود الطلب إلى Hindi.
- legacy `qualityFilter=English/Hindi` يتحول إلى audioLanguage، ولا يبقى فلتر جودة.
- `4K HDR` يتطابق مع 2160p؛ 480p لا يتطابق مع 1080p؛ اللغة لا تدخل في المقارنة.
- قيم descriptor `4K HDR` و`UHD HDR` تُطبّع إلى `2160p`.
- نصوص اللغة والجودة المجهولة لا تُسقط streams صالحة تلقائيًا.
- top-level `SourceManifest.language` لا يصبح audioLanguage.
- Stremio/QuickJS/Web Embed/Anime engine لا تتغير نتيجة تنفيذها عند ترك الوسيط الاختياري null.

## الحالة

أُضيفت الاختبارات إلى الملفات المحددة، بما فيها اختبار preference مستقل. لم يُعلن نجاحها قبل تشغيل CI. Flutter/Dart غير متاحين في بيئة إعداد الحزمة الحالية.
