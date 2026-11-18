# RAVEN23 — Phase 32: Top Rated Anime, Streaming Anime, Search Anime & Default Red Theme

## نطاق المرحلة

تم تنفيذ التعديلات على أحدث أرشيف `RAVEN23.zip` الذي أرسله المستخدم، مع الاحتفاظ بهوية المشروع وملفات الصور والشعارات التي جهّزها المستخدم. تمت مراجعة توثيق المراحل الموجودة داخل `phases`، خصوصًا قواعد Phase 28 الخاصة بهوية الأنمي.

## 1. اللون الافتراضي في CUSTOM THEME COLOR

- أصبح لون الاختيار الافتراضي `#FF0000` (`0xFFFF0000`) بدل البرتقالي.
- تم ضبط `useExactPrimary: true` حتى تكون قيمة `ColorScheme.primary` هي الأحمر الصريح، لا درجة مولّدة منه.
- بقيت ألوان اللوحة الأخرى متاحة كاختيارات إضافية؛ لا يُفرض الأحمر على اختيار لون مخصص آخر.
- أضيف اختبار يثبت قيمة اللون الافتراضي في الوضعين الفاتح والداكن.

الملف:
- `lib/models/app_colors.dart`

## 2. Home — Top rated anime

- أضيف `HomeList.topRatedAnime` كقائمة مستقلة عن Top Rated Series.
- أضيف endpoint يستخدم TMDB `/discover/tv` مع:
  - `sort_by=vote_average.desc`
  - `vote_count.gte=30`
  - `with_genres=16` (Animation)
  - `with_original_language=ja`
  - `include_adult` مطابقًا لإعداد المستخدم.
- يعرض Home صف `Top rated anime` منفصلًا، ويظهر ضمن All وSeries، ولا يظهر في Movies.
- صفحة See All تستخدم نفس استعلام القائمة وعنوان Anime الصحيح.
- تظل النتائج `MediaKind.series` حتى تستمر في فتح صفحة المسلسل والمواسم والحلقات ومسار تشغيل الأنمي الحالي.

الملفات:
- `lib/api/endpoints.dart`
- `lib/catalog/home_feed_controller.dart`
- `lib/mobile/screens/home_screen.dart`

## 3. Streaming services — Anime لكل مزوّد

أصبح الضغط على أي خدمة بث يفتح ثلاثة تبويبات بالترتيب:

1. Movies
2. Series
3. Anime

يُحمّل تبويب Anime ككتالوج TV منفصل للمزوّد المختار، باستخدام:
- `with_watch_providers=<providerId>`
- `watch_region=US` (مطابق لإعدادات كتالوج الخدمات الحالي)
- `with_genres=16`
- `with_original_language=ja`
- `include_adult` وفق إعداد المستخدم.

تُفلتر النتائج مرة أخرى بواسطة `TV.isLikelyAnime` قبل عرضها، وتبقى من النوع التلفزيوني الحَلَقي. لم تتم إضافة مواضع إعلانات جديدة إلى عقد الخادم؛ استُخدم موضع `streaming_tv` المعتمد للمحتوى التلفزيوني/الأنمي.

الملفات:
- `lib/api/endpoints.dart`
- `lib/catalog/catalog_controller.dart`
- `lib/mobile/screens/home_screen.dart`

## 4. Search — Anime tab

أصبح ترتيب فلاتر نتائج البحث:

1. All
2. Movies
3. Series
4. Anime
5. People

يستمر البحث باستخدام مصدر TV المعتاد، ثم تُقسّم نتائجه إلى Series وAnime وفق قاعدة المشروع المعتمدة في `TV.isLikelyAnime`:
- Genre ID 16 (Animation)
- Original language `ja`

لا يتم تحويل نتائج Anime إلى نوع محتوى جديد؛ تظل `MediaKind.series` للحفاظ على صفحات التفاصيل والحلقات والتشغيل. كما أصبح `SearchResults.isEmpty` ونتيجة البحث الأعلى احتسابًا لنتائج Anime.

الملفات:
- `lib/catalog/media_search.dart`
- `lib/mobile/screens/search_screen.dart`

## 5. الترجمة

تمت إضافة/تأكيد مفتاح `top_rated_anime` في ملفات اللغات الأربعة:
- `assets/translations/en.json`
- `assets/translations/ar.json`
- `assets/translations/es.json`
- `assets/translations/hi.json`

وتم تحديث:
- `lib/translations/codegen_loader.g.dart`
- `lib/translations/locale_keys.g.dart`

## 6. تصحيح مساري استيراد في نقطة بناء Android

أثناء التحقق من الاستيرادات النسبية، وُجد في `lib/main.dart` استيرادان يبدأان بـ`../` ويشيران فعليًا خارج مجلد `lib`، مع أن ملفي الهدف موجودان داخل `lib`. وبما أن Workflow يبني التطبيق باستخدام `--target lib/main.dart`، تم تصحيح المسارين إلى:
- `models/translation.dart`
- `provider/app_dependency_provider.dart`

هذا التصحيح لا يغيّر السلوك أو الاعتمادات؛ إنما يجعل مساري الاستيراد متوافقين مع موضع ملف نقطة الدخول.

## 7. الاختبارات المضافة/المحدّثة

- `test/anime_home_and_streaming_test.dart` — استعلام Top Rated Anime، وأنمي مزوّد البث، وشروط المزوّد واللغة والبالغين، وأن Anime تبقى مجموعة TV.
- `test/home_feed_controller_test.dart` — فصل Top Rated Anime عن Series وMovies.
- `test/home_screen_test.dart` — ظهور صف Top Rated Anime مع All وSeries واختفاؤه في Movies، مع تغطية قيمة enum الجديدة في fake source.
- `test/search_screen_test.dart` — خمس فلاتر منفصلة واحتفاظ نتائج Anime بنوع `MediaKind.series`.
- `test/app_colors_test.dart` — اختبار اللون الافتراضي الدقيق.

## 8. ملفات لم تُغيّر

- محركات استخراج الفيديو ومصادر التشغيل.
- مشغّل الفيديو والجسر بين المصادر والمشغّل.
- تفاصيل المسلسلات والمواسم والحلقات.
- صور وشعارات المستخدم وأصول Android/Flutter.
- عقود الإعلانات الخلفية الحالية.

## 9. نتائج التحقق

تم تنفيذ فحوص ثابتة داخل بيئة التحرير:
- 29 ملف JSON قابل للقراءة.
- 44 ملف Android XML قابل للتحليل.
- وجود `top_rated_anime` في ملفات اللغات الأربعة.
- ترتيب Search filters مطابق للترتيب المطلوب.
- 1,841 مرجع import/export/part نسبي دون ملفات مفقودة بعد تصحيح استيرادي `main.dart`.
- فحص توازن الأقواس في 13 ملف Dart معدل.
- إضافة تغطية لاكتمال switch الذي يتعامل مع `HomeList`.
- لم تتغير ملفات الصور في `assets/images` مقارنة بالأرشيف الذي رفعه المستخدم.

لم تتوفر Flutter/Dart SDK في بيئة التحرير، لذلك لم يتم تشغيل `flutter analyze` أو `flutter test` أو بناء APK. يجب تنفيذها في GitHub Actions قبل اعتبار البناء ناجحًا.
