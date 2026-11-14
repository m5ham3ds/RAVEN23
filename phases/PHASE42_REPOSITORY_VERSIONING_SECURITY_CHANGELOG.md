# RAVEN23 — Phase 42: Repository Versioning, Integrity & Security

**التاريخ:** 2026-11-07  
**الحالة:** Implementation prepared — CI pending  
**نقطة العمل:** أرشيف Phase 41 الحالي، بناءً على توجيه المستخدم بالبدء مباشرةً دون انتظار اعتماد Phase 41.  
**الاعتمادات وفق الخطة:** Phase 36 وPhase 37. لم يُسجل نجاح بوابات ما بعد التغيير لكل اعتماد في هذه الحزمة؛ Phase 41 أيضًا ما زالت CI pending، ولا يُدّعى اعتمادها.

## إضافات

- revision artifact store وhost policy.
- repository provenance and duplicate review.
- version pin، preview، apply، rollback، resume.
- App-private provider script hash storage.
- security boundaries لقنوات QuickJS وXHR.
- حدود payload/redirect/timeout/DNS وإلغاء التنزيل التدريجي.

## تعديلات

- مدير المستودعات والخدمة والعميل.
- QuickJS runtime / JS engine.
- Stremio provider.
- VidKing Direct provider وOpenStream Anime/Web Embed engines.
- Android WebView bridge: حظر local/private literals على التنقلات والموارد الفرعية.
- شاشة إدارة المستودعات.
- Android CI وDart format script.
- Manager / revision / host / Stremio / VidKing Direct security tests؛ أضيف اختبار رفض Anime host ذي DNS خاص ضمن host policy test.

## التراجع

1. أعد الملفات المذكورة في هذا السجل إلى نسخة Phase41 الأساسية إذا استدعى الأمر.
2. إزالة ملفات `source_repository_revision.dart` و`source_host_policy.dart` بعد إعادة جميع مراجعها إلى الحالة السابقة فقط.
3. مفاتيح SharedPreferences الجديدة: `unified_source_repository_pins_v1` و`unified_source_repository_rollback_v1`. لا تحذف سجل artifact store من جهاز المستخدم في rollback آلي؛ يمكن تجاهله وإزالته فقط ضمن إجراء ترحيل/تنظيف منفصل واضح.
4. مجلد `source_repository_artifacts` app-private؛ لا يتشارك مع ملفات المستخدم ولا يحذف تلقائيًا أثناء استعادة الكود.
5. أعد workflow وقائمة التنسيق إلى نسخة Phase41 فقط عند الرجوع الكامل.
