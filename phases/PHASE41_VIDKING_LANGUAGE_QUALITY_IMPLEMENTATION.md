# Phase 41 — Implementation

## العقود والبيانات

- أضيف `SourceEngineDescriptor.audioLanguage` كحقل اختياري additive.
- وُثّق `language` كمعامل legacy خاص بالمحرك، و`qualityFilter` كفلتر دقة فيديو فقط.
- أضيف `VidkingAudioQualityNormalizer` لتوحيد allowlisted language aliases وvideo-resolution aliases، بما فيها `4K HDR` كـ`2160p`.
- تطبيع descriptor خاص بـVidKing فقط؛ بقية المحركات تعيد descriptor نفسه دون تعديلات.

## سلوك VidKing

- يطبّع descriptor قبل بناء الطلب وتحليل النتيجة.
- أولوية لغة الصوت الداخلية: `preferredAudioLanguage` ثم `audioLanguage` الصريح/المرحّل من `qualityFilter` ثم `language` القديم إذا كان معروفًا.
- إذا كان `engine.language` القديم هو القيمة الوحيدة، يحافظ الطلب على النص الأصلي كما هو (مثل `german`) للتوافق مع endpoint؛ وتظل بيانات الصوت الداخلية مطبّعة إلى `German`. أما تفضيل المستخدم و`audioLanguage` الصريح فيُرسلان بصيغة اسم اللغة الموحّد.
- يضيف معامل `language` للطلب فقط عند توفر قيمة.
- يطبق `qualityFilter` على ارتفاع الفيديو فقط عبر `VideoUtils.videoQualityHeight`.
- عند عدم معرفة دقة stream الفعلية، يحتفظ به بدل حذفه.
- في Master Playlist adaptive، تُحفظ لغة الصوت المختارة في `UnifiedStreamOption.audioLanguage`، بينما لا تُفرض جودة مفردة على playlist.
- تُقرأ لغة الصوت من `audioLanguage` أو `language` أو `lang` في بيانات stream، ثم fallback إلى اللغة المختارة للمصدر.
- يبقى `audioKind` مشتقًا من أوصاف المسار فقط (`audioKind`, `audioType`, `label`)، ولا يستنتج من اللغة أو الجودة أو `sourceType`.
- لا تتداخل subtitles مع هذا المسار؛ قائمة الترجمات تُحوّل كما كانت إلى `UnifiedSubtitleTrack`.

## تمرير تفضيل المستخدم

أضيف الوسيط الاختياري `preferredAudioLanguage` إلى:
- `UnifiedSourceService.search`
- `SourceEngineRegistry.resolveMany` و`resolve`
- عقد `SourceEngine.resolve`
- `VidkingDirectSourceEngine` و`VidkingDirectProvider`

كما أضيف إعداد مستقل محفوظ عبر `SettingsPreferences` و`SettingsProvider`، وتظهر واجهته في إعدادات المشغل على Mobile وTV. يقرأ `ProviderLoader` القيمة عند بدء بحث المصادر ويمررها إلى UnifiedSourceService؛ القيمة الافتراضية `Auto` تعني عدم إرسال تفضيل للمحرك. تقبل بقية المحركات الوسيط ولا تستخدمه، لذلك لا يتغير سلوكها.

## توافق الفهرس

يُطبّع VidKing فقط أثناء parsing. Vyse/Fade القديمان يتحولان من `qualityFilter` إلى `audioLanguage`. Killjoy يحتفظ بـ`engine.language` القديم؛ ويُحل إلى German كقيمة افتراضية للصوت دون نسخه إلى `audioLanguage`، مع الحفاظ على معامل الطلب القديم.

## حدود التغيير

لا تغيير في مشغل الفيديو أو كاش الترجمة أو اختيار الجودة داخل المشغل. أضيفت إعدادات مستقلة للغة صوت VidKing فقط على Mobile وTV؛ لا يُعاد استخدام لغة الترجمة أو لغة واجهة التطبيق لهذا الغرض.
