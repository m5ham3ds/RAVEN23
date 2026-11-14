# RAVEN23 — Phase 31: Restore original brand asset structure

**تاريخ التنفيذ:** 2026-11-05  
**المرجع:** `RAVEN23-PHASE30-CROSS-SCREEN-REVEAL-ANIMATION.zip` وملفات FlixQuest الأصلية المرفوعة، بالإضافة إلى ملفات XML الأربعة التي قدمها المستخدم.

## الهدف

فصل صورة شعار RAVEN23 المخصصة لأيقونة التطبيق الخارجية عن الشعارات الداخلية، وإعادة بنية ملفات FlixQuest المخصصة للأماكن المختلفة بدل استخدام صورة PNG واحدة في جميع المواضع.

## ما تمت استعادته

### أصول Flutter الداخلية

أعيدت الملفات الثلاثة من FlixQuest **بايتًا ببايت دون تعديل**:

- `assets/images/fq_svg.svg` — علامة OutlineMark.
- `assets/images/fq_mark.svg` — العلامة الصغيرة المستخدمة في بطاقة Hero، شاشة تحميل التشغيل، واحتياطي شعار الصفحة الرئيسية وشريط تنقل التلفاز.
- `assets/images/fq_plus.svg` — علامة PlusMark الخاصة بقسم Plus.

تمت إعادة مراجع الاستخدام في:

- `lib/design/outline_mark.dart`.
- `lib/widgets/playback_loading_screen.dart`.
- `lib/mobile/widgets/hero_card.dart`.
- `lib/mobile/screens/home_screen.dart`.
- `lib/tv/widgets/tv_navigation_rail.dart`.
- `lib/widgets/plus/plus_visuals.dart`.

استُعيد أيضًا تنفيذ `FlixAiMark` المرسوم بـ`CustomPainter` من FlixQuest بدل صورة `raven23_mark.png`، مع الحفاظ على واجهة الـWidget الحالية.

### ملفات الشعارات العامة وشاشة البداية

أعيدت نسختا FlixQuest الأصليتان إلى مواضعهما المستقلة:

- `assets/images/logo.png` — fallback الافتراضي لـ`AppLogo` ويستخدم أيضًا في Update وWellness.
- `assets/images/splash_logo.png` — مصدر صورة Flutter Native Splash.

أعيدت كذلك صور Splash المولدة لكل كثافات Android، بما فيها `android12splash.png` و`splash.png` والنسخ الليلية، من FlixQuest؛ حتى لا تبقى صورة أيقونة RAVEN23 مستخدمة كشعار Splash داخلي.

أعيد `android/app/src/main/res/drawable-xhdpi/tv_banner.png` إلى أصل FlixQuest لأنه بانر Android TV مستقل وليس أيقونة التطبيق.

### موارد Android XML

نُسخت ملفات المستخدم الأربعة إلى `android/app/src/main/res/drawable/` **كما هي تمامًا**، وتطابقت SHA-256 مع الملفات المرفوعة:

- `ic_monochrome.xml`.
- `ic_notification.xml`.
- `ic_stat_onesignal_default.xml`.
- `icon.xml`.

حافظنا على ربط FlixQuest الأصلي:

- `AndroidManifest.xml` يوجّه Firebase Messaging وFlutter Downloader إلى `@drawable/ic_notification`.
- `values/notification_icons.xml` يوجّه إشعار Media3 إلى `@drawable/ic_notification`.
- OneSignal يحتفظ بالاسم المتعارف عليه `ic_stat_onesignal_default`.
- `mipmap-anydpi-v26/ic_launcher.xml` يستخدم `@drawable/icon` كطبقة monochrome، كما في FlixQuest.
- `ic_monochrome.xml` محفوظ بالاسم الذي قدمه المستخدم كمورد drawable مستقل، مثل مورد FlixQuest المناظر.

أعيد ملف علامة الـWidget إلى VectorDrawable حقيقي، باستخدام مسارات FlixQuest الأصلية من `flixquest_widget_mark.xml`، مع اسم مورد RAVEN23 الحالي:

`android/app/src/main/res/drawable/raven23_widget_mark.xml`

وجميع تخطيطات Widgets تواصل الإشارة إلى `@drawable/raven23_widget_mark`، كما يستمر كود Kotlin في تطبيق لون الـtheme عليها.

## صورة أيقونة RAVEN23 الخارجية

بقيت أيقونات التطبيق الخارجية المولدة في موارد Android (`mipmap-*` و`mipmap-television-*`) دون استبدالها بشعارات FlixQuest؛ فهي هوية RAVEN23 الجديدة.

نُقلت الصورة المصدر `RAVEN23.png` من مجلد Flutter runtime assets إلى:

`branding/launcher/RAVEN23.png`

وبذلك لا تدخل ضمن أصول `assets/images/` التي يضمّنها Flutter كأصول واجهة داخلية. أُحدّث رابط الصورة في README ليتبع المسار الجديد.

## حذف بدائل PNG غير المطلوبة

حُذفت الصور الاصطناعية التي كانت قد استُخدمت بدل ملفات SVG/XML:

- `assets/images/raven23_mark.png`.
- `android/app/src/main/res/drawable/raven23_notification.png`.
- `android/app/src/main/res/drawable/raven23_widget_mark_image.png`.

لا توجد مراجع نشطة إليها في ملفات Dart أو Android بعد الاستعادة.

## ملفات لم تتغير

- صور Launcher الخاصة بـRAVEN23 في mipmap وأيقونة متجر Play.
- معرّف الحزمة `com.m5ham3ds.raven23`.
- إعدادات Firebase وOneSignal وManifest غير المرتبطة بمسارات الصور.
- بيانات التطبيق أو محركات التشغيل والمصادر أو قاعدة البيانات.
- تقارير المراحل السابقة.

## نتائج التحقق

- SHA-256 لأصول `fq_svg.svg` و`fq_mark.svg` و`fq_plus.svg` مطابق تمامًا لنسخ FlixQuest.
- SHA-256 لملفات XML الأربعة مطابق تمامًا للملفات الأربعة التي رفعها المستخدم.
- ملفات `logo.png` و`splash_logo.png` مطابقة لنسخ FlixQuest الأصلية.
- تم فحص 50 ملف XML/SVG في موارد Android وأصول SVG؛ لا توجد أخطاء parsing.
- فحص مراجع الصور في Dart: لا توجد مراجع أصول مفقودة.
- لا توجد مراجع نشطة للصور الثلاثة التي حُذفت.
- كل تخطيطات Widgets ما زالت تشير إلى VectorDrawable `raven23_widget_mark`.

## حدود التحقق

لم يتم تشغيل `flutter analyze` أو بناء APK أو تثبيت التطبيق في هذه البيئة لعدم توفر Flutter SDK. لذلك يلزم التحقق النهائي من المظهر الفعلي بعد بناء التطبيق، خصوصًا شكل أيقونات الإشعارات على Android وOneSignal. لم نعدّل محتوى ملفات XML التي قدمها المستخدم؛ تم نسخها كما هي بناءً على طلبه.

## ملاحظة للمستقبل

يمكن استبدال الرسومات الداخلية لاحقًا في المواضع المنفصلة نفسها دون المساس بأيقونة التطبيق:

- `fq_svg.svg` للعلامة العامة.
- `fq_mark.svg` للعلامة المختصرة.
- `fq_plus.svg` لعلامة Plus.
- `logo.png` للاحتياطي العام.
- `splash_logo.png` لصورة البداية.
- `raven23_widget_mark.xml` لعلامة Android Widget المتجهة.
- ملفات XML الأربعة داخل `android/app/src/main/res/drawable/` لأدوار Android المحددة أعلاه.
