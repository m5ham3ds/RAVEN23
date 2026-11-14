# RAVEN23 — Phase 36 Comprehensive Source Audit

- **تاريخ التحقق:** 2026-11-06
- **قاعدة المشروع:** `RAVEN23-MASTER-IMPLEMENTATION-BLUEPRINT-PHASE36-51.zip` المبني على Phase 35.1
- **النطاق:** تدقيق الكود المحلي + الفهارس الحية الستة + قراءة ساكنة لعينات JavaScript محددة
- **نوع المرحلة:** Audit / Documentation only
- **الحالة:** **Passed with limitations** — اكتمل التدقيق الثابت؛ لا تزال اختبارات runtime/playback وبناء CI مسؤولية بوابات المراحل التالية.
- **تغييرات التطبيق:** لا توجد. لم تتغير ملفات `lib/` أو `test/` أو `assets/` أو إعدادات البناء.

## 1. الملخص التنفيذي

تم التحقق من وصول محتوى الفهارس الستة عبر روابط Raw GitHub الصحيحة في تاريخ الفحص. عدد السجلات المعلن في هذا Snapshot هو **142 سجل فهرس** عبر المستودعات الستة (30 + 9 + 5 + 89 + 5 + 4). هذا عدد سجلات، وليس عدد مصادر فريدة؛ توجد تكرارات مؤكدة/مرشحة بين المستودعات.

تأكد عنوان Spyou Additional Providers بدقة:

`https://raw.githubusercontent.com/Spyou/Zangetsu-spyou-provider/main/index.json`

كما ثبت أن Spyhell Latin الصحيح هو `index.json`، وأن المسار السابق `index.ison` يعيد **404 Not Found**.

أهم النتائج البرمجية:

1. المشروع لا يحتاج إلى Source Registry أو Live TV interface موازٍ؛ توجد بالفعل `SourceRepositoryManager` و`SourceRepositoryParser` و`SourceEngineRegistry` و`LiveTvService`.
2. محلل QuickJS يرفض طلب المسلسلات مبكراً إذا أعلن `getInfo().type` القيمة `movie`، حتى إذا احتوى ملف الإضافة على دوال حلقات وموسم. تم تأكيد هذا التعارض في Serenity CineStream وStreamPlay.
3. كود 4K HDHub يعلن `movie` في الفهرس و`getInfo()`؛ لا يوجد إثبات حالي يسمح بتفعيل المسلسلات له.
4. QuickJS يسمح بمطابقة رقم الحلقة عند غياب رقم الموسم حتى لو كان الموسم المطلوب معروفاً. هذا قد يطابق موسمًا غير صحيح، ويجب إصلاحه في Phase 38.
5. `getSettings` مكشوف داخل Bootstrap لكن لم يظهر استدعاء له من طبقة تشغيل/إدارة الإعدادات؛ `__settings` مجرد كائن ابتدائي، وليس نظام إعدادات محفوظاً لكل إضافة.
6. Stremio parser يعد `configurable == true` مانعاً للتشغيل حتى عندما تكون `configurationRequired == false`؛ يحتاج ذلك إلى fixtures واختبارات Manifest قبل التغيير في Phase 40.
7. VidKing Direct يستخدم `qualityFilter` لفلترة دقة الفيديو، ويستخدم القيمة نفسها كـ`audioLanguage` في بعض المخرجات؛ وهذا يفسر تعارض English/Hindi مع مرشح الجودة.
8. مصادر Live TV في Spyhell تعتمد في بعض الحالات على `getHome()` ومعرّفات URI مخصصة مثل `worldtv://`، بينما محرك QuickJS العام يعالج مسار VOD المعتاد. لا يجوز تمريرها إلى Movie pipeline أو اعتبارها روابط HTTP عادية.
9. فهارس Spyhell لا تتضمن حقل `nsfw` صريحاً، مع وجود مصادر ذات طبيعة محتوى للبالغين. المحلل الافتراضي يجعل غياب الحقل `false`؛ لذلك يلزم تصنيف آمن قبل تثبيت/إظهار هذه المصادر.
10. بيئة التحرير لا تحتوي Flutter أو Dart؛ لم يتم تنفيذ Analyze/Test/Release Build محلياً. ملف CI يثبت Flutter 3.35.7 وJava 17 وGradle 8.7 ويبني Release افتراضياً مع ARM64 فقط.

## 2. نطاق الأدلة ودرجات اليقين

| الدرجة | معناها | ما الذي تسمح به |
|---|---|---|
| Index Retrieved | محتوى الفهرس الحي قُرئ | إثبات وجود السجل وإصداره ونوعه المعلن فقط |
| Script Inspected | ملف JS/كود موفر فُحص ساكناً | إثبات ما يعلنه/يحتويه الكود، لا نجاح الشبكة |
| Contract Verified (static) | توافق معلن/دوال/نوع تم فحصها | يصلح لتحديد فجوات العقد؛ لا يثبت تشغيل الموقع |
| Runtime Verified | تشغيل الإضافة في QuickJS مع Fixtures أو بيئة مضبوطة | لم يُنفذ في Phase 36 |
| Playback Verified | رابط حقيقي شُغّل داخل التطبيق | لم يُنفذ في Phase 36 |

**مهم:** `Index Retrieved` لا يعني أن الموقع متاح للمستخدم الآن، و`Script Inspected` لا يعني أن مزود الفيديو أو CDN يعمل. لم يتم وصف أي مصدر بأنه Playback Verified.

## 3. سجل المستودعات الستة

تمت قراءة الفهارس النصية عبر Raw GitHub. أداة التصفح لم تعرض status code رقمياً لطلبات الفهارس الناجحة، لذلك حُفظت قيمة `httpStatus` كـ`null` بدلاً من اختلاق `200`. رابط `index.ison` الخاطئ أعاد 404 صراحة.

| # | المستودع | الفهرس المؤكد | تنسيق/إجمالي الأسطر | عدد سجلات الفهرس | النتيجة |
|---:|---|---|---:|---:|---|
| 1 | OpenStream Official | `https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json` | OpenStream JSON / 604 | 30 | Retrieved |
| 2 | Spyou Zangetsu Providers | `https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json` | Zangetsu JSON / 96 | 9 | Retrieved |
| 3 | Serenity-MIST Zangetsu Sources | `https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json` | Zangetsu JSON / 56 | 5 | Retrieved |
| 4 | Spyhell Experiment | `https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json` | Zangetsu JSON / 807 | 89 | Retrieved; wide mixed catalog |
| 5 | Spyou Additional Providers | `https://raw.githubusercontent.com/Spyou/Zangetsu-spyou-provider/main/index.json` | Zangetsu JSON / 11 | 5 | Retrieved; exact repo URL confirmed |
| 6 | Spyhell Latin Sources | `https://raw.githubusercontent.com/Spyhell/spyou-latin-zan/main/index.json` | Zangetsu JSON / 42 | 4 | Retrieved; corrected path confirmed |

**طريقة العدد:** OpenStream count was checked against the checked-in official fixture and the live index structure. Counts for the Zangetsu indexes were enumerated from their `sources` arrays; Spyhell Experiment's 89 records were counted from the repeating source-object blocks across its 807-line index. The 142 total is therefore an index-row count, not global deduplicated providers.

### 3.1 OpenStream Official — 30 entries

- 9 VidKing Direct routes: Yoru, Cypher, Breach, Neon, Vyse, Killjoy, Fade, Omen, Raze.
- 5 anime-site routes: Anikoto, Re:Anime, AnimePahe, FourAnimo, AnimeGG.
- 5 Stremio routes: HdHub, YaStream, Zeus, FrostStream, FenixFlix.
- 10 Web Embed routes: Jett, Sage, Sova, Phoenix, Reyna, Viper, Skye, Astra, Harbor, Gekko.
- 1 VidKing WebView compatibility/fallback entry.

Local fixture `test/fixtures/openstream_official_repo.json` also contains 30 entries and tests the 5 Stremio and 10 Web Embed families. Live index showed Yoru/Cypher/Breach/Neon version 1.1.0 with `updatedAt` 2026-08-29. OpenStream index also contains `qualityFilter: English` for Vyse and `Hindi` for Fade; that confirms the exact metadata shape currently misused as quality by the provider.

### 3.2 Spyou Zangetsu Providers — 9 entries

- AniKoto 1.0.8 (anime)
- 4K HDHub 1.0.6 (movie)
- UHD Movies 1.0.3 (movie)
- HDHub4u 1.2.4 (movie)
- HiAnime 1.2.2 (anime)
- VegaMovies 1.0.4 (movie, `hi`)
- MultiMovies 1.0.3 (movie, `hi`)
- AnimeCube 1.0.5 (anime, `zh`)
- TorBox 1.0.0 (movie; integration needs its own authentication/configuration review)

### 3.3 Serenity-MIST — 5 entries

- Anikoto 0.2.9 (anime)
- AnimeKai 0.2.9 (anime)
- AniWave 0.2.9 (anime)
- StreamPlay 0.2.9 (index says movie)
- CineStream 0.2.9 (index says movie)

The repository's description says it includes CineStream and StreamPlay with settings. Static script inspection confirms their implementation contains series/season/episode code, but the top-level `TYPE` and `getInfo()` still return `movie`. This is a manifest/runtime-contract mismatch, not permission to change their type blindly.

### 3.4 Spyhell Experiment — 89 entries

The index is a mixed catalog containing movie-type sources, anime-type sources, VOD/archive sources, and live channel providers. Confirmed examples include AnimeSuge, AnimeX, AnimeTosho, SubsPlease, Archive Anime, ARTE TV, NHK World, Pluto TV, MoviesJoy, Prelinger Archives, and multiple Live TV groups (including Kids, News, Documentary, Entertainment, Series, Animation, Cooking and Education Live TV). The file-level inventory should be treated as 89 separate records pending full per-script contract tests.

The index does **not** contain an explicit `nsfw` field. The parser sets `isNsfw` to false when the field is absent, and the repository UI only marks a source based on that parsed flag. Adult-oriented providers in this index therefore cannot be trusted to be safely labelled by the current metadata. Do not auto-install/enable them until a fail-safe classification and visibility policy exists.

### 3.5 Spyou Additional Providers — 5 entries

- AnimeLok 1.0.0 (anime, `hi`)
- AnimeSalt 1.0.0 (anime, `hi`)
- AnimixStream 1.0.0 (anime, `hi`)
- NetPrime 1.0.0 (movie, `en`)
- AnimeDrive 1.0.1 (anime, `hi`)

Exact index URL: `https://raw.githubusercontent.com/Spyou/Zangetsu-spyou-provider/main/index.json`. The earlier report's informal repo description was not sufficient to build a URL; the verified repository path is now recorded above.

### 3.6 Spyhell Latin — 4 entries

- AnimeAV1 1.0.0 (`es`)
- AnimeJL 1.0.0 (`es`)
- Jkanime 1.0.0 (`es`)
- AnimeYTX 1.0.1 (`es`)

Correct path: `index.json`. The path `index.ison` was checked and returned 404.

## 4. Selected source-script static inspections

| Source | Exact file path | Declared type | Static code finding | Phase 36 conclusion |
|---|---|---|---|---|
| HiAnime | Spyou `providers/hianime.js` | anime | Search/detail/episode/server flow and stream/subtitle mapping are present; source comments note server variability | Anime contract inspected; runtime/playback unverified |
| AnimeCube | Spyou `providers/animecube.js` | anime | Chinese-language source; code uses embed/HLS routes | Anime/Donghua candidate; runtime/playback unverified |
| 4K HDHub | Spyou `providers/fourkhdhub.js` | movie | `getInfo()` agrees with movie declaration | Movie-only contract as currently advertised; no series claim accepted |
| AnimeSuge | Spyhell `providers/animesuge.js` | anime | Multi-server/extractor logic and stream metadata are present | Anime contract inspected; encrypted/host chain not runtime verified |
| World Live TV | Spyhell `providers/worldlivetv.js` | movie in index/getInfo | `getHome()` returns channel groups; channel identity uses `worldtv://`; getVideoSources resolves channel HLS | Live TV adapter required; not a VOD movie source |
| AnimeSalt | Spyou Additional `providers/animesalt.js` | anime | Season/episode identifiers and multi-audio HLS metadata are represented in code | Episode/audio contract inspected; runtime/playback unverified |
| Serenity CineStream | Serenity `serenity-cinestream.js` | movie in `TYPE`/`getInfo()` | Code has movie/series catalog branches, season and episode resolution | Series implementation is unreachable through current QuickJS type gate until the contract is fixed |
| Serenity StreamPlay | Serenity `serenity-streamplay.js` | movie in `TYPE`/`getInfo()` | Code has movie/series branches and episode extraction | Same series contract mismatch; no type override without targeted tests |

Static inspection only. None of these scripts was executed in QuickJS in Phase 36. No live video was played.

## 5. Confirmed local implementation findings

### 5.1 Repository parser / client / manager

- `SourceRepositoryParser` handles OpenStream descriptor indexes, Zangetsu `sources` indexes, raw lists, and Stremio manifests.
- Zangetsu paths are resolved relative to the index URL; scripts must resolve to HTTP(S) `.js`/`.mjs` endpoints.
- `SourceRepositoryManager` seeds only OpenStream as the default first-run repository. The remaining five repositories are not automatically seeded in this code snapshot; they must be added by repository management/configuration.
- Source stable identity is `${repositoryUrl}::${id}`. This avoids duplicate IDs inside one repo but does not deduplicate the same site across different repos.
- Catalog caching is five minutes and the last known catalog is retained when refresh fails; preserve this offline/continuity behavior.

### 5.2 QuickJS capability and episode matching

- `QuickJsSourceEngine.resolve()` calls `getInfo()` first and rejects a requested type that conflicts with the declared `type` before it calls `search()`.
- For non-movies it calls `getDetail()` and/or `getEpisodes()` and then `getVideoSources()`.
- Episode comparison currently accepts `itemSeason == null` as a match even when the requested season is specified (`itemSeason == null || media.seasonNumber == null || itemSeason == media.seasonNumber`). This is unsafe for multi-season shows. Phase 38 should reject ambiguous season matches or apply an explicit, tested source-specific season mapping.
- `js_bootstrap.dart` initializes `globalThis.__settings = {}` and exposes a provider's `getSettings` function, but no application-layer `getSettings` invocation or user settings persistence was found by code search.

### 5.3 Stremio Manifest

`SourceRepositoryParser` currently sets `needsConfiguration` when either `behaviorHints.configurable == true` **or** `configurationRequired == true`. Therefore an optional-configurable addon may be marked unsupported even when it does not require configuration. Phase 40 must test the combinations with fixtures and follow the manifest contract; do not change this by assumption alone.

### 5.4 VidKing Direct

`VidKingDirectProvider` uses `source.engine.qualityFilter` to filter each `rawQuality`, then sets `audioLanguage = source.engine.qualityFilter ?? source.engine.language`. OpenStream fixture declares English/Hindi in `qualityFilter`. This confirms a concrete schema/semantic collision. Phase 41 must introduce/consume a separate language field while preserving old manifests during migration.

### 5.5 Live TV

- `LiveTvService` exists in `daddylive_service.dart`; both DaddyLive and EthioSports implement it.
- Mobile and Android TV screens instantiate `DaddyLiveService` directly.
- EthioSports import, service instance, database and selector code are present but commented out in both screens.
- `LiveTVDatabaseController` accepts a namespace and creates separate storage keys for channels/favorites/history/EPG; keep existing `daddylive` keys stable to avoid losing user data.
- Live channel models are currently named around DaddyLive (`DaddyLiveCatalog`, `DaddyLiveStream`) and may need additive generic abstractions or adapters rather than a breaking rename.
- Spyhell Live TV scripts can return `getHome()` groups and custom URI IDs (e.g. `worldtv://`). The current app's QuickJS video-source path does not itself constitute a `LiveTvService` integration.

## 6. Duplicate and routing risks

| Duplicate / overlap | Evidence | Recommended handling |
|---|---|---|
| Anikoto | OpenStream, Spyou, Serenity, Spyhell | Compare script hash + engine contract; keep separate provenance and selectable preferred copy |
| AnimeGG | OpenStream and Spyhell | Compare implementation before activating both |
| CineStream | Serenity and Spyhell | Different scripts; compare features and settings before deduplication |
| JKanime | Spyhell Experiment and Spyhell Latin | Same source identity/site candidate; prefer language-aware version after script hash and behavior check |
| AnimeGG / AnimeKoto variants | Multiple repositories | Do not deduplicate by display name only |
| Live TV entries | Many all declare `movie` in a VOD-oriented index | Route to Live TV by explicit channel capability/adapter, never from the generic movie type alone |

Repository-scoped `stableKey` means the same site in another repository remains a separate installed item. Global duplicate detection must be an advisory match first; automatic removal could lose a useful alternate build.

## 7. Existing tests and coverage gaps

### Existing related tests/files

- `test/fixtures/openstream_official_repo.json`
- `test/video_providers/source_repository_parser_test.dart`
- `test/video_providers/source_repository_client_test.dart`
- `test/video_providers/source_repository_manager_test.dart`
- `test/video_providers/stremio_addon_provider_test.dart`
- `test/video_providers/quickjs_stream_mapper_test.dart`
- `test/video_providers/unified/quickjs_stream_mapper_test.dart`
- `test/video_providers/vidking_payload_cipher_test.dart`
- `test/live_tv_error_test.dart`

### Gaps confirmed

- Only OpenStream has a checked-in full repository JSON fixture among the six audited indexes.
- Zangetsu parser has representative synthetic fixtures, but no checked-in snapshots for the five live Zangetsu manifests.
- Current tests do not establish live availability or playback of the selected providers.
- No adapter-level test proves Spyhell `getHome()` channels flow into `LiveTvService` and `LivePlayer`.
- No provider settings persistence/injection test exists for QuickJS.
- Add fixtures for Stremio `configurable` × `configurationRequired` combinations.
- Add tests for strict season matching and unknown season behavior.
- Add tests proving that adult provider records with missing `nsfw` metadata are not silently shown as normal sources.

## 8. Baseline build / CI

- Local environment: `flutter` and `dart` executables are not installed; `java` exists. `flutter analyze`, `flutter test`, and Release build were not run locally.
- `.github/workflows/android-ci.yml` installs Java 17, Gradle 8.7, Flutter 3.35.7, Android platform 36/build-tools 36.0.0/NDK 28.2.13676358.
- CI defaults to Release; manual Debug is available. Build command targets `prod`, `lib/main.dart`, `android-arm64`, and defines `ENABLE_FIREBASE=false`, `LOCAL_DEV_MODE=true`.
- Earlier user-reported CI compile failure at `tv_home_controller.dart:93` was addressed in Phase 35.1 by removing a redundant `TvMediaItem.fromSeries` conversion and typing `trendingAnimeFuture`. No newer successful CI run was supplied in this audit; build status is **not confirmed**.
- Phase 36 did not alter Dart or Android build inputs.

## 9. Phase files and preservation rules

The current `phases/` folder contains 54 top-level documents: 49 carried from the Phase 35.1 baseline plus the five Blueprint documents. Relevant requirements reviewed include Phase 8 (identity/routing/fallback/Anime mapping/QuickJS contract), Phase 11 (provider capability classification), Phase 14 (failure isolation and subtitle continuity), Phase 17 (quality metadata and player behavior), Phase 20 (source pipeline/player parity), Phase 28 (Anime discover/new/hot/search), Phase 31 (brand assets), Phase 32 (Anime tabs and `MediaKind.series` preservation), Phase 34 (authoritative Phase32 merge and player defaults), Phase 35 (dynamic Anime rows and studio/network catalog separation), and Phase 35.1 (Android TV type fix). Duplicate historical filenames for Phases 22, 25 and 26 remain part of the archive; this audit does not delete or rewrite them.

Preservation invariants:

- Anime series remains `MediaKind.series` in app catalog/detail/season/episode/player flows. `UnifiedMediaType.anime` is a source routing classification, not a third player kind.
- Phase 11 Anime classifier (Animation genre 16 + original language `ja` where used for TMDB TV) is preserved; do not add hardcoded trending titles.
- Phase 32 provider Anime tab, Top Rated Anime, search ordering, translations and TV ad contract remain intact.
- Phase 34 is the source-of-truth merge for Phase32 files and player defaults.
- Phase 35/35.1 Home rows, studio/network catalogs, and TV type fix remain intact.
- Existing BetterPlayer integration, headers, audio/subtitle metadata, watch progress, source fallbacks, player settings, user data and Live TV namespaces must remain backward compatible.

## 10. Phase 36 conclusion and Phase 37 readiness

**Phase 36 static audit: Passed with limitations.** All six index endpoints were retrieved; the correct fifth and sixth repository paths were pinned; selected scripts and local source contracts were inspected; concrete incompatibilities and missing tests were recorded; no functional code was changed.

**Limitations:** raw index bytes and commit SHA values could not be persisted from this environment (container outbound DNS is unavailable and web retrieval does not expose a downloadable local file). The JSON snapshot therefore records normalized index metadata, line counts, record counts, sampled entries, and evidence URLs; `commitHash` and numeric success status are explicitly null, not guessed. Runtime/playback and CI baseline remain unverified.

**Phase 37 readiness:** Ready for architecture design and contract specification. Before functional Phase 37 changes are merged, run the existing Release workflow on the exact Phase35.1/Blueprint baseline and capture its run URL/result; if it fails, resolve only baseline failures first. Do not start broad source activation until Phase 37/38/39/42 dependencies close.

## 11. Evidence URLs

- OpenStream index: https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json
- Spyou Zangetsu index: https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json
- Serenity-MIST index: https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json
- Spyhell Experiment index: https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json
- Spyou Additional index: https://raw.githubusercontent.com/Spyou/Zangetsu-spyou-provider/main/index.json
- Spyhell Latin index: https://raw.githubusercontent.com/Spyhell/spyou-latin-zan/main/index.json
- Incorrect Spyhell Latin path (404): https://raw.githubusercontent.com/Spyhell/spyou-latin-zan/main/index.ison
- Sample scripts: `providers/hianime.js`, `providers/animecube.js`, `providers/fourkhdhub.js`, `serenity-cinestream.js`, `serenity-streamplay.js`, `providers/animesuge.js`, `providers/animesalt.js`, `providers/worldlivetv.js` under their respective repository roots.


## Addendum — CI baseline result observed before Phase 37 edits (2026-11-06)

After this audit document was first written, the repository's GitHub Actions Release workflow was observed succeeding on commit `a9d414d` in run `42142404064` (24.9 MB APK artifact). This closes the Phase 36 *baseline Release CI* gate that was previously marked unconfirmed. It does not represent a build of Phase 37 changes and does not imply that `flutter analyze` or `flutter test` were run. Phase 37 must still pass its own post-change validation.

Evidence URL: https://github.com/m5ham3ds/RAVEN23/actions/runs/42142404064
