# RAVEN23 — Phase 42: Repository Versioning, Integrity & Security

**التاريخ:** 2026-11-07  
**الحالة:** Implementation prepared — CI pending  
**نقطة العمل:** أرشيف Phase 41 الحالي، بناءً على توجيه المستخدم بالبدء مباشرةً دون انتظار اعتماد Phase 41.  
**الاعتمادات وفق الخطة:** Phase 36 وPhase 37. لم يُسجل نجاح بوابات ما بعد التغيير لكل اعتماد في هذه الحزمة؛ Phase 41 أيضًا ما زالت CI pending، ولا يُدّعى اعتمادها.

## الملفات الحالية التي تم توسيعها

- `lib/video_providers/unified/source_repository_manager.dart`: إدارة المستودعات والمزامنة والمخزن المؤقت وإعدادات التثبيت.
- `lib/video_providers/unified/source_repository_client.dart`: تنزيل الفهارس ووثائق extensions والتحويلات.
- `lib/video_providers/unified/quickjs/quickjs_provider_runtime.dart` و`js_engine.dart`: runtime وشبكة QuickJS.
- `lib/video_providers/unified/stremio_addon_provider.dart`: تنزيل manifest/resources الخاصة بإضافات Stremio.
- `lib/video_providers/unified/vidking_direct_provider.dart`: direct API وseed requests الخاصة بـ VidKing.
- `lib/video_providers/unified/openstream_anime_engine.dart`: AniList/AniZip وAnimePahe وبقية المواقع التي تستخدم Dio مباشرة.
- `lib/video_providers/unified/openstream_web_embed_engine.dart` و`android/.../OpenStreamWebEmbedBridge.kt`: direct HTTP extraction وWebView navigation/subresources.
- `lib/video_providers/unified/unified_source_service.dart`: واجهة الخدمات التي تستخدمها الشاشات.
- `lib/screens/common/source_repositories_screen.dart`: شاشة إدارة المستودعات الحالية.

## الفجوات التي عولجت

- غياب سجل snapshot وبصمة ثابتة لمحتوى المستودع والوثائق التابعة له.
- غياب pin لمراجع GitHub غير المتحركة.
- عدم وجود معاينة فرق قبل التفعيل أو rollback/resume.
- عدم وجود provenance موحد ظاهر للمستخدم.
- توسيع قنوات JavaScript بما يسمح بمسار XHR لا يمر بسياسة المضيف.
- قصور تحقق الشبكة من الوجهات الخاصة والتحويلات وحدود الاستجابة؛ كانت بعض Native engines لا تزال تستخدم Dio/WebView مباشرة خارج السياسة العامة.
- احتمال تسريب query credentials داخل metadata.
- تجاوز زمني منطقي (TOCTOU) حيث يمكن أن يعاد جلب المستودع بعد المعاينة ويُفعّل محتوى مختلف.

## مخاطر متبقية

1. سياسة DNS في Dart تتحقق من العناوين قبل الطلب والتحويل، لكن Dio ينفذ resolution للاتصال بصورة مستقلة؛ DNS rebinding لا يُغلق قطعياً دون adapter يربط العناوين التي جرى التحقق منها باتصال socket. Android WebView لا يتيح للـbridge ربط نتيجة DNS بالـsocket الداخلي؛ لذلك يرفض الـbridge local hostnames وprivate IP literals والنطاقات الخاصة لكل redirect/subresource، لكن تبقى DNS rebinding داخل WebView قيدًا معلنًا.
2. SHA-256 يكشف اختلاف البايتات أو تلف snapshot، لكنه لا يثبت هوية المؤلف أو سلامة المستودع؛ يلزم توقيع ناشر موثوق/سلسلة ثقة مستقلة لادعاء authenticity.
3. تطبيق معاينة غير مثبتة على GitHub commit يظل ذا مرجع متغير عند إعادة تشغيل التطبيق ما لم يثبت المستخدم commit كاملًا؛ snapshot الذي تمت الموافقة عليه محفوظ ويمكن الرجوع إليه.
4. لم تُنفذ Flutter/Dart/Gradle محليًا في بيئة إعداد الحزمة؛ اعتماد التنفيذ مرهون بتشغيل CI.
