# Phase 41 — VidKing Direct Language & Quality

**الحالة:** Implementation prepared; CI acceptance pending.
**الأساس:** RAVEN23-PHASE40-MINIMAL-CI-GATE، بعد اعتماد Phase 40 عبر GitHub Actions run `42384394976`.

## الهدف

فصل اختيار لغة الصوت عن فلتر جودة الفيديو داخل VidKing Direct، مع الحفاظ على سلوك محركات Stremio وQuickJS وOpenStream الأخرى، والحفاظ على توافق مصادر OpenStream القديمة.

## النطاق الوظيفي

1. إضافة `audioLanguage` كحقل مستقل في `SourceEngineDescriptor`.
2. حصر معنى `qualityFilter` في دقة الفيديو، وتطبيع aliases المعروفة فقط إلى `360p`/`480p`/`720p`/`1080p`/`1440p`/`2160p`/`4320p` أو `Auto`.
3. ترحيل قيم اللغة القديمة المعروفة التي وُضعت داخل `qualityFilter` إلى `audioLanguage` عبر قائمة سماح محددة، لا عبر استنتاج النصوص الحرة.
4. دعم مصدر اللغة القديم `engine.language` كـselector خاص بطلب VidKing وبقيمة صوت افتراضية عندما تكون اللغة معروفة.
5. ترتيب الأولوية: تفضيل المستخدم المحفوظ والمخصص لـVidKing، ثم `engine.audioLanguage` الصريح/المرحّل، ثم لغة المحرك القديمة المعروفة. لا تُستخدم لغة التطبيق أو الترجمة لتوليد هذا التفضيل.
6. إبقاء `SourceManifest.language` لغة فهرس/كتالوج فقط؛ لا تُستخدم كدليل على لغة صوت المسار.
7. تمرير تفضيل اللغة عبر `SettingsPreferences` و`SettingsProvider` و`ProviderLoader` ثم `UnifiedSourceService` و`SourceEngineRegistry` إلى VidKing فقط. المحركات الأخرى تقبل الوسيط دون أن يتغير سلوكها.
8. إضافة اختيار مستقل محفوظ للغة الصوت في إعدادات Player على Mobile وTV، مع `Auto` كقيمة افتراضية.
9. إبقاء `audioLanguage` منفصلًا عن `UnifiedSubtitleTrack.language` وعن تصنيف Dub/Sub/Raw (`audioKind`).
10. عدم تغيير مشغل الفيديو أو واجهات التشغيل أو دورة تشغيل المصادر أو منطق الترجمة.

## توافق OpenStream القديم

- Vyse: `qualityFilter: English` يصبح `audioLanguage: English` و`qualityFilter: null`.
- Fade: `qualityFilter: Hindi` يصبح `audioLanguage: Hindi` و`qualityFilter: null`.
- Killjoy: يظل `engine.language: german` كما هو حتى يستمر معامل API القديم، ويُحل إلى قيمة صوت افتراضية German دون نسخه إلى `audioLanguage`.
- لا يتم تعديل `test/fixtures/openstream_official_repo.json`؛ يبقى fixture قديمًا لاختبار الترحيل.

## خارج النطاق

- لا تُعاد تسمية أو إعادة استخدام إعداد اللغة الافتراضية للترجمة. تُضاف خانة مستقلة محفوظة خاصة بلغة صوت VidKing في إعدادات المشغل على Mobile وTV، وقيمتها الافتراضية `Auto`.
- لا يوجد تغيير في لغة الترجمة أو تخزينها أو اختيارها؛ مفتاح تفضيل VidKing منفصل تمامًا.
- لا تغيير على مصادر غير VidKing أو سلوك تشغيل المشغل على Android/TV؛ إضافة إعداد التفضيل فقط ضمن Player Settings.
- لا استيراد/تفعيل مصادر إضافية من OpenStream؛ ذلك نطاق Phase 43.

## معايير القبول

- اختيار English/Hindi/Arabic لا يدخل في مقارنة الجودة.
- اختيار 720p/1080p/4K لا يغيّر لغة الصوت.
- اللغة المفضلة للمستخدم تتقدم على القيمة الافتراضية للمصدر.
- قيمة `qualityFilter` غير المعروفة لا تحذف stream صالحًا.
- الدقة غير المعروفة في stream لا تحذفه عند وجود فلتر دقة معروف.
- توافق fixture الرسمي القديم Vyse/Fade/Killjoy يبقى سليمًا.
- لا تتغير نتائج Stremio/QuickJS/OpenStream engines بسبب وسيط اللغة الاختياري.
- يمر التحليل، ومجموعة الاختبارات المطلوبة المحددة، ثم Release ARM64 CI.
