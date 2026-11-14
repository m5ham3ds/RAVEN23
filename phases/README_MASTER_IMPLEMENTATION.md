# RAVEN23 — Master Implementation Documentation

## أحدث حالة تنفيذ — PHASE63.6 (2026-11-13)

**PHASE63.6 — تحسين أيقونات شريط التنقل ودمج دليل مصادر المانغا:** أصبحت أيقونة Home هي `house` وعادت `radio-button` إلى زر القائمة الأوسط بدل `list`. بقي New & Hot وباقي الأيقونات دون تغيير، مع بقاء `x` عند فتح القائمة وأيقونة الوجهة الثانوية النشطة بعد الاختيار. كُبّرت أيقونة الزر الأوسط 25% إلى 30 نقطة، وقلّ عرض توزيع عناصر الشريطين الرئيسي والثانوي إلى 87.5% لتقليل المسافات بين المراكز 12.5%. كما دُمجت شاشة `Manga sources & extensions` وشاشة المصادر المثبتة في دليل واحد باسم `Installed Manga Sources`: يعرض العناصر المثبتة بسهم فتح، والمتاحة بإجراءي الموقع والتنزيل، ويحتفظ بالتثبيت بعد الموافقة والتحقق من بصمة التوقيع والإزالة والبحث ومعلومات المصدر. تظل إدارة المستودعات في Settings > Sources، وأُزيلت الشاشة المستقلة القديمة بعد نقل سلوكها.

**حالة التحقق:** تمت إضافة اختبار Widget للدليل الموحد إلى بوابة Flutter المركزة، فأصبح عدد ملفات الاختبار 13، وأضيفت ملفات الشاشة والاختبار إلى قائمة التنسيق (55 هدفًا). اجتازت الفحوص الساكنة: `bash -n`، ووجود جميع أهداف التنسيق الـ55 والاختبارات الـ13، وتحليل YAML الخاص بـCI، وعدم بقاء مراجع للشاشة القديمة. لا تتوفر أدوات Dart/Flutter/Gradle/Android SDK في بيئة التحرير، لذلك لم تُشغّل `dart format` أو `flutter analyze` أو الاختبارات أو بناء APK. يلزم تشغيل GitHub Actions جديد وفحص الجهاز قبل اعتماد البناء. راجع [`PHASE63.6_NAVIGATION_AND_UNIFIED_MIHON_DIRECTORY.md`](PHASE63.6_NAVIGATION_AND_UNIFIED_MIHON_DIRECTORY.md).

---

## PHASE63.5 — Focused pre-build test repair (2026-11-13)

تقرير GitHub Actions رقم `43417262025` أثبت نجاح `flutter pub get` والتنسيق ذي الأهداف الـ53 و`flutter analyze`، ثم فشل اختبار واحد فقط من بوابة الاختبارات الـ12 (94 ناجحًا، واختبار واحد فاشل). كان الاختبار يبحث عن أيقونة `video` على مستوى الشجرة كلها ويتوقع ظهورها مرة واحدة، رغم أن ظهورها مرتين صحيح: في وجهة Movies وفي زر القائمة الأوسط الذي يعكس الوجهة المختارة. تم تصحيح الاختبار ليحصر التحقق داخل زر القائمة ذي المفتاح `mobile-nav-menu-toggle` ويتحقق من قيمة الأيقونة مباشرة، مع الحفاظ على التنفيذ الفعلي دون تعديل. كما صُحح تقرير CI الذي كان لا يزال يعرض عددًا قديمًا قدره 8 ملفات رغم أن البوابة تشغّل 12 ملفًا.

**حالة التحقق:** إصلاح PHASE63.5 أصبح خط أساس المرحلة التالية؛ لم يُنتج التشغيل الأصلي APK لأن الاختبار أوقف المراحل اللاحقة. راجع [`PHASE63.5_CI_PREBUILD_NAVIGATION_TEST_FIX.md`](PHASE63.5_CI_PREBUILD_NAVIGATION_TEST_FIX.md).

---

## PHASE63.4 — Phosphor navigation icons and destination-aware menu toggle

- [`PHASE63.4_PHOSPHOR_NAVIGATION_ICONS.md`](PHASE63.4_PHOSPHOR_NAVIGATION_ICONS.md) — تغيير أيقونة Home إلى radioButton، وأيقونات Movies/Series/Anime/Manga إلى video/televisionSimple/maskHappy/bookOpenText، مع الإبقاء على Search، وتحويل زر القائمة الثانية إلى أيقونة الوجهة النشطة وإرجاعه إلى list عند العودة إلى Home.

**الحالة:** تحديث الأيقونات وسلوك زر القائمة محفوظان. كشف CI لاحقًا خطأً في أداة اختبار واحدة لا في سلوك الواجهة؛ أصلحه PHASE63.5. يلزم CI جديد وبناء APK قبل الاعتماد النهائي.

---

## PHASE63.2 — ملخص التنفيذ (2026-11-13)

**PHASE63.2 — إصلاحات واجهة صفحة العمل وحفظ الحالة وتكامل مصادر Mihon:** تمت مراجعة تنفيذ Zangetsu الفعلي قبل كل تعديل. أُثبت شريط التبويبات الأربعة عبر `NestedScrollView` و`SliverPersistentHeader(pinned: true)`، مع جعل حالات التحميل والفراغ قابلة للتمرير كي لا تعطل تثبيت التبويبات. عُدّل رأس العمل إلى تصميم الغلاف المتداخل فوق الخلفية الذي زوّده المالك. ترتيب الفصول رقمي تصاعدي افتراضيًا مع دعم الأرقام المحلية، وأصبحت إعدادات كل عمل (قائمة/شبكة، عكس الترتيب، مرشح المترجم، التبويب المختار وNotify) محفوظة ذريًا وتُقرأ بعد انتظار أي كتابة معلقة. أضيف Notify بين My List وShare، مع تنبيه محلي عند اكتشاف زيادة الفصول عند فتح الصفحة أو استئناف التطبيق. بحث Mihon يستخدم Romaji وEnglish وNative وجميع Synonyms في كل مصدر مثبت؛ يجرّب المصدر الأخير الناجح أولًا ثم يستكمل بقية المصادر عند عدم التطابق. قائمة Mihon تعرض All/Manga وAuto Resolve والمصدر الحالي وترتيب التثبيت وإجراءات Cloudflare/Sign in/Settings، وتقرأ أيقونة الإضافة من APK المثبت مع fallback.

**حدود صريحة:** Notify لا يعمل بجدولة خلفية عند إغلاق التطبيق؛ الفحص يتم عند فتح العمل أو استئناف التطبيق فقط. لا يوجد بعد مزامنة Tracking خارجية. وبما أن جسر Mihon الحالي يعرض مصادر مانغا فقط، فإن All وManga يعرضان نفس المصادر حاليًا. لا يُدّعى بناء APK جديد لهذه المرحلة.

**الفحوص المتاحة:** ملفات ar/en/es/hi JSON سليمة ومتطابقة عند 2,317 مفتاحًا؛ `bash -n` ناجح؛ 51 هدف تنسيق موجودة؛ ملف GitHub Actions YAML سليم؛ وتأكدت بنية الرأس المثبت وسلسلة الأسماء البديلة. Flutter وDart وGradle وAndroid SDK غير متاحة في بيئة التحرير، لذلك لم يُنفّذ Analyze أو الاختبارات أو تجميع APK. يلزم CI جديد وفحص فعلي على الجهاز قبل الاعتماد. راجع [`PHASE63.2_STICKY_TABS_PERSISTENCE_NOTIFY_ALIAS_SOURCE_PICKER.md`](PHASE63.2_STICKY_TABS_PERSISTENCE_NOTIFY_ALIAS_SOURCE_PICKER.md).

## PHASE63.1 — ملخص التنفيذ (2026-11-13)

**PHASE63.1 — Zangetsu source discovery and chapter-catalogue parity:** بعد استلام صور الجهاز عقب نجاح بناء PHASE63، راجعت ملفات Zangetsu المرجعية قبل تعديل RAVEN23. أُعيد تنظيم ترويسة صفحة العمل لتسلسل Sliver مماثل: خلفية قابلة للطي، عنوان/بيانات، زر Continue كامل العرض، شريط المصدر، الملخص، بيانات العمل والإجراءات، ثم تبويبات ثابتة. أُضيف البحث التلقائي في مصادر Mihon عند فتح العمل غير المرتبط، مع قبول التطابق الكامل للعناوين/المرادفات فقط، وحفظ الربط لكل عمل وآخر مصدر ناجح، ومبدّل مصادر يتضمن Auto Resolve وWrong title? وتصحيح العنوان. قائمة الفصول تدعم List/Grid، الصور المصغرة مع fallback، التاريخ النسبي، التنزيل الفردي والجماعي All/Custom، إفراغ HTTP cache عند التحديث، عكس الترتيب، وتعليم الفصل أو الفصل وجميع ما قبله كمقروء. تم الحفاظ على Mihon والتنزيلات وتقدم القراءة والـOCR/الترجمة دون تغيير مسار الفيديو.

**PHASE63 — Zangetsu Manga Work & Reader Parity (المرحلة الأساسية):** بُنيت التعديلات فوق أرشيف PHASE62 المحفوظ، مع الحفاظ على Mihon وربط المصدر والفصول والتنزيلات وتقدم القراءة. صفحة العمل تتضمن أربعة تبويبات فقط (Chapters / Characters / Relations / Details)، ولا يوجد Sources tab أو Recommendations أو Volumes. أُعيد ترتيب بيانات Details، وأضيفت وسوم AniList مع إخفاء الحرق افتراضيًا، كما تم توحيد إجراءات My List / Share / Web وإضافة معاينة الملخص والانتقال إلى Details. القارئ يستخدم قائمة علوية عائمة وقائمة إجراءات وإعدادات موزعة على Translation / Reading / Display / Navigation / Comfort، وأسهم أسفل القارئ للفصل السابق/التالي والمنزلق للصفحات داخل الفصل. تم إعداد OCR محلي وترجمة Google عبر الإنترنت (النص المستخرج فقط) وترجمة ML Kit دون اتصال بعد موافقة المستخدم على تنزيل النماذج. أُحكم إلغاء العمليات غير المتزامنة بحيث يُلغى جيل الفصل السابق فور طلب الانتقال، مع منع نافذة إعداد الترجمة والنتائج القديمة من التأثير في الفصل الجديد.
Formatter gate: `tool/format_phase57_dart.sh` now explicitly includes the four new PHASE63 translation Dart files; the Android CI summary labels and formatter count were updated to 50 targets.

**تثبيت السلوك المرجعي:** كان وصف الأسهم في تقرير التعديل متناقضًا. المرجع الحاسم هو كود Zangetsu الفعلي في `lib/features/reader/manga_reader_screen.dart` داخل `_buildBottomBar`: السهمان للفصل السابق/التالي، والمنزلق لصفحات الفصل الحالي. هذا هو السلوك المعتمد في PHASE63.

**الحالة:** اجتازت الفحوص المتاحة هنا: تحليل بنية الملفات المعدّلة، `bash -n` لسكربت التنسيق، قراءة Workflow YAML، وجود أهداف التنسيق الخمسين، وصحة ملفات JSON الأربع مع تطابق مفاتيحها الـ2,281. لكن بيئة التحرير لا تحتوي Flutter أو Dart أو Gradle أو Android SDK؛ لذلك لم يُنفّذ `dart format` أو `flutter analyze` أو `flutter test` أو تجميع Kotlin/Gradle أو Release APK لهذه المرحلة. نجاحات البناء التي أكدها المالك حتى PHASE62 لا تُعد دليلًا على بناء PHASE63. توجد فجوات موثقة عن التطابق الكامل (إعدادات قارئ متقدمة، مزودو ترجمة متعددة، Notify/Tracking)، ويجب تشغيل CI وفحص الجهاز قبل اعتماد المرحلة. راجع [`RAVEN23-PHASE63-ZANGETSU-MANGA-WORK-READER-PARITY.md`](RAVEN23-PHASE63-ZANGETSU-MANGA-WORK-READER-PARITY.md).

## PHASE63.1 — Zangetsu source discovery and chapter-catalogue parity (2026-11-13)

- [`PHASE63.1_ZANGETSU_SOURCE_AND_CHAPTER_PARITY.md`](PHASE63.1_ZANGETSU_SOURCE_AND_CHAPTER_PARITY.md) — مراجعة مصدر Zangetsu أولًا، ثم إضافة البحث التلقائي الدقيق في مصادر Mihon، تثبيت المصدر المرتبط بالعمل، خيار Auto Resolve، مبدّل المصادر وتصحيح العنوان، وتطابق قائمة/شبكة الفصول والتنزيل الكلي/المخصص والتحديث وعكس الترتيب وتعليم القراءة.

**الحالة:** اجتازت فحوص JSON والترجمات الأربع (2,303 مفتاحًا متطابقًا) وصياغة سكربت التنسيق ووجود أهدافه الخمسين. لم تُشغّل أدوات Flutter/Dart/Gradle في بيئة التحرير؛ لذلك يلزم CI جديد وبناء ARM64 واختبار الجهاز قبل اعتماد PHASE63.1. بقي Notify وTracking وترتيب مصادر قابل للتخصيص فجوات موثقة.

## أحدث حالة تنفيذ سابقة — PHASE58 (2026-11-11)

**تأكيد المالك:** نجح بناء PHASE57.7 وعملت خاصية تثبيت إضافة Mihon على الجهاز. بعد ذلك أفاد المالك بأن صفحات Movies وSeries وAnime تغيرت عن التصميم الصحيح. قدّم المالك `RAVEN23-PHASE55(1).zip` كمرجع سليم وملزم لهذه الصفحات.

**PHASE58:** استعيد `lib/mobile/screens/home_screen.dart` من PHASE55(1) بايتًا ببايت؛ لذلك رجع Home/Movies/Series/Anime إلى المصدر الذي حدده المالك. عُزل دعم صور AniList المباشرة في callbacks اختيارية لا تمررها صفحات الفيديو؛ الافتراضيات في HeroCard/PosterCard/PosterRow/TopTenRow تحفظ مسار TMDB وسلوك التشغيل/قائمتي كما في PHASE55. Manga/Manhwa/Manhua تستعمل Hero/Header/Poster/TopTen/Loading/spacing components نفسها، مع إبقاء البحث وتفاصيل Mihon خاصة بالمحتوى. ترتيب الرفوف الـ18 مركزي ومختبر، وصفوف JP/KR/CN باقية في All.

**ما حُفظ:** إصلاح Mihon ABI 1.6 الذي أكد المالك نجاحه، والتحقق من بصمة المستودع، والتعامل مع لقطات المستودع الصريحة، وبوابة CI الناجحة في PHASE57.7. لم تتغير محركات الفيديو أو BetterPlayer أو مصادر الفيديو.

**حالة Phase58:** فحوص بنيوية ومقارنة المصدر اكتملتا، لكن Flutter/Dart/Gradle غير متوفرة في بيئة التحرير؛ لذلك لم يُشغّل Analyze أو الاختبارات أو APK هنا. يجب تشغيل GitHub Actions ثم فحص صفحات Movies/Series/Anime وManga على الجهاز قبل اعتماد المرحلة.

## سجل محاولة CI السابقة — PHASE57.7 (2026-11-11)


**تشخيص أحدث محاولة CI:** run `42943537695` على commit `91a2b6fac9fa2fd43a74b71f0743d0fbe709a043`. نجحت الاعتماديات والتنسيق والتحليل والاختبارات الخمسة لـFlutter (17/17)، كما نجحت مهمة Gradle `:app:testProdReleaseUnitTest` وظهرت حالات Mihon ABI الثلاث كلها `PASSED`. لم يصل CI إلى APK لأن مدقق PHASE57.6 نظّف وبحث عن تقارير JUnit تحت `android/app/build`، بينما `android/build.gradle` يوجّه مجلد المشروع الفرعي إلى `RAVEN23/build/app`. هذا خطأ مسار في CI، وليس فشلًا في اختبارات ABI.

**PHASE57.7:** تم تصحيح التنظيف والبحث ورفع ملفات JUnit إلى `build/app/...` الحقيقي، وإضافة تحقق احتياطي صارم من أحداث Gradle لكل حالة عند عدم إنشاء XML. لا يقبل الاحتياطي إلا `BUILD SUCCESSFUL` وثلاثة أحداث `PASSED` مطابقة للأسماء المتوقعة، مرة واحدة لكل حالة، مع رفض أي `FAILED` أو `SKIPPED` أو حالة غير متوقعة. لا تغيير في كود التطبيق أو إصدارات الأدوات أو مصادر الاختبارات.

**حالة الاعتماد وقت كتابة سجل CI:** لم ينتج run `42943537695` ملف APK لأن مدقق التقارير أوقف الخطوة. أكد المالك لاحقًا نجاح بناء PHASE57.7 وعمل تثبيت إضافة Mihon؛ هذا التأكيد اللاحق هو حالة المشروع المعتمدة، بينما يبقى run المذكور سجلًا تاريخيًا لفشل مسار التقارير.

## سجل الحالة السابقة — PHASE57.5 snapshot

**أحدث حالة تنفيذ (2026-11-11) — Phase57.5:** فشلت محاولة CI `42927816064` عند `flutter pub get` قبل التنسيق والتحليل والاختبارات، لأن `flutter_native_splash 2.4.8` يتطلب `meta ^1.18.0` بينما Flutter 3.35.7 يثبت `meta 1.16.0` ضمن `flutter_test`. لا توجد اختبارات فاشلة في هذه المحاولة؛ لم يبدأ أي اختبار. عالجت Phase57.5 السبب بإبقاء مولّد شاشة البداية خارج اعتماديات التطبيق، مع الاحتفاظ بملف الإعداد المستقل والموارد المولّدة مسبقًا. لا تغيير في Flutter SDK أو بقية toolchain.

**سياسة البناء الروتيني الجديدة:** الاعتماديات → تنسيق 23 ملف Dart محددًا → `flutter analyze` كامل المشروع → خمسة ملفات Flutter حرجة لـManga/Mihon فقط → Gradle Wrapper → فئة Kotlin واحدة `MihonExtensionLoaderAbiTest` (3 حالات) → APK → تدقيق APK. لا تبدأ أي بوابة لاحقة إلا بعد نجاح سابقتها. اختبارات Flutter الـ254 الأخرى وملفات Android التسعة الأخرى واختبارات Laravel الحية تبقى محفوظة في المستودع، لكنها خارج بوابة APK الروتينية لاختبارها يدويًا بعد تثبيت التطبيق أو ضمن تشغيل regression موسّع منفصل. لم يُحذف أو يُعطّل أي ملف اختبار.

**Phase57.5 مجهزة لكن غير معتمدة:** أُزيل مولّد splash من اعتماديات التطبيق بعد تعارض `meta`، مع إبقاء Flutter 3.35.7 والموارد الأصلية وبوابة الاختبارات المركزة. لم تتوفر Flutter/Dart/Gradle في بيئة تحرير الأرشيف؛ يلزم CI جديد لإثبات نجاح `pub get` ثم التنسيق والتحليل والاختبارات المركزة وبناء APK ARM64 وتدقيقه، ثم تحقق الجهاز من تثبيت Team X وواجهات Manga.

**ملاحظة قراءة مهمة:** حالات `CI Pending` الموجودة داخل تقارير المراحل 36–50 تصف حالة كل مرحلة وقت كتابتها. أُغلقت بوابة التكامل والبناء لهذه الأعمال ضمن Phase51 الناجحة، ثم أكد المالك نجاح جميع عمليات البناء اللاحقة حتى Phase56. تبقى اختبارات المزودين الفعلية وتجارب الجهاز مستقلة، ولا تعني موافقة البناء أن كل مزود أو إضافة تم اختباره ميدانيًا.

- **Build milestone through PHASE57.7:** أكد مالك المشروع صراحةً نجاح بناء PHASE57.7 وعمل تثبيت إضافة Mihon على الجهاز. هذا أحدث قبول بناء/تشغيل مؤكد قبل Phase58. هذا هو الوضع المعتمد حاليًا، ويتجاوز سجلات محاولات CI القديمة التي كانت تشير إلى فشل وسيط. لا تُعرض تلك السجلات بوصفها أخطاء نشطة.
- Phase51 اجتازت بوابة Release في GitHub Actions run `42507906881`: Analyze وDart Format و302 اختبارًا وKotlin/Gradle و`assembleProdRelease` وAPK Audit. الناتج الموثق كان `4.3.0+10` بحجم 28,111,482 bytes وABI `arm64-v8a` فقط.
- Phase52 مقبولة بتأكيد المالك: قوائم الأولوية المستقلة Movies 13 / Series 9 / Anime 11، وحد أقصى 15 مصدرًا نشطًا تلقائيًا لكل مستودع. لا تُعاد اختبارات Phase52 في بوابات المراحل اللاحقة.
- Phase53 مقبولة بتأكيد المالك: تحديث التنقل، أقسام Anime، كتالوج AniList، وفهرس Keiyoushi Protobuf المنفصل عن مستودعات الفيديو الستة.
- Phase54 وPhase55 اجتازتا البناء وفق تأكيد المالك. Phase56 عالجت قراءة بصمة `repo.json` ودمج الكتالوج الإقليمي وأضافت عناصر Home المشتركة، ثم أكد المالك نجاح بناء Phase56. كشف اختبار التثبيت الفعلي بعد ذلك رفض إصدار ABI 1.6 بسبب توسيع Float إلى Double، كما طلب المالك مطابقة Manga/Manhwa لتصميم Home حرفيًا باستخدام مكونات Home المشتركة بدل تخطيط Manga مستقل. هذه عيوب تشغيل/اتساق واجهة وليست إخفاقات بناء؛ وهي نطاق Phase57.
- Phase56: Build passed by owner confirmation. تُحفظ قراءة sidecar كنص JSON مع شرط SHA-256 الصارم، وتجميع JP/KR/CN المستقل، وعزل فشل المناطق، وبيانات Hero/Top 10 وHomeSkeleton. بقي رفض ABI 1.6 الظاهر بعد الضغط على Install وملاحظة اختلاف تخطيط Manga، وهما مدخلات Phase57.
- لا يعني نجاح البناء أو ظهور فهرس Protobuf أن كل إضافة Mihon ثبتت أو عملت بنجاح. يجب الحفاظ على التحقق من توقيع APK واسم الحزمة وحدود ABI وعدم التفعيل التلقائي.


## الوثائق الرئيسية

1. [`MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md`](MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md) — الخطة الرئيسية والتبعيات والمواصفات ومعايير القبول للمراحل 36–51.
2. [`MASTER_SOURCE_CATALOG_AND_VALIDATION_MATRIX.md`](MASTER_SOURCE_CATALOG_AND_VALIDATION_MATRIX.md) — قائمة المستودعات الستة ومصادر الأفلام والمسلسلات والأنمي وLive TV وحالات التحقق.
3. [`IMPLEMENTATION_TRACKER_PHASE36_58.md`](IMPLEMENTATION_TRACKER_PHASE36_58.md) — المتتبع الحالي للمراحل وسجل القرارات وآخر نطاق عمل. الملف Phase36_57 محفوظ كسجل تاريخي.
4. [`PHASE36_INITIAL_BASELINE_AUDIT.md`](PHASE36_INITIAL_BASELINE_AUDIT.md) — خط أساس أولي مستند إلى قراءة كود أرشيف Phase 35.1.
5. [`PHASE37_UNIFIED_SOURCE_ARCHITECTURE_IMPLEMENTATION.md`](PHASE37_UNIFIED_SOURCE_ARCHITECTURE_IMPLEMENTATION.md) — تفاصيل عقود Phase 37 والملفات والاختبارات وحالة التحقق.
6. [`PHASE37.1_BUNDLED_REPOSITORIES.md`](PHASE37.1_BUNDLED_REPOSITORIES.md) — المستودعات المضمّنة الستة، وترحيل التثبيتات الحالية، وزر الاستعادة والاختبارات.


## Phase 53 outputs

- [`PHASE53_ZANGETSU_NAVIGATION_AND_MANGA_INTEGRATION.md`](PHASE53_ZANGETSU_NAVIGATION_AND_MANGA_INTEGRATION.md) — مراجعة Zangetsu، حركة شريط التنقل، ترتيبات القائمتين، صفحات Manga/Anime، مزود AniList، مستودع Keiyoushi، الاختبارات والقيود.

**الحالة:** Accepted — أكد مالك المشروع نجاح بناء Release وعمل وظائف Phase53 بشكل صحيح في 2026-11-09. لا تُعاد اختبارات Phase52 أو تُفعّل كبوابة لاحقة. تم تجاوز حد Phase53 الخاص بغياب محرك Mihon لاحقًا بتنفيذ Phase55؛ راجع وثيقة Phase55.

## Phase 54 outputs

- [`PHASE54_MANGA_CATALOGUE_AND_REPOSITORY_MANAGEMENT.md`](PHASE54_MANGA_CATALOGUE_AND_REPOSITORY_MANAGEMENT.md) — مطابقة كتالوج Manga/Manhwa/Manhua لتصميم Home، وخلط البنر الرائج، وحصر إدارة مستودعات Mihon Protobuf داخل Sources.

**الحالة:** Build accepted by owner confirmation through PHASE56. Remaining runtime and visual-parity findings are assigned to PHASE57; build acceptance remains separate from device acceptance.

## Phase 55 — Manga catalogue and Mihon-compatible runtime

- [`PHASE55_MANGA_CATALOGUE_AND_MIHON_RUNTIME.md`](PHASE55_MANGA_CATALOGUE_AND_MIHON_RUNTIME.md) — Mihon-compatible Android runtime, DEX loading boundary, repository fingerprint trust, Manga reader and source browser.

**الحالة:** All build operations through PHASE56 are owner-confirmed successful. Later device findings are captured under PHASE57; do not treat superseded intermediate CI failures as current blockers.

## Phase 56 — Manga runtime, catalogue reliability and extension trust

- [`PHASE56_MANGA_RUNTIME_CATALOGUE_AND_EXTENSION_TRUST_FIX.md`](PHASE56_MANGA_RUNTIME_CATALOGUE_AND_EXTENSION_TRUST_FIX.md) — raw-text `repo.json` parsing, independent JP/KR/CN aggregation, per-category hero/Top 10, and Home-style loading skeleton.

**الحالة:** Build passed by owner confirmation. Device testing then identified the Float representation issue for ABI 1.6 and requested exact visual parity with Home; these are assigned to Phase57.


## Phase 57 — Manga Home parity and Mihon ABI normalization

- [`PHASE57_MANGA_HOME_PARITY_AND_EXTENSION_ABI_FIX.md`](PHASE57_MANGA_HOME_PARITY_AND_EXTENSION_ABI_FIX.md) — canonicalizes Android Float metadata for the existing Mihon ABI allow-list, reuses the shared Home feed components for Manga/Manhwa/Manhua, and preserves every catalogue shelf.
- [`PHASE57.1_CI_FULL_REGRESSION_GATE_REPAIR.md`](PHASE57.1_CI_FULL_REGRESSION_GATE_REPAIR.md) — resolves the two analyzer errors from run `42857526541` and establishes discovery of the active Flutter/Android test suites.
- [`PHASE57.2_FULL_REGRESSION_FAILURE_RECOVERY.md`](PHASE57.2_FULL_REGRESSION_FAILURE_RECOVERY.md) — diagnoses all 21 failures from run `42888346400`, repairs production/test root causes and generated translations, and runs independent diagnostics while retaining a strict APK gate.
- [`PHASE57.3_MINIMAL_PREBUILD_GATE_AND_NATIVE_SPLASH_FIX.md`](PHASE57.3_MINIMAL_PREBUILD_GATE_AND_NATIVE_SPLASH_FIX.md) — diagnoses run `42913766313`, upgrades `flutter_native_splash` to 2.4.8 to remove the stale Android plugin registration, and narrows routine APK CI to five focused Flutter test files plus one three-case Android ABI test while preserving all other tests for manual/deeper QA.

**الحالة:** Phase57.3 prepared a minimal sequential pre-build gate after run `42913766313`; the updated dependency resolution, five focused Flutter files, one Android ABI class, ARM64 Release APK and device verification remain pending. All other test files are preserved outside routine APK CI.

## Phase 50 outputs

- [`PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_PLAN.md`](PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_PLAN.md) — النطاق ومعيار الفصل بين direct stream وembedded HTML.
- [`PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_AUDIT.md`](PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_AUDIT.md) — تدقيق محرك WebView والـQuickJS والـLegacy Player gaps.
- [`PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_IMPLEMENTATION.md`](PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_IMPLEMENTATION.md) — النتيجة المستقلة وشاشة Android WebView وسياسة التنقل والتخلص من الجلسة.
- [`PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_TESTS.md`](PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_TESTS.md) — الاختبارات المركزة وبوابة CI ذات 29 ملفًا وحدود التحقق.
- [`PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_CHANGELOG.md`](PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_CHANGELOG.md) — الملفات المضافة والمعدلة وتوافق `resolveUrl`.
- [`PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_REPORT.md`](PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_REPORT.md) — تقرير التنفيذ والقيود والمرحلة التالية.

**الحالة النهائية بعد Phase51:** اجتازت تكامل Release والبناء ضمن run `42507906881`؛ أما تشغيل مزودي WebView الفعلي والتحقق من أجهزة Mobile/TV فيبقيان منفصلين عن بوابة البناء. حالة CI المعلقة المذكورة داخل تقرير Phase50 كانت تاريخية وقت إعداد التقرير.

## Phase 49 outputs

- [`PHASE49_XMLTV_EPG_PLAN.md`](PHASE49_XMLTV_EPG_PLAN.md) — النطاق والحدود ومعايير القبول المأخوذة من الخطة الرئيسية.
- [`PHASE49_XMLTV_EPG_AUDIT.md`](PHASE49_XMLTV_EPG_AUDIT.md) — فجوات M3U/Channel/EPG وعقود التوافق مع DaddyLive.
- [`PHASE49_XMLTV_EPG_IMPLEMENTATION.md`](PHASE49_XMLTV_EPG_IMPLEMENTATION.md) — XMLTV parser/repository/mapper وربط `tvg-id` مع M3U وشاشة الدليل الحالية.
- [`PHASE49_XMLTV_EPG_TESTS.md`](PHASE49_XMLTV_EPG_TESTS.md) — fixtures parser/cache/M3U وبوابة CI المحددة ذات 28 ملفاً.
- [`PHASE49_XMLTV_EPG_CHANGELOG.md`](PHASE49_XMLTV_EPG_CHANGELOG.md) — الملفات المضافة والمعدلة والتوافق.
- [`PHASE49_XMLTV_EPG_REPORT.md`](PHASE49_XMLTV_EPG_REPORT.md) — الحالة وحدود التحقق والمرحلة التالية.

**الحالة النهائية بعد Phase51:** اجتازت عقود Phase49 ضمن بوابة التكامل الناجحة `42507906881`؛ تدفقات EPG الحية وعرضها على الجهاز يظلان تحققًا تشغيليًا منفصلًا. حالة CI المعلقة كانت تاريخية وقت إعداد تقرير Phase49.

## Phase 48 outputs

- [`PHASE48_PLUTO_TV_LIVE_ADAPTER_PLAN.md`](PHASE48_PLUTO_TV_LIVE_ADAPTER_PLAN.md) — نطاق Phase48 ومسار التكامل المصرّح ومعيار Experimental fallback.
- [`PHASE48_PLUTO_TV_LIVE_ADAPTER_AUDIT.md`](PHASE48_PLUTO_TV_LIVE_ADAPTER_AUDIT.md) — تدقيق فهرس Spyhell وغياب السكربت وعقود API/المنصة الرسمية.
- [`PHASE48_PLUTO_TV_LIVE_ADAPTER_IMPLEMENTATION.md`](PHASE48_PLUTO_TV_LIVE_ADAPTER_IMPLEMENTATION.md) — تسجيل الخدمة التجريبية وحالة Unavailable والإحالة الخارجية.
- [`PHASE48_PLUTO_TV_LIVE_ADAPTER_TESTS.md`](PHASE48_PLUTO_TV_LIVE_ADAPTER_TESTS.md) — اختبارات عدم اختلاق البيانات وعزل namespace وبوابة CI.
- [`PHASE48_PLUTO_TV_LIVE_ADAPTER_CHANGELOG.md`](PHASE48_PLUTO_TV_LIVE_ADAPTER_CHANGELOG.md) — الملفات المضافة والمعدلة والمحافظة على التوافق.
- [`PHASE48_PLUTO_TV_LIVE_ADAPTER_REPORT.md`](PHASE48_PLUTO_TV_LIVE_ADAPTER_REPORT.md) — النتيجة وحدود التحقق والمرحلة التالية.

**الحالة النهائية بعد Phase51:** اجتازت بوابة تكامل Release ضمن run `42507906881`. يظل Pluto TV مصنفًا `Experimental / Unavailable` لعدم وجود عقد API حي مصرح؛ نجاح البناء لا يضيف قنوات أو روابط بث ولا يثبت التشغيل.

## Phase 47 outputs

- [`PHASE47_IPTV_M3U_SPYHELL_PLAN.md`](PHASE47_IPTV_M3U_SPYHELL_PLAN.md) — نطاق التنفيذ وحدوده ومعايير القبول المأخوذة من الـBlueprint.
- [`PHASE47_IPTV_M3U_SPYHELL_AUDIT.md`](PHASE47_IPTV_M3U_SPYHELL_AUDIT.md) — البنية الحالية والفجوات والاعتماد على Phase46.
- [`PHASE47_IPTV_M3U_SPYHELL_IMPLEMENTATION.md`](PHASE47_IPTV_M3U_SPYHELL_IMPLEMENTATION.md) — parser والتخزين والخدمات والربط بين Mobile/TV/LivePlayer.
- [`PHASE47_IPTV_M3U_SPYHELL_TESTS.md`](PHASE47_IPTV_M3U_SPYHELL_TESTS.md) — حالات الاختبار وبوابة CI ذات 25 ملفًا وحدود التحقق.
- [`PHASE47_IPTV_M3U_SPYHELL_CHANGELOG.md`](PHASE47_IPTV_M3U_SPYHELL_CHANGELOG.md) — الملفات المضافة والمعدلة وحدود التراجع.
- [`PHASE47_IPTV_M3U_SPYHELL_REPORT.md`](PHASE47_IPTV_M3U_SPYHELL_REPORT.md) — حالة التنفيذ ومعايير القبول المفتوحة.

**الحالة النهائية بعد Phase51:** اجتازت أعمال M3U/Live TV ضمن بوابة التكامل وRelease في run `42507906881`. صلاحية قوائم IPTV الخارجية وتوافر القنوات وتشغيلها على الجهاز تظل تحققًا منفصلًا.

## Phase 46 outputs

- [`PHASE46_LIVE_TV_SERVICE_MANAGER_PLAN.md`](PHASE46_LIVE_TV_SERVICE_MANAGER_PLAN.md) — النطاق والعقود ومعايير القبول من الـBlueprint.
- [`PHASE46_LIVE_TV_SERVICE_MANAGER_AUDIT.md`](PHASE46_LIVE_TV_SERVICE_MANAGER_AUDIT.md) — سبب تعطيل EthioSports والفجوات في إدارة المزودين والتخزين.
- [`PHASE46_LIVE_TV_SERVICE_MANAGER_IMPLEMENTATION.md`](PHASE46_LIVE_TV_SERVICE_MANAGER_IMPLEMENTATION.md) — المدير الموحد، التسجيل المركزي، دورة الحياة، التحقق من stream metadata، والربط بين Mobile/TV/LivePlayer.
- [`PHASE46_LIVE_TV_SERVICE_MANAGER_TESTS.md`](PHASE46_LIVE_TV_SERVICE_MANAGER_TESTS.md) — الاختبارات المحددة وبوابة CI ذات 21 ملفًا.
- [`PHASE46_LIVE_TV_SERVICE_MANAGER_CHANGELOG.md`](PHASE46_LIVE_TV_SERVICE_MANAGER_CHANGELOG.md) — الملفات المعدلة والمضافة والتوافق.
- [`PHASE46_LIVE_TV_SERVICE_MANAGER_REPORT.md`](PHASE46_LIVE_TV_SERVICE_MANAGER_REPORT.md) — حالة التنفيذ وحدود التحقق.

**الحالة النهائية بعد Phase51:** اجتازت عقود Phase46–50 المتكاملة بوابة Phase51 في run `42507906881`، بما يشمل Analyze والاختبارات المختارة وRelease ARM64. بقي التحقق من مزودي Live TV وEPG وWebView على الجهاز وتوافر الخدمات الخارجية منفصلًا. كانت بوابة 21/28 ملفًا ووسم `CI Pending` حالات تاريخية عند كتابة تلك التقارير.

## Phase 43 outputs

- [`PHASE43_OPENSTREAM_SOURCES_PLAN.md`](PHASE43_OPENSTREAM_SOURCES_PLAN.md) — نطاق الدمج واعتماديات المرحلة ومعايير القبول.
- [`PHASE43_OPENSTREAM_SOURCES_AUDIT.md`](PHASE43_OPENSTREAM_SOURCES_AUDIT.md) — جرد live index والاختلافات وحالات Beta والقيود.
- [`PHASE43_OPENSTREAM_SOURCES_IMPLEMENTATION.md`](PHASE43_OPENSTREAM_SOURCES_IMPLEMENTATION.md) — عقود التشغيل ومسارات التوجيه وتمرير expiry.
- [`PHASE43_OPENSTREAM_SOURCES_TESTS.md`](PHASE43_OPENSTREAM_SOURCES_TESTS.md) — قائمة CI المحددة (15 ملفاً) والاختبارات الحتمية الجديدة.
- [`PHASE43_OPENSTREAM_SOURCES_CHANGELOG.md`](PHASE43_OPENSTREAM_SOURCES_CHANGELOG.md) — ملفات التغيير.
- [`PHASE43_OPENSTREAM_SOURCES_REPORT.md`](PHASE43_OPENSTREAM_SOURCES_REPORT.md) — حالة التنفيذ وحدود التحقق.

**الحالة التاريخية عند إعداد Phase43:** كان اعتماد CI للمراحل 41–43 pending آنذاك. تم تجاوز هذا الوضع لاحقاً بواسطة بوابة CI المشتركة الناجحة في run `42428688859`؛ انظر أحدث حالة التنفيذ أعلى هذا الملف وسجل Tracker.

## Phase 42 outputs

- [`PHASE42_REPOSITORY_VERSIONING_SECURITY_PLAN.md`](PHASE42_REPOSITORY_VERSIONING_SECURITY_PLAN.md) — الهدف والحدود ومعايير القبول.
- [`PHASE42_REPOSITORY_VERSIONING_SECURITY_AUDIT.md`](PHASE42_REPOSITORY_VERSIONING_SECURITY_AUDIT.md) — تدقيق الفجوات والمخاطر المتبقية.
- [`PHASE42_REPOSITORY_VERSIONING_SECURITY_IMPLEMENTATION.md`](PHASE42_REPOSITORY_VERSIONING_SECURITY_IMPLEMENTATION.md) — ملفات التنفيذ وسلوك الإصدار والمعاينة والأمان.
- [`PHASE42_REPOSITORY_VERSIONING_SECURITY_TESTS.md`](PHASE42_REPOSITORY_VERSIONING_SECURITY_TESTS.md) — بوابة CI ذات الملفات العشرة والتغطية الحرجة.
- [`PHASE42_REPOSITORY_VERSIONING_SECURITY_CHANGELOG.md`](PHASE42_REPOSITORY_VERSIONING_SECURITY_CHANGELOG.md) — قائمة الإضافات والتعديلات وخط التراجع.
- [`PHASE42_REPOSITORY_VERSIONING_SECURITY_REPORT.md`](PHASE42_REPOSITORY_VERSIONING_SECURITY_REPORT.md) — حالة التنفيذ وحدود التحقق ومعايير الإغلاق.

**الحالة التاريخية عند إعداد Phase42:** كانت بوابة CI pending آنذاك. اجتازت عقود Phase42 المحددة لاحقاً ضمن البوابة المشتركة الناجحة في run `42428688859`؛ التحقق من WebView على جهاز فعلي يظل منفصلاً.

## Phase 41 outputs

- [`PHASE41_VIDKING_LANGUAGE_QUALITY_PLAN.md`](PHASE41_VIDKING_LANGUAGE_QUALITY_PLAN.md) — نطاق Phase41 وفصل لغة الصوت عن جودة الفيديو.
- [`PHASE41_VIDKING_LANGUAGE_QUALITY_AUDIT.md`](PHASE41_VIDKING_LANGUAGE_QUALITY_AUDIT.md) — تدقيق حقول اللغة والجودة وبيانات OpenStream legacy.
- [`PHASE41_VIDKING_LANGUAGE_QUALITY_IMPLEMENTATION.md`](PHASE41_VIDKING_LANGUAGE_QUALITY_IMPLEMENTATION.md) — عقود التنفيذ وتمرير تفضيل اللغة والتوافق.
- [`PHASE41_VIDKING_LANGUAGE_QUALITY_TESTS.md`](PHASE41_VIDKING_LANGUAGE_QUALITY_TESTS.md) — ملفات الاختبارات المطلوبة وحدود CI.
- [`PHASE41_VIDKING_LANGUAGE_QUALITY_CHANGELOG.md`](PHASE41_VIDKING_LANGUAGE_QUALITY_CHANGELOG.md) — ملفات التغيير وخط التراجع.
- [`PHASE41_VIDKING_LANGUAGE_QUALITY_REPORT.md`](PHASE41_VIDKING_LANGUAGE_QUALITY_REPORT.md) — حالة التنفيذ والاعتماد المعلق.


## قاعدة الاستخدام

- اقرأ الـBlueprint قبل تنفيذ أي Phase من 36 إلى 51.
- اقرأ Phase 36 Initial Baseline Audit كبداية فقط؛ لا يعتبر إغلاقاً للتدقيق الحي للمستودعات.
- حدّث Tracker عند بدء/إغلاق المرحلة، ولا تضع `Passed` قبل اجتياز بوابة القبول.
- أبقِ هذه الملفات داخل `phases/` في كل أرشيف مشروع لاحق.
- أي قرار أحدث في تقرير Phase سابق/لاحق قد يغيّر خطة التنفيذ يجب أن يُراجع ويوثق كتعديل للـBlueprint قبل تعديل الملفات الوظيفية.

**مهم:** ملفات الخطة لا تنفذ تغييرات على كود التطبيق، ولا تثبت عمل أي مصدر خارجي.


## Phase 36 audit outputs

- `PHASE36_AUDIT_REPORT.md` — detailed findings, evidence scope, build baseline and Phase 37 readiness.
- `SOURCE_REPOSITORY_SNAPSHOT.json` — normalized metadata for all six live indexes, counts, samples and explicit missing hashes/status codes.
- `SOURCE_COMPATIBILITY_MATRIX.md` — compatibility assessment separating index claims, static inspection, runtime and playback verification.
- `PHASE36_CANDIDATE_FILES_AND_GAPS.md` — code file boundaries, existing tests and no-touch rules for later phases.

Phase 36 made documentation-only changes. A successful baseline Release CI run was observed before Phase 37 edits. Phase 37 has a user-supplied successful Release build, while format/analyze/test remain pending. Phase 37.1 preloads the six default repositories with additive migration; its post-change CI and device verification remain pending. The pre-change baseline Release run is recorded in the Phase 37 implementation report and the Phase 36 audit addendum.

## Phase 37 outputs

- `PHASE37_UNIFIED_SOURCE_ARCHITECTURE_IMPLEMENTATION.md` — implementation record, compatibility guarantees, baseline CI result and pending validation.

## Phase 37.1 outputs

- `PHASE37.1_BUNDLED_REPOSITORIES.md` — root cause, exact bundled URLs, migration behavior, changed files, tests and acceptance gates.

7. [`PHASE37_37.1_CONTINUATION_VALIDATION_AUDIT.md`](PHASE37_37.1_CONTINUATION_VALIDATION_AUDIT.md) — continuation audit, authoritative next step, CI validation gates and pending acceptance evidence.
8. [`PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_PLAN.md`](PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_PLAN.md) — Phase 38 scope and exact matching contract.
9. [`PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_AUDIT.md`](PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_AUDIT.md) — current identity/engine gap audit.
10. [`PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_IMPLEMENTATION.md`](PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_IMPLEMENTATION.md) — implementation decisions and changed files.
11. [`PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_TESTS.md`](PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_TESTS.md) — fixtures, tests and actual execution limits.
12. [`PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_CHANGELOG.md`](PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_CHANGELOG.md) — additions, modifications and rollback list.
13. [`PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_REPORT.md`](PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_REPORT.md) — acceptance status and blockers.


## Phase 40 CI recovery outputs

- `PHASE40_CI_WIDGET_REGRESSION_RECOVERY_FOLLOWUP_2026-11-07.md` — latest CI run `42341398241`, exact four widget-test failures, test-only corrections, preservation boundary, and remaining CI/Release acceptance gates.
- `PHASE40_CI_WIDGET_REGRESSION_RECOVERY_FOLLOWUP_2_2026-11-07.md` — newer CI run `42375238484`; records why the previous fixes still failed (zero-delay timer scheduling, unbuilt lazy Sliver targets, and stale owned FocusNode diagnostics), the second recovery patch, and the required full-suite/Release validation.

## Phase 38 status

Historical Phase38 snapshot: implementation and deterministic test cases were drafted while Phase37/37.1 post-change validation was still pending. The shared contracts were subsequently included in the successful Phase51 integration/Release gate `42507906881`, as recorded in the current Tracker. This closes the integrated build gate, not every external provider/device check. See the six Phase38 documents and the current Tracker.


## Phase 39 — QuickJS Extension Settings System

Implementation files: `PHASE39_QUICKJS_SETTINGS_SYSTEM_PLAN.md`, `PHASE39_QUICKJS_SETTINGS_SYSTEM_AUDIT.md`, `PHASE39_QUICKJS_SETTINGS_SYSTEM_IMPLEMENTATION.md`, `PHASE39_QUICKJS_SETTINGS_SYSTEM_TESTS.md`, `PHASE39_QUICKJS_SETTINGS_SYSTEM_CHANGELOG.md`, and `PHASE39_QUICKJS_SETTINGS_SYSTEM_REPORT.md`. The CI-pending label in this phase snapshot is historical; the Phase39 contracts were subsequently included in the successful Phase51 integration/Release gate `42507906881`. Next planned phase at that Phase39 snapshot: 40 — Stremio Manifest & Configuration Engine.


## Phase 40 — Stremio Manifest & Configuration Engine

Implementation files: `PHASE40_STREMIO_MANIFEST_CONFIGURATION_PLAN.md`, `PHASE40_STREMIO_MANIFEST_CONFIGURATION_AUDIT.md`, `PHASE40_STREMIO_MANIFEST_CONFIGURATION_IMPLEMENTATION.md`, `PHASE40_STREMIO_MANIFEST_CONFIGURATION_TESTS.md`, `PHASE40_STREMIO_MANIFEST_CONFIGURATION_CHANGELOG.md`, and `PHASE40_STREMIO_MANIFEST_CONFIGURATION_REPORT.md`. The parser/provider/UI changes and deterministic tests are included; Dart/Flutter CI and live playback acceptance remain pending. This earlier statement reflects the original blueprint before the user's 2026-11-07 instruction to proceed with Phase42; see the current Phase42 status section.


### Historical Phase 40 regression run — 2026-11-07 (superseded by later successful CI)

Historical CI run `42375238484` passed dependency resolution, formatter, `flutter analyze` and 160 focused source tests, then failed the separate widget regression group with 160 passed / 4 failed. The test lifecycle/finders were corrected in subsequent follow-ups. This intermediate run was superseded by the successful Phase51 integration/Release gate `42507906881`; the old failure is not a current build blocker. Live widget/provider behaviour remains a separate device-level check. See `PHASE40_CI_WIDGET_REGRESSION_RECOVERY_FOLLOWUP_2_2026-11-07.md`.

### Historical Phase 40 CI follow-up — 2026-11-07 (superseded by later successful CI)

Historical CI passed `flutter analyze` and then reported 138 focused tests passed / 7 failed. The local follow-up removed empty URI fragments from derived Stremio URLs and rejects malformed manifest-shaped JSON missing `resources`. These changes were subsequently included in the successful Phase51 integration/Release gate `42507906881`; the old rerun request is not active. See `PHASE40_CI_STREMIO_TEST_RECOVERY.md`.


Historical Phase40 follow-up: the 140-pass/5-fail test run exposed an empty query delimiter in `/configure` URLs. The URL construction was corrected, and the integrated Phase51 Release gate `42507906881` subsequently passed. This old intermediate result is retained for audit history only; it is not an active Phase40 build blocker. See `PHASE40_CI_STREMIO_TEST_RECOVERY.md`.


## Phase 40 CI build diagnostics

- `PHASE40_CI_COMPREHENSIVE_BUILD_REPORTING.md` — describes the per-run Markdown build report, command logs, warning/error extraction, APK diagnostics and always-uploaded CI artifact. Actual report contents are generated by GitHub Actions for each run.


### Latest Phase 40 full-suite CI analysis — 2026-11-07

Historical full-suite run `42328559177` passed dependency resolution, Dart format, Flutter analyze and the 147-test focused architecture/Stremio suite, then failed a broader test batch (2,143 passed, 34 failed and 11 skipped). These intermediate failures and their follow-up corrections were later superseded for the integrated build by the successful Phase51 run `42507906881`. The broader full suite is not the active APK CI gate; external provider/device checks remain separate. See `PHASE40_CI_FULL_TEST_SUITE_FAILURE_ANALYSIS.md` for the historical diagnostic record.


### Phase 40 — Full-suite widget/settings recovery — 2026-11-07

The latest supplied CI run (`42331596314`) passed format, analyze and focused tests but failed the full suite (2,155 passed / 23 failed / 11 skipped) before Gradle or APK build. Follow-up fixes for all 23 test failures are prepared, including visibility-test timer control, serialization, OneSignal, OpenSubtitles, media container/quality mapping, seasonal selection and lazy-list widget test corrections. CI rerun is still required; see `PHASE40_CI_FULL_SUITE_WIDGET_SETTINGS_RECOVERY_2026-11-07.md`.


### Phase 40 — Phase 35.1 baseline/design-preservation audit — 2026-11-07

`PHASE40_PHASE35.1_BASELINE_RECONCILIATION.md` compares Phase 35.1 files against the current Phase 40 project, identifies unchanged core screens, restores selected palette/reveal/quality-label behavior to the reference, distinguishes mismatched CI report artifacts, and records the remaining strict validation gates. No broad UI redesign or screen replacement was performed.

### Phase 40 — Minimal automatic APK CI gate — 2026-11-07

The last user-supplied analyzer excerpt identified a redundant `flutter/widgets.dart` import in `test/support/scroll_until_built.dart`; it was removed. The automatic APK workflow was narrowed to four Stremio Manifest/Configuration tests, avoiding unrelated broad batches. That historical workflow design and its pending label were later superseded by the successful Phase51 integrated Release gate `42507906881`. The targeted suite remains intentionally narrow for routine APK CI; broader test files remain available for explicit/manual QA. See `PHASE40_CI_MINIMAL_GATE_2026-11-07.md`.

## Phase 40 acceptance and Phase 41 in progress — 2026-11-07

Phase 40 automatic CI gate passed in run `42384394976` (Analyze clean; 44 Phase 40 tests passed; Release ARM64 APK 26.64 MiB). This is not a live playback claim and does not close all pending prior dependency/device validations.

Phase 41 implementation is now prepared: independent VidKing audio-language and resolution fields, controlled legacy migration for Vyse/Fade/Killjoy, a separately persisted VidKing audio preference exposed on Mobile/TV Player Settings and wired through ProviderLoader, and a 12-file targeted test gate. CI/Release verification is pending. See the six `PHASE41_VIDKING_LANGUAGE_QUALITY_*.md` documents above.


## Phase 44–45 combined CI recovery — 2026-11-08

The first combined Phase44/45 upload (`42422826322`) stopped during `flutter analyze` before reaching the contract tests or Android build. The subsequent corrections were later covered by the successful Phase51 integration/Release gate `42507906881`, so Phase44/45 build integration is accepted. Actual external source execution remains separate. `codegen_loader.g.dart` remains excluded from the formatter target list to avoid a non-functional formatter diff. See `PHASE44_45_CI_ANALYZE_RECOVERY_2026-11-08.md` for the historical repair record.


## Phase51 acceptance and superseded CI history

Phase51 was accepted by the successful integration/Release gate in run `42507906881` (Analyze, format, 302 tests, Gradle/Kotlin, ARM64 Release and APK audit). Intermediate failure attempts before that run were superseded and their individual failure-note files were removed from the active phase folder to avoid presenting resolved history as current blockers. No Phase51 failure is currently open.


## Phase 52 outputs

- [`PHASE52_SOURCE_REPOSITORY_PRIORITY_PLAN.md`](PHASE52_SOURCE_REPOSITORY_PRIORITY_PLAN.md) — الهدف ونظام الأولويات وحدود التفعيل والبحث الاحتياطي.
- [`PHASE52_SOURCE_REPOSITORY_PRIORITY_AUDIT.md`](PHASE52_SOURCE_REPOSITORY_PRIORITY_AUDIT.md) — تدقيق الفهارس الستة وقرارات الإدراج والاستبعاد.
- [`PHASE52_SOURCE_REPOSITORY_PRIORITY_IMPLEMENTATION.md`](PHASE52_SOURCE_REPOSITORY_PRIORITY_IMPLEMENTATION.md) — مدير الأولويات والسياسة ومحرك المراحل والواجهة.
- [`PHASE52_SOURCE_REPOSITORY_PRIORITY_TESTS.md`](PHASE52_SOURCE_REPOSITORY_PRIORITY_TESTS.md) — الاختبارات وبوابة CI ذات 40 ملفًا وقائمة التنسيق ذات 94 هدفًا.
- [`PHASE52_SOURCE_REPOSITORY_PRIORITY_CHANGELOG.md`](PHASE52_SOURCE_REPOSITORY_PRIORITY_CHANGELOG.md) — قائمة التغييرات.
- [`PHASE52_SOURCE_REPOSITORY_PRIORITY_REPORT.md`](PHASE52_SOURCE_REPOSITORY_PRIORITY_REPORT.md) — التقرير النهائي والقيود وخطوة التحقق التالية.

**الحالة:** Accepted — أكد مالك المشروع نجاح بناء Release بتاريخ 2026-11-09. لا توجد بوابة Phase52 فاشلة مفتوحة، ولا يعاد تشغيل مجموعة اختباراتها في بوابات لاحقة.


## Phase 53 acceptance

The project owner confirmed the Phase53 Release build succeeded and that the updated navigation and manga features worked correctly on-device on 2026-11-09. Phase53 is treated as accepted.

## Phase 54 — Manga catalogue and repository management refinement

- [`PHASE54_MANGA_CATALOGUE_AND_REPOSITORY_MANAGEMENT.md`](PHASE54_MANGA_CATALOGUE_AND_REPOSITORY_MANAGEMENT.md) — country-filtered Manga categories and Sources-owned Mihon repository management. Build accepted through PHASE56; screenshot-discovered runtime ABI and Home-layout parity defects are addressed in PHASE57.


## Phase57.4 — Dependency-resolution recovery — 2026-11-11

Run `42927816064` stopped at `flutter pub get`: Flutter 3.35.7's `flutter_test` pins `meta 1.16.0`, conflicting with `flutter_native_splash 2.4.8`'s `meta ^1.18.0` requirement. The splash package is a static resource generator only and is not imported by app code. It is absent from app dependencies; settings remain in standalone `flutter_native_splash.yaml`, and committed Android splash resources remain unchanged. No global activation script is shipped. For future resource regeneration only, temporarily add compatible `flutter_native_splash 2.4.7` as a dev dependency, generate resources, then remove it and rerun `flutter pub get` before any build. CI checks the lockfile and `.flutter-plugins-dependencies` to block accidental reintroduction. See [`PHASE57.4_PUB_RESOLUTION_AND_SPLASH_TOOL_ISOLATION.md`](PHASE57.4_PUB_RESOLUTION_AND_SPLASH_TOOL_ISOLATION.md).


## Phase57.5 — Keep splash generation outside the app graph — 2026-11-11

- [`PHASE57.5_SPLASH_GENERATOR_APP_GRAPH_REMOVAL.md`](PHASE57.5_SPLASH_GENERATOR_APP_GRAPH_REMOVAL.md) — follows the Phase57.4 `flutter pub get` failure; removes the inaccurate global generator script, retains the standalone splash config and committed Android resources, documents safe temporary resource regeneration with 2.4.7, and keeps the existing minimal CI gates/toolchain unchanged.

**الحالة:** source/CI correction prepared. Flutter dependency resolution, five focused Flutter tests, Android ABI tests, ARM64 Release APK audit and physical-device acceptance are pending.


## Phase 58 — Restore the confirmed Home baseline and Manga parity

- [`PHASE58_HOME_BASELINE_RESTORE_AND_MANGA_HOME_REUSE.md`](PHASE58_HOME_BASELINE_RESTORE_AND_MANGA_HOME_REUSE.md) — restores Movies/Series/Anime Home source byte-for-byte from the owner's PHASE55(1) baseline; confines AniList direct artwork to explicit Manga-only callbacks; keeps all 18 Manga shelves and JP/KR/CN rows while using shared Home components.

**الحالة:** Source and static archive validation prepared. PHASE57.7 build and Mihon installation remain owner-confirmed; PHASE58 CI, Release APK and device visual checks are pending. Do not claim Phase58 accepted until the new workflow passes and the owner verifies the pages.


## Phase61.2 — Focused test failure corrections — 2026-11-11

- [`PHASE61.2_TEST_FAILURE_FIX_2026-11-11.md`](PHASE61.2_TEST_FAILURE_FIX_2026-11-11.md) — fixes two incorrect/misconfigured focused test expectations exposed after PHASE61.1 Analyze passed: parent-series versus episode identity in Continue Watching, and the missing `onMangaSeeAll` callback in the row-builder test fixture. Production feed behavior is unchanged. CI rerun is required before acceptance.


## Phase62 — Manga work detail and reader baseline

- [`RAVEN23-PHASE62-MANGA-WORK-DETAIL-AND-READER.md`](RAVEN23-PHASE62-MANGA-WORK-DETAIL-AND-READER.md) — سجّل خط الأساس الذي أضاف صفحة عمل Manga وربط Mihon والقارئ والتنزيلات والتقدم. هذا تقرير تاريخي؛ أقسامه التي تصف خمسة تبويبات والتوصيات لا تمثل واجهة PHASE63 الحالية.

## Phase63 — Zangetsu Manga work & reader parity

- [`RAVEN23-PHASE63-ZANGETSU-MANGA-WORK-READER-PARITY.md`](RAVEN23-PHASE63-ZANGETSU-MANGA-WORK-READER-PARITY.md) — مطابقة بنية صفحة العمل والقارئ، تصحيح ترتيب المعلومات، قائمة الإجراءات، OCR والترجمة، التحقق الساكن وحدود التوافق المتبقية.

**الحالة:** Source-level Analyze blockers corrected after CI run 43283800739; fresh Flutter Analyze, focused tests, Android unit tests, ARM64 Release APK and device validation remain pending.

## PHASE63.6 — Navigation refinement and unified Mihon source directory (2026-11-13)

- [`PHASE63.6_NAVIGATION_AND_UNIFIED_MIHON_DIRECTORY.md`](PHASE63.6_NAVIGATION_AND_UNIFIED_MIHON_DIRECTORY.md) — House/radio-button icon reassignment, 25% larger centre toggle, 12.5% tighter main/secondary dock spacing, and the combined Installed Manga Sources directory with installed/available row actions.

**الحالة:** الفحوص الساكنة نجحت؛ بوابة CI أصبحت 13 اختبار Flutter و55 هدف تنسيق. لا يُدّعى نجاح Flutter Analyze أو الاختبارات أو بناء APK قبل تشغيل GitHub Actions.

## PHASE63.5 — Focused pre-build navigation test repair (2026-11-13)

- [`PHASE63.5_CI_PREBUILD_NAVIGATION_TEST_FIX.md`](PHASE63.5_CI_PREBUILD_NAVIGATION_TEST_FIX.md) — documents CI run `43417262025`, the single failing global Phosphor icon finder, the scoped center-toggle assertion, and the correction of the stale 8-versus-12-file report inventory.

**الحالة:** إصلاح المصدر وتقرير CI جاهز؛ إعادة تشغيل GitHub Actions لا تزال مطلوبة لإثبات مرور الاختبارات الـ12، واختبار Mihon، وبناء ARM64 APK وفحصه.

## PHASE63.4 — Phosphor navigation icons and destination-aware menu toggle (2026-11-13)

- [`PHASE63.4_PHOSPHOR_NAVIGATION_ICONS.md`](PHASE63.4_PHOSPHOR_NAVIGATION_ICONS.md) — تغيير أيقونة Home إلى radioButton، وأيقونات Movies/Series/Anime/Manga إلى video/televisionSimple/maskHappy/bookOpenText، مع الإبقاء على Search، وتحويل زر القائمة الثانية إلى أيقونة الوجهة النشطة وإرجاعه إلى list عند العودة إلى Home.

**الحالة:** أضيف اختبار widget إلى بوابة CI؛ أصبحت أهداف التنسيق 53 والاختبارات المركزة 12. الفحوص المحلية ساكنة فقط، ويلزم CI وبناء APK قبل الاعتماد.

## PHASE63.2 — Pinned tabs, persistence, Notify, alias search and Mihon source picker (2026-11-13)

- [`PHASE63.2_STICKY_TABS_PERSISTENCE_NOTIFY_ALIAS_SOURCE_PICKER.md`](PHASE63.2_STICKY_TABS_PERSISTENCE_NOTIFY_ALIAS_SOURCE_PICKER.md) — pinned tab header and scrollable empty states, new work hero layout, per-work saved preferences, ascending chapter ordering, Notify action, all AniList aliases across all installed sources, and Mihon source picker with extension icons/actions.

**الحالة:** الفحوص الثابتة نجحت، لكن لم تُشغّل أدوات Flutter/Dart/Gradle/Android SDK هنا. Notify يعمل عند فتح العمل/استئناف التطبيق فقط وليس عبر فحص خلفي أثناء إغلاق التطبيق. يجب تشغيل CI والتحقق من الجهاز قبل الاعتماد.

## PHASE63.1 — Zangetsu source and chapter follow-up (2026-11-13)

- [`PHASE63.1_ZANGETSU_SOURCE_AND_CHAPTER_PARITY.md`](PHASE63.1_ZANGETSU_SOURCE_AND_CHAPTER_PARITY.md) — توثيق الاختلافات في لقطات الجهاز وسلوك Zangetsu الفعلي، وتنفيذ الاكتشاف التلقائي للمصدر والتبديل وإعادة الحل، وإجراءات قائمة الفصول والتنزيل والقراءة.

**الحالة:** فحوص ثابتة فقط؛ يلزم CI وبناء جديد واختبار الجهاز قبل الاعتماد. لا تُعرض Notify أو Tracking أو أولوية المصادر حسب اللغة كميزات منفذة.

## PHASE63 — CI analysis repair follow-up (2026-11-12)

- [`PHASE63_BUILD_REPAIR_2026-11-12.md`](PHASE63_BUILD_REPAIR_2026-11-12.md) — documents the failed Release run `43283800739`, the two invalid `AppType.caption` references, the applied formatter/lockfile patch and analyzer cleanups, and the still-required fresh CI/Android validation.

**الحالة:** Source-level analyzer blockers corrected; fresh Flutter Analyze, focused tests, Android unit tests, ARM64 Release APK and device validation remain pending.

## PHASE63.7 — Zangetsu chapter-reader UI parity (2026-11-13)

- [`PHASE63.7_ZANGETSU_CHAPTER_READER_UI_PARITY.md`](PHASE63.7_ZANGETSU_CHAPTER_READER_UI_PARITY.md) — `Find a source`/`Continue reading`/`Read` CTA states; Home Manga hero labels `Read` and `Install sources`; Zangetsu-referenced reader controls and reading options adapted to the RAVEN23 theme while retaining Mihon as the page/network runtime; RTL-aware page/spread tap zones, double-tap zoom, page indicator, optional double-page landscape, crop, pull navigation, auto-scroll in paged and vertical modes, current-chapter list anchoring, volume keys, comfort, save/share and all four locale files.

**الحالة:** اجتازت الفحوص الساكنة التمهيدية؛ بوابة Flutter تشتمل على 14 اختبارًا مركّزًا و56 هدف تنسيق. لا يُدّعى نجاح Dart format أو Flutter Analyze/tests أو Android/Gradle build أو APK حتى تمرّ GitHub Actions ويُتحقق من القراءة الفعلية على الجهاز. قارئ Mihon بقي محرك جلب الصور؛ لم تُنقل بنية جلب الصفحات الداخلية الخاصة بـZangetsu.

## PHASE63.8 — Source management, synchronization and paged catalogues (2026-11-13)

- [`PHASE63.8_SOURCE_MANAGEMENT_SYNC_AND_PAGED_CATALOGUE.md`](PHASE63.8_SOURCE_MANAGEMENT_SYNC_AND_PAGED_CATALOGUE.md) — moves repository management into `Check server status`, moves `REPOSITORIES` priority ordering into `Synchronize`, adds source-catalog search and ten-at-a-time rendering, pins installed sources above available entries in both catalogues, and adds safe one-time default Mihon installation for the ten requested Keiyoushi sources using the official signer fingerprint.

**الحالة:** فحوص ساكنة للحزمة فقط؛ بوابة GitHub Actions تضم 15 اختبار Flutter و63 هدف تنسيق. يجب تشغيل `flutter analyze` والاختبارات واختبار Mihon Android وبناء APK ARM64 ثم التحقق من التثبيت على الجهاز قبل اعتماد المرحلة.

## PHASE63.10 — Mihon paged-directory test correction (2026-11-14)

- [`PHASE63.10_MIHON_PAGED_DIRECTORY_CI_TEST_FIX.md`](PHASE63.10_MIHON_PAGED_DIRECTORY_CI_TEST_FIX.md) — diagnoses CI run `43533044222`: dependency resolution, 63-target formatting and Flutter Analyze passed; 103 focused tests passed and one pagination widget test failed because numeric fixture names were alphabetically sorted (`Source 15` was not a stable final-page marker). Zero-padded the fixture and asserted the initial `10 / 15` page count without changing production pagination.

**الحالة:** إصلاح اختبار المصدر جاهز على مستوى الكود والفحص الساكن فقط. يجب إعادة تشغيل GitHub Actions؛ اختبار Flutter المصحح لم يُنفّذ محليًا، واختبار Mihon Android وبناء ARM64 APK وتدقيقه لم تبدأ في التشغيل السابق.
