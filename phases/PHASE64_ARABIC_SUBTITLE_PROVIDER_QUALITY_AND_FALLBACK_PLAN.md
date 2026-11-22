# PHASE64 — Arabic Subtitle Providers, Matching Quality, Synchronization & Fallback

**Status:** APPROVED FOR IMPLEMENTATION — IN PROGRESS (owner approval: 2026-11-22).  
**Project:** RAVEN23  
**Baseline inspected:** main commit 6d12023e446db3d444716c3b407572a89cf545be  
**Baseline build:** GitHub Actions #249 passed (Flutter tests, Android tests, ARM64 release APK, ABI/size audit).  
**Language target:** Arabic (ar) as the automatic preferred subtitle language.  
**Cost constraint:** free provider/API tiers only. No paid AI-translation service, VIP plan, or paid provider is included in this proposal.  
**Owner-confirmed product rule (2026-11-21):** search for and select already-published Arabic subtitle files only. Do not translate English subtitles into Arabic, do not invoke an AI translation endpoint, and do not generate substitute Arabic captions.

## 0. Approval gate

The owner explicitly approved implementation on 2026-11-22. Work may proceed only in the ordered, scoped phases below. Approval authorizes implementation; it does not mark any phase complete, does not waive provider terms or credential handling, and does not authorize changes to protected features.

The separate rule in RAVEN23_PROTECTED_FEATURES_NO_TOUCH_WITHOUT_EXPLICIT_REQUEST.md remains active. In particular, the existing offline player, episode cards, season switching, video downloads, DCIM video export, source ordering, quality behavior, and other accepted features are outside this phase.

### Mandatory execution order and dependency gate

The subtitle-selection engine must be completed and accepted **before** any Shared Subtitle Intelligence / Community Cache implementation or integration test begins.

Required order:
1. PHASE64.0–64.2: establish the eligible sources, validate the owner's existing credentials, and implement only permitted/documented adapters.
2. PHASE64.3: make discovery and candidate fallback reliable without delaying video startup.
3. PHASE64.4: implement the candidate evaluation and recommended-subtitle selection algorithm.
4. PHASE64.5: validate Arabic decoding, display, and synchronization behavior.
5. PHASE64.6: run the selector acceptance benchmark on movies, ordinary series, and anime, including real Android playback. Record the approved selector version and its scorecard.
6. Only after PHASE64.6 is explicitly marked PASS may PHASE64.7 Shared Subtitle Intelligence & Community Cache begin. The shared cache must store and distribute the winner produced by the approved selector; it must not invent a separate ranking algorithm or turn an unverified candidate into a verified result.

Until this gate passes, no subtitle candidate may be uploaded as a globally recommended/shared result, and PHASE64.7 remains blocked even if the Laravel server becomes available.

The known issue that copies a selected subtitle sidecar beside the video under DCIM/RAVEN23/<title>/SUBTITLE is deferred. This phase does not reopen or alter it.

---

## Implementation progress log

### 2026-11-22 — Implementation authorized and first PHASE64.3 reliability fix

- Owner approval received to begin implementation. This changes the document from proposal-only to active work; it does not mark PHASE64.0–64.6 as passed.
- Baseline at start: `main` commit `b61f4f4916319c50b384400bf362590c81b326f1`.
- Commit `8776ac4a5605fa301395aff150ae56d72f258372` added `SubtitleProviderOrchestrator.collectPartialResults` and replaced the all-or-nothing 48-second result timeout. Completed provider results are now retained if another provider stalls; late results are ignored after the deadline.
- Added four focused unit tests for aggregation, deadline/partial-result behavior, provider exception isolation, and immutable snapshots. The repository's routine test list did not include subtitle tests at the time of this commit; the next implementation commit adds the relevant subtitle regression files to the Android CI test gate before claiming those new tests ran.
- GitHub Actions run #265 for commit `8776ac4`: Flutter static analysis and the pre-existing focused test batch completed successfully. The Android Gradle wrapper/build steps were still in progress at the last check; this run is not recorded as a complete build pass.
- Baseline configuration audit found `OPENSUBTITLES_API_KEY` and `ARABICSUBS_PROXY_URL` empty in the tracked `.env.example`, and no `SUBSOURCE_API_KEY` entry. The owner already confirmed obtaining the three keys; no key values are recorded here. Live key validation and provider calls remain blocked until they are made available through the approved private development configuration and, for ArabicSubs, a protected proxy.
- Current code still uses the legacy undocumented SubSource route. The documented adapter migration is not complete. PHASE64.0–64.2 therefore remain open; the timeout fix is only the first implementation slice of PHASE64.3.
- No player UI, language preference, provider ordering, video stream behavior, offline player, download/export flow, or other protected feature was changed. PHASE64.7 remains blocked until selector acceptance (PHASE64.6 PASS) and Laravel shared-cache deployment.

### 2026-11-22 — PHASE64.4 language-aware selector wiring (implementation started)

- Added a deterministic, language-neutral candidate selector. It filters to the explicitly requested language, rejects candidates explicitly marked as wrong media identity, and orders remaining results by available release signals, exact-identity evidence, trusted-uploader evidence, ratings, votes, downloads, and upload date. It does not use fixed provider-name priority or unbenchmarked numeric weights.
- The existing Arabic default search now uses the same selector. A deliberate player switch to another provider-supplied subtitle language runs the selector for that language only; it does not change the app's configured default language.
- All existing subtitle rows remain available. The selector's target-language filter is applied only to the selection operation, not to the displayed subtitle catalogue.
- The active stream exposes a quality label, not a verified full release filename or timing fingerprint. Matching those available quality tokens is ordering evidence only; it is not sufficient to claim high confidence or to close PHASE64.4–64.6.
- Shared publication is still blocked. The owner has additionally specified that any future shared upload must accept only Arabic (ar) and English (en); all other languages remain searchable, visible, selectable, and device-local, but are not published to the server.
- .env.example already declares OPENSUBTITLES_API_KEY, SUBSOURCE_API_KEY, and ARABICSUBS_PROXY_URL. No values were copied, inserted, or exposed by this implementation. ArabicSubs credentials remain server-only.
- Validation is pending until the next CI run. This progress entry does not mark PHASE64.4 complete, does not claim live-provider or real-device acceptance, and does not unlock PHASE64.7.

**Protected-scope impact:** only subtitle language resolution, external subtitle candidate selection, its focused tests, the Phase64 CI test list, and Phase64 documentation are touched. No video URL/source selection, PRIMARY/BACKUP order, quality policy, offline player/download/export path, UI layout, backend contract, or deferred DCIM subtitle-sidecar behavior is changed.

### 2026-11-22 — CI #291 result and post-CI selector pipeline audit

- GitHub Actions run #291 for commit `d570ec90f174d843beef22a24d77d4d826b44de4` completed successfully: Flutter analysis passed; the captured pre-build log records 59 focused Flutter test files and `482` passing tests; Android logs record 3 Mihon ABI methods and 22 Media3/download contract methods passed; Release ARM64 APK build and ABI audit passed. The APK artifact was 45,397,593 bytes (about 43.29 MiB).
- The focused run includes `external_subtitle_service_test.dart`, `subtitle_selection_engine_test.dart`, `language_names_test.dart`, subtitle normalization/options/cache/orchestrator tests. This establishes CI success for the tested commit, not live provider credentials, real provider availability, synchronization, or physical-device playback.
- A deeper post-CI review found that `_mergeAndSort` still applied a fixed provider-name rank and removed same-language/same-release entries before `SubtitleSelectionEngine` could inspect them. This contradicted the new selector's provider-neutral contract and could discard better candidates. The current follow-up removes provider-name ranking and preserves distinct provider records; its regression run is pending.
- The Android CI report template also contained an obsolete hard-coded 32-file inventory although the executed log showed 59 files. The current follow-up derives the reported test-file inventory from the actual Flutter log instead of keeping a duplicate stale list.
- `PHASE64.4` remains IN PROGRESS: the selector still lacks accepted confidence classes/thresholds and benchmark evidence; the active stream currently supplies only a quality label rather than a verified full release fingerprint. Do not start PHASE64.5 or unlock PHASE64.7 until the required matching, Arabic decoding/RTL, and real-device gates are accepted.
- `PHASE64.0` live credential validation remains blocked until the exposed OpenSubtitles and SubSource keys are rotated. SubF2M, Sub-Scene, and AnimeTosho remain research candidates, not integrated providers.
- **Protected-scope impact:** the follow-up is restricted to provider-result merge/deduplication, its tests, accurate CI-report generation, environment descriptions, and this phase document. Provider-supplied video subtitle tracks, active video URLs, provider/server ordering, quality selection, offline playback, downloads/export, DCIM behavior, player layout, and backend contracts remain unchanged.
- **Changed files in this follow-up:** `.github/workflows/android-ci.yml`, `lib/services/external_subtitle_service.dart`, `test/external_subtitle_service_test.dart`, and `phases/PHASE64_ARABIC_SUBTITLE_PROVIDER_QUALITY_AND_FALLBACK_PLAN.md`. The environment template correction is recorded separately in the preceding commits.

### 2026-11-22 — CI #294 success and owner-confirmed API-key exception

- GitHub Actions run #294 for commit `e0c0e8cf2c0a0c07b82f9b01772502bf00786b48` completed with conclusion `success`. Flutter analysis passed; the focused Flutter gate recorded 59 test files and 482 passing tests. The Android contract gate verified 25 cases from JUnit XML: 3 Mihon ABI cases and 22 Media3/download cases, with zero failures/errors/skips.
- The production Release APK build and APK/ABI audit both passed. The artifact was 45.63 MiB (47,850,874 bytes); the only native ABI directory was `arm64-v8a`. APK upload, diagnostics, formatting patch, and comprehensive build report uploads all completed.
- Run #294 used commit `e0c0e8cf`, whose `.env.example` still had blank OpenSubtitles/SubSource values. It proves the blank-template build path passed, but does not prove live provider authentication or the owner's populated-key phone-test path.
- The owner has explicitly instructed that the existing TMDB, OpenSubtitles, and SubSource values must remain populated in `.env.example` during Android phone testing. The public exposure and APK extraction risk are acknowledged and accepted only for this temporary development period. The standalone policy is `phases/RAVEN23_TEMPORARY_PUBLIC_API_KEY_TESTING_EXCEPTION.md`; do not blank/remove/rotate/migrate the values without a later explicit owner instruction. ArabicSubs remains server-only.
- The follow-up implementation prepared after #294 removes fixed provider-name priority and cross-provider same-release/URL collapse from `ExternalSubtitleService._mergeAndSort`. It preserves distinct provider records and removes only repeated records with the same source, ID, and URL. Regression tests now cover same-release alternatives, provider-neutral merging, and shared-URL provenance.
- The CI report template now extracts its test-file inventory from the actual Flutter log instead of maintaining a stale hard-coded 32-file inventory.
- A new CI run is required for the merge fix and the populated-key test-template update. Until that run passes, the follow-up is not accepted.
- `PHASE64.4` remains IN PROGRESS: accepted confidence classes, benchmark evidence for movies/series/anime, strong release identity, and real Android playback verification are still outstanding. Do not jump to PHASE64.5 or unlock PHASE64.7 based on the build alone.
- **Protected-scope impact:** only external subtitle result merging, its regression tests, CI report generation, the authorized subtitle-provider environment template, and Phase64 documentation/policy are touched. Provider-supplied subtitle tracks, video source/server ordering, active video URLs, quality selection, offline playback, downloads/export, DCIM behavior, player layout, and backend contracts remain unchanged.
- **Changed files in this update:** `.env.example`, `.github/workflows/android-ci.yml`, `lib/services/external_subtitle_service.dart`, `test/external_subtitle_service_test.dart`, `phases/PHASE64_ARABIC_SUBTITLE_PROVIDER_QUALITY_AND_FALLBACK_PLAN.md`, and `phases/RAVEN23_TEMPORARY_PUBLIC_API_KEY_TESTING_EXCEPTION.md`.

## 1. Goal and non-goals

### Goal

Make Arabic subtitles the reliable default for movies, series, and anime by:
- using maintained and documented free subtitle APIs where possible;
- identifying the exact movie or episode and the closest matching release;
- rejecting wrong-language, wrong-episode, stale, corrupt, or clearly mismatched subtitle files;
- not allowing one slow or unavailable provider to delay or hide results from the others;
- trying the next eligible Arabic subtitle/provider when a candidate is unavailable or fails to download, parse, or apply;
- preserving the existing rule that video startup must not wait for subtitle search;
- improving Arabic text decoding, right-to-left display checks, and subtitle timing diagnosis.

### Not included

- Paid plans, paid translation quotas, paid AI subtitle generation, or subscription-only APIs.
- Translating English subtitles into Arabic by any automated service, model, API, or local conversion pipeline. The owner explicitly confirmed that RAVEN23 must search for existing Arabic subtitle files and apply those files; it must not convert English subtitles into Arabic.
- AI subtitle-generation and translation endpoints, including paid and free trials. The task is discovery of existing Arabic files, not the production of new ones.
- Changing the main player design, stream provider order, video quality policy, offline player, download flow, or phone export.
- The deferred DCIM subtitle-sidecar issue.

## 2. Current repository audit

The existing project is not starting from zero. The following code already exists:

- lib/services/external_subtitle_service.dart — current provider aggregation, search, ranking, and download/normalization path.
- lib/screens/common/player/player_external_subtitles.dart — Arabic default language handling, external search, automatic candidate download, and manual selection UI.
- lib/models/external_subtitles.dart — common subtitle result model.
- lib/services/subtitle_file_normalizer.dart — ZIP/GZIP extraction and SRT/VTT/ASS/SSA normalization to WebVTT.
- phases/PHASE14_SUBTITLE_SOURCES_AND_RELEASE_BUILD_FIX.md — original OpenSubtitles/SubSource integration history.
- phases/PHASE15_ARABIC_DEFAULT_SUBTITLES_AND_PLAYBACK_STABILITY.md — existing Arabic-default preference and background-application behavior.

### Existing sources found in code

1. **OpenSubtitles.com API v1:** the current adapter uses the documented `https://api.opensubtitles.com/api/v1` endpoints and the `Api-Key` header when `OPENSUBTITLES_API_KEY` is configured. When the key is empty, the provider is skipped; there is no fallback to `rest.opensubtitles.org`.
2. **SubSource documented API v1:** the current adapter uses `https://api.subsource.net/api/v1`, sends `X-API-Key`, searches by IMDb identity, reads the subtitle list and downloads the ZIP from the documented endpoint. The old undocumented website flow has been removed from the active adapter.
3. **ArabicSubs:** an optional adapter already exists behind `ARABICSUBS_PROXY_URL`. It expects the app's protected proxy to forward search, title-subtitle listing, and download requests while keeping the Bearer key server-side.
4. **RAVEN23 Scraper API:** retained as an additional provider-specific fallback.

### Important current behavior and weaknesses

- Provider requests now start concurrently through `SubtitleProviderOrchestrator.collectPartialResults`; results completed before the 48-second batch deadline are retained when another provider stalls. Per-provider deadlines and true live incremental menu updates are still not implemented.
- The previous fixed provider-rank and same-release deduplication step could hide alternatives before the selector. The current follow-up removes provider-name ranking and preserves distinct provider records; its regression run is pending.
- The former global first-five candidate limit has been removed from automatic application; candidate iteration continues until a candidate downloads and applies or the result list is exhausted.
- The legacy OpenSubtitles REST endpoint is no longer called. Without an API v1 key, the OpenSubtitles provider is skipped rather than falling back to the VIP-restricted legacy service.
- SubSource now uses its documented API v1 and `X-API-Key` authentication; the old undocumented website flow has been removed from the active adapter.
- ArabicSubs is designed around an Arabic catalogue and exposes title/episode subtitle records, release labels, download counts, and translation-type metadata. Its current API contract is different from the custom proxy adapter already in RAVEN23 and needs to be mapped deliberately.
- If a preferred Arabic provider subtitle is already marked selectedByDefault, the automatic external-provider search is skipped. This can suppress better alternatives when the in-stream Arabic track is badly timed or otherwise poor.
- The owner has explicitly excluded translating English subtitle files into Arabic; candidate discovery and scoring must never invoke a translation service as a fallback.
- The current OpenSubtitles query includes both the requested language and English even when Arabic is preferred. The selector/auto-apply filter remains target-language-specific, but the provider request still spends quota/time on English results.
- SubtitleFileNormalizer first tries UTF-8 and then falls back to Windows-1252. It does not currently have explicit Arabic Windows-1256 or UTF-16 decoding. Some older Arabic subtitle files may therefore be corrupted even when the provider returned the correct file.
- Search quality and timing quality are different problems. Correct title/episode identity does not guarantee the subtitle is synchronized to the exact release.

The old phase documents explain how these integrations began; this proposal upgrades the implementation rather than adding duplicate provider names on top of the same weaknesses.

---

## 3. Recommended free provider candidates

The order below is a provisional evaluation order, not a hard-coded final priority. Final ranking must be based on the benchmark in Section 7.

### Candidate A — ArabicSubs API v1: Arabic-specialist source

Official documentation: https://arabicsubs.com/api-access  
OpenAPI schema: https://arabicsubs.com/api/v1/openapi.json

Documented free allowance:
- 5,000 requests per month;
- 200 requests per day;
- 5 requests per minute;
- one active API key.

Documented capabilities:
- title search;
- title metadata and TMDB provider ID;
- series episode list;
- episode-specific subtitle listing with season and episode filters;
- file matching by release filename;
- subtitle detail and download;
- original filename, release label, download count, and translation type metadata.

Why evaluate it first: it is specifically an Arabic subtitle catalogue and exposes release and translation-type information that can help distinguish human-submitted files from machine-generated files.

Constraints:
- The API documentation explicitly says to keep the API key on the server and not in frontend code or a public repository.
- The free rate limit is low, so ArabicSubs must not be queried repeatedly for every video state change.
- Its actual coverage, accuracy, synchronization, and uptime for RAVEN23's movie/series/anime test set are not proven by the documentation. Live coverage testing is required.
- Use the current documented v1 routes; do not assume that the old custom proxy's response shape is the API's response shape.

### Candidate B — OpenSubtitles.com API v1: broad community fallback

Official API onboarding: https://opensubtitles.tawk.help/article/getting-started  
Official API overview and current free limits: https://opensubtitles.tawk.help/article/about-the-api  
Migration notice: https://blog.opensubtitles.com/opensubtitles/web/understanding-opensubtitles-websites-and-services

Documented free access:
- free account API access;
- OpenSubtitles states that a basic free account can download up to 20 subtitles per day;
- anonymous access is lower;
- the old OpenSubtitles.org API is restricted to VIP users from January 2024.

Why retain it: it is a large general subtitle community with movie/episode identifiers and a maintained API. It is a strong broad fallback when the Arabic-specialist catalogue does not contain a good candidate.

Constraints:
- Do not rely on rest.opensubtitles.org as the free provider path.
- Use a real application name/version User-Agent and the documented API-key flow.
- Respect the free download quota. Do not rotate keys or accounts to bypass limits.
- The app must not silently download English when the selected preference is Arabic.

### Candidate C — SubSource documented API: replace the undocumented flow

Official API documentation: https://subsource.net/api-docs

Advertised free-key allowance:
- 60 requests per minute;
- 1,800 requests per hour;
- 7,200 requests per day.

The current documented API exposes title search/details and subtitle list/detail/download routes. The existing RAVEN23 integration instead uses an undocumented website flow without the documented X-API-Key contract.

Why evaluate it: it is already an existing catalogue in RAVEN23 and can remain an independent fallback if the documented API provides sufficient Arabic coverage and exact episode/release metadata.

Constraints:
- Confirm Arabic language filtering and exact series-season-episode behavior against the current API contract before implementation.
- Do not use the old undocumented route as the long-term production integration.
- Do not assume its Arabic coverage is strong until benchmarked.

### Existing RAVEN23 Scraper API

Keep it as a final independent compatibility source while the documented providers are evaluated. Do not remove or rewrite its video-provider or stream-scraping behavior in this phase. Its subtitle adapter may only be changed under the explicit subtitle scope and must not alter stream URLs, provider selection, or source priority.

### Sources explicitly excluded by owner decision

- **SubDL (all versions):** explicitly and completely removed from RAVEN23 by the owner's direct instruction. Do not add SubDL v1, v2, website scraping, mirrors, or any other SubDL route to the app, fallback order, research shortlist, or acceptance benchmark unless the owner explicitly reopens the decision.
- **SubtitleCenter:** excluded completely from PHASE64 and must not be integrated through scraping or another workaround. Its official API status page says the API is paused by its maintainers and all /api/v1 calls return HTTP 503 while the website itself remains open. Direct checks of /api/v1/languages and /api/v1/stats also returned 503. SubtitleCenter is not currently integrated in RAVEN23 (repository search found no implementation). Although its website currently lists Arabic subtitle files, the owner chose to abandon it because its API is provider-paused; do not add it to the app or benchmark unless the owner explicitly reopens that decision.

### Candidate D — SubF2M: community Arabic catalogue

Website: https://subf2m.co

Evidence and limitations:
- The independent Bazarr provider catalog maps the Arabic language to ara for SubF2M and includes captured Arabic episode pages in its test fixtures (for example, fixture examples for Chernobyl and The Matrix).
- The available implementation is a community scraper, not a documented official API contract in the material reviewed for this plan.
- It is a promising Arabic coverage candidate, but live results, exact episode quality, site terms, robots policy, download behavior, and stable access must be validated before implementation.
- No CAPTCHA, Cloudflare, Anubis, or other access-control bypass is allowed. If automated access is disallowed or blocked, exclude it rather than building a bypass.

### Candidate E — Sub-Scene: Arabic-capable community mirror

Website: https://sub-scene.com

Evidence and limitations:
- The independent Bazarr+ provider catalog describes this Subscene-style mirror as covering 35+ languages, including Arabic, for movie and episode subtitles.
- Its community adapter currently relies on browser-like scraping and anti-bot challenge handling. This is not equivalent to a documented, provider-authorized public API.
- Keep it in the experimental research pool only. Do not integrate challenge-solving, CAPTCHA bypass, proxy rotation, or other access-control circumvention. A supported API or explicit permission is required before any production integration.

### Candidate F — AnimeTosho: anime-only Arabic archive attachment source

Website: https://animetosho.org

Evidence and limitations:
- The current Bazarr Subliminal provider implementation lists ara (Arabic) among AnimeTosho's supported languages.
- Its adapter consumes AnimeTosho JSON feeds and retrieves embedded subtitle attachments for older anime releases by AniDB episode identity. It is an archive/attachment source, not a guaranteed current-release Arabic subtitle catalogue.
- Include it in the anime-only benchmark. Verify that an attachment is an actual Arabic subtitle file, matches the requested anime episode/release, and can be retrieved within the site's documented/public access rules.
- The provider's archive-only notes indicate that new torrent ingestion stopped on 2026-05-09; this may limit coverage of newly released episodes. Do not present it as the primary current-season anime provider.

### Candidate I — Other community sources from the Bazarr provider ecosystem

The Bazarr/Bazarr+ ecosystem lists dozens of independent providers, but language coverage differs significantly. Many are built for Greek, Romanian, Persian, Turkish, Bulgarian, Polish, French, or other language communities; their existence does not prove Arabic coverage.

Rules for this pool:
- Only shortlist providers whose own current language maps or captured live pages explicitly demonstrate Arabic (ar/ara).
- Verify movies versus series and exact episode handling separately.
- Verify terms and API availability before automation.
- Prefer a documented provider API. Treat HTML scrapers as experimental and do not evade access controls.
- Do not clone a full third-party scraper framework into RAVEN23. Reimplement only a small, scoped adapter where access is authorized and the test corpus proves measurable Arabic coverage.

### Source counting and overlap

- A website and a mirror that carry the same file must be deduplicated by file hash/metadata when possible and must not be counted as two independent successful sources.
- The third-party Bazarr/Bazarr+ catalogs are research references for discovering providers and language support; they are not subtitle providers themselves and their code is not automatically authorized for inclusion in RAVEN23.

### Open-source repository provenance (research references only)

- [LavX/bazarr-provider-catalog](https://github.com/LavX/bazarr-provider-catalog) — MIT-licensed provider catalog containing the SubF2M, Sub-Scene, and AnimeTosho adapter references and test fixtures. It is a code catalog, not a subtitle source. Review each provider independently; do not embed the entire catalog runtime.
- [LavX/bazarr](https://github.com/LavX/bazarr) — GPL-3.0 Bazarr+ application that consumes the provider catalog. It is an implementation reference, not a subtitle provider. Do not vendor the full application into RAVEN23.
- [morpheus65535/bazarr](https://github.com/morpheus65535/bazarr) — GPL-3.0 original Bazarr project; its Subliminal provider implementation is a reference for AnimeTosho. Preserve required license/copyright notices if any code is reused.
- RAVEN23 remains GPL-3.0. The catalog's MIT license and the two Bazarr projects' GPL-3.0 terms are not interchangeable; record provenance and retain the applicable notices for any code copied or adapted.
- Current disposition: SubF2M is not integrated and remains conditional on site terms/live Arabic benchmark; Sub-Scene is blocked unless an authorized API/access path exists (no challenge bypass); AnimeTosho is not integrated and remains an anime-only archive candidate. None of these repositories is added as a runtime dependency.


---

## 4. Proposed provider orchestration and fallback behavior

Do not implement a simple sequential chain that waits for one provider's full timeout before starting the next. Use isolated provider tasks with independent deadlines:

1. Start the eligible Arabic-provider searches independently and immediately after the video is ready. The video must not wait for subtitle results.
2. Give each provider its own bounded timeout and result/error state. One timeout or exception must not discard results already received from other providers.
3. Display partial Arabic results as they arrive, while continuing the remaining provider searches in the background.
4. Search specifically for Arabic code ar for the Arabic-default path. Keep English separate as an explicit optional fallback; it must not be auto-applied as an Arabic subtitle.
5. On an empty result, 401/403, 404/410, 429, timeout, invalid JSON, expired download, ZIP failure, corrupt file, or player-apply failure, mark that candidate/provider unavailable for the current request and move to the next eligible candidate.
6. Honor Retry-After and provider quota headers on 429. Do not retry rapidly or bypass quotas.
7. Cache search results by media type + TMDB/IMDb identity + season + episode + requested language + relevant release identity. Use bounded freshness so providers are not hit repeatedly while the same player is open.
8. Report provider-specific diagnostics without leaking API keys, cookies, signed download URLs, or user credentials.
9. Do not use one global top-five candidate limit. Keep a fair candidate budget per provider and continue through the remaining Arabic candidates when earlier files fail.
10. Preserve the existing behavior that subtitle search does not delay video startup. Do not change the active video provider or video URL while searching or applying subtitles.

---

## 5. Arabic subtitle matching and quality scoring

A result matching the TMDB title and episode is only a first filter. The provider ranking should score the actual file:

1. Exact language: only ar/ara/Arabic normalized to ar for the Arabic auto-apply path.
2. Exact media identity: movie ID or series ID plus exact season and episode. Reject season packs, multi-episode ranges, trailers, and adjacent episodes from the auto-apply candidate set.
3. Release identity: compare the subtitle release/file name with the active stream's release/file name when available. Compare group, WEB-DL/WEBRip/BluRay, resolution, codec, and other meaningful release tags.
4. File hash: use it when the active provider exposes a trustworthy hash or the real video file is locally available. Do not invent a hash for a remote HLS/DASH URL.
5. Provider metadata: consider translation type (prefer human-authored when the user wants professional Arabic), download count, rating/quality signals when supplied, upload age, hearing-impaired tag, and file integrity.
6. Format and encoding: validate the actual downloaded payload, not just its filename or extension. Reject HTML error pages, empty files, invalid archives, malformed cue timing, and files with no cues.
7. Confidence: calculate a normalized match score and distinguish exact/high-confidence, plausible, and weak matches. A weak result must not silently replace an existing usable Arabic track.

The final provider priority must be derived from measured results. A provider that ranks first by name must not automatically outrank an exact release match from another provider.

### Arabic text and encoding

- Add explicit BOM-aware UTF-8 and UTF-16 decoding.
- Evaluate Arabic Windows-1256 handling using real samples before enabling it; do not fall back to Windows-1252 for every non-UTF-8 Arabic file.
- Preserve Arabic characters, punctuation, and line order through SRT/ASS/SSA normalization.
- Verify right-to-left text rendering and mixed Arabic/Latin names on the actual Android player.

### Subtitle timing

- Separate “correct Arabic translation” from “correctly synchronized to this video release”.
- Prefer exact release matches before attempting any time correction.
- Compare subtitle cue duration/end time with the actual episode/movie duration as a sanity check, but do not treat duration similarity alone as proof of synchronization.
- Add a user-controlled subtitle delay adjustment only after confirming the current BetterPlayer fork's supported API and testing it on-device. Do not automatically shift subtitle cues without evidence.
- Any saved manual offset must be scoped to the exact title/season/episode and selected subtitle, not globally applied to every video.

---

## 6. Proposed implementation phases

### PHASE64.0 — Baseline and expanded Arabic-provider discovery
- Record current provider results and failures for a fixed benchmark of movies, ordinary series, and anime.
- Check every provider separately for Arabic availability, exact episode identity, release matching, actual download success, human/machine label, and synchronization signals.
- Validate the three owner-supplied API keys (ArabicSubs, SubSource, OpenSubtitles) with one minimal authenticated request each; record only pass/fail, masked key identity, response status, quota headers, and any provider-side restrictions. Never print or persist a full key in logs or reports.
- Verify current service availability, free limits, key-sharing restrictions, site terms, robots/access policy, and exact request/response contracts.
- Benchmark the existing eligible paths plus SubF2M, Sub-Scene, and AnimeTosho where each source is lawfully and technically accessible.
- Mark paused, captcha-protected, undocumented, or access-restricted sources as unavailable; do not bypass their controls.
- Identify duplicate catalogues and mirrored files so the final provider count reflects independent sources rather than aliases.
- Create mocked tests for every documented provider response and failure mode.
- No player UI, settings, subtitle search order, or provider behavior changes in this stage.

### PHASE64.1 — Development credentials and production separation
- **Owner-authorized temporary exposure exception (2026-11-22):** keep the existing TMDB, OpenSubtitles, and SubSource test values populated in the tracked `.env.example` while the owner is testing RAVEN23 on Android. Do not blank, delete, rotate, replace, or migrate these existing values unless the owner explicitly confirms that phone testing is complete or gives a separate instruction.
- The owner understands that `.env.example` is public and that GitHub Actions copies it to `.env`; `pubspec.yaml` bundles `.env` as an application asset. Therefore the configured values are publicly visible and are extractable from built APKs. This is an explicitly accepted, temporary development exception only, not a secure design.
- Do not replace the existing keys with newly registered keys as an automatic remediation. Preserve the owner's current test configuration and do not repeat the previous blanking/removal action.
- Do not use these exposed values for production traffic, production deployments, or release credentials. They must remain limited to the owner's development/testing period and provider-approved usage.
- Do not print, echo, or copy actual key values into chat replies, phase documents, CI logs, build reports, test diagnostics, or screenshots. Logs may record variable names, masked identifiers, response status, and quota metadata only.
- ArabicSubs explicitly requires its Bearer key to remain server-side. Keep only `ARABICSUBS_PROXY_URL` in the phone app and route calls through a protected test proxy; never put `ARABICSUBS_API_KEY` in `.env.example` or the APK.
- Do not place primary account passwords, session cookies, or private account recovery data into the mobile app.
- Respect provider terms, free quotas, rate limits, and key-sharing rules. Do not use key rotation or additional accounts to evade quotas.
- **Owner-only closure condition:** only after the owner explicitly confirms phone testing is complete may the existing test values be migrated to protected backend configuration and removed from the public template/build asset. Record that closure before changing this exception.
- Add per-provider enabled/disabled state and quota/error status without changing unrelated settings.

### PHASE64.2 — Documented provider adapters
- OpenSubtitles.com API v1 only; remove reliance on the VIP-only legacy route for free operation.
- ArabicSubs documented v1 via a secure proxy, including the documented translationType field and exact episode metadata.
- SubF2M experimental adapter, only if the live Arabic benchmark and site access rules permit automated retrieval.
- Sub-Scene experimental candidate, only if the provider supplies an approved API/access path; never build CAPTCHA/anti-bot bypass.
- AnimeTosho anime-only adapter, after confirming Arabic attachment availability and AniDB episode mapping.
- Do not implement SubtitleCenter: it remains explicitly excluded by the owner decision recorded in Section 3.
- SubSource documented API using the owner's registered account/API key, replacing the existing undocumented `/v1` website flow; verify the documented endpoint/authentication and exact Arabic season/episode coverage.
- Preserve RAVEN23 Scraper API as the last compatibility source.

### PHASE64.3 — Fast independent search and robust fallback
- Replace the all-or-nothing 48-second Future.wait behavior with independently timed provider tasks and incremental partial results.
- Use Arabic-only search for the Arabic automatic path.
- Remove the global five-candidate starvation problem.
- Continue automatically to the next provider/candidate on a real failure while preserving the video session.

### PHASE64.4 — Best-subtitle selection engine (mandatory before shared cache)
This phase defines the single authoritative selector used by both the standalone app and the later shared cache. It must be implemented and validated before any shared subtitle publication is enabled.

#### A. Hard rejection gates (not score penalties)
Reject a candidate from automatic selection when any of the following is proven:
- wrong language for the user's selected primary language;
- wrong movie/title identity;
- wrong season or episode, trailer, season pack, or multi-episode range for a single-episode request;
- invalid, empty, corrupt, unsupported, or cue-less subtitle payload;
- file content/metadata contradicts its advertised language or format;
- known wrong release/timing identity that makes it unsafe for this video.

A candidate that fails a hard gate must never be rescued by high download count, provider reputation, or a user popularity score.

#### B. Candidate evidence and ranking
For every remaining candidate, compute and retain an explainable evidence record using:
- exact media identity and exact season/episode;
- exact release identity where the video provider exposes reliable release information;
- normalized release tags (release group, WEB-DL/WEBRip/BluRay, resolution, codec and other stable tokens);
- trustworthy video/subtitle hash equality only when a real video file or provider hash is available;
- source metadata such as translator/uploader attribution, translation type, hearing-impaired flag, download count and provider quality signals;
- actual downloaded-file integrity, encoding/decoding success and cue structure;
- synchronization evidence, including real playback verification and user feedback scoped to this title/episode/release.

Provider name or fixed provider priority is never sufficient to make a candidate the winner.

#### C. Confidence classes and automatic-choice policy
- **High confidence:** exact media/episode match, strong release match, valid Arabic payload, and no known timing/content defect. Eligible for automatic recommendation.
- **Medium confidence:** exact media/episode and valid file, but release or synchronization evidence is incomplete. Show as an alternative; do not silently replace a working verified subtitle.
- **Low confidence:** weak release evidence, conflicting metadata, or unresolved synchronization concern. Never auto-apply as the preferred winner; show only when useful and label as unverified.
- **Rejected:** fails a hard gate or receives sufficient confirmed evidence of a serious defect.

Do not invent numeric weights or confidence cutoffs before measuring the fixed benchmark. Calibrate the weights/thresholds using PHASE64.6 evidence, version the selector rules, and keep the same selector version across phone and TV clients.

#### D. Single recommended row and alternatives
- Present one recommended candidate for the configured primary language.
- Group the other candidates for that same language behind an expandable alternatives section.
- Preserve source/release/HI details for each alternative.
- Respect a user's explicit manual choice; background search, cache updates, or community feedback must not silently switch it.
- Never merge distinct releases or timing variants merely because their language is the same.

#### E. Fallback and no-result behavior
- Try eligible candidates in explainable rank order, with a fair per-provider budget rather than a global five-result starvation limit.
- On download, parse, decode, or application failure, move to the next eligible candidate.
- Preserve an already working verified subtitle when no stronger high-confidence candidate exists.
- If every candidate is weak or rejected, report no verified preferred subtitle rather than presenting a false "perfect" result.

#### Required tests for this phase
- exact movie/episode identity and season/episode boundary tests;
- exact-release versus different-release ordering;
- duplicate-content versus distinct-release retention;
- wrong-language and malformed-payload rejection;
- human/machine translation metadata handling;
- score determinism and selector-version regression;
- fallback after download/normalization/player-apply failure;
- low-confidence candidate never replacing a working verified subtitle;
- single recommended row with expandable alternatives;
- manual selection persistence during later refreshes.

### PHASE64.5 — Arabic encoding, RTL, and synchronization verification
- Add Arabic-specific decoding tests for UTF-8, UTF-16, and verified Windows-1256 samples.
- Test Arabic/Latin mixed text, punctuation, multi-line cues, ASS/SSA normalization, and right-to-left rendering.
- Verify subtitle delay controls against the actual BetterPlayer fork before implementing a user-facing offset control.
- Keep all changes scoped to subtitle behavior.

### PHASE64.6 — Selector acceptance, telemetry, and release validation (hard gate for PHASE64.7)
- Run the complete relevant Flutter tests, Android JVM tests, static analysis, and Release ARM64 APK/ABI audit.
- Run live-provider tests using only the owner's free accounts/keys and within published quotas.
- Perform real-device playback checks for movies, ordinary series, and anime, covering multiple releases and known Arabic subtitle references.
- Publish a provider and selector scorecard with Arabic coverage, exact-episode match rate, exact-release match rate, hard-rejection correctness, high/medium/low confidence distribution, successful download/parse/apply rate, p50/p95 response time, sync complaints, and fallback success rate.
- Verify that the selector consistently chooses the best supported candidate in the benchmark and never auto-applies a proven wrong-language, wrong-episode, or low-confidence candidate over a working verified subtitle.
- Freeze and record the accepted selector algorithm/version, confidence thresholds, benchmark corpus, and test results.
- PHASE64.7 cannot start until the owner-visible report records PHASE64.6 as PASS.
- Do not claim a provider is “best” based only on its marketing description or catalogue size.

---

## 7. Benchmark and acceptance criteria

Use a fixed test corpus containing movies, standard TV episodes, and anime episodes, with known Arabic subtitle references and the active stream release identifiers. Include multiple release types (WEB-DL, WEBRip, BluRay, 720p/1080p) where possible.

For every sample record:
- whether each provider found an Arabic result;
- whether media identity and season/episode were exact;
- whether the release matched;
- whether the file downloaded, decoded, normalized, and applied successfully;
- whether Arabic text rendered correctly;
- whether the timing matched the video;
- response time and quota consumption;
- whether fallback reached a working candidate after the first candidate failed.

Acceptance:
- No non-Arabic subtitle is silently auto-applied while Arabic is the selected preference.
- No wrong season/episode or multi-episode pack is auto-applied to a single episode.
- A provider timeout or outage never empties results already returned by other providers.
- A failed candidate causes a real fallback to the next eligible candidate/provider.
- Search never delays video startup or changes the active video source.
- The best candidate is selected by match evidence, not provider name alone.
- A wrong-language, wrong-episode, malformed, or proven incompatible candidate is never automatically selected.
- A low-confidence candidate cannot silently replace a working verified subtitle.
- The menu shows one recommended track with other same-language tracks available as explicit alternatives.
- The accepted selector has a recorded version and repeatable passing benchmark for movies, ordinary series, and anime.
- Production API keys and account credentials are not committed, logged, or embedded as public application secrets. The owner's temporary phone-testing values in `.env.example` are an explicit development-only exception already documented in PHASE64.1; they must not be treated as safe for production or permanent credentials.
- All provider quotas and published terms are respected.
- Arabic text encoding, RTL rendering, and timing are checked on an actual Android device.
- No protected feature group is changed; every phase declares the protected-scope impact.

## 8. Owner decisions and current confirmed direction

### Confirmed by the owner on 2026-11-21

- Search for existing Arabic subtitle files and apply those files.
- Do not translate English subtitles into Arabic.
- Do not use AI translation, machine-translation APIs, or generated replacement subtitles in this phase.
- Use free sources only; respect each provider's published quotas and key-sharing rules.
- Keep the currently deferred DCIM subtitle-sidecar export issue outside this work.

### Owner-confirmed provider API keys (2026-11-22)
The owner confirmed that an API key has already been obtained from each of the three registered providers:
- ArabicSubs — https://arabicsubs.com — documented `Authorization: Bearer <key>`.
- SubSource — https://subsource.net — documented `X-API-Key: <key>`.
- OpenSubtitles — https://www.opensubtitles.com — current API v1 uses the `Api-Key` request header and a valid application User-Agent.

Do not copy actual key values, usernames, passwords, cookies, or tokens into this phase file, chat replies, CI logs, build reports, or diagnostics. PHASE64.0 must validate each key without exposing it, record only masked identifiers/status, confirm the active free quota, and check the provider's rules for client-side versus server-side use. ArabicSubs explicitly requires its key to be kept on a server; that key must be used through a protected test proxy even during phone testing. SubSource and OpenSubtitles keys can be used in the owner's temporary development configuration only after their current terms and key-exposure implications are respected. The current RAVEN23 code is not yet aligned with all three documented API contracts (see Sections 2 and 6).

### Owner-confirmed temporary public-key testing exception (2026-11-22)
- The owner explicitly reaffirmed that the existing TMDB, OpenSubtitles, and SubSource values are intentionally exposed for the current phone-testing window and must remain in `.env.example`. This instruction supersedes earlier advice in this phase to blank or remove the existing OpenSubtitles and SubSource values.
- Do not remove, blank, rotate, replace, or migrate these existing values without a later explicit owner instruction. The owner will direct the server migration after the Android testing period is complete.
- This is not a production-security approval: the tracked file is public and the CI/APK asset path makes values extractable. Do not use the exposed values for production traffic or production releases.
- Keep actual values out of phase documents, chat replies, CI logs, build reports, and diagnostics. The template may contain the values only as the owner's explicitly approved exception.
- ArabicSubs remains a separate server-only credential: its Bearer key must remain behind the protected proxy and must never be added to the mobile `.env.example` or APK.

### Decisions still to settle before provider credentials or production ranking

1. **Human-authored versus labelled machine-submitted files:** proposed default is to prefer human-authored Arabic files and exclude files explicitly marked as AI/machine translated. Confirm whether all machine-labelled files should be excluded or merely ranked below human submissions.
2. **Low-confidence matches:** keep the currently selected/available subtitle and show alternatives, rather than silently replacing it with a weak release match.

No provider integration or player change is authorized by this proposal alone. PHASE64.0 remains a research/benchmark stage and must not modify application behavior.

## 9. Official references checked on 2026-11-21

- OpenSubtitles API setup: https://opensubtitles.tawk.help/article/getting-started
- OpenSubtitles free access and old API migration: https://opensubtitles.tawk.help/article/about-the-api and https://blog.opensubtitles.com/opensubtitles/web/understanding-opensubtitles-websites-and-services
- SubSource documented API and free limits: https://subsource.net/api-docs
- ArabicSubs API, free tier, Arabic endpoints, documented translationType schema, and key-handling guidance: https://arabicsubs.com/api-access and https://arabicsubs.com/api/v1/openapi.json
- SubtitleCenter free API, current paused status, human/machine filtering, exact-release and hash lookup: https://subtitlecenter.com/api/docs
- SubF2M and Sub-Scene language coverage evidence in the independent Bazarr+ provider catalog: https://github.com/LavX/bazarr-provider-catalog
- AnimeTosho Arabic language support in the Bazarr Subliminal provider implementation: https://github.com/morpheus65535/bazarr/blob/master/custom_libs/subliminal_patch/providers/animetosho.py
