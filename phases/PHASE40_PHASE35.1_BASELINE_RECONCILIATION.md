# Phase 40 — Phase 35.1 Baseline Reconciliation & UI Preservation Audit

**التاريخ:** 2026-11-07  
**المرجع البصري والسلوكي:** `RAVEN23-PHASE35.1.zip`  
**نسخة التطوير المقارنة:** `RAVEN23-PHASE40-FULL-SUITE-REGRESSION-RECOVERY.zip`

## 1. نطاق المقارنة ونتيجتها

تم فحص أرشيف Phase 35.1 كاملاً، ومقارنته بملفات مشروع التطوير قبل هذه المراجعة.

| البيان | العدد |
|---|---:|
| ملفات Phase 35.1 | 1,314 |
| ملفات نسخة التطوير قبل هذه المراجعة | 1,366 |
| ملفات مشتركة | 1,314 |
| ملفات مشتركة مختلفة المحتوى | 65 |
| ملفات أضيفت بعد Phase 35.1 | 52 |
| ملفات أصلية محذوفة | 0 |

لا يوجد حذف لملفات Phase 35.1 في نسخة التطوير المقارنة.

## 2. واجهات Phase 35.1 التي بقيت مطابقة

تحققت من التطابق byte-for-byte للملفات التالية بين النسختين:

- `lib/mobile/screens/home_screen.dart`
- `lib/mobile/screens/search_screen.dart`
- `lib/mobile/screens/discover_screen.dart`
- `lib/mobile/screens/new_and_hot_screen.dart`
- `lib/mobile/screens/title_details_screen.dart`
- `lib/mobile/widgets/poster_grid.dart`
- `lib/design/app_palette.dart`
- `lib/design/app_tokens.dart`
- `lib/constants/theme_data.dart`

وبالتالي فإن إخفاقات اختبارات Home وSearch وDiscover وNew & Hot وTitle Details وPoster Grid في سجل الاختبار المنفصل لا تثبت وحدها أن تصميم هذه الصفحات قد تغير؛ ملفات تنفيذ هذه الصفحات ومكونات التصميم المذكورة ما زالت مطابقة للمرجع. يجب فحص إعداد الاختبارات والبيانات والترجمات والـfinders قبل تغيير واجهات الإنتاج.

## 3. اختلافات مرئية/سلوكية أعيدت إلى مرجع Phase 35.1

### 3.1 App Colors

كان التطوير قد فعّل `useExactPrimary: true` لكل ألوان لوحة الاختيارات، بينما Phase 35.1 تستخدم `ColorScheme.fromSeed` للألوان الأساسية، مع اللون الأحمر الافتراضي واللون المخصص الدقيقين كما كانا.

تمت إعادة توليد ألوان الاختيارات الأساسية إلى سلوك Phase 35.1. بقي اللون الافتراضي الأحمر واللون المخصص كما في المرجع. عُدّل اختبار اللون البرتقالي ليتحقق من بقاء الخيار ذي `index == 9` ومن استخدامه مخطط اللون المشتق من seed، بدلاً من فرض تغيير لون الواجهة إلى قيمة primary دقيقة لم تكن سلوك Phase 35.1.

### 3.2 RevealItem

كانت النسخة المطورة تستدعي `_controller.forward()` فوراً عندما يكون تأخير العنصر صفراً. المرجع يستخدم جدولة مؤجلة (`Future.delayed(Duration.zero, ...)`). تم الحفاظ على تأجيل العنصر الأول باستخدام `Timer(Duration.zero, ...)` مع الاحتفاظ بإلغاء المؤقت عند `dispose`.

لم تتغير خصائص الحركة: مدة 380ms، إزاحة 28px، مقياس 0.94 إلى 1.0، ومنحنيات الحركة نفسها.

### 3.3 Legacy Player Quality Label

كان Phase 35.1 يضع `providerName` داخل `qualityLabel` بعد الجودة، قبل وسم الصوت. أُعيد هذا الترتيب حتى يستمر عرض التسمية القديمة (مثال `540p · Provider`) كما كان. عُدّل اختبار adapter ليتحقق من عقد التسمية المرجعي بدلاً من تغيير النص الظاهر للمستخدم.

## 4. تعديلات واجهة مطلوبة للمراحل 37.1 و39 و40

ملف `lib/screens/common/source_repositories_screen.dart` هو الواجهة الإنتاجية الوحيدة ذات تغييرات وظيفية واضحة ضمن نطاق Source Manager:

- زر الاستعادة الموجود احتفظ بنوعه وموقعه المرئي (`OutlinedButton.icon`) ونظام التباعد والألوان، وتغير نصه/وظيفته من إضافة OpenStream وحده إلى استعادة المستودعات المضمّنة.
- أضيفت أيقونة إعدادات QuickJS وأيقونة تهيئة Stremio إلى صف المصدر الحالي.
- أضيفت شارة حالة التهيئة باستعمال `_SourceStatusChip` الموجود نفسه.
- لم تتغير مكونات `AppPalette`, `AppType`, `AppSpace`, أو شكل البطاقات العام.

هذه إضافات وظائف لازمة للمراحل 37.1 و39 و40، وليست إعادة تصميم عامة للتطبيق. لا تُجرى تعديلات على Home/Search/Discover/Player/Title Details لإخفاء فشل اختبارات قديمة.

## 5. تغييرات أخرى لا تغير شكل الواجهة

- `lib/screens/common/player.dart`: الاختلافات المقارنة المتبقية في الملف هي تصحيحات String Interpolation/تنسيق، دون تغيير ترتيب عناصر واجهة المشغل.
- `lib/mobile/screens/episode_screen.dart`: تصحيح تركيب نص `ValueKey` فقط.
- `lib/screens/movie/movie_video_loader.dart` و`lib/screens/tv/tv_video_loader.dart`: إزالة import غير مستخدم وnon-null assertion غير لازم.
- `lib/presentation/session/session_view_model.dart`: إزالة non-null assertion بعد فحص القيمة.
- `lib/functions/player_subtitle_configuration.dart`: إزالة import غير مستخدم.
- `lib/screens/common/player/player_external_subtitles.dart`: تصحيح نص تشخيصي فقط.
- تغييرات المحركات والمستودعات والإعدادات تتعلق بعقود البيانات، العزل، التحقق، والتشغيل؛ لا تستبدل بنية المشغل.

## 6. مطابقة ملفات تقارير CI — لا تدمج تشغيلين مختلفين

### تقرير البناء المرفق في هذه الجولة

- Run: `42335259990`
- Commit: `27a40f76da41a98cb1dde6414221c649b561e4d0`
- الفشل الوحيد المسجل: `Flutter analyze`.
- ظهرت 7 ملاحظات `curly_braces_in_flow_control_structures` في:
  - `lib/services/external_subtitle_service.dart` (5 مواضع)
  - `lib/video_providers/unified/legacy_provider_adapter.dart` (موضعان)
- بقية الخطوات، بما فيها الاختبارات المركزة والكاملة وGradle وAPK، كانت `skipped` ولم تُنفذ.

عولجت المواضع السبعة بإضافة أقواس واضحة دون تغيير مسارات التنفيذ.

### سجل Full Flutter Test المنفصل المرفق في محادثة سابقة

يحتوي ذلك الملف على `flutter-analyze.log` ينص على `No issues found!`، ثم يسجل 2,155 اختباراً ناجحاً و23 فاشلاً و11 متخطياً. هذه النتيجة لا يمكن أن تكون من نفس تشغيل التقرير أعلاه لأن سجل التحليل متعارض: 7 issues/exit code failure مقابل No issues/exit code 0. لذلك حُفظت النتيجتان كسجلين منفصلين ولا تُعرضان على أنهما تشغيل CI واحد.

في ذلك السجل المنفصل ظهرت تحذيرات EasyLocalization عن مفاتيح غير موجودة أثناء اختبارات Widget. عند فحص ملفات الترجمة الفعلية في النسختين، كانت مفاتيح مثل `filter_all`, `top_10_movies_today`, `trending_movies_week`, `new_episodes_series`, `anime_status`, `movie`, و`details` موجودة في ملفات `assets/translations`؛ لذلك لا يصح استنتاج أنها ناقصة في أصول التطبيق من رسائل test harness وحدها.

## 7. إصلاحات التحليل ضمن هذه المراجعة

- أضيفت أقواس إلى حواجز الاستجابة وصفوف SubSource الخمسة في `external_subtitle_service.dart`.
- أضيفت أقواس إلى موضعي `continue` و`return` في `legacy_provider_adapter.dart`.
- طُبق Dart formatter patch المرفق من CI (22 ملفاً عُدلت بالتنسيق؛ 65 هدفاً تم فحصها في خطوة التحقق).
- بقي فحص Flutter الفعلي غير قابل للتشغيل محلياً لعدم توفر Flutter/Dart SDK في بيئة التحرير.

## 8. حالة القبول

- **تصميم Phase 35.1:** محفوظ في الصفحات الرئيسية ومكونات Design Tokens وAppPalette.
- **سلوك الألوان والحركة وتسمية الجودة:** تمت إعادة الاختلافات الثلاثة المحددة إلى المرجع.
- **ميزات إدارة المصادر الجديدة:** محفوظة بإضافات داخل التصميم الحالي.
- **Flutter analyze بعد إصلاح الملاحظات السبعة:** لم يُشغّل محلياً؛ يحتاج إعادة CI.
- **Flutter Test الكامل:** غير معتمد؛ السجل الكامل المرفق يعود لمحاولة مختلفة ويحتاج تشغيل موحد جديد.
- **Android Release ARM64:** لم يصل إليه تشغيل `42335259990` بسبب توقفه عند Analyze.
- **Phase 40:** `In Progress`، وليست Passed أو Accepted.
- **Phase 41:** لم تبدأ.



## 9. الحصر النهائي لنسخة المتابعة بعد تطبيق Patch المستخدم

بعد تطبيق `dart-format.patch` المرفق مع تقرير التشغيل، وإضافة الأقواس السبعة المطلوبة، وإعادة مواءمة سلوك الألوان والحركة ووسم الجودة مع Phase 35.1، تم التحقق من الأرشيف النهائي المراد تسليمه:

| البيان | العدد |
|---|---:|
| ملفات مرجع Phase 35.1 | 1,314 |
| ملفات المشروع النهائي | 1,367 |
| ملفات Phase 35.1 الموجودة دون حذف | 1,314 |
| ملفات أصلية محذوفة | 0 |
| ملفات إضافية مقارنة بالمرجع | 53 |
| ملفات مشتركة مختلفة المحتوى عن المرجع | 69 |

الـ53 ملفاً الإضافية هي 52 ملفاً كانت موجودة في حزمة التطوير السابقة، إضافة إلى تقرير المطابقة هذا. ولا يعني اختلاف 69 ملفاً تغييراً في تصميم التطبيق؛ تتضمن هذه المجموعة عقود ومحركات المصادر، الترجمات، إعدادات المستودعات، اختبارات وتوثيق المراحل، وتصحيحات غير مرئية للمستخدم.

### 9.1 نتيجة المطابقة المرئية النهائية

تم التحقق مرة أخرى من أن ملفات Home وSearch وDiscover وNew & Hot وTitle Details وPoster Grid وAppPalette وAppTokens و`theme_data.dart` مطابقة byte-for-byte لمرجع Phase 35.1. كما أن جميع الملفات في `lib/design/` و`lib/constants/` متطابقة مع المرجع.

`lib/models/app_colors.dart` عاد byte-for-byte إلى Phase 35.1. بقيت تغييرات RevealItem داخل حدود جدولة الحركة وإلغاء المؤقت عند التخلص من العنصر، دون تغيير مدة الحركة أو الإزاحة أو المقياس أو المنحنيات. كما أعيد `providerName` إلى تسمية الجودة في Legacy adapter كما في المرجع.

### 9.2 إصلاح فشل CI المرفق بهذه الجولة

تقرير التشغيل `42335259990` يوضح أن الفشل الوحيد كان في `flutter analyze` بسبب سبعة ملاحظات `curly_braces_in_flow_control_structures`:
- خمسة مواضع في `lib/services/external_subtitle_service.dart`.
- موضعان في `lib/video_providers/unified/legacy_provider_adapter.dart`.

تم تطبيق Dart formatter patch الذي أرفقه المستخدم (22 ملف Dart)، ثم أضيفت الأقواس إلى المواضع السبعة. تم فحص المسارات الـ65 التي يستهدفها `tool/format_phase37_40_dart.sh` ووجدت جميعها. لم يتم تشغيل Flutter/Dart محلياً، لذلك يحتاج هذا الإصلاح إلى إعادة CI ولا يوصف بأنه ناجح في GitHub حتى يظهر سجل لاحق.

### 9.3 حدود الأدلة

هذا التقرير لا يخلط بين تشغيل `42335259990` وبين سجل full-test تاريخي منفصل؛ الأول توقف عند Analyze ولم يصل إلى أي اختبار، أما سجل الاختبارات المنفصل فيحتوي على نتيجة Analyze مختلفة. لم يتم بناء APK بعد إصلاحات هذا التقرير، ولا تُعتمد Phase 40 قبل نجاح Analyze وFocused Tests وFull Test وRelease ARM64 في تشغيل CI موحد.
