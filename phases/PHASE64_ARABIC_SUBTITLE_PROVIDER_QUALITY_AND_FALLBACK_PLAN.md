# PHASE64 — Arabic Subtitle Providers, Matching Quality, Synchronization & Fallback

**Status:** PROPOSAL ONLY — RESEARCH AND PLAN. NOT AUTHORIZED FOR IMPLEMENTATION.  
**Project:** RAVEN23  
**Baseline inspected:** main commit 6d12023e446db3d444716c3b407572a89cf545be  
**Baseline build:** GitHub Actions #249 passed (Flutter tests, Android tests, ARM64 release APK, ABI/size audit).  
**Language target:** Arabic (ar) as the automatic preferred subtitle language.  
**Cost constraint:** free provider/API tiers only. No paid AI-translation service, VIP plan, or paid provider is included in this proposal.  
**Owner-confirmed product rule (2026-11-21):** search for and select already-published Arabic subtitle files only. Do not translate English subtitles into Arabic, do not invoke an AI translation endpoint, and do not generate substitute Arabic captions.

## 0. Approval gate

This file is a planning document only. No provider integration, UI change, settings change, key configuration, subtitle algorithm, or playback change may begin until the owner explicitly approves this plan.

The separate rule in RAVEN23_PROTECTED_FEATURES_NO_TOUCH_WITHOUT_EXPLICIT_REQUEST.md remains active. In particular, the existing offline player, episode cards, season switching, video downloads, DCIM video export, source ordering, quality behavior, and other accepted features are outside this phase.

The known issue that copies a selected subtitle sidecar beside the video under DCIM/RAVEN23/<title>/SUBTITLE is deferred. This phase does not reopen or alter it.

---

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

1. **OpenSubtitles.com API v1:** already supported when OPENSUBTITLES_API_KEY is configured. Without that key, the code falls back to the old rest.opensubtitles.org API.
2. **SubSource:** already supported through the older undocumented api.subsource.net/v1 website flow. It currently performs IMDb title search, title/season lookup, episode filtering, a detail lookup, token resolution, and ZIP download. The current flow does not use the documented SubSource API-key contract.
4. **ArabicSubs:** an optional adapter already exists behind ARABICSUBS_PROXY_URL. It expects the app's own proxy to forward search, title-subtitle listing, and download requests.
5. **RAVEN23 Scraper API:** retained as an additional provider-specific fallback.

### Important current behavior and weaknesses

- Provider requests are gathered using Future.wait with a global timeout of 48 seconds. If that wait times out, the timeout handler returns an empty result list rather than preserving the providers that already completed. A single slow provider can therefore delay or hide otherwise useful Arabic results.
- Arabic ordering is currently a fixed provider rank: SubSource, OpenSubtitles, ArabicSubs, then other sources. That rank does not prove that a particular file matches the active release.
- Automatic application tries only the first five Arabic candidates after merging and sorting. Five weak results from one provider can consume the candidate budget before a better result from another provider is attempted.
- The OpenSubtitles legacy REST endpoint is not a suitable free-only fallback: OpenSubtitles announced that access to the old API was restricted to VIP users from January 2024. The new OpenSubtitles.com API remains the relevant free route.
- SubSource's current implementation is explicitly described in the source as an undocumented flow. The provider now publishes a documented API requiring an API key and advertising a free tier.
- ArabicSubs is designed around an Arabic catalogue and exposes title/episode subtitle records, release labels, download counts, and translation-type metadata. Its current API contract is different from the custom proxy adapter already in RAVEN23 and needs to be mapped deliberately.
- If a preferred Arabic provider subtitle is already marked selectedByDefault, the automatic external-provider search is skipped. This can suppress better alternatives when the in-stream Arabic track is badly timed or otherwise poor.
- The owner has explicitly excluded translating English subtitle files into Arabic; candidate discovery and scoring must never invoke a translation service as a fallback.
- The current OpenSubtitles query includes both Arabic and English even when Arabic is preferred. The final auto-apply filter is Arabic-only, but the provider search still spends quota/time on non-Arabic results.
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
- Preserve the owner's current development workflow: `.env.example` is temporarily used as the active configuration source for phone-testing builds, and its current values must remain available during this testing period. Do not blank the file, remove it from the Flutter asset/build path, or migrate the values to the production server until the owner confirms that phone testing is complete.
- The owner has confirmed that API keys have been obtained for ArabicSubs, SubSource, and OpenSubtitles. Do not ask the owner to register again; validate the existing keys in PHASE64.0.
- The current CI flow copies `.env.example` to `.env`, and Flutter currently bundles `.env` as an application asset. Therefore, values used this way are readable from the public repository and extractable from the test APK. This is a documented, temporary development exception, not a secure secret-storage design.
- OpenSubtitles and SubSource development keys may be used in the temporary phone-test configuration only after confirming their provider terms and accepting the known extraction exposure for this test build. Do not use these test keys as production credentials.
- ArabicSubs explicitly says its Bearer API key must remain on the server and must not be placed in frontend code. Keep `ARABICSUBS_PROXY_URL` in the phone app configuration and route calls through a protected test proxy; never embed the ArabicSubs key in the APK, even during phone testing.
- Do not place primary account passwords, session cookies, or private account recovery data into the mobile app.
- Use only provider credentials whose terms permit the chosen development/testing use. Track free quotas and revoke or replace temporary credentials if misuse or unexpected quota consumption is detected.
- After phone testing is complete, move production credentials to the appropriate protected backend configuration and remove the temporary development values from public source/build artifacts, with explicit owner approval.
- Prefer per-user keys stored in Android secure storage where the provider permits BYOK for the production design.
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

### PHASE64.4 — Release-aware Arabic candidate ranking
- Add exact episode and release matching.
- Add candidate confidence, translation-type, download-count, and file-validation scoring.
- Preserve a working in-stream Arabic track as a candidate, but do not let its existence silently disable the independent Arabic search when the track is poor or fails validation.
- Do not replace a working subtitle with a lower-confidence candidate.

### PHASE64.5 — Arabic encoding, RTL, and synchronization verification
- Add Arabic-specific decoding tests for UTF-8, UTF-16, and verified Windows-1256 samples.
- Test Arabic/Latin mixed text, punctuation, multi-line cues, ASS/SSA normalization, and right-to-left rendering.
- Verify subtitle delay controls against the actual BetterPlayer fork before implementing a user-facing offset control.
- Keep all changes scoped to subtitle behavior.

### PHASE64.6 — Acceptance, telemetry, and release validation
- Run the complete relevant Flutter tests, Android JVM tests, static analysis, and Release ARM64 APK/ABI audit.
- Run live-provider tests using only the owner's free accounts/keys and within published quotas.
- Perform real-device playback checks for movies, ordinary series, and anime.
- Publish a provider scorecard with Arabic coverage, exact-episode match rate, exact-release match rate, successful download/parse rate, p50/p95 response time, sync complaints, and fallback success rate.
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

### Additional owner-confirmed development configuration decision (2026-11-22)
- The owner requires the current `.env.example` values to remain usable during development because the app will consume them in test builds installed on the owner's Android phone.
- Do not migrate those values to the server or disable their test-build loading before the owner says phone testing is complete.
- The owner has been informed that the current public repository and CI/APK asset flow make these values retrievable. This temporary arrangement must be treated as a development/testing exception only.
- Provider-specific restrictions still apply: a credential documented as server-only must remain behind a protected test proxy, even while the app is being tested on a phone.
- No credential values should be copied into phase documentation, CI logs, build reports, chat replies, or diagnostic output.

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
