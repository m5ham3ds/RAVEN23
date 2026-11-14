# RAVEN23 — Phase 27: Full Application Rebrand

**الحالة:** اكتملت إعادة الهوية والتهيئة الثابتة.  
**المصدر:** آخر نسخة Phase 26 من المشروع.  
**اسم الحزمة:** `raven23`  
**معرّف Android الجديد:** `com.m5ham3ds.raven23`

## 1. الهوية المرئية

- استُخدم شعار RAVEN23 الذي زوّدني به المستخدم، دون إعادة رسم النص أو تغيير تصميمه.
- أُضيف الأصل الكامل إلى:
  - `assets/images/RAVEN23.png`
  - `assets/images/logo.png`
  - `assets/images/splash_logo.png`
- أُنشئت علامة شفافة مشتقة من رأس الغراب والقمر للاستخدامات الصغيرة في الواجهات: `assets/images/raven23_mark.png`.
- حُدّثت أصول Android: adaptive launcher icon، والأيقونة الدائرية، وأيقونة TV، وأيقونة المتجر، وبانر TV، وصور Splash لكل الكثافات والوضع الليلي، وأيقونات الإشعارات والـWidgets.
- حُدّثت العلامة المستخدمة في واجهات الهاتف والتلفاز، وبطاقات الصفحة الرئيسية، وشاشة التحميل، ومكونات Plus.
- حُدّثت ملفات الترجمة العربية والإنجليزية والإسبانية والهندية والنصوص المولّدة التي تعرض اسم التطبيق إلى `RAVEN23`.

## 2. اسم التطبيق والحزمة

- Flutter package في `pubspec.yaml`: `raven23`.
- نقطة دخول التطبيق: `lib/main.dart` تستورد `lib/raven23_main.dart`.
- اسم تطبيق Flutter الرئيسي: `Raven23App`.
- Android `namespace` و`applicationId`: `com.m5ham3ds.raven23`.
- حُدّثت مسارات Kotlin وتصريحات `package` والاستيرادات والأصناف التي تحمل اسم التطبيق.
- أصبحت قناة الروابط العميقة الداخلية وقنوات Method/EventChannel المتبادلة بين Dart وAndroid ضمن نطاق `com.m5ham3ds.raven23`، وتم تحديث الطرفين معًا.
- مخطط روابط Widgets الداخلي أصبح `raven23://`.
- تسميات Android وAndroid TV ونسخة التطوير أصبحت `RAVEN23` و`RAVEN23 Dev`.
- حُدّثت أسماء ملفات المشروع/الاختبارات المتأثرة، وأسماء موارد Widgets التي كانت تشير إلى `raven23_widget.xml` بينما الملف الفعلي يحمل اسمًا قديمًا.
- حُدّثت GitHub Actions لتسمية APK الناتج `RAVEN23-apk.apk` والتحقق من `com.m5ham3ds.raven23`.

## 3. حفظ التوافق والبيانات

لم أستبدل كل سلسلة قديمة آليًا؛ بعض القيم ليست علامات تجارية مرئية، بل مفاتيح تخزين أو عقود خارجية مستخدمة بالفعل. تغييرها دون ترحيل الطرف الآخر قد يقطع الخدمة أو يفقد بيانات.

### ترحيل تفضيلات التطبيق

تُقرأ مفاتيح RAVEN23 الجديدة أولًا. عند عدم وجود قيمة جديدة، تتم قراءة القيمة القديمة مرة واحدة وكتابتها إلى المفتاح الجديد:

- `flixquestLogoUrl` → `raven23LogoUrl`
- `flixquestAPIURL` → `raven23APIURL`
- `flixquestAPIInstances` → `raven23APIInstances`

أُضيف اختبار تغطية لهذه الحالات في:
`test/preferences/app_dependency_preferences_migration_test.dart`.

### معرّفات محفوظة عمدًا

أُبقيت بعض الأسماء القديمة لأنها صيغ تخزين أو مفاتيح تكامل وليست أسماء تظهر للمستخدم:

- مفاتيح جلسة Laravel ومساحة `SharedPreferences` (`flixquest.laravel.v1.*`) للحفاظ على شكل التخزين القائم.
- اسما ملفي SQLite للـHTTP cache وطابور أحداث الإعلانات كي لا يتغير اسم قاعدة البيانات عند تحديث متوافق.
- وسم OneSignal `flixquest_platform` لأنه قد يكون مستخدمًا في قواعد الاستهداف والشرائح داخل لوحة OneSignal.
- مفاتيح Remote Config/Bootstrap `flixquest_api_instances` و`flixquest_api_url_v2` لأنها أسماء حقول يرسلها الخادم الحالي، وقد حُفظت في نماذج JSON والاختبارات.
- مجلد `cinestream_subtitles` باقٍ كمصدر قراءة لترحيل ملفات الترجمة القديمة إلى `raven23_subtitles`.

هذه المعرّفات لا تُعرض كاسم للتطبيق. يجب ترحيلها على الخادم/لوحة الخدمة أولًا قبل حذفها من العميل.

## 4. الروابط والخدمات الخارجية التي لم تتغير

لم تُخترع نطاقات أو حسابات بديلة دون أن يزوّدني المستخدم بها. لذلك بقيت الروابط/المراجع التالية كما هي، بينما تغير الاسم الظاهر في التطبيق والتوثيق إلى RAVEN23:

- مستودع مكتبة BetterPlayer الخارجية: `github.com/BeamlakAschalew/flixquest-betterplayer`؛ هذا اسم مستودع طرف ثالث ومصدر اعتماد البناء، وليس اسم التطبيق.
- خدمة Scraper الحالية: `https://scraper-1.flixquest.app` في `.env.example` تحت مفتاح `RAVEN23_API_URL`. يجب استبدال عنوان الخادم فقط عند توفير مضيف RAVEN23 الجديد واختباره.
- نطاق الروابط المشتركة الحالي `flix.quest`، وروابط الدعم/Instagram/Telegram الحالية؛ لم تُستبدل لأن حسابات/نطاقات RAVEN23 الجديدة لم تُزوّد بعد.
- Firebase project ID الحالي `flixquest-ac354`، ومفاتيح الخادم القديمة؛ ملف إعداد Firebase غير موجود في الأرشيف، كما أن CI الحالي يبني مع `ENABLE_FIREBASE=false`.

كما يمكن لقيمة `app_logo_url` الآتية من Remote Config أو Bootstrap أن تعرض شعارًا بعيدًا فوق الشعار المحلي؛ يجب تحديث تلك القيمة إلى شعار RAVEN23 أو إفراغها حتى لا يستمر الخادم في إرسال الشعار القديم.

## 5. أثر تغيير Android applicationId

تم تغيير معرّف Android من `com.m5ham3ds.cinestreampron` إلى `com.m5ham3ds.raven23` كما هو موثق في إعدادات الإصدار. هذا يجعل RAVEN23 تطبيق Android بهوية تثبيت جديدة:

- لن يُحدّث تثبيت CineStream السابق فوق نفسه؛ يمكن أن يظهر RAVEN23 كتطبيق منفصل.
- بيانات التطبيق الخاصة بالتثبيت القديم لا تنتقل تلقائيًا إلى الحزمة الجديدة.
- يجب تسجيل `com.m5ham3ds.raven23` في Firebase قبل تفعيل Firebase مستقبلًا، وإنشاء `google-services.json` المناسب مع بصمات التوقيع.
- إذا استُخدمت App Links على `flix.quest`، يجب تحديث `/.well-known/assetlinks.json` ليضم `com.m5ham3ds.raven23` وبصمة شهادة التوقيع المستخدمة للتوزيع.
- يجب التأكد من إعداد Android platform/package الصحيح في OneSignal عند تفعيل الإشعارات على تطبيق RAVEN23؛ وسم `flixquest_platform` أُبقي عمدًا لتوافق شرائح لوحة OneSignal الحالية.

إذا كان المطلوب لاحقًا أن يكون RAVEN23 تحديثًا مباشرًا فوق تثبيت CineStream الحالي بدل تطبيق منفصل، فيجب الإبقاء على `applicationId` القديم. هذا قرار هوية توزيع مستقل عن الاسم المرئي.

## 6. التحقق المنفذ

- تحليل 47 ملف Android XML: بلا أخطاء صياغة.
- تحليل 29 ملف JSON: بلا أخطاء صياغة.
- التحقق من 228 استيرادًا بصيغة `package:raven23/...`: جميع المسارات موجودة، ولم تبقَ استيرادات `package:flixquest/...`.
- التحقق من 22 ملف Kotlin: تطابق تصريح الحزمة مع مسار المجلد.
- التحقق من 138 مرجع موارد Android: لم تُعثر على موارد محلية مفقودة.
- التحقق من ملفات شعار RAVEN23 والأيقونات وصحة الصور.
- لم تبقَ ملفات محلية بأسماء `FlixQuest` أو `CINESTREAM` في شجرة ملفات المشروع.

**حد التحقق:** لم تتوفر أوامر `flutter` و`dart` في بيئة العمل؛ لذلك لم يتم تنفيذ `flutter pub get` أو `flutter analyze` أو `flutter test` أو بناء `assembleProdRelease`. يجب تشغيل GitHub Actions على النسخة المرفقة قبل اعتماد APK نهائي.

## 7. الملفات والتغييرات الرئيسة

- `pubspec.yaml`, `lib/main.dart`, `lib/raven23_main.dart`.
- `android/app/build.gradle`, `AndroidManifest.xml`, ومجلد Kotlin الجديد `android/app/src/main/kotlin/com/m5ham3ds/raven23/`.
- `assets/images/RAVEN23.png`, `logo.png`, `splash_logo.png`, `raven23_mark.png`.
- أصول Android launcher/splash/TV/notification/widget.
- `lib/preferences/app_dependency_preferences.dart` مع ترحيل مفاتيح التفضيلات.
- README، مستندات التطوير، الاختبارات، GitHub Actions، وتقارير `phases`.

تم حفظ هذا التقرير في جذر المشروع وداخل `phases/PHASE27_RAVEN23_FULL_REBRAND.md`.
