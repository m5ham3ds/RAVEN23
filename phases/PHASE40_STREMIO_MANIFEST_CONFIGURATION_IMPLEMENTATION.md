# Phase 40 — Stremio Manifest & Configuration Engine — Implementation

**التاريخ:** 2026-11-07  
**الحالة:** Implementation added; runtime/build acceptance pending

## التنفيذ

### Manifest parser

- التحقق من `resources`, `types`, `idPrefixes`, `catalogs`, `behaviorHints`, و`config` عند وجودها.
- دعم موارد Stremio النصية والكائنية وحفظ `streamResourceProfiles` منفصلة حسب `types` و`idPrefixes`.
- مورد `stream` النصي يستخدم `idPrefixes` الجذر عند وجودها؛ غيابها يعني قبول المعرفات المتاحة دون تقييد تلقائي بـIMDb.
- مورد `stream` الكائني يحترم ملف تعريفه الخاص؛ غياب `idPrefixes` فيه لا يرث قيد الجذر.
- تطبيع أنواع المحتوى إلى lowercase فقط، مع الاحتفاظ بحالة الأحرف في prefixes وخيارات config/catalog.
- تحليل Catalogs وحقول `extra` ضمن حدود: 128 كتالوجاً، 32 extra لكل كتالوج، 100 خيار و128 حرفاً للخيار.
- تحليل Config schema المدعوم: `text`, `number`, `password`, `checkbox`, `select`؛ 64 حقل كحد أقصى، 100 خيار، مع تجاهل الأنواع غير المدعومة والمفاتيح المكررة والحقول المشوهة.
- لا يتم تخزين `default` الخاص بحقل password في `SourceManifest`.

### Configuration behavior

- `configurable` يعني أن رابط إعداد الإضافة متاح، ولا يعطل streams وحده.
- `configurationRequired` يظل شرطاً مستقلاً ويمنع تنفيذ stream قبل الإعداد.
- يتم إنشاء `/configure` مع الاحتفاظ بالمسار الأساسي وإزالة query/fragment لمنع كشف tokens في المتصفح.
- تعرض إدارة المصادر علامة «الإعداد متاح اختيارياً» أو «الإعداد مطلوب»، وتفتح الصفحة الخارجية فقط بعد تحذير المستخدم بأن بيانات الاعتماد يجب أن تبقى على موقع الإضافة.
- في حال قدمت الصفحة manifest URL مهيأ، ينسخه المستخدم ويضيفه إلى مدير المصادر. لا يرسل RAVEN23 بيانات اعتماد إلى الإضافة نيابةً عن المستخدم.

### Stream ID resolution

- اختيار Resource Profile المطابق لنوع Movie/Series فقط.
- دعم explicit Stremio ID وIMDb عند الإعلان عنه، ودعم TMDB فقط عند إعلان prefix ملائم صراحة.
- لا يتم اصطناع prefix خارجي إلا عند توفر المعرف من `MediaIdentity` ووجود بادئة معلنة مطابقة.
- يتم رفض إحداثيات الحلقة المتعارضة مع season/episode المطلوبة.
- يحافظ stream endpoint على path/query المخصصين للإضافة، مع تنقية رموزها من diagnostics.
- يستمر الاقتصار على Direct HTTP(S) streams المدعومة بمسار التشغيل الحالي؛ لا يتم الإبلاغ عن روابط torrent أو YouTube على أنها تشغيل جاهز.

### Repository & runtime compatibility

- تم الاحتفاظ بـ`SourceRepositoryClient`, `SourceEngineRegistry`, `StremioSourceEngine`, ومشغل RAVEN23 الحالي.
- فشل جلب Manifest إضافة أو تعذر تحليلها يبقى محصوراً في تلك الإضافة وفق client الحالي؛ لم تتم إضافة fallback يتجاوز المصادقة أو الحماية.
- أضيف Fixture ثابت لـYaStream لاختبار Parser دون الاعتماد على شبكة CI.

## ملاحظات وحدود

- `configurationSchema` يصف الحقول المعلنة ويختبرها Parser؛ مسار الإعداد الفعلي ما زال صفحة `/configure` التابعة للإضافة، وليس محرر إعدادات عام داخل التطبيق.
- لا تثبت Fixture صحة الروابط الحية أو صلاحية التشغيل.
- لا يوجد تحقق Android runtime أو جهاز Mobile/TV ضمن هذه البيئة.


## CI formatting recovery (2026-11-07)

The first submitted CI log reported 35 formatting changes across 36 gated Dart files. The check used `--output=none`, so it reported drift without writing formatter output and exited with status 1. The workflow now invokes `tool/format_phase37_40_dart.sh --fix` followed by `--check` using the Dart version bundled with the pinned Flutter 3.35.7 toolchain, and uploads the resulting git diff as `RAVEN23-dart-format-patch`. The workflow does not auto-commit the patch. A green format gate and all later gates remain unverified until CI is rerun.


## CI follow-up — URI hygiene and invalid Manifest detection (2026-11-07)

- `_stremioBaseUrl` now uses `Uri.removeFragment()` after removing `/manifest.json`. Query data is retained for runtime requests, while an empty `#` is not emitted.
- `_stremioConfigurationUrl` clears query data, then removes the fragment component entirely. This prevents per-user query tokens and empty fragment markers from reaching the configuration page.
- `SourceRepositoryClient` removes fragments from derived base/manifest URLs without dropping the original query parameters.
- `_isStremioManifest` now identifies a manifest-like object from `id` plus any Stremio-specific field. A missing `resources` array is therefore rejected by `_parseStremioManifest` rather than silently parsed as an empty generic repository.
- Regression assertions verify no URI fragment is present. CI test reporter changed to `expanded` to make remaining failures easier to diagnose.
- Runtime tests remain pending; this environment has no Dart/Flutter SDK.

### URI empty-query normalization follow-up

The `/configure` URL is now constructed using `Uri(scheme:, host:, port:, pathSegments:)` rather than setting `query: ''` on `Uri.replace`. The constructor therefore omits query and fragment components entirely. Runtime base endpoints preserve non-empty configured query data, but an explicitly empty query delimiter is removed. This avoids both the trailing `?` observed in CI and disclosure of private query tokens in the browser configuration URL.
