> **Implementation snapshot (updated 2026-11-10):** Phase51 Release gate passed in run `42507906881`: Analyze, formatting, 302 tests, Kotlin/Gradle, `assembleProdRelease`, and ARM64 APK audit succeeded. APK was 28,111,482 bytes, package `com.m5ham3ds.raven23`, version `4.3.0+10`, ABI `arm64-v8a`. The owner confirms all build operations completed successfully through PHASE56. Phase52 VOD priority lanes (Movies 13 / Series 9 / Anime 11) and Phase53 navigation/Manga integration are owner-accepted. PHASE54/55 builds are included in that confirmation. Phase56 build success is owner-confirmed. Its follow-up device finding (Float representation of ABI 1.6) and requested exact Manga/Home visual parity are assigned to PHASE57; they are not historical build failures. PHASE57 CI/Release/device acceptance remains pending. Pluto remains Experimental/Unavailable without an authorized API contract.

# RAVEN23 — Master Implementation Blueprint

## Unified Sources, Multi-Provider Playback & Live TV Expansion

- **المشروع:** RAVEN23 / CINESTREAM-PRO-N
- **النطاق الأصلي للخطة:** Phase 36 إلى Phase 52؛ أضيفت لاحقًا مراحل التكامل 53–57 وتوثق حالتها الحالية في README_MASTER_IMPLEMENTATION.md
- **حالة الوثيقة (محدّثة 2026-11-10):** Phase51 اجتازت بوابة التكامل وRelease في run `42507906881`، بما يشمل 302 اختبارًا وAPK ARM64. وأكد مالك المشروع نجاح جميع عمليات البناء اللاحقة حتى PHASE55، بما فيها Phase52–55. سجلات فشل المحاولات الوسيطة لـPhase52 وغيرها تاريخية ومتجاوزة، ولا تمثل حالة بناء نشطة. لا يزال اختبار المزودين والجهاز منفصلًا، أما أعطال Manga/Mihon الظاهرة في صور الجهاز تُعالج بالتتابع في PHASE56 وPHASE57؛ بناء Phase56 مؤكد النجاح، وتحقق Phase57 ما زال مطلوبًا.
- **قاعدة المشروع:** أحدث أرشيف Phase 35.1 الذي تمت مراجعته لإعداد هذه الوثيقة
- **الهدف:** توسيع منظومة المصادر الستة وإدارة Live TV مع الحفاظ على أنظمة الكتالوج والمشغل والترجمات والتقدم والإعدادات الموجودة.

---

## 1. القرار التنفيذي

سيتم التعامل مع المقترحات باعتبارها برنامج تطوير واحداً متعدد المراحل، وليس دفعة تعديلات واحدة. يجب أن تسبق معالجة العقود المشتركة إضافة أعداد كبيرة من المصادر؛ وإلا ستتكرر أخطاء النوع والحلقات والإعدادات وتصبح أعطال المصادر الخارجية صعبة العزل.

**مبدأ التنفيذ الحاكم:** إعادة استخدام البنية الموجودة وتوسيعها، لا إنشاء بنية موازية لمجرد أن اسمها وارد في التقرير.

### النتائج المستهدفة

1. إدارة مركزية موحدة للمستودعات والمصادر والإصدارات والحالات، مع إبقاء محرك التنفيذ متخصصاً حسب نوع الإضافة.
2. معالجة موحدة وآمنة لهوية الفيلم والمسلسل والأنمي والموسم والحلقة.
3. دعم إعدادات QuickJS لكل إضافة بطريقة قابلة للحفظ والاستعادة.
4. تفسير صحيح لـStremio Manifest وسلوك الإعدادات الاختيارية والإلزامية.
5. فصل لغة الصوت عن جودة الفيديو في VidKing Direct.
6. توسيع مصادر OpenStream وZangetsu وSpyhell بعد التحقق من كل عقد برمجي ومصدر فعلي.
7. تطوير Live TV الموجود إلى منظومة متعددة المزودين تدعم M3U وخدمات القنوات وPluto TV، ثم XMLTV/EPG.
8. تحسين ترتيب التنفيذ والمهلات والتراجع دون حجب نتائج المصادر السليمة بسبب مصدر بطيء أو متوقف.
9. إجراء اختبارات ثابتة واختبارات Fixtures واختبارات تشغيل حقيقية منفصلة، واعتماد Release Build قبل اعتبار أي مجموعة مكتملة.

## 2. النطاق والحدود

### داخل النطاق

- مستودعات OpenStream وZangetsu وSpyhell الستة المشار إليها في تقرير التدقيق.
- محركات RAVEN23 المسجلة حالياً: Native، OpenStream Anime، Web Embed، VidKing Direct/WebView، Stremio، QuickJS/JavaScript، وواجهات HTTP/JSON أو Scraper عند انطباقها.
- مصادر الأفلام والمسلسلات والأنمي والدونغهوا والمصادر المتخصصة لغوياً.
- خدمات Live TV وقوائم IPTV/M3U وPluto TV وEPG/XMLTV.
- واجهات Android Mobile وAndroid TV وإعدادات المصادر والمشغل.

### خارج النطاق ما لم يعتمد المستخدم مرحلة مستقلة

- استبدال BetterPlayer أو إعادة بناء مشغل الفيديو.
- تغيير نموذج التقدم أو المفضلات أو المزامنة دون خطة ترحيل منفصلة.
- تحويل الأنمي إلى MediaKind ثالث داخل التطبيق.
- إدراج روابط تورنت/Magnet على أنها روابط HTTP قابلة للتشغيل دون محرك تورنت مستقل ومعتمد.
- تجاوز DRM أو Cloudflare أو القيود الجغرافية أو أنظمة المصادقة.
- ضمان عمل كل رابط خارجي أو كل قناة على مدار الساعة.
- إدراج Pluto TV VOD في كتالوج الأفلام ضمن مهمة Live TV.
- إضافة مفاتيح API أو أسرار داخل المستودع أو سجلات التطبيق.

## 3. حقائق معمارية مؤكدة من أرشيف Phase 35.1

هذه نتائج فحص ملفات المشروع، وليست تصميماً افتراضياً:

| المجال | الموجود فعلياً في الأرشيف | التوجيه في الخطة |
|---|---|---|
| تسجيل محركات المصادر | `lib/video_providers/unified/source_engine.dart` وفيه `SourceEngineRegistry` و`SourceEngine` و`resolveMany` | توسيع السجل الحالي؛ لا إنشاء Registry ثانٍ |
| تعريف المصدر | `source_manifest.dart` وفيه `SourceManifest` و`SourceEngineDescriptor` و`SourceEngineKind` وقدرات النوع | مراجعة العقد وتوسيعه مع توافق رجعي |
| إدارة المستودعات | `source_repository_manager.dart` وفيه الإضافة والإزالة والتثبيت والتعطيل والمزامنة والتخزين المؤقت | توسيعه للإصدارات والبصمات وفحص التكرار وتاريخ التغيير |
| تحليل الفهارس | `source_repository_parser.dart` ويدعم OpenStream وZangetsu/JavaScript ومصفوفات خام وStremio | إضافة اختبارات وفروع لازمة؛ لا استبدال المحلل قبل تدقيقه |
| QuickJS | `quickjs_source_engine.dart` و`quickjs_provider_runtime.dart` و`quickjs/js_bootstrap.dart` | استكمال إعدادات الإضافات وعقودها؛ `__settings` موجود كحامل مبدئي و`getSettings` يُكتشف في Bootstrap |
| نوع QuickJS | `QuickJsSourceEngine` يتعامل حالياً مع `all` و`movie` و`series` و`anime`، ويفصل البحث عن استخراج الحلقة | توسيع التحقق من نوع كل نتيجة وليس الاكتفاء بوسم `all` |
| Stremio | `stremio_addon_provider.dart` مع تفسير Manifest في `source_repository_parser.dart` | مراجعة شرط `configurable` و`configurationRequired` وتغطية حالات Manifest |
| VidKing | `vidking_direct_provider.dart` | يوجد استعمال لـ`qualityFilter` في ترشيح الجودة واستعماله أيضاً كمصدر محتمل لـ`audioLanguage`؛ يلزم فصل صريح |
| Live TV contract | `LiveTvService` موجود داخل `daddylive_service.dart` ويقدم `getCatalog` و`getStream` و`close` | تطوير العقد تدريجياً دون كسر الخدمات القائمة |
| مزودو Live TV | `DaddyLiveService` و`EthioSportsService` يطبّقان `LiveTvService` | الحفاظ عليهما وإضافة Adapter/Manager مشترك |
| واجهة اختيار المزود | منطق EthioSports ومفاتيح التبديل في `live_tv_screen.dart` و`tv_live_screen.dart` موجود داخل تعليقات | فحص سبب التعطيل ثم إعادة التفعيل باختبارات، لا افتراض أنه يعمل حالياً |
| تخزين Live TV | `LiveTVDatabaseController` يدعم namespaces مستقلة للقنوات والمفضلات والسجل وEPG | إعادة استخدامه وتقييم ترحيل المفاتيح فقط إذا لزم |
| EPG | نماذج DaddyLive الحالية موجودة في `models/live_tv.dart` وتغذي البرنامج الحالي/التالي | إضافة XMLTV Parser/Adapter دون ربط النموذج العام بمزود DaddyLive |
| سلوك المصادر | Phase 8 يوثق fallback head-start لمدة 8 ثوانٍ واختيار أول نتيجة صالحة، و`SourceEngineRegistry.resolveMany` يدعم توازياً محدوداً ويبدأ افتراضياً بتوازٍ 1 | توحيد السياسة واختبارها؛ لا إعادة كتابة جدولة قائمة |
| Anime | Phase 8 يضم `MediaIdentity` و`OpenStreamAnimeSourceEngine` وربط AniList/ani.zip، وPhase 11/28/32/34/35 تثبت قواعد التصنيف والتصفح | الحفاظ على هذه السلسلة؛ لا إضافة عناوين يدوياً |

### قواعد لا يجوز تجاوزها

- في طبقة التطبيق والكتالوج والتفاصيل والحلقات، الأنمي المسلسلي يبقى `MediaKind.series` ويستخدم مسار المواسم والحلقات الحالي.
- توجد في طبقة هوية المصادر قيمة/تمييز `UnifiedMediaType.anime` في بعض مسارات التوجيه. هذا لا يغيّر قاعدة `MediaKind.series` على مستوى التطبيق؛ يجب توثيق التحويل بين الطبقتين بدقة.
- قاعدة Phase 11 الحالية لتصنيف Anime هي Genre ID `16` (Animation) مع اللغة الأصلية `ja` حيث تنطبق على بيانات TMDB التلفزيونية. لا تُستبدل بقوائم عناوين يدوية.
- Phase 28 و32 و34 و35 و35.1 ومراحل اللاعب السابقة قيود حفظ إلزامية.
- أي مصدر متعدد الأنواع يجب أن يثبت قدرته الفعلية على كل نوع. وجود `getEpisodes()` في ملف JavaScript وحده لا يثبت أن المصدر يعلن أو يدعم المسلسلات بصورة صحيحة.

## 4. خريطة المراحل والاعتماد

| المرحلة | الاسم | الاعتماد | نوع العمل |
|---|---|---|---|
| 36 | Comprehensive Source Audit | Phase 35.1 | تدقيق وتوثيق فقط |
| 37 | Unified Source Architecture | 36 | عقود وإدارة مركزية |
| 38 | Media & Episode Normalization | 36، 37 | هوية وبيانات وحلقات |
| 39 | QuickJS Settings System | 36، 37 | إعدادات وإدارة runtime |
| 40 | Stremio Manifest & Configuration | 36، 37 | Manifest وإعدادات Stremio |
| 41 | VidKing Language & Quality | 36، 37، 38 | فصل خصائص الصوت والجودة |
| 42 | Repository Versioning & Security | 36، 37 | المستودعات والإصدارات والأمان |
| 43 | OpenStream Integration | 37، 38، 42 | مصادر ومحركات OpenStream |
| 44 | Zangetsu & Spyhell QuickJS Integration | 37، 38، 39، 42 | حزم إضافات متعددة |
| 45 | Execution, Ranking & Fallback | 37، 38، 41، 43، 44 | الجدولة والمرونة |
| 46 | Unified Live TV Manager | 36، 37 | خدمات القنوات |
| 47 | IPTV / M3U Engine | 46 | قوائم القنوات |
| 48 | Pluto TV Live Adapter | 46، 47 | مزود خطي تجريبي؛ لا تشغيل داخلي دون عقد API مصرح |
| 49 | XMLTV / EPG | 46، 47 | دليل البرامج |
| 50 | WebView / Embedded Playback | 37، 42، 44 | سياق المتصفح والتضمين |
| 51 | Integration & Release Validation | جميع المراحل المعتمدة | اختبارات واعتماد |

### ترتيب التنفيذ

- لا تبدأ أي مرحلة تنفيذية قبل إغلاق بوابة قبول اعتمادياتها.
- يمكن تطوير Phase 39 و40 و41 و42 على مسارات متوازية بعد اعتماد Phase 37، شرط عدم تعديل الملفات المشتركة نفسها دون تنسيق.
- لا يبدأ توسيع مصادر QuickJS على نطاق واسع قبل اعتماد 38 و39 و42.
- يمكن تطوير Live TV بالتوازي مع مجموعات المصادر بعد اعتماد 37 و46، مع منع التداخل في النماذج المشتركة.
- Phase 51 بوابة اعتماد نهائية، وليست مرحلة إصلاح متأخرة تُلقى فيها كل المشكلات.

## 5. مواصفات كل مرحلة

### Phase 36 — Comprehensive Source Audit

**الهدف:** التحقق من واقع المشروع والفهارس الستة وتحديد فجوات التنفيذ قبل أي تعديل وظيفي.

**المهام:**
1. قراءة جميع وثائق `phases` السابقة، وبالأخص Phase 8 و11 و14 و17 و20 و28 و31 و32 و34 و35 و35.1، ثم مراجعة أي وثيقة أخرى تؤثر في مصدر أو مشغل أو تخزين.
2. تسجيل الملفات والكلاسات والواجهات الفعلية لكل محرك.
3. بناء جرد لكل فهرس من المستودعات الستة: رابط الفهرس، تنسيق الملف، أسماء الإضافات، مصدر السكربت، الإصدار، اللغة، النوع المعلن، المحرك، المتطلبات، حالة الرابط، وآخر تحقق.
4. التحقق من الرابط المصحح لمستودع Spyhell Latin: `https://raw.githubusercontent.com/Spyhell/spyou-latin-zan/main/index.json` وعدم استخدام `index.ison`.
5. تأكيد الرابط الدقيق لمستودع Spyou Additional Providers من المصدر الرسمي؛ لا يتم تخمينه أو توليده من الاسم.
6. حفظ Snapshot للفهرس وتاريخ/وقت الوصول وHTTP status وcommit hash إن توفر.
7. مراجعة أكواد الإضافات المختارة فعلياً، لا أسماءها أو أوصافها فقط.
8. إنشاء مصفوفة توافق أولية وفصل الادعاءات الواردة في تقرير المستخدم عن النتائج التي تم التحقق منها مستقلاً.
9. مراجعة نقاط اختيار Live TV التي عُلّقت في الهاتف والتلفاز ومعرفة سبب التعطيل والآثار الجانبية.
10. توثيق اختبارات البناء الحالية وأخطاء CI إن وجدت.

**المخرجات:** `PHASE36_AUDIT_REPORT.md`، `SOURCE_REPOSITORY_SNAPSHOT.json`، `SOURCE_COMPATIBILITY_MATRIX.md`، قائمة الملفات المرشحة للتعديل، وقرار جاهزية Phase 37.

**معيار القبول:** لا توجد روابط مستودعات مخمّنة؛ كل إضافة في الجرد مرتبطة بفهرس وملف مصدر حقيقي أو معلّمة بوضوح أنها غير متاحة؛ لا تعديل وظيفي في Phase 36.

### Phase 37 — Unified Source Architecture

**الهدف:** تثبيت عقد مشترك لإدارة المصادر مع الإبقاء على المحركات المتخصصة.

**المكونات القائمة التي يجب فحصها وتطويرها:** `SourceManifest`، `SourceEngineDescriptor`، `SourceEngine`، `SourceEngineRegistry`، `SourceRepositoryManager`، `UnifiedSourceService`، `UnifiedStreamOption`.

**المهام:**
1. توثيق lifecycle من اكتشاف المستودع إلى تثبيت المصدر وتفعيله وإرساله إلى المحرك واستلام النتائج.
2. تحديد الفرق بين repository identity وsource identity وengine identity وcontent identity.
3. توحيد تمثيل capabilities لكل مصدر مع توافق بيانات الفهارس القديمة.
4. توحيد حالة الإضافة (discovered، validated، installed، enabled، disabled، experimental، incompatible، failed، duplicate) دون تغيير سلوك التثبيت الحالي فجأة.
5. فصل نتيجة المحرك عن تشخيص المحاولة ووقت التنفيذ وسبب الفشل.
6. تثبيت واجهة إلغاء الطلبات والمهلات ومنع عمليات stale بعد مغادرة الشاشة.
7. ضمان أن المصدر غير المدعوم يبقى مرئياً في الكتالوج مع توضيح أنه غير قابل للتشغيل، لا أن يُمرر إلى محرك خاطئ.
8. تحديد حد مسؤولية كل engine وعدم نقل منطق Stremio أو QuickJS إلى طبقة عامة.
9. إضافة اختبارات عقود مشتركة لكل المحركات المسجلة.

**معيار القبول:** يمكن تشغيل مصدر واحد من كل محرك مدعوم من خلال registry الحالي؛ لا يتم إدخال مدير أو Registry موازٍ؛ وتظل واجهة المشغل المستهلكة لـ`UnifiedStreamOption` متوافقة.

**تنفيذ Phase 37 الحالي:** تمت إضافة `source_contracts.dart` لهويات المستودع/المصدر/المحرك/المحتوى، وملف capabilities وصفي، وحالة lifecycle متعددة الأعلام، كما أضيفت diagnostics مستقلة لمحاولات المحركات و`SourceRepositoryManager.lifecycleOf`. لم تتغير `stableKey` أو مفاتيح التخزين أو dispatch policy. راجع `PHASE37_UNIFIED_SOURCE_ARCHITECTURE_IMPLEMENTATION.md`. المرحلة `In Progress` حتى تنجح format/analyze/test وRelease CI بعد التعديلات.

### Phase 37.1 — Bundled Repositories

**الهدف:** تضمين فهارس المستودعات الستة في التثبيت الافتراضي وإيصالها بأمان إلى المستخدمين الحاليين دون حذف إعداداتهم.

**التنفيذ:** قائمة مضمنة من ستة URLs داخل `SourceRepositoryManager`؛ ترحيل v2 يضيف الخمسة الجديدة إلى مستخدمي v1، ويزرع الستة للتثبيت الجديد؛ زر استعادة يدوي additive؛ ترجمات en/ar/es/hi؛ اختبارات للترحيل وعدم التكرار والحفاظ على إعدادات المستخدم.

**حدود التنفيذ:** إضافة الفهارس لا تثبت جميع الإضافات ولا تضمن تشغيل كل مصدر. تظل عمليات Install/Uninstall مستقلة، وتُختبر مصادر QuickJS الفعلية ضمن Phase 44.

**معيار القبول:** يعرض التطبيق ستة مستودعات بعد المزامنة على تثبيت جديد وترقية تثبيت قديم؛ لا تفقد المستودعات المخصصة أو مفاتيح التثبيت والتعطيل؛ تمر اختبارات manager/parser وAnalyze وRelease CI.

**التفاصيل:** `PHASE37.1_BUNDLED_REPOSITORIES.md`.

### Phase 38 — Media & Episode Normalization

**الهدف:** منع أخطاء مطابقة المحتوى والموسم والحلقة عند انتقال الطلب بين المحركات.

**المهام:**
1. توثيق التحويل بين `MediaKind` و`UnifiedMediaType` وتصنيف Anime/Donghua/Animation.
2. توحيد الهوية التي تمر إلى المحركات: TMDB IDs، IMDb/AniList/MAL عند توفرها، العنوان الأصلي، سنة العمل، نوعه، ومعرف الحلقة.
3. توحيد قيم الموسم والحلقة كقيمتين مستقلتين nullable مع التحقق من المجال.
4. دعم استخراج SxxExx من العنوان/المعرف/URL عندما يكون واضحاً فقط.
5. دعم بيانات الموسم المنفصل، IDs الخاصة بالحلقات، تواريخ العرض عند وجودها.
6. منع مطابقة الحلقة على رقم الحلقة وحده عند وجود عدة مواسم.
7. وضع سياسة explicit للحالات التي لا تعلن فيها الإضافة seasonNumber: exact match أولاً؛ ثم mapping موثق؛ ثم فشل تشخيصي، ولا تخمين موسم.
8. دعم الأعمال متعددة الأجزاء والأفلام الأنمي دون تحويل فيلم الأنمي إلى S1E1.
9. الحفاظ على `OpenStreamAnimeSourceEngine` وربط AniList/ani.zip ومفاتيح cache التي تميز movie عن TV.
10. توسيع fixtures لاختبار Japanese/Korean/Chinese/Arabic/Latin title normalization.

**معيار القبول:** لا يمكن قبول نتيجة حلقة من موسم غير المطلوب لمجرد تطابق episode number؛ وتبقى تفاصيل وتشغيل الأنمي على المسار الحَلَقي المعتمد.

**سجل التنفيذ الحالي (2026-11-06):** أضيف تطبيع `MediaIdentity` والتصنيفات المنفصلة، ومطابق حلقات صارم، وحواجز مبكرة لـStremio/VidKing، وربط ذلك بمسارات QuickJS وOpenStream الحالية. أضيفت fixtures واختبارات للموسم/الحلقة والتعارض واللغات. لا تعتبر المرحلة مقبولة بعد: لا تزال اختبارات Dart/Flutter وبناء Release واختبارات الجهاز غير منفذة، كما أن تحقق اعتماد Phase 37/37.1 بعد التعديل لا يزال شرطاً سابقاً. التفاصيل في `PHASE38_MEDIA_AND_EPISODE_NORMALIZATION_*.md`.

### Phase 39 — QuickJS Extension Settings System

**الهدف:** استكمال `__settings` و`getSettings()` إلى نظام إعدادات آمن ومحفوظ لكل إضافة.

**المهام:**
1. فحص schema الحقيقي الذي ترجعه إضافات المستودعات الستة.
2. تصميم parser محدود لأنواع الإعدادات المدعومة فعلياً: text، number، boolean، select، وربما multiselect بعد إثبات احتياجه.
3. التحقق من required/default/min/max/options/validation وعدم الوثوق بقيم الإضافة دون تحقق.
4. عرض نموذج إعدادات لكل sourceId في إدارة المصادر.
5. تخزين الإعدادات بحسب stable source identity مع version/schema version.
6. تمرير القيم إلى runtime قبل `getInfo` و`search` و`getDetail` و`getEpisodes` و`getVideoSources` حسب العقد.
7. التعامل مع تغيّر schema بعد التحديث مع حفظ القيم المتوافقة فقط.
8. تشفير/حماية القيم الحساسة وفق إمكانات Android المتاحة، وعدم إظهارها في logs أو diagnostics.
9. منع إضافة JavaScript من قراءة إعدادات إضافة أخرى.
10. وضع حدود لحجم schema وعدد الحقول وأطوال القيم.

**معيار القبول:** إعدادات مصدر لا تتسرب إلى مصدر آخر، وتبقى بعد إعادة تشغيل التطبيق، وتصل إلى الدوال الصحيحة قبل التنفيذ.

**سجل تنفيذ Phase 39 (2026-11-06):** أضيف parser محدود لـ`getSettings()`، ومحرر إعدادات للمصادر المثبتة، وتخزين Android Secure Storage بمفتاح مشتق من stable source identity، وحلقة reconciliation للمخطط، وحقن للقيم قبل استدعاءات QuickJS. تم عزل `__settings` داخل نطاق كل إضافة ومنع تشغيل المصدر إذا كانت إعداداته الإلزامية غير مكتملة. لا تعتبر المرحلة مقبولة بعد: format/analyze/test وRelease CI لم تُشغّل في بيئة التنفيذ. راجع ملفات `PHASE39_QUICKJS_SETTINGS_SYSTEM_*.md`.

### Phase 40 — Stremio Manifest & Configuration Engine

**الهدف:** إصلاح تفسير Manifest ودعم الإعدادات الاختيارية دون رفض الإضافات السليمة.

**المهام:**
1. تدقيق parser الحالي لسلوك `behaviorHints.configurable` و`configurationRequired`.
2. اعتبار `configurable: true` وحدها إشارة إلى إمكانية التهيئة، لا دليلاً تلقائياً على أن الإضافة لا تعمل دون config.
3. عدم فرض شاشة إعداد إلزامية إلا إذا أعلن العقد بوضوح أن configuration is required أو أعاد الخادم توجيهاً موثقاً إلى configuration URL.
4. التحقق من أنواع catalog وresource وtype وidPrefixes وbase URL.
5. دعم `movie` و`series` وأنواع المحتوى التي يعلنها Manifest فعلياً، دون تعميم غير مبرر.
6. إدارة إعداد URL/query/config لكل إضافة بشكل مستقل، مع عدم تسجيل tokens.
7. احترام `idPrefixes` وعدم اختراع IMDb/TMDB identifiers عند غيابها.
8. استخدام MediaIdentity resolver الموجود لإثراء IMDb عند حاجة الإضافة فقط.
9. اختبار YaStream أولاً بعد الحصول على Manifest live مؤكد، ثم بقية المرشحين كل على حدة.
10. التعامل مع Manifest مكسور/متغير/غير متاح دون تعطيل باقي الإضافات.

**معيار القبول:** الإضافة ذات `configurable: true` و`configurationRequired: false` لا تُرفض لمجرد configurable؛ ولا يتم إرسال معرف لا تقبله `idPrefixes`.

**سجل تنفيذ Phase 40 (2026-11-07):** أضيف تفسير منفصل لـ`configurable` و`configurationRequired`، وParser محدود لـ`config` وCatalogs والموارد، وملفات تعريف `stream` خاصة بكل نوع وبادئات المعرفات، ورابط `/configure` لا يكشف query tokens، واختبارات Parser/Client/Provider/identity مع Fixture YaStream. لم تُشغّل اختبارات Dart/Flutter أو Release Build في بيئة التنفيذ؛ لذلك تبقى المرحلة `In Progress` حتى نجاح CI والتحقق الحي. راجع ملفات `PHASE40_STREMIO_MANIFEST_CONFIGURATION_*.md`.

**إغلاق بوابة CI لPhase 40 (2026-11-07):** أكّد المستخدم نجاح GitHub Actions run `42384394976`: dependency resolution ناجح؛ Dart format `26 files (0 changed)`؛ `flutter analyze` أبلغ `No issues found!`؛ ملفات Phase 40 الأربعة نفذت 44 اختبارًا ناجحًا؛ Release APK أُنتج بحجم 27,936,634 bytes (26.64 MiB) وبـABI `arm64-v8a` فقط. لذلك أُغلقت بوابة Phase 40 CI. لا يعني ذلك نجاح playback حي للإضافات، ولا يغلق تلقائيًا كل اختبارات الجهاز/اعتماد Phases 37/37.1/38/39.


### Phase 40 — latest CI regression follow-up 2 (2026-11-07)

CI run `42375238484` on commit `b165afffb67b023e8f151f6b92070269a19c5581` passed dependency resolution, Dart format, `flutter analyze` and 160 focused tests, then failed the Phase 40 regression gate with four widget failures. The exact causes and corrections are recorded in `PHASE40_CI_WIDGET_REGRESSION_RECOVERY_FOLLOWUP_2_2026-11-07.md`: the RevealItem test must deliver its zero-delay stagger timer before measuring animation progress; tests must scroll until lazy Sliver targets are built before `ensureVisible`; and `TvFocusable` must update an internally owned FocusNode's diagnostic label when its semantic label changes. The visible subtitle selection already changed to 15px; the stale value was in `FocusNode.debugLabel`, not the saved setting or UI. The complete Flutter suite, Gradle wrapper generation, Release ARM64 APK build and ABI audit were skipped. Phase 40 remains In Progress; Phase 41 remains Not Started.


### Phase 40 — Minimal automatic APK CI gate (2026-11-07)

The user-supplied latest analyzer excerpt identified a redundant `flutter/widgets.dart` import in `test/support/scroll_until_built.dart`; the import has been removed. The automatic Android APK workflow previously ran a 15-file broad source/provider suite, a separate 17-file UI/regression suite, and the complete Flutter test directory. Those overlapping, mostly out-of-scope test batches have been removed from the automatic APK path. The workflow now runs only the four test files named in `PHASE40_STREMIO_MANIFEST_CONFIGURATION_TESTS.md`: `source_repository_parser_test.dart`, `source_repository_client_test.dart`, `stremio_addon_provider_test.dart`, and `unified_source_service_stremio_identity_test.dart`. Legacy test files remain in the repository for explicit QA; they are not deleted. A 10-minute step timeout and 30-second per-test timeout guard the required set. YAML, Bash, report-generator Python and path checks passed statically; Flutter/Dart and Android build tools are unavailable in this packaging environment, so no successful Analyze/test/Release claim is made. Phase 40 remains In Progress.

### Phase 41 — VidKing Direct Language & Quality

**الهدف:** الفصل الواضح بين جودة الفيديو ولغة الصوت.

**المهام:**
1. إضافة خاصية مستقلة للصوت (`audioLanguage`) في descriptor/normalizer عند الحاجة، بعد مراجعة توافق الفهارس.
2. الاستمرار في استخدام `qualityFilter` للجودة فقط.
3. نقل قيم Vyse/Fade الحالية من الحقل الخاطئ إلى الحقل الصحيح عبر adapter توافق رجعي مضبوط.
4. عدم تحويل كل قيمة نصية إلى لغة تلقائياً؛ يلزم قاموس لغات/قواعد معتمدة.
5. تعريف أولوية اللغة: إعداد المستخدم، إعداد المصدر، ثم القيمة الافتراضية للمصدر.
6. فصل لغة الصوت عن لغة الترجمة وعن لغة المصدر.
7. اختبار 720p/1080p/4K مع English/Hindi/Arabic مستقلين.
8. التأكد من أن filter لا يستبعد stream صالحاً بسبب عدم تطابق حقل غير متعلق به.

**معيار القبول:** اختيار Hindi/English لا يدخل في مقارنات الجودة؛ واختيار 1080p لا يغير اللغة.

**سجل بدء وتنفيذ Phase 41 (2026-11-07):** بعد اعتماد بوابة Phase40، بدأ فصل لغة الصوت عن الجودة في VidKing. أضيف `SourceEngineDescriptor.audioLanguage` و`VidkingAudioQualityNormalizer` بقائمة سماح للغات والدقات، وترحيل legacy لقيم Vyse/Fade، مع حفظ معامل Killjoy القديم. أضيف تمرير `preferredAudioLanguage` من إعداد مستقل محفوظ عبر SettingsPreferences/SettingsProvider وواجهة Player Settings على Mobile وTV وProviderLoader إلى UnifiedSourceService/Registry وVidKing، وأصبح `qualityFilter` يقارن ارتفاع الفيديو فقط. بقية محركات المصادر تقبل الوسيط دون استخدامه. بوابة CI أصبحت 12 ملف اختبار محددًا تغطي عقود 37/37.1/38 وStremio Phase40 وVidKing Phase41، مع مهلة 10 دقائق و30 ثانية لكل اختبار، ولا تشغّل المجموعة الكاملة أو اختبارات UI العامة. التنفيذ مضاف لكنه غير معتمد قبل CI جديد (Analyze + 12 files + Release ARM64). راجع `PHASE41_VIDKING_LANGUAGE_QUALITY_*.md`.

### Phase 42 — Repository Versioning, Integrity & Security

**ملاحظة تسلسل:** كان النص السابق يوصي بانتظار اعتماد Phase41؛ تم استبدال هذه التوصية بقرار المستخدم الصريح في 2026-11-07 ببدء Phase42 مباشرةً. لا يعني ذلك اعتماد Phase41.

**حالة التنفيذ (2026-11-07):** نُفّذت طبقات version history/snapshot integrity وcommit pin وpreview/rollback/provenance وQuickJS bridge hardening وnetwork host policy في فرع Phase42 الجاري. تشمل السياسة جميع محركات HTTP المباشرة: repository، QuickJS، Stremio، VidKing Direct وOpenStream Anime/Web Embed، إضافةً إلى فحص local/private على WebView bridge. التنفيذ لم يجتز CI بعد. راجع `PHASE42_REPOSITORY_VERSIONING_SECURITY_PLAN.md` و`_AUDIT.md` و`_IMPLEMENTATION.md` و`_TESTS.md` و`_CHANGELOG.md` و`_REPORT.md`. بدأ المستخدم هذه المرحلة مباشرةً قبل اعتماد Phase41؛ تم احترام هذا التوجيه دون تسجيل Phase41 كمرحلة ناجحة.


**الهدف:** جعل تحديثات المستودعات قابلة للتدقيق والرجوع، وتقليل مخاطر تنفيذ JavaScript خارجي.

**المهام:**
1. توسيع `SourceRepositoryManager` الحالي وعدم إعادة بناء مزامنته من الصفر.
2. تثبيت snapshot للفهرس ووقت التحقق وHTTP status وcommit hash عند توفره.
3. حفظ المصدر الأصلي ونسخة script/manifest حسب سياسة cache واضحة.
4. حساب content hash للملف وفحص تغيّر المصدر بين التحديثات.
5. دعم pin version/commit عند توفر مرجع ثابت.
6. إظهار التغيير قبل التحديث، مع rollback إلى آخر نسخة محفوظة.
7. اكتشاف التكرار عبر source identity وcanonical URL/name/domain/script hash مع عدم حذف نسخ مختلفة تلقائياً.
8. تسجيل مصدر كل إضافة ومؤلفها ورابطها وإصدارها.
9. حصر واجهات QuickJS bridge (HTTP, crypto, timers, console, extraction) وفق أقل صلاحيات لازمة.
10. منع الوصول المباشر إلى tokens/credentials أو filesystem أو Android APIs من JS.
11. وضع قيود request host policy وtimeouts وresponse size وredirect limits، ومراجعة حماية SSRF.
12. عدم اعتبار hash بديلاً عن مراجعة الثقة؛ فهو يكشف التغيير ولا يثبت سلامة المصدر.

**معيار القبول:** يمكن معرفة ما تغير في كل إضافة والعودة للإصدار السابق؛ ولا تتجاوز الإضافة صلاحيات bridge المحددة.

### Phase 43 — OpenStream Sources Integration

**الهدف:** توسيع المحركات الأصلية المستخدمة بالفعل في RAVEN23 بمصادر OpenStream الموثقة.

**المهام:**
1. جرد ما يدعمه index الفعلي مقابل `sourceEngineKindFrom` و`SourceEngineRegistry.standard`.
2. تدقيق أسماء engines وحالات beta/disabled/experimental.
3. البدء بمجموعة VidKing Direct: Yoru وCypher وBreach وNeon؛ ثم Omen وRaze احتياطياً؛ ثم Vyse وFade وKilljoy بعد Phase 41.
4. الحفاظ على OpenStream anime engines: Re:Anime وFourAnimo وAnikoto وAnimeGG وAnimePahe كما هي في العقد الذي يعلنه الفهرس الحالي، لا حسب أسماء ثابتة.
5. اختبار مصدر أفلام ومصدر مسلسل وحلقة أنمي وفيلم أنمي حيث يدعم ذلك المصدر.
6. دعم الجودة والصوت والترجمة وheaders/expiry من خلال UnifiedStreamOption.
7. عدم تغيير player engine أو طريقته في تمرير headers.
8. إظهار Beta status كما هو وتسجيل اختبارات إضافية قبل رفع الحالة.

**معيار القبول:** كل مصدر مفعّل لديه fixture وcontract test وحالة واضحة؛ ولا يُعتبر Playback Verified إلا بعد اختبار رابط فعلي صالح.

**سجل تنفيذ 2026-11-07:** الفهرس الرسمي الحي جرى التحقق منه واحتوى 30 إدخالاً (9 VidKing Direct، 5 Anime، 5 Stremio، 10 Web Embed، 1 VidKing WebView). أُضيفت اختبارات exact route mapping لكل VidKing وTV coordinates، وAniList/ani.zip mapping لحلقة S2E4 وفيلم أنمي، وتغطية Beta/fallback/lifecycle؛ أضيف تمرير expiry الصريح إلى UnifiedStreamOption دون إنشاء TTL. بوابة CI تضم 15 ملفاً محدداً من اعتماديات Phase37/38 وPhase40/41/42 وعقود Phase43، مع إبقاء full suite ودفعات UI خارج APK gate. التنفيذ جاهز لكن CI وRelease ARM64 لم يُشغّلا في بيئة التعبئة؛ الحالة `In Progress / CI Pending`. راجع `PHASE43_OPENSTREAM_SOURCES_*.md`.

### Phase 44 — Zangetsu & Spyhell QuickJS Integration

**الهدف:** إدخال مجموعات الإضافات على دفعات قابلة للقياس، مع عدم فرض نوع غير معلن على الإضافة.

**الحزم الداخلية:**
- **44.1 Foundation:** parser, identity, settings, runtime sandbox, diagnostics.
- **44.2 Movies:** 4K HDHub، UHD Movies، HDHub4u، VegaMovies، MultiMovies، CineStream، StreamPlay، ثم مرشحو Spyhell مثل Filmzie وMoviesJoy وARTE وNHK World والمكتبات الأرشيفية بعد تصنيف حقوق المحتوى.
- **44.3 Series:** MyAsianTV، Dramacool، CineStream، StreamPlay، TheNkiri، ومصادر HDHub عند ثبوت دعمها للحلقات.
- **44.4 Anime Core:** HiAnime، AnimeSuge، AnimeX، AnimeSalt، AnimeCube، Anikoto، AnimeKai، AniWave، AnimeGG، AnimeDrive، AnimixStream، GoGoAnime.
- **44.5 Specialized:** DonghuaNation، NekoSama، Samehadaku، AnimeWorld، Aniworld، Anoboy، MonosChinos، JKanime، HindiAnime وغيرها حسب الفهرس الحي.
- **44.6 Latin:** AnimeAV1، AnimeJL، AnimeYTX، ونسخة JKanime واحدة مختارة بعد مقارنة manifests/scripts.
- **44.7 Live Source Adapters:** لا تُمرر إضافات `getHome()` الخاصة بالقنوات إلى QuickJS movie/series pipeline؛ تُحوّل إلى عقد Live TV مخصص ضمن Phase 47.
- **44.8 Archive/VOD classification:** فصل VOD عن أرشيفات الفيديو وعن البث الخطي، وفحص حقوق التوزيع لكل مصدر.
- **44.9 Deduplication & Validation:** اختبار تكرار المصدر نفسه بين المستودعات دون حذف نسخ بديلة تلقائياً.

**متطلبات كل مصدر:**
1. تحقق من الفهرس والسكربت والإصدار.
2. قراءة `getInfo()` و`getSettings()` إن وجد.
3. اختبار `search()` بfixture أو حساب حقيقي متاح.
4. اختبار `getDetail()` و`getEpisodes()` للمحتوى الحلقي.
5. إثبات `seasonNumber`/`episodeNumber` أو آلية URL موثوقة.
6. اختبار `getVideoSources()` ومطابقة headers/language/subtitles/expiry.
7. توثيق ما يعمل وما لم يُختبر.

**قاعدة متعددة الأنواع:** إذا أعلن المصدر `movie` فقط فلا نغيره إلى `all` لمجرد وجود دوال حلقات. يجب فحص الكود وإثبات مسار series ثم إجراء patch adapter أو manifest override موثق، مع اختبار مستقل.

**معيار القبول:** لا يفعّل أي مصدر في القسم الخطأ، ولا يسبب مصدر مكسور أو بطيء فشل بقية المصادر.

### Phase 45 — Source Execution, Ranking & Fallback

**الهدف:** توحيد جدولة المحركات وتحسين تجربة النتائج دون التضحية بإتاحة تبديل الخوادم.

**المهام:**
1. تدقيق ProviderLoader الحالي وآلية 8-second fallback التي وثقتها Phase 8.
2. تدقيق `SourceEngineRegistry.resolveMany` والتوازي المحدود الذي يبدأ حالياً افتراضياً بواحد.
3. وضع execution policy واحدة قابلة للضبط حسب المحرك، لا قيمة توازٍ عامة عمياء.
4. بدء المصادر ذات الأداء الأفضل سابقاً مع احترام الأولوية والقيود.
5. إظهار أول نتيجة قابلة للتشغيل فوراً مع استمرار جمع بدائل الخوادم ضمن مهلة محددة.
6. إضافة remembered last-working source إن لم يكن موجوداً، مع head-start منفصل ومحدود، بعد إثباته بالاختبارات.
7. إضافة resolved-stream cache وفق صلاحية الرابط/انتهائه وخصوصية الهوية.
8. إضافة circuit breaker وcooldown بعد عدد فشل محدد (مثلاً 5) بعد قياس مناسب، وعدم اعتبار الفشل المؤقت الدليل الوحيد لتعطيل المصدر.
9. احترام cancellation ومنع callback بعد إلغاء الشاشة.
10. تجميع metrics: latency، empty results، HTTP status class، extraction errors، play verification حيث تتوفر إشارة.
11. عدم إرسال URLs أو tokens حساسة إلى Analytics.
12. إبقاء ترتيب النتائج مستقرّاً وإتاحة اختيار المستخدم.

**معيار القبول:** أول نتيجة تظهر بسرعة مع بقاء البدائل؛ فشل مصدر مستقل؛ لا عمليات زائدة بعد الإلغاء؛ وترتيب المصادر يستند إلى بيانات حقيقية لا قيم ثابتة غير مفسرة.

### Phase 46 — Unified Live TV Service Manager

**الهدف:** استكمال منظومة Live TV الموجودة بدلاً من ربط الشاشات مباشرة بـDaddyLive.

**الموجود الذي يجب الحفاظ عليه:** `LiveTvService` و`DaddyLiveService` و`EthioSportsService` و`Channel` و`DaddyLiveStream` و`DaddyLiveCatalog` و`LiveTVDatabaseController` و`LivePlayer`.

**المهام:**
1. تحديد سبب تعطيل اختيار EthioSports في واجهتي الهاتف والتلفاز.
2. تصميم manager يختار الخدمة بالمعرف، ويملك lifecycle لكل خدمة.
3. تطوير نماذج عامة للقناة والكتالوج والتدفق إن لزم، مع adapters للحفاظ على التوافق مع أسماء DaddyLive الحالية.
4. وضع contract موحد لـcatalog/stream/categories/refresh/close/health.
5. ربط الشاشتين بـmanager بدلاً من إنشاء DaddyLive مباشرة.
6. إعادة تفعيل الاختيار بين DaddyLive وEthioSports بعد اجتياز اختبارات regression.
7. توسيع namespace لكل مزود دون اختلاط المفضلات والسجل.
8. توحيد حالات Loading/Empty/Error/Unavailable/Blocked.
9. التحقق من headers وexpiry وmediaType وclearKey/DRM fields وفق سياسات التشغيل المسموح بها، دون تجاوز DRM.
10. الحفاظ على EPG الحالي الذي يوفره DaddyLive كميزة مزود، لا جعله شرطاً لكل خدمة.

**معيار القبول:** DaddyLive يبقى يعمل كما كان؛ EthioSports قابل للاختيار بعد التأهيل؛ وكل خدمة جديدة يمكن إضافتها دون تعديل منطق واجهات الهاتف والتلفاز مرة أخرى.

### Phase 47 — IPTV / M3U Engine & Spyhell Live Adapters

**الهدف:** إضافة مصادر قنوات IPTV إلى Live TV الحالي، لا إلى Unified Movies/Series pipeline.

**المهام:**
1. بناء parser لـM3U وEXTM3U وEXTINF مع دعم attributes والاقتباسات.
2. قراءة `tvg-id` و`tvg-logo` و`group-title` واسم القناة ورابطها.
3. إنشاء channel stable ID namespaced؛ تفضيل `tvg-id` مع تجنب تصادم IDs بين المصادر، ثم fallback hash مستقر مبني على حقول غير متغيرة.
4. التمييز بين M3U channel list وHLS media playlist.
5. دعم ملفات remote/local فقط وفق صلاحيات التطبيق، دون افتراض مسارات غير متاحة.
6. توفير refresh/cache/etag أو last-modified عند توفرها، وحدود حجم/عدد القنوات.
7. إزالة التكرارات داخل المصدر مع الحفاظ على نسخ القنوات عبر مزودين مختلفين.
8. دعم HTTP headers عند الحاجة ضمن allowlist وسياسة آمنة.
9. بناء adapter منفصل لإضافات Spyhell التي تستخدم `getHome()` ومجموعات القنوات.
10. mapping من group-title إلى فئات RAVEN23 دون اعتبار أسماء الفئات معياراً موحداً عالمياً.
11. اختبار التشغيل على LivePlayer، والتعامل مع القناة غير المتاحة بوضوح.
12. تفعيل مجموعات World/Sports/News/Documentary/Entertainment/Movies/Series/Animation/Kids/Music/Travel/Comedy/Cooking/Education على دفعات بعد الفحص.
13. تصنيف Movies Live TV وSeries Live TV وAnimation Live TV كقنوات خطية لا ككتالوج VOD.
14. توثيق التوافر الجغرافي وحقوق القناة عند معرفة المصدر؛ لا تجاوز القيود.

**معيار القبول:** قوائم M3U تُعرض كمجموعات قنوات، ويعمل رابط صالح عبر LivePlayer، ولا تظهر القنوات في بحث الأفلام أو المسلسلات.

### Phase 48 — Pluto TV Live Adapter

**الهدف:** إضافة Pluto TV كمزود قنوات خطية ضمن Live TV، مع عدم افتراض وجود واجهة عامة أو الإذن باستخدام endpoints داخلية.

**نتيجة التدقيق:** ملف الفهرس يذكر `plutotv` كنوع `movie` ويشير إلى `providers/plutotv.js`، لكن السكربت غير موجود في ملفات المشروع. شروط Pluto الرسمية تمنع استخدام واجهة غير واجهتها وجمع المحتوى آلياً دون تصريح وتجاوز geo-filtering/DRM. لم يقدّم المشروع عقد API عام أو تصريح شريك. لذلك لا يجوز بناء محول على API غير موثّق أو tokens أو scraping.

**المهام المنفذة وفق مسار Experimental:**
1. تسجيل Pluto TV في Live TV manager كخدمة `Experimental` مستقلة.
2. عزل التخزين في namespace خاص.
3. إبقاء بيانات القنوات وVOD منفصلة؛ لا تفعيل سجل `movie` في VOD.
4. عدم جلب قنوات/شعارات/تصنيفات أو استخراج stream دون API مصرح به.
5. عرض حالة `Unavailable` واضحة دون status code أو ادعاء تشغيل.
6. توفير إحالة خارجية فقط إلى `https://pluto.tv/` من الهاتف والتلفاز.
7. الإبقاء على فحوصات 401/403/geo restrictions ضمن السياسة: احترامها وعدم الالتفاف عليها.

**معيار القبول:** إما قناة مصرح بها تعمل عبر Live TV manager وLivePlayer، أو مزود Experimental/Unavailable موثق مع إحالة خارجية رسمية. الحالة الحالية تحقق المسار الثاني؛ لا تعتبر تكاملاً داخلياً أو Playback Verified.

### Phase 49 — XMLTV / EPG

**الهدف:** دليل برامج عام لا يعتمد على نموذج DaddyLive فقط.

**المهام:**
1. بناء XMLTV parser مع حدود للملف/الذاكرة والكيانات غير الصالحة.
2. دعم القنوات والبرامج والتوقيتات والتكرار/التداخل.
3. تطبيع الوقت إلى UTC داخلياً وعرضه حسب المنطقة الزمنية للمستخدم/القناة وفق مصدر موثوق.
4. مطابقة XMLTV channel id مع `tvg-id` عبر mapping صريح.
5. دعم مصادر EPG متعددة حسب المزود.
6. تخزين مؤقت مع TTL وآلية stale data واضحة.
7. حساب Now/Next من التوقيتات لا من ترتيب النصوص.
8. عدم عرض برنامج حالي أو تالٍ إذا كانت البيانات قديمة/غير متطابقة.
9. عزل غياب EPG عن تحميل قائمة القنوات وتشغيلها.
10. ترحيل تدريجي من `DaddyLiveEpg` إلى abstraction عام مع adapter رجعي.

**معيار القبول:** قناة M3U يمكن أن تعمل دون EPG؛ وعند توفر XMLTV صحيح يظهر البرنامج الحالي والتالي بتوقيت مضبوط.

**سجل تنفيذ (2026-11-08):** تم إعداد نماذج XMLTV مستقلة وparser/repository/mapper، وربط `tvg-id` وروابط EPG القادمة من M3U، مع compatibility adapter إلى `DaddyLiveEpg`. التحقق البرمجي وCI وRelease ما زال pending؛ راجع `PHASE49_XMLTV_EPG_*.md`. المرحلة التالية Phase50.

### Phase 50 — WebView & Embedded Playback Integration

**الهدف:** استكمال المحركات الحالية `webEmbed` و`vidkingWebView` للمصادر التي تحتاج سياق متصفح حقيقياً.

**المهام:**
1. تدقيق `OpenStreamWebEmbedSourceEngine` و`QuickJsProviderRuntime` وطبقة WebView الموجودة.
2. الفصل بين extract HTTP stream وembedded player الذي يجب تشغيله داخل WebView.
3. إدارة جلسة وcookies وheaders ضمن نطاق المصدر ووفق سياسة الخصوصية.
4. إلغاء الجلسة والعمليات عند الخروج من الشاشة.
5. دعم Redirect وDeep-link والروابط المؤقتة بطريقة آمنة.
6. كشف نوع embed وعدم تمرير صفحة HTML إلى video player على أنها HLS.
7. إظهار حالة الانتظار/التحقق/الرفض/غير المدعوم.
8. دعم Android Mobile وAndroid TV مع بدائل UI مناسبة للتحكم عن بعد.
9. عدم تجاوز CAPTCHA أو Cloudflare أو DRM أو geo restrictions؛ يمكن عرض صفحة التحقق للمستخدم فقط إذا سمحت شروط الخدمة ولا يتطلب ذلك تحايلاً.
10. منع JavaScript من التحكم في WebView خارج bridge محدود وآمن.

**معيار القبول:** صفحة embed مدعومة تفتح ضمن WebView instance مخصصة لدورة حياة الشاشة وتعيد نتيجة مفهومة؛ تمرر فقط Referer/Origin/User-Agent الأولية المسموحة؛ لا يُدّعى وجود CookieJar معزول لأن Android CookieManager مشترك على مستوى عملية التطبيق. فشل التحقق لا يسبب حلقة إعادة فتح لا نهائية أو حجب مصادر أخرى.

**سجل تنفيذ (2026-11-08):** تم إعداد نتيجة منفصلة لـEmbedded HTML، ومررها عبر Legacy adapter، وإضافة شاشة Android WebView مرئية مع حالات واضحة وسياسة تنقل محدودة، وإزالة التشغيل/النقر الآلي من capture script، والإبقاء على عقد `resolveUrl` القديم. تم تحديث provider scan وMobile/TV loaders ومشغل المصدر والكاش وCI إلى 29 اختبارًا محددًا. التنفيذ وCI والجهاز ما زالت pending؛ راجع `PHASE50_WEBVIEW_EMBEDDED_PLAYBACK_*.md`. المرحلة التالية Phase51.

### Phase 51 — Integration, Regression & Release Gate

**الهدف:** تثبيت التوافق الكامل واعتماد Release قابل للبناء والتجربة.

**بوابات الاختبار:**
1. `dart format --set-exit-if-changed` على الملفات المتغيرة.
2. `flutter analyze` دون أخطاء؛ والتحذيرات الجديدة يجب توثيقها أو إصلاحها.
3. `flutter test` على الاختبارات المرتبطة ثم المجموعة الكاملة.
4. Unit/contract tests للمحركات: QuickJS، Stremio، VidKing، OpenStream، Live TV، M3U، XMLTV.
5. Fixtures ثابتة لجميع ردود الفهارس/Manifests/الحلقات/M3U/XMLTV.
6. اختبارات واجهة الهاتف والتلفاز لاختيار المصادر وتغيير المزود.
7. اختبارات تشغيل حقيقية منفصلة عن CI، مع توثيق البلد/الوقت/الاستجابة وعدم ضمان الاستمرار.
8. اختبار Regression للمشغل، الترجمة، الجودة، Headers، subtitles، watch progress، downloads، favorites، player defaults، themes وads contracts.
9. `flutter build apk --release` أو أمر GitHub Actions المعتمد للمشروع، مع flavors/defines نفسها المستخدمة في CI.
10. التأكد من سياسة ABI واسم APK وإعدادات Release المعتمدة في وثائق المشروع، وعدم تغييرها دون طلب.
11. فحص حجم ZIP وسلامة الأرشيف وقائمة الملفات والتأكد من عدم وجود أسرار.
12. تسليم المشروع كاملاً مع Phase Report ونتائج CI الحقيقية.

**معيار القبول النهائي:** كل فشل بناء أو اختبار معروف محلول؛ جميع الاختبارات المقررة موثقة؛ لا يتم وصف المصدر بأنه Playback Verified دون اختبار فعلي؛ Release Build ناجح على GitHub Actions أو بيئة Flutter موثوقة.

**سجل تنفيذ Phase51 (2026-11-08، محدث 2026-11-10):** تم تدقيق بوابة Android CI وإضافة 10 مجموعات Regression مشتركة إلى 29 اختبار عقد قائم، ليصبح الإجمالي 39 ملف اختبار صريحاً. اجتاز التشغيل النهائي `42507906881` التحليل والتنسيق والاختبارات الـ302 وتجميع Kotlin/Gradle وبناء Release وفحص APK ARM64. الحالة: `Accepted`. راجع `PHASE51_INTEGRATION_REGRESSION_RELEASE_GATE_REPORT.md`.

**سجل Phase51:** كانت هناك محاولات CI وسيطة قبل النجاح النهائي. جميعها متجاوزة بنتيجة Release الناجحة في run `42507906881`، ولا تمثل أعطالًا مفتوحة. تفاصيل القبول في `PHASE51_INTEGRATION_REGRESSION_RELEASE_GATE_REPORT.md`.



## 6. نظام اعتماد المصدر

يجب فصل مراحل اكتشاف المصدر عن إثبات عمله:

| الحالة | معناها | ما تسمح به |
|---|---|---|
| Discovered | ظهر في الفهرس | العرض في الكتالوج فقط |
| Manifest Verified | بيانات الفهرس/Manifest سليمة | تثبيت تجريبي |
| Contract Verified | عقده متوافق مع محركه | اختبارات محلية/Fixtures |
| Runtime Verified | دواله تعمل دون أخطاء عقدية | تشغيل اختباري |
| Playback Verified | رابط حقيقي صالح عمل في اختبار موثق | إمكانية التوصية به كمصدر عامل |
| Experimental | Beta أو جزئي أو غير مستقر | ترتيب تجريبي وإظهار الحالة |
| Blocked | 403/Cloudflare/قيود/متطلبات غير متاحة | عدم وعد المستخدم بالتشغيل |
| Duplicate Candidate | احتمال تكرار | مقارنة يدوية/آلية قبل إخفاء نسخة |
| Retired | لم يعد صالحاً أو أزيل من المصدر | حفظ سجل الإصدار وسبب الإزالة |

**لا تنتقل الإضافة إلى Playback Verified بمجرد نجاح `getVideoSources()`؛ يلزم نجاح فتح stream مع Headers/expiry والقدرة على تشغيله في player test.**

## 7. سياسة التكرار بين المستودعات

- `stableKey` الحالي repository URL + source ID صالح لمنع التصادم داخل هوية التثبيت، ويجب الحفاظ عليه ما لم توجد خطة ترحيل.
- التكرار بين المستودعات يحتاج fingerprint متعدد الإشارات: canonical homepage/domain، script URL/hash، اسم الإضافة، المؤلف، engine، metadata.
- تشابه الاسم وحده لا يكفي لإخفاء نسخة.
- النسخ البديلة يمكن الاحتفاظ بها مع رابط المستودع والإصدار.
- Anikoto وAnimeGG وJKanime وأسماء أخرى في تقرير المستخدم مرشحو تكرار، وليس حكماً مسبقاً بأن الكود متطابق.

## 8. سياسة الاختبارات

### CI deterministic

- لا تعتمد على توفر مواقع خارجية في لحظة تنفيذ GitHub Actions.
- تستخدم Mock HTTP وfixtures ثابتة ومسارات error tests.
- تمنع regressions في parsing وrouting وsource selection وplayer handoff.

### Live smoke tests

- تشغيل اختياري منفصل عن CI الأساسي.
- لا يرسل أسرار المستخدم إلى artifacts.
- يسجل HTTP status/latency/result category بعد تنقية الروابط والتوكنات.
- لا يضعف Release gate إذا تعذر موقع خارجي مؤقتاً؛ تسجل حالة المصدر Unavailable/Not verified.

### Regression غير قابل للتفاوض

- الحفاظ على Phase 8 playback handoff وUnifiedStreamOption/header mapping.
- الحفاظ على Phase 28/32/34/35 Anime classification وhome/search/details flow.
- الحفاظ على Phase 34 subtitle defaults وPhase 31 assets.
- عدم تغيير مفاتيح التخزين الحالية دون migration test.
- اختبار Mobile وAndroid TV لكل feature مشتركة.

## 9. قواعد التنفيذ لكل مهمة

1. قراءة هذه الوثيقة والمرحلة السابقة ذات الصلة.
2. فتح الملفات الفعلية المتأثرة وقراءة callers/callees/tests، لا الاكتفاء باسم الملف.
3. إعداد قائمة الملفات المتوقع تعديلها قبل التعديل.
4. إذا كشف الفحص أن ميزة موجودة، توثيقها واختبارها بدلاً من إعادة تنفيذها.
5. تنفيذ مجموعة صغيرة مترابطة من التعديلات.
6. إضافة tests قبل/مع الإصلاح؛ لا تكتفِ بفحص regex أو بناء شكلي.
7. تشغيل formatter/analyzer/tests المتاحة.
8. إن لم يتوفر Flutter/Dart، ذكر ذلك صراحة وعدم ادعاء نجاح بناء.
9. إنشاء تقرير مرحلة يضم الملفات المعدلة وغير المعدلة المهمة، الاختبارات ونتائجها، المخاطر والمهام المؤجلة.
10. عدم بدء المرحلة التابعة قبل قبول معايير المرحلة الحالية.
11. تسليم أرشيف المشروع الكامل ببنية المجلدات الأصلية عند تعدد الملفات المعدلة.

## 10. القرارات المفتوحة التي تحسم في Phase 36

- الرابط الرسمي الدقيق لمستودع Spyou Additional Providers.
- هل جميع الفهارس الستة متاحة الآن؟ وما إصداراتها/commits الحالية؟
- هل كل المصادر التي ذكرها تقرير التدقيق ما زالت موجودة في snapshots الحالية؟
- الفروق الفعلية بين scripts المكررة، لا مجرد تشابه الاسم.
- شكل `getSettings()` الواقعي لدى كل مجموعة QuickJS.
- شكل `getHome()` في إضافات Live TV التي يلزم تكييفها.
- هل بعض مصادر Pluto TV تستخدم واجهات رسمية متاحة في نطاق الاستخدام، وما حدود التوافر الإقليمي؟
- XMLTV feeds المرشحة وشروطها وتواتر تحديثها.
- سبب تعليق اختيار EthioSports في الهاتف والتلفاز، وهل هناك قرار سابق وراء التعليق.
- حالة الاختبارات والبناء الحالية قبل Phase 36.

**لا تُحسم هذه النقاط بالافتراض أو بإنشاء روابط/IDs غير موثقة.**

## 11. تعريف الاكتمال

يعد هذا البرنامج مكتملاً عندما:
- جميع المراحل 36–51 اجتازت معايير قبولها أو وُثقت الاستثناءات التي لم تعتمد.
- جميع الإضافات الموجودة في الكتالوج تحمل حالة موثقة ودقيقة.
- لا تتداخل مصادر Live TV مع VOD.
- يستطيع المستخدم اختيار/تعطيل/تحديث/استرجاع مصادره دون فقدان بيانات المشاهدة.
- لا يؤدي مصدر فاشل إلى تعطيل غيره.
- يعمل مشغل الهاتف والتلفاز بالعقود الحالية بعد التوسعة.
- يمر المشروع بتحليل واختبارات وبناء Release موثق.

---

**تنبيه حالة:** هذه الوثيقة خطة شاملة وليست تقرير تنفيذ. إضافة هذه الوثيقة إلى المشروع لا تعني أن أي Phase من 36 إلى 51 قد نُفذت أو أن أي مصدر خارجي أصبح عاملاً.


## 6. نتيجة Phase 36 — 2026-11-06

اكتمل التدقيق الساكن في `PHASE36_AUDIT_REPORT.md`. تم التحقق من الفهارس الستة (142 سجل فهرس قبل إزالة التكرار)، وتثبيت رابط Spyou Additional Providers الصحيح، وإثبات 404 لمسار Spyhell Latin `index.ison`. تم فحص عينات JavaScript وتوثيق مشكلات declared type/series وQuickJS season matching وStremio configurable وVidKing language/quality وLive TV `getHome()` وغياب `nsfw` metadata في Spyhell.

**قرار الجاهزية:** Phase 37 جاهزة للبدء في التصميم والعقود. لا تُدمج تغييرات وظيفية قبل تسجيل Release CI baseline ناجح أو إصلاح فشله المحدد. لم يتم تعديل كود التطبيق ضمن Phase 36.

المخرجات:
- `PHASE36_AUDIT_REPORT.md`
- `SOURCE_REPOSITORY_SNAPSHOT.json`
- `SOURCE_COMPATIBILITY_MATRIX.md`
- `PHASE36_CANDIDATE_FILES_AND_GAPS.md`


**تحديث متابعة Phase 40 (2026-11-07):** بعد نجاح Analyze في CI، فشلت 7 اختبارات مركزة من 145. أضيفت معالجة empty URI fragment والتحقق من Manifest المرشح الذي يفتقد resources، مع اختبارات regression وexpanded test reporter. لا تعتبر هذه الإصلاحات معتمدة قبل إعادة تشغيل CI. راجع `PHASE40_CI_STREMIO_TEST_RECOVERY.md`.


**Phase 40 follow-up (2026-11-07):** أحدث تشغيل للاختبارات المركزة بعد إصلاح Manifest أظهر `140 passed / 5 failed`، وكانت الفروق الخمسة كلها بسبب ظهور `?` فارغة في رابط `/configure`. إصلاح `Uri.removeFragment()` السابق لم يكن كافياً لأن `replace(query: '')` ينشئ Query فارغاً صريحاً. أُعيد الآن بناء رابط الإعداد من scheme/host/port/path فقط، مع حذف Query الفارغ من endpoint runtime والحفاظ على Query غير الفارغ. أضيف اختبار `removes empty query markers from derived Stremio URLs`. تبقى Phase 40 `In Progress` حتى إعادة CI بنجاح. راجع `PHASE40_CI_STREMIO_TEST_RECOVERY.md`.


## Phase 40 — Full-suite widget/settings follow-up (2026-11-07)

The latest supplied CI run `42331596314` passed Dart format, Flutter analyze, and focused source/architecture tests, then failed the full suite with 2,155 passed, 23 failed, and 11 skipped. The failure set is no longer the earlier provider-scan close/timeout defect; it comprises widget visibility lifecycle, current settings defaults, subtitle serialization, OpenSubtitles fixtures/headers, URL container inference, legacy quality labels, seasonal date-window resolution, and lazy Sliver test assumptions. Targeted recovery changes and a shared test-only `VisibilityDetectorController.updateInterval = Duration.zero` helper are prepared. The report’s EasyLocalization warnings were checked against all four locale assets: every extracted warning key exists, so no placeholder translation keys are to be added. This follow-up is not CI-verified; Phase 40 remains In Progress and Phase 41 remains blocked. See `PHASE40_CI_FULL_SUITE_WIDGET_SETTINGS_RECOVERY_2026-11-07.md`.


## Phase 44/45 implementation prepared — 2026-11-07

- Phase 44: reused the existing QuickJS runtime and six bundled repository indexes; added nullable safety-declaration state, Live TV vs VOD guards for known Spyhell `getHome()` source IDs, archive/credential-review labels, type-preserving Zangetsu parsing, and non-destructive duplicate tests. Current index audit: OpenStream 30, Spyou Zangetsu 9, Serenity-MIST 5, Spyhell Experiment 89, Spyou Additional 5, Spyhell Latin 4 (142 index records; discovery only).
- Phase 45: added configurable per-engine concurrency, reserved fallback worker, first-playable callback, stable priority/health ordering, hash-only last-working preference, explicit-expiry-only in-memory cache, temporary retryable-failure circuit breaker, cancellation guards and privacy-safe metrics. Existing `ProviderScanSession` remains the player-facing coordinator; its queue is now engine-capacity-aware without changing the player adapter or eight-second fallback policy.
- Deferred validation: `.github/workflows/android-ci.yml` and `tool/format_phase37_45_dart.sh` now target 19 explicit test files (including 13 unified-execution cases and a separate player-scan fairness case) across dependencies 37–43 and phases 44/45. No full Flutter suite is included.
- `dart format`, `flutter analyze`, selected tests, Release ARM64 APK and Android device playback were not run in the packaging environment; all post-change acceptance remains pending. Phase 41/42/43 remain CI pending and are not retroactively accepted.
- Detailed records: `PHASE44_ZANGETSU_SPYHELL_QUICKJS_*.md` and `PHASE45_SOURCE_EXECUTION_*.md`.





### Phase 52 — Source Repository Audit & VOD Priority Lanes (2026-11-09)

**Objective:** audit the six bundled source indexes and selected scripts, then add independently persisted Movies, Series and Anime search-priority lists with editable order and category-specific language/capability gates.

**Curated initial order:** Movies 13; Series 9; Anime 11. Series intentionally remains below 10 because only nine candidates meet reviewed exact-episode and runtime requirements; Movie-only records are not promoted to fill the list. Multi-content providers may participate in both Movies and Series. Japanese/Chinese declared language is allowed only in Anime; Movies/Series accept English and declared Multi. Two reviewed Serenity scripts have a narrow Series exception, but exact season and episode matching remains mandatory.

**Activation and fallback:** first-run activation union is capped at 15 unique source records per repository. A search exhausts the selected priority tier first, then all remaining installed/eligible direct providers for the same content category, then embedded/WebView fallbacks. Removing an entry demotes it to backup without uninstalling it. An intentionally empty priority list still routes every eligible direct provider through the backup tier.

**Audit decisions:** NetPrime remains backup-only due browser-signed/IP-bound embed behavior; HDHub4u and AniLibria are excluded for declared-language/script mismatch; SubsPlease is excluded because it returns torrent/magnet links not accepted by the current HTTP(S) source mapper; known adult and Live TV records are excluded from VOD. Upstream status is displayed as a declaration, not an uptime check.

**Implementation record:** `source_priority_manager.dart`, `source_priority_policy.dart`, parser metadata-declaration flags, `UnifiedSourceService` tier orchestration, and the `REPOSITORIES` management UI. The automatic Phase52 gate was narrowed to 25 Phase52-specific selected cases across five files and the 16 Phase52-changed Dart files rather than the accumulated cross-phase test batch. Version `4.4.0+12`. The project owner later confirmed successful builds through PHASE55, so Phase52 is accepted; transient analyzer/test runs were superseded and their individual failure-note files were removed from the active phase folder.


**Phase52 CI scope decision (2026-11-09):** the workflow was narrowed to the 25 Phase52-specific selected cases across five files and the 16 Dart files changed in Phase52, rather than replaying accumulated Phase37–51 test suites. The owner later confirmed successful builds through PHASE55; Phase52 is accepted.