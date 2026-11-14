# RAVEN23 — Phase 36 Initial Baseline Audit

## حالة التدقيق

- **الهدف:** تسجيل خط أساس أولي من أرشيف Phase 35.1 قبل كتابة الخطة التنفيذية.
- **نوع الفحص:** قراءة ملفات المصدر والـphase reports محلياً.
- **التغييرات الوظيفية:** لا توجد في هذه الخطوة.
- **لا يمثل هذا المستند إغلاق Phase 36:** لم تتم بعد إعادة جلب وفحص الفهارس الستة الحية ولا اختبار جميع الإضافات أو تشغيل CI.

## 1. الأرشيف المفحوص

- الملف: `RAVEN23-PHASE35.1-TV-ANIME-TYPE-FIX.zip`
- عدد مدخلات ZIP: 1314
- نتيجة اختبار سلامة ZIP: `testzip() = None`
- جذر المشروع: `RAVEN23/`
- مجلد التوثيق: `RAVEN23/phases/` ويحتوي 49 ملفاً/مدخلاً وقت الفحص.

## 2. ملفات/طبقات المصادر المؤكدة

| الملف | ملاحظة من الكود الحالي |
|---|---|
| `lib/video_providers/unified/source_engine.dart` | `SourceEngine` و`SourceEngineRegistry` و`resolveMany` بحد توازٍ `maxConcurrency`، الافتراضي 1 |
| `lib/video_providers/unified/source_manifest.dart` | `SourceManifest` و`SourceEngineDescriptor` و`SourceEngineKind` وقدرات `supportsMedia` |
| `lib/video_providers/unified/source_repository_manager.dart` | إضافة/إزالة repository، تثبيت/إلغاء مصدر، تعطيل المصادر الافتراضية، cache TTL خمس دقائق، والاحتفاظ بآخر كتالوج عند تعذر refresh |
| `lib/video_providers/unified/source_repository_parser.dart` | محلل لأشكال OpenStream وZangetsu وStremio وغيرها؛ يحتاج اختبارات تغطية لكل مستودع |
| `lib/video_providers/unified/quickjs_source_engine.dart` | يقرأ `getInfo` ثم `search` ثم `getDetail`/episodes ثم `getVideoSources`؛ يطبق declared type routing |
| `lib/video_providers/unified/quickjs/js_bootstrap.dart` | `globalThis.__settings` موجود كحامل؛ يكتشف `getSettings` ضمن API المكشوفة |
| `lib/video_providers/unified/stremio_addon_provider.dart` | موفر Stremio قائم مع معالجة معرفات وStreams |
| `lib/video_providers/unified/vidking_direct_provider.dart` | مرشح الجودة يقرأ `qualityFilter`؛ يوجد مسار يشتق `audioLanguage` من `qualityFilter` قبل/ضمن metadata |
| `lib/video_providers/unified/openstream_anime_engine.dart` | محرك أنمي أصلي قائم يجب الحفاظ عليه |
| `lib/video_providers/unified/openstream_web_embed_engine.dart` | محرك Web Embed قائم |
| `lib/video_providers/unified/media_identity.dart` | هوية موحدة للمحتوى للمحركات |
| `lib/video_providers/unified/stream_option.dart` | نموذج `UnifiedStreamOption` يحوي بيانات stream وaudio/subtitle metadata |

## 3. Live TV الموجود

| الملف | ما تأكد |
|---|---|
| `lib/services/daddylive_service.dart` | يعرّف `LiveTvService`، و`DaddyLiveService` يطبقه؛ `getCatalog` و`getStream` و`close` |
| `lib/services/ethio_sports_service.dart` | `EthioSportsService` يطبق `LiveTvService` ويحوّل IDs إلى namespace `ethio:` |
| `lib/models/live_tv.dart` | نماذج القنوات والبث ودليل DaddyLive الحالية |
| `lib/controllers/live_tv_database_controller.dart` | namespace افتراضي `daddylive` ومفاتيح مستقلة للقنوات/المفضلات/السجل/EPG |
| `lib/screens/common/live_tv_screen.dart` | مسارات اختيار EthioSports وخدماته ظاهرة داخل تعليقات؛ يلزم معرفة سبب التعطيل قبل إعادتها |
| `lib/tv/screens/tv_live_screen.dart` | مسارات الاختيار نفسها تقريباً موجودة داخل تعليقات |
| `lib/screens/common/live_player.dart` | المشغل الحالي الذي يجب أن يبقى نقطة تسليم للقنوات |

**استنتاج:** لا حاجة إلى إنشاء واجهة `LiveTvService` جديدة. المطلوب manager/adapter حول العقد الموجود، مع تعميم نماذج `DaddyLiveCatalog`/`DaddyLiveStream` تدريجياً إن كان ذلك ضرورياً للتوافق مع IPTV وPluto.

## 4. قواعد ومراحل يجب حمايتها

- Phase 8: source identity، TMDB-to-IMDb، OpenStream anime mapping، QuickJS contract، headers/player hand-off، وfallback head-start.
- Phase 11: Anime classification.
- Phase 28: Anime Discover/New & Hot/Search مع بقائه TV episodic.
- Phase 31: أصول العلامة.
- Phase 32: Top Rated Anime وAnime في Streaming/Search واللون الافتراضي.
- Phase 34: صيانة Phase 32 وPlayer subtitle defaults.
- Phase 35: Trending/Popular/New Episodes Anime وstudio/network catalog separation.
- Phase 35.1: إصلاح Dart type في Android TV Trending Anime.

## 5. فجوات محتملة تستحق التحقق

1. `SourceRepositoryManager` يمنع المصدر المكرر عبر `stableKey` المرتبط بعنوان المستودع ومعرف المصدر؛ لكنه لا يثبت هوية التكرار عبر مستودعات مختلفة.
2. `SourceManifest.supportsMedia` يطبق tags وanime rules؛ يجب اختبار التوافق مع provider types لكل فهرس، وعدم اعتبار `all` بديلاً عن تصنيف كل نتيجة.
3. `getSettings()` مكتشف في bootstrap لكن واجهة إعدادات المستخدم وتخزين schema لكل إضافة يحتاجان إلى تحقق/استكمال.
4. محلل Stremio يتضمن حالياً شرطاً يحتاج مراجعة لـ`configurable` و`configurationRequired` في سطرَي parser المعنيين.
5. VidKing Direct يحتاج فصلاً بين `qualityFilter` و`audioLanguage`.
6. Live TV provider selector موجود بصورة معطلة بالتعليقات في الهاتف والتلفاز.
7. لا يوجد من نتائج الفحص الأولي ما يثبت وجود XMLTV parser عام مستقل؛ EPG الحالي موصول بعقد DaddyLive.
8. لا توجد نتائج فحص حية موثقة هنا لجميع قوائم Spyhell/Zangetsu أو كل روابط تشغيلها.

## 6. ما بقي لإغلاق Phase 36

- إعادة الوصول للفهارس الستة باستخدام الروابط الدقيقة.
- تأكيد الرابط الدقيق لمستودع Spyou Additional Providers.
- حفظ snapshots وتواريخ وHTTP statuses وcommit hashes.
- تنزيل scripts وفحص دوالها الفعلية لكل المصدر المرشح.
- إنتاج matrix حالات `Discovered / Manifest Verified / Contract Verified / Runtime Verified / Playback Verified`.
- تشغيل baseline `flutter analyze` و`flutter test` وRelease build عبر CI المعتمد، أو تسجيل فشل البيئة دون ادعاء النجاح.
- فحص سبب تعليق اختيار EthioSports ودراسة المخاطر على قواعد البيانات/المفضلات.

## النتيجة الأولية

البنية الأساسية للمصادر وLive TV أكثر تقدماً مما يوحي به وصف إنشاء الأنظمة من الصفر. الخطة المعتمدة يجب أن **تستكمل** `SourceRepositoryManager` و`SourceEngineRegistry` و`LiveTvService` الحالية بدلاً من إنشاء بدائل موازية. لم يتم تغيير أي ملف وظيفي في Phase 36 Initial Baseline Audit.


## Phase 36 final audit pointer (2026-11-06)

The subsequent live repository and selected-script audit is recorded in `PHASE36_AUDIT_REPORT.md`. Normalized index records and explicit limitations are in `SOURCE_REPOSITORY_SNAPSHOT.json`; contract findings are in `SOURCE_COMPATIBILITY_MATRIX.md`. The earlier report above remains the initial local-code baseline and is not the final source-index audit.
