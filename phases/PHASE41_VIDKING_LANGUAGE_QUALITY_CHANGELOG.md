# Phase 41 — Changelog

## ملفات الإنتاج المعدلة

- `lib/video_providers/unified/source_manifest.dart` — field contract `audioLanguage` موثق ومستقل عن `language` و`qualityFilter`.
- `lib/video_providers/unified/vidking_audio_quality_normalizer.dart` — normalizer جديد بقائمة سماح للغات والدقات وترحيل legacy؛ `4K HDR`/`UHD HDR` كدقة 2160p، مع إبقاء `engine.language` legacy selector منفصلًا.
- `lib/video_providers/unified/source_repository_parser.dart` — parse صريح لـ`audioLanguage` و`qualityFilter` وتطبيع VidKing فقط.
- `lib/video_providers/unified/source_repository_client.dart` — حفظ audioLanguage عند إعادة بناء descriptor.
- `lib/video_providers/unified/source_engine.dart` — تمرير تفضيل الصوت الاختياري في عقد المحرك والـregistry.
- `lib/video_providers/unified/unified_source_service.dart` — تمرير تفضيل الصوت الاختياري من واجهة الخدمة.
- `lib/preferences/setting_preferences.dart` و`lib/provider/settings_provider.dart` و`lib/main.dart` — حفظ تفضيل VidKing المستقل وتحميله عند بدء التطبيق.
- `lib/video_providers/provider_loader.dart` — تمرير القيمة المحفوظة إلى UnifiedSourceService عند البحث الفعلي.
- `lib/screens/common/player_settings.dart` و`lib/tv/screens/tv_settings_screen.dart` — اختيار لغة صوت VidKing مستقلة على Mobile وTV.
- `assets/translations/{en,ar,es,hi}.json` — تسميات وخلاصة التفضيل الجديدة.
- `lib/video_providers/unified/vidking_direct_provider.dart` — فصل query language عن quality resolution وعن stream audioKind، مع الحفاظ على كتابة legacy query عند كونها المصدر الوحيد.
- `lib/video_providers/unified/quickjs_source_engine.dart` و`openstream_web_embed_engine.dart` و`openstream_anime_engine.dart` — قبول الوسيط الاختياري دون استعماله للمحافظة على تطابق العقد.

## ملفات الاختبار المعدلة/المضافة

- `test/video_providers/source_repository_parser_test.dart` — explicit language/quality parsing بالإضافة إلى اختبار fixture legacy.
- `test/video_providers/source_engine_contract_test.dart` — مواءمة fake engine لعقد resolve الاختياري.
- `test/video_providers/vidking_direct_provider_test.dart` — أولوية لغة المستخدم مقابل default المصدر.
- `test/video_providers/vidking_audio_quality_normalizer_test.dart` — اختبارات normalizer والمصفوفة المستقلة.
- `test/settings_vidking_audio_language_test.dart` — default Auto وحفظ/استعادة تفضيل الصوت المستقل.
- `test/fixtures/openstream_official_repo.json` بقي دون تغيير عمدًا.

## CI وformatter

- `.github/workflows/android-ci.yml` يشغّل 12 ملف اختبار محددًا تشمل عقود الاعتمادات السابقة وPhase40/41 واختبار تخزين تفضيل الصوت، دون full-suite أو دفعات UI العامة.
- `tool/format_phase37_41_dart.sh` هو قائمة الملفات المصدرية والاختبارية المنسقة.
- `tool/format_phase37_40_dart.sh` بقي كواجهة توافق تستدعي سكربت 37–41.

## التراجع

تُراجع القائمة أعلاه ويُعاد آخر commit معروف صالح إذا كشف CI فشلًا. لا تُحذف ملفات الاختبارات القديمة أو fixture؛ ولا يُعاد إدخال مجموعات UI/full-suite إلى البوابة التلقائية لمجرد فشل غير متعلق. يجب تصحيح السبب المحدد ثم إعادة تشغيل مجموعة الاختبارات المطلوبة.
