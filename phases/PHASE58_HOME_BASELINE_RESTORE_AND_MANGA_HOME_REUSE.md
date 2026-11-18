# PHASE58 — Restore Home Baseline and Make Manga Use Home Components

**تاريخ الإعداد:** 2026-11-11  
**المرجع البصري الملزم:** الأرشيف الذي أعاده المالك `RAVEN23-PHASE55(1).zip`  
**نقطة الانطلاق:** نسخة PHASE57.7 التي أكد المالك نجاح بنائها وعمل تثبيت إضافات Mihon فيها.

## الهدف

استعادة صفحات Home الخاصة بالأفلام والمسلسلات والأنمي إلى خط أساس PHASE55 بدقة، مع إبقاء Manga/Manhwa/Manhua ضمن نفس نظام عناصر Home بدل إنشاء نظام واجهة منفصل. يجب ألا يمس هذا الإصلاح عمل Mihon الذي أكّد المالك نجاحه، أو محركات الفيديو والمشغل.

## التغييرات المنفذة

1. استُعيد `lib/mobile/screens/home_screen.dart` من PHASE55(1) **بايتًا ببايت**. بذلك تعود بنية Home، شرائح All/Movies/Series/Categories، فرع Anime، مواضع الإعلانات، صفوف الأفلام/المسلسلات/الأنمي، ترتيبها، وتخطيط الرأس إلى النسخة التي أكد المالك أنها صحيحة.
2. بقيت مكونات Home المشتركة `HeroCarousel` و`HeroCard` و`PosterRow` و`TopTenRow` و`PosterCard` و`MediaArt` متوافقة رجعيًا: كل خيارات Manga المخصصة اختيارية، وقيمها الافتراضية تحفظ مسار PHASE55.
3. أزيل تمرير روابط AniList المباشرة بصورة عامة من البطاقات. روابط الصور المطلقة لا تُستخدم إلا عندما تمرر Manga صراحةً `artworkUrlFor`/`directArtworkUrl`. صفحات Movies/Series/Anime تبقى على صور TMDB/proxy المبنية من `posterPath` و`backdropPath` كما كانت.
4. شاشة Manga تستخدم عناصر Home نفسها: `HomeHeaderDelegate`، وشرائح Home، و`HeroCarousel`/`HeroCard`، و`TopTenRow`، و`PosterRow`، و`HomeOptionalRow`، و`HomeSkeleton`، وإيقاع المسافات والانتقالات نفسه. تمت إضافة البحث وتفاصيل Mihon بوصفها وظائف خاصة بالمحتوى، لا نظام بطاقات أو رفوف بديلًا.
5. جرى تثبيت ترتيب الكتالوج في `MangaCatalogue.homeShelves` والتحقق من وجود **18 رفًا** بالترتيب: Top 10، Recently Released، Trending، Popular، Top Rated، Upcoming، Completed، Action، Adventure، Comedy، Drama، Fantasy، Horror، Mystery، Romance، Sci-Fi، Supernatural، Slice of Life.
6. تبقى صفحة All مبنية من خلاصات JP/KR/CN المستقلة، مع إزالة التكرار ودمج الرفوف، ثم عرض رفوف Japanese Manga وManhwa وManhua الإقليمية. وتظل صفحات كل فئة تستخدم بلدها المستهدف.
7. بقي إصلاح Mihon الذي أثبت المالك نجاحه كما هو: قراءة sidecar `repo.json` مع التحقق من بصمة التوقيع، وتطبيع تمثيل Float لإصداري ABI 1.4 و1.6 فقط. لم يُعدّل `MihonExtensionLoader.kt` أو `keiyoushi_extension_repository.dart` في هذه المرحلة.
8. بقي إصلاح لقطة المستودع الصريحة في `unified_source_service.dart` كما هو. لم تتغير محركات الفيديو أو BetterPlayer أو مستودعات الفيديو.

## ضمان عدم التأثير على صفحات الفيديو

- `home_screen.dart` مطابق للأصل PHASE55(1) بايتًا ببايت.
- القيمة الافتراضية لـ`HeroCard.artworkUrlFor` و`HeroCarousel.artworkUrlFor` هي `null`، فيستمر استخدام مسار TMDB الأصلي.
- القيمة الافتراضية لـ`PosterRow.artworkUrlFor` و`TopTenRow.artworkUrlFor` هي `null`، و`PosterCard.directArtworkUrl` غير محدد، لذلك لا يجري تحميل روابط AniList مباشرة في هذه الصفحات.
- الإضافات في `discover_screen.dart` و`page_kit.dart` عبارة عن مفاتيح اختبار ثابتة فقط ولا تغيّر تخطيط الواجهة.

## الاختبارات والتغطية

- أُضيف تأكيد صغير إلى `phase57_manga_home_parity_test.dart` بأن مكونات الفيديو المشتركة تحتفظ افتراضيًا بإعدادات PHASE55 (لا روابط مباشرة، لا أفعال Manga، وعرض شعار العنوان/ورقة العنوان الافتراضيين).
- بقي اختبار ترتيب الرفوف الـ18 واختبار دمج All.
- لم تُحذف ملفات الاختبار الموجودة.
- تم فحص ملفات JSON/YAML وكتل Bash وروابط وثائق المرحلة وفهرس الملفات وسلامة ZIP.

## حدود التحقق

بيئة تحرير الأرشيف لا تحتوي على Flutter/Dart/Gradle؛ لذلك لم يُشغّل `dart format` أو `flutter analyze` أو `flutter test` أو Release APK محليًا. تم التحقق بنيويًا وبالمقارنة المباشرة مع PHASE55(1). لا يُدّعى أن PHASE58 اجتازت CI حتى يشغّل المالك GitHub Actions ويختبر الصفحات على الجهاز.

## معيار القبول

1. بناء Release ARM64 ينجح دون تغيير بوابة CI التي نجحت في PHASE57.7.
2. صفحات Movies وSeries وAnime تطابق سلوك وتصميم PHASE55(1)، ولا تتسرب إليها روابط AniList أو إجراءات Manga.
3. Manga/Manhwa/Manhua تستخدم عناصر Home المشتركة مع ظهور الأقسام الـ18 عندما تتوفر بياناتها، وتظهر أقسام JP/KR/CN في All.
4. يبقى تثبيت Mihon extension ناجحًا مع التحقق من الثقة وABI.
5. لا تتغير محركات الفيديو أو BetterPlayer.

**الحالة:** التعديلات والفحوص البنيوية جاهزة؛ CI وفحص الجهاز بانتظار التنفيذ. لا تعتبر PHASE58 معتمدة قبل ذلك.
