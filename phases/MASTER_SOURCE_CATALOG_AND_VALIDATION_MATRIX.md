# RAVEN23 — Source Catalog & Validation Matrix

## الغرض

هذه القائمة تحول تقرير المستخدم عن المستودعات الستة إلى سجل عمل قابل للتحقق. **الأسماء والحالات والتوصيات الواردة أدناه مرشحات أولية من التقرير، وليست تأكيداً مستقلاً بأن كل الإضافات ما زالت موجودة أو قابلة للتشغيل.** المرجع النهائي هو Snapshot موثق من Phase 36 ثم اختبارات العقد والتشغيل.

## المستودعات الستة

| # | المستودع | فئة الفهرس حسب التدقيق | الفهرس/الرابط | الإجراء في Phase 36 |
|---:|---|---|---|---|
| 1 | OpenStream Official | OpenStream JSON | `https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json` | التحقق من snapshot والـmanifest والـengine لكل مصدر |
| 2 | Spyou Zangetsu Providers | JavaScript repository | `https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json` | التحقق من ملفات scripts وإصداراتها |
| 3 | Serenity-MIST Zangetsu Sources | JavaScript repository | `https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json` | التحقق من المصادر وتكرارها مع Spyou/Spyhell |
| 4 | Spyhell Experiment | JavaScript repository | `https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json` | مراجعة مصادر VOD وLive `getHome()` |
| 5 | Spyou Additional Providers | JavaScript repository | `https://raw.githubusercontent.com/Spyou/Zangetsu-spyou-provider/main/index.json` — verified 2026-11-06 | تم التأكد من الاسم والرابط والفرع والفهرس؛ 5 مصادر في النسخة المفحوصة |
| 6 | Spyhell Latin Sources | JavaScript repository | `https://raw.githubusercontent.com/Spyhell/spyou-latin-zan/main/index.json` | اعتماد `index.json`؛ تجاهل المسار الخاطئ `index.ison` بعد توثيق 404 |

## معنى حالات التحقق

- `Candidate`: وارد في التقرير ولم يُتحقق من الفهرس الحالي.
- `Indexed`: موجود في Snapshot حديث للفهرس.
- `Script Retrieved`: تم جلب ملف التنفيذ بنجاح.
- `Contract Verified`: اجتاز تحليل النوع والدوال والعقد.
- `Runtime Verified`: اجتاز اختبار تنفيذ مع HTTP fixtures أو بيئة مضبوطة.
- `Playback Verified`: رابط فعلي اشتغل في المشغل باختبار موثق.
- `Experimental`: beta أو غير ثابت أو يحتاج تفاعلاً/متطلبات إضافية.
- `Blocked/Unavailable`: الموقع أو المسار غير متاح أو يتطلب تحققاً/قيوداً غير مدعومة.
- `Duplicate Candidate`: تشابه محتمل ينتظر مقارنة script hash والعقد.

## A. OpenStream / VidKing Direct

| المصدر | المحتوى المذكور | أولوية الاختبار | شروط قبل التفعيل |
|---|---|---|---|
| Yoru | Movies + Series | أولى | فحص `getInfo`/manifest/engine والبحث والتشغيل |
| Cypher | Movies + Series | أولى | نفس الاختبار |
| Breach | Movies + Series | أولى | نفس الاختبار |
| Neon | Movies + Series | أولى | نفس الاختبار |
| Omen | Movies + Series | احتياط | تفعيل تجريبي بعد المجموعة الأولى |
| Raze | Movies + Series | احتياط | تفعيل تجريبي بعد المجموعة الأولى |
| Vyse | English-focused | بعد Phase 41 | إصلاح language/quality separation أولاً |
| Fade | Hindi-focused | بعد Phase 41 | إصلاح language/quality separation أولاً |
| Killjoy | German-focused | اختياري | التحقق من meaning of language field والـstream labels |

## B. Zangetsu — Movies candidates

| المصدر | المستودع المذكور | النوع في التقرير | ملاحظة تحقق |
|---|---|---|---|
| 4K HDHub | Spyou | Movie | يبدأ كأفلام؛ series فقط بعد ثبوت الدوال والعقد |
| UHD Movies | Spyou | Movie | تحقق من DriveSeed/DriveLeech routes دون افتراض استمراريتها |
| HDHub4u | Spyou | Movie | تحقق من HubCloud/HBLinks ومخرجات extractor |
| VegaMovies | Spyou | Movie | تحقق من V-Cloud route |
| MultiMovies | Spyou | Movie | تحقق من GDMirror/StreamWish/HLS |
| CineStream | Serenity-MIST | Movie | تحقق من movie وseries بشكل مستقل |
| StreamPlay | Serenity-MIST | Movie | تحقق من movie وseries بشكل مستقل |

## C. Spyhell — VOD / Archive / Documentary candidates

| المصدر | نوع مرشح | ملاحظات قبول |
|---|---|---|
| Filmzie | VOD | التحقق من API/HLS والتوافر وحقوق المحتوى |
| MoviesJoy | VOD | اختبار HLS وheaders والتوفر |
| TheNkiri | Mixed VOD | تصنيف movie/series/anime من نتائج فعلية |
| CineStream | Mixed VOD | مطابقة نسخة Spyhell مع نسخة Serenity قبل إبقائهما معاً |
| ARTE TV | VOD / linear حسب الوظيفة | لا يفترض أنه مصدر أفلام فقط؛ تصنيف كل endpoint |
| NHK World | VOD / linear حسب الوظيفة | المحتوى الثقافي/الوثائقي ليس بالضرورة أفلاماً |
| Internet Archive | Archive VOD | فحص metadata/license لكل عنوان قدر الإمكان |
| Wikimedia Films | Archive VOD | التحقق من صيغة الفيديو والترخيص |
| Library of Congress | Archive VOD | التحقق من حقوق كل مادة وشروط الوصول |
| Prelinger Archives | Archive VOD | التحقق من حقوق كل مادة |
| Silent Films | Archive VOD | فحص المصدر الفعلي والتصنيفات |
| Orphaned Films | Archive VOD | فحص المصدر الفعلي والحقوق |
| PeerTube Films | Federated VOD | التعامل مع تعدد الخوادم وتباين metadata |

## D. Series / Asian Drama candidates

| المصدر | المستودع المذكور | المحتوى/الوظيفة | شرط التفعيل |
|---|---|---|---|
| MyAsianTV | Spyhell | Asian drama/K-Shows + possible movies | دعم settings/mirrors والتحقق من season+episode |
| Dramacool | Spyhell | Asian drama | التحقق من مواسم وحلقات كل نتيجة |
| CineStream | Spyhell / Serenity-MIST | Mixed | لا تغيير type إلى all دون تحليل script |
| StreamPlay | Serenity-MIST | Mixed | الموسم والحلقة ومسارات التشغيل |
| TheNkiri | Spyhell | Movies/Series/Anime candidate | تحليل نتائج النوع قبل التوجيه |
| 4K HDHub / UHD Movies / HDHub4u / VegaMovies / MultiMovies | Spyou | Series candidate | لا يُفتح دعم المسلسلات لأن دالة `getEpisodes` موجودة وحدها؛ يلزم عقد موثق واختبار |

## E. Stremio candidates

| الإضافة | المحتوى المذكور | أولوية التحقق | ملاحظة |
|---|---|---|---|
| YaStream | Asian drama / Movies / Series | أولى | Manifest live المذكور في التقرير يحتاج إعادة تحقق وconfiguration tests |
| HDHub | Movies / Series | تجريبي | التحقق من Manifest الرسمي والأنواع |
| Zeus | Movies / Series / Portuguese Anime candidate | تجريبي | لا تعتمد لغة المحتوى أو النوع قبل manifest/stream test |
| FrostStream | Movies / Series Portuguese | تجريبي | نفس الاختبارات |
| FenixFlix | Movies / Series / Novelas | تجريبي | نفس الاختبارات |

## F. OpenStream Native Anime candidates

| المصدر | ميزات التقرير | أولوية الاختبار | ملاحظة |
|---|---|---|---|
| Re:Anime | Sub/Dub, multiple episode servers | أولى | حالة Beta تبقى كما في الفهرس |
| FourAnimo | HLS, multi-audio, subtitles, intro/outro metadata | أولى | التحقق من حفظ audio/subtitle/intro metadata في stream option |
| Anikoto | Sub/Dub, multiple languages | أولى | مقارنة التكرار بين المستودعات |
| AnimeGG | MP4 up to reported 1080p, Sub/Dub | متوسطة | التحقق من quality metadata |
| AnimePahe | Sub/Dub, may use WebView/anti-bot path | احتياط | لا محاولة لتجاوز Cloudflare؛ اعرض الحالة بوضوح |

## G. QuickJS Anime candidates

| المجموعة | المصادر المرشحة | الأولوية/القيود |
|---|---|---|
| Spyou Zangetsu | HiAnime، AniKoto، AnimeCube | HiAnime وAnimeCube مرشحان رئيسيان؛ Anikoto duplicate candidate |
| Serenity-MIST | Anikoto، AnimeKai، AniWave | Anikoto duplicate candidate؛ البقية اختيارية |
| Spyhell Experiment — general | AnimeSuge، AnimeX، GoGoAnime، AnimeGG، ToonStream، WcoFlix، AnimeAni | AnimeSuge وAnimeX أولوية؛ AnimeGG وAnikoto-like duplicates compare first |
| Spyhell Experiment — Chinese | DonghuaNation | فحص 403 والتوافر؛ لا إعلان ثابت عن التشغيل |
| Spyhell Experiment — regional | NekoSama، Samehadaku، AnimeWorld، Aniworld، Anoboy، JKanime، MonosChinos، HindiAnime | اختبار لغة العناوين/الترجمة والـepisode identity لكل مجموعة |
| Spyou Additional | AnimeSalt، AnimixStream، AnimeDrive، AnimeLok | AnimeSalt ثم AnimixStream؛ AnimeLok Experimental ولا يتجاوز Cloudflare |
| Spyhell Latin | AnimeAV1، AnimeJL، JKanime، AnimeYTX | JKanime duplicate candidate مع Spyhell Experiment |

## H. Live TV candidates

| مجموعة القنوات | وظيفة البيانات | حالة الاستخدام |
|---|---|---|
| World Live TV | قنوات عامة دولية | IPTV Live |
| Live TV India | قنوات إقليمية | IPTV Live |
| Sports Live TV | قنوات رياضية | IPTV Live |
| News Live TV | قنوات أخبار | IPTV Live |
| Documentary Live TV | قنوات وثائقية | IPTV Live |
| Entertainment Live TV | ترفيه | IPTV Live |
| Movies Live TV | قنوات خطية للأفلام | Live فقط، ليس VOD |
| Series Live TV | قنوات خطية للمسلسلات | Live فقط، ليس VOD |
| Animation Live TV | قنوات رسوم/أنمي | Live فقط، ليس Anime catalog |
| Music Live TV | موسيقى | IPTV Live |
| Kids Live TV | أطفال | IPTV Live |
| Travel Live TV | سفر | IPTV Live |
| Comedy Live TV | كوميديا | IPTV Live |
| Cooking Live TV | طبخ | IPTV Live |
| Education Live TV | تعليم | IPTV Live |
| Pluto TV | Linear channels | Phase48 Experimental/Unavailable external handoff only; no in-app channels/streams or VOD without an authorized API contract |

**أعداد القنوات التقريبية التي وردت في التقرير ليست ضماناً للتوافر ولا تُستخدم كمعايير قبول.** عدد القنوات الفعلي يؤخذ من Snapshot القوائم في لحظة الاختبار، وتُقاس القنوات القابلة للتشغيل بعينة تشغيل منفصلة.

## سجل التحقق لكل مصدر

يُنشأ لكل مصدر سجل بهذه الحقول على الأقل:

```json
{
  "repositoryId": "repository-key",
  "repositoryUrl": "https://.../index.json",
  "sourceId": "provider-id",
  "sourceName": "Provider name",
  "engine": "quickjs|stremio|vidking-direct|anime-site|web-embed|native|live-tv",
  "version": "source-version",
  "commitHash": null,
  "scriptUrl": "https://.../provider.js",
  "contentHash": "sha256:...",
  "declaredCapabilities": ["movie", "series"],
  "verifiedCapabilities": [],
  "languages": [],
  "settingsSchemaVersion": null,
  "status": "candidate",
  "lastCheckedAt": null,
  "tests": {
    "manifest": "not_run",
    "runtime": "not_run",
    "search": "not_run",
    "episodes": "not_applicable",
    "playback": "not_run"
  },
  "notes": []
}
```

يجب أن تكون القيم أعلاه تمثيلية وليست بيانات مصدر حقيقية. لا تضع قيماً مخمّنة في ملفات التشغيل أو مستودع الإنتاج.


## Phase 36 — verified live index baseline (2026-11-06)

| # | Repository | Lines | Records | Verified index |
|---:|---|---:|---:|---|
| 1 | OpenStream Official | 604 | 30 | Retrieved |
| 2 | Spyou Zangetsu Providers | 96 | 9 | Retrieved |
| 3 | Serenity-MIST Zangetsu Sources | 56 | 5 | Retrieved |
| 4 | Spyhell Experiment | 807 | 89 | Retrieved |
| 5 | Spyou Additional Providers | 11 | 5 | Retrieved; exact URL confirmed |
| 6 | Spyhell Latin Sources | 42 | 4 | Retrieved; `index.json` correct, `index.ison` 404 |

Total: 142 index records before cross-repository duplicate analysis. These are discovery records only, not runtime-verified providers. See `SOURCE_REPOSITORY_SNAPSHOT.json`, `PHASE36_AUDIT_REPORT.md`, and `SOURCE_COMPATIBILITY_MATRIX.md` for evidence, selected code inspections, and limitations.


## Phase 43 — OpenStream live index re-check (2026-11-07)

The official live index was retrieved again at the start of Phase 43. It contains 30 entries: 9 `vidking-direct`, 5 native Anime, 5 `stremio`, 10 `web-embed`, and 1 `vidking-webview`. See `PHASE43_OPENSTREAM_SOURCES_AUDIT.md` for the ids, routes, priorities and lifecycle handling.

The blueprint's rollout preference (Yoru/Cypher/Breach/Neon before Omen/Raze and language-focused routes after Phase41) is not used to rewrite the upstream manifest. The current live index still sets `installedByDefault: true` on Vyse. The parser retains this official metadata; activation and Phase41's post-change CI acceptance are tracked separately. No source is considered Playback Verified on the basis of index presence or deterministic fixtures.


## Phase 44 live Zangetsu/Spyhell catalog re-check — 2026-11-07

| Repository | Index records | Phase44 treatment |
|---|---:|---|
| OpenStream Official | 30 | Existing adapters retained; no duplicate repository seed.
| Spyou Zangetsu Providers | 9 | QuickJS candidates; type/safety declarations preserved.
| Serenity-MIST Zangetsu Sources | 5 | Mixed scripts reviewed; CineStream/StreamPlay remain Movie-declared until Series contract tests pass.
| Spyhell Experiment | 89 | QuickJS candidates; known `getHome()` channel groups routed away from VOD; missing `nsfw` declaration remains unknown.
| Spyou Additional Providers | 5 | QuickJS candidates; Anime/Movies classifications are not promoted.
| Spyhell Latin Sources | 4 | Anime Latin candidates; JKanime duplicates require comparison before user-facing consolidation.

**Total: 142 index records before cross-repository de-duplication.** Catalog presence is not runtime verification. No provider is auto-installed. No archive entry is treated as rights-cleared merely because it has an archive label.

## Phase 52 — VOD priority review (2026-11-09)

The six current indexes were rechecked (142 records before global duplicate analysis), and selected scripts were inspected for language/type/runtime mismatches. The initial user-editable priority lanes are Movies 13, Series 9, and Anime 11. Series remains at 9 because only nine candidates met current exact-episode and runtime requirements; no unsupported source was promoted to fill the lane.

Automatic activation is limited to 15 unique source records per repository. The search scheduler uses the exact category lane first, remaining installed/eligible direct providers second, and embedded pages last. Multi-content providers may be in more than one lane but are installed once. Removing a source from priority leaves it installed as a backup.

| Lane | Curated order | Important treatment |
|---|---:|---|
| Movies | 13 | OpenStream 7 status-1 direct sources; Spyou 2; reviewed Serenity 2; Spyhell 2. |
| Series | 9 | OpenStream 7 plus two exact Serenity scripts with reviewed episode paths; strict season/episode matching remains required. |
| Anime | 11 | Spyou 3, Serenity 3, Spyhell 5; Japanese/Chinese allowed only in this lane. |

OpenStream's two Beta Movie/Series adapters and five Beta Anime adapters remain in the backup tier. Known exclusions include HDHub4u (index/script language mismatch: English vs Hindi), AniLibria (Russian voice-over despite English index label), SubsPlease and other torrent/magnet-only sources (unsupported by the current HTTP(S) mapper), known adult sources, Live TV adapters, credential-review sources and languages outside the requested lanes. NetPrime is backup-only because its own code/documentation describes browser-signed and IP-bound embed limitations.

**Status semantics:** upstream `1` means Listed OK, `2` Slow, `3` Beta, `0` Unavailable; missing status is Unrated. These are upstream declarations, not independent uptime measurements. No live playback test of all 142 index records was performed. Refer to the six `PHASE52_SOURCE_REPOSITORY_PRIORITY_*.md` documents and `SOURCE_REPOSITORY_SNAPSHOT.json` → `phase52Review` for details.
