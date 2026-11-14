# Phase 41 — Implementation Report

**الحالة: Implemented; CI acceptance pending.**

## Phase 40 baseline

اعتمد المستخدم نجاح Phase 40 من GitHub Actions run `42384394976`: `flutter analyze` بلا مشاكل؛ 44 اختبار Phase 40 ناجح؛ Release APK حجمه 26.64 MiB وABI `arm64-v8a` فقط. تم فحص مرفقات تقرير البناء وسجل الاختبارات الحرجة لهذا التشغيل.

## ما أُنجز في Phase 41

- عقد `audioLanguage` منفصل عن جودة الفيديو.
- normalizer محدود للغات والدقات المعروفة.
- ترحيل legacy لمصدري Vyse وFade مع الحفاظ على Killjoy؛ قيمة `engine.language` القديمة لا تُنسخ إلى `audioLanguage` لكي تبقى صيغة طلب endpoint الأصلية مثل `german` سليمة.
- تمرير `preferredAudioLanguage` عبر API الخدمة/registry إلى VidKing بأولوية أعلى من default المصدر. أضيفت preference محفوظة منفصلة بقيمة Auto وواجهة اختيار Mobile/TV، وربطها `ProviderLoader` بالطلب الفعلي. لا تُخلط لغة الصوت بلغة الترجمة أو لغة الواجهة.
- إبقاء مصادر/محركات أخرى دون تغيير وظيفي.
- فصل audio language عن audioKind وعن subtitles وعن لغة catalog.
- تحديث بوابة CI إلى 12 ملف اختبار محددًا تشمل اختبارات الاعتمادات السابقة وPhase40/41 واختبار تخزين تفضيل الصوت؛ لا يوجد full Flutter suite أو UI batch عام في مسار بناء APK.
- تحديث Blueprint وTracker وإضافة وثائق Phase41.

## ما لم يُعتمد بعد

لم يتوفر Flutter/Dart SDK في بيئة إعداد الملفات؛ لذلك لم أتمكن من تنفيذ `dart format`, `flutter analyze`, أو `flutter test` محليًا بعد هذه التعديلات، ولم أنفذ Release build جديدًا محليًا. workflow يطبق formatter على قائمة الملفات المحددة قبل فحص التنسيق والتحليل والاختبارات والبناء. لا تُعتبر Phase41 ناجحة قبل نجاح CI التالي.

لم تُنفذ اختبارات تشغيل حي لمزود VidKing ولا توجد مصادقة على توفر لغة بعينها في كل endpoint. مسار التفضيل المحفوظ أصبح موصولًا من Settings UI عبر ProviderLoader إلى الخدمة والمحرك؛ ويظل قبول قيمة اللغة الفعلية من VidKing مرهونًا باستجابة endpoint الحية.

## البوابات التالية

1. formatter و`flutter analyze`.
2. 12 ملف اختبار محدد بحد أقصى 10 دقائق و30 ثانية للاختبار الواحد.
3. Release ARM64 APK.
4. فحص ABI وحجم APK.
5. اختبار تشغيل يدوي لمصدر VidKing فعلي إذا توفرت استجابة خدمة مناسبة.

## القرار

التنفيذ جاهز لمراجعة CI. Phase41 تبقى `In Progress` إلى أن ينجح CI. لا يُنتقل إلى Phase42 قبل إغلاق بواباتها.
