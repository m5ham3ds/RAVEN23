# PHASE 19 — Player gesture API compatibility build fix

## المشكلة التي ظهرت في GitHub Actions

فشل `assembleProdRelease` عند إنشاء `BetterPlayerGestureConfiguration` في:

`lib/screens/common/player.dart`

رسالة Dart كانت:

- `No named parameter with the name 'fastHoldSpeed'`
- والسياق يشير إلى constructor الفعلي في `raven23-betterplayer` الذي تم تنزيله من Git.

## السبب الجذري

ملف RAVEN23 المرفوع يستخدم اعتمادًا محليًا:

`better_player_plus: path: ../raven23-betterplayer`

وهذا الاعتماد المحلي في بيئة RAVEN23 يحتوي على حقلي `fastHoldSpeed` و`slowHoldSpeed`؛ لذلك يمرر RAVEN23 هذين الخيارين إلى `BetterPlayerGestureConfiguration`.

أما RAVEN23 فيستخدم اعتماد Git:

`https://github.com/BeamlakAschalew/flixquest-betterplayer.git` على الفرع `main`.

تعريف `BetterPlayerGestureConfiguration` في نسخة `main` التي جرى التحقق منها لا يحتوي على `fastHoldSpeed` أو `slowHoldSpeed`. لذلك لا يجوز تمريرهما من تطبيق RAVEN23 إلى هذا constructor. تطابق اسم المكتبة لا يعني تطابق نسخة API مع نسخة RAVEN23 المحلية.

## التصحيح

- إزالة وسيطَي `fastHoldSpeed` و`slowHoldSpeed` غير المدعومين من إنشاء `BetterPlayerGestureConfiguration` في `player.dart`.
- الإبقاء على إعدادات السرعة المخزنة في Settings/Preferences كما هي، وعدم حذف مفاتيح التخزين أو تغيير القيم القديمة.
- عدم إظهار عناصر إعداد الضغط المطوّل أو الادعاء بأن الإيماءة تعمل؛ فهي تظل غير مفعلة في واجهة RAVEN23 إلى أن تُنفذ داخل طبقة التطبيق أو تُستخدم نسخة مكتبة تدعمها صراحةً.
- الإبقاء على بقية إعدادات الإيماءات المدعومة حاليًا (السحب للتحكم بالصوت/السطوع/البحث والنقر المزدوج) دون تغيير.
- عدم تعديل كتالوج الجودة أو مصادر الفيديو أو تصميم المشغل ضمن هذا الإصلاح.

## تصحيح توثيق Phase 18

وصف Phase 18 لإعادة ربط إعدادَي الضغط المطوّل لم يكن صحيحًا بالنسبة إلى اعتماد Git المستخدم في RAVEN23. المقصود كان مطابقة سلوك نسخة RAVEN23 المحلية، لكن المعاملات المنقولة غير متاحة في API الذي يسحبه RAVEN23. هذا التقرير يصحح ذلك دون تعديل تقرير Phase 18 أو أي تقرير سابق.

## الملفات التي عُدلت في هذه المرحلة

- `lib/screens/common/player.dart`
- `phases/PHASE19_PLAYER_GESTURE_API_COMPATIBILITY_FIX.md`
- `README_CHANGED_FILES.txt` (تحديث سجل المرحلة الحالية)

## التحقق والقيود

- تم التحقق من تعريف constructor في ملف `better_player_gesture_controls.dart` على فرع Git `main`، وهو لا يعرّف حقلي السرعة.
- تمت إزالة جميع تمريرات `fastHoldSpeed` و`slowHoldSpeed` إلى constructor من ملفات Dart الخاصة بالمشغل.
- بقيت قيم التفضيلات القديمة ومفاتيح التخزين دون تغيير.
- لم يتوفر Flutter/Dart SDK في بيئة التحرير، لذلك لم يُشغّل `flutter analyze` أو `flutter test` أو `assembleProdRelease`. هذا الإصلاح يعالج الخطأ المحدد في سجل البناء، ولا يُعد تأكيدًا مسبقًا لخلو بقية المشروع من أخطاء بناء لاحقة.

## سياسة المراحل

تُضاف Phase 19 كتقرير تصحيحي مستقل. تبقى تقارير المراحل 1–18 وقراراتها السابقة محفوظة دون إعادة كتابة.
