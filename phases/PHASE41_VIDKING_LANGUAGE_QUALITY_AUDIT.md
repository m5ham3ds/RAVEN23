# Phase 41 — Audit

## خط الأساس

- المشروع الحالي: RAVEN23-PHASE40.
- Phase 40 CI: run `42384394976`, commit `7912457bb96291d096522213b5a7f1d3655dccfa`.
- نتيجة التشغيل المعتمدة: dependency resolution ناجح؛ Dart format: 26 files / 0 changed؛ `flutter analyze`: No issues found؛ اختبارات Phase 40 المحددة: 44 passed؛ Release APK: 26.64 MiB وبـABI `arm64-v8a` فقط.
- هذا الاعتماد خاص ببوابة Phase 40 التي شُغلت، ولا يغلق تلقائيًا اعتماد Phases 37/37.1/38/39 أو تحقق التشغيل الحي.

## المشكلة السابقة

كان VidKing Direct يعامل `qualityFilter` وكأنه نص يمكن مطابقته مباشرة مع حقل جودة stream. في بيانات OpenStream الرسمية، Vyse يحمل `qualityFilter: English` وFade يحمل `qualityFilter: Hindi`. هذه ليست دقة فيديو؛ مقارنتها بالجودة قد تستبعد streams صحيحة بلا داعٍ.

كانت هناك أيضًا حقول متعددة تحمل كلمة language لكن بمعان مختلفة:

- `SourceManifest.language`: لغة كتالوج/فهرس المصدر.
- `SourceEngineDescriptor.language`: معامل legacy خاص بالمحرك، ويُمرر إلى endpoint باسم `language` مع الحفاظ على كتابته الأصلية عند عدم وجود تفضيل/حقل صوت صريح؛ لا يُنسخ إلى `audioLanguage` عند التطبيع حتى تبقى provenance واضحة.
- `UnifiedStreamOption.audioLanguage`: وصف لغة الصوت للمسار.
- `UnifiedSubtitleTrack.language`: لغة الترجمة.
- `audioKind`: تصنيف Dub/Sub/Raw، وليس لغة.

لا يجوز دمج هذه الحقول في قيمة واحدة.

## المصدر المرجعي

`test/fixtures/openstream_official_repo.json` fixture حالي من المستودع الرسمي، ويحوي إدخالات VidKing التسع. اختبارات parser الحالية تؤكد Vyse وFade وKilljoy تحديدًا. الملف يُترك دون تعديل لتظل بياناته legacy ويستمر اختبار adapter.

## تدقيق الإعدادات

لم يكن في baseline إعداد مستقل محفوظ للغة الصوت. لذلك أضيف ضمن Phase41 مفتاح preference منفصل وواجهة اختيار في إعدادات Player على Mobile وTV، ثم رُبط بـ`ProviderLoader` قبل `UnifiedSourceService`. لا تُستخدم لغة الترجمة أو لغة التطبيق بدلًا منه. القيمة الافتراضية Auto لا تغير سلوك المصدر القديم، ويظل المصدر يستخدم قيمة `audioLanguage`/legacy default الخاصة به.

## حدود الحماية

- لا تحليل عام للنصوص لاكتشاف اللغات.
- قبول أسماء/رموز لغات محددة عبر allowlist فقط.
- اللغة الموجودة ضمن نص مثل `English dub 1080p` لا تُصنّف تلقائيًا.
- الفلتر المجهول لا يستبعد نتائج صالحة.
- لا تُستخدم اللغة لتصنيف `audioKind`.
