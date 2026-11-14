# RAVEN23 — Phase 42: Repository Versioning, Integrity & Security

**التاريخ:** 2026-11-07  
**الحالة:** Implementation prepared — CI pending  
**نقطة العمل:** أرشيف Phase 41 الحالي، بناءً على توجيه المستخدم بالبدء مباشرةً دون انتظار اعتماد Phase 41.  
**الاعتمادات وفق الخطة:** Phase 36 وPhase 37. لم يُسجل نجاح بوابات ما بعد التغيير لكل اعتماد في هذه الحزمة؛ Phase 41 أيضًا ما زالت CI pending، ولا يُدّعى اعتمادها.

## بوابة الاختبارات المحددة

يُشغّل workflow أحد عشر ملفًا فقط، مع `--timeout 30s` لكل test و`--concurrency=4` وحد 10 دقائق للخطوة. لا يجري تشغيل Flutter full suite أو دفعات UI غير مرتبطة بمسار المصادر.

1. `test/video_providers/source_contracts_test.dart`
2. `test/video_providers/source_engine_contract_test.dart`
3. `test/video_providers/source_repository_manager_test.dart`
4. `test/video_providers/unified/quickjs_source_engine_test.dart`
5. `test/video_providers/source_repository_parser_test.dart`
6. `test/video_providers/source_repository_client_test.dart`
7. `test/video_providers/stremio_addon_provider_test.dart`
8. `test/video_providers/source_repository_revision_test.dart`
9. `test/video_providers/source_host_policy_test.dart`
10. `test/video_providers/quickjs_bridge_security_test.dart`
11. `test/video_providers/vidking_direct_provider_test.dart`

## التغطية المضافة مباشرةً لـ Phase 42

- persist/reload revisions، SHA-256، previous hash، retention limits، عدم استهلاك التاريخ عند تحقق المحتوى نفسه.
- كشف تلف bytes قبل استخدام snapshot، منع body path traversal، وتنقية query credentials وconfig secrets.
- pin/unpin GitHub full commit وتصدير schema v3.
- preview/apply/rollback/resume، والتحقق من عدم إعادة طلب المستودع بعد preview approval.
- رفض loopback/private/local/IP-mapped/NAT64/6to4/special IPv6 ومضيف يحل إلى عنوان خاص.
- منع redirect إلى loopback في Stremio، والتحويل الآمن بالمستودعات ومحرك QuickJS وVidKing وAnime.
- OpenStream Anime: إثبات عدم خروج طلب AniList عندما يحلّ DNS إلى عنوان خاص.
- VidKing Direct: حماية API/seed من عناوين خاصة وتحويلات غير آمنة.
- WebView bridge: كود Android يفحص local/private literals لكل تنقل وطلب فرعي؛ اختباره الفعلي يتطلب بناء Android وCI.
- إبقاء قنوات QuickJS الأربع فقط وتعطيل XHR الأصلي.

## حالة التنفيذ

الاختبارات مكتوبة ومدرجة بالبوابة؛ **لم تُشغّل بعد في بيئة البناء هذه** لعدم توفر Flutter/Dart SDK. نجاح الاختبارات أو Analyze أو Release لم يُدّعَ. CI التالي يجب أن يجتاز Analyze والملفات الإحدى عشرة وبناء Release ARM64 وفحص ABI.
