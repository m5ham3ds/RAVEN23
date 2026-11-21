# PHASE64 — Arabic Subtitle Providers, Matching Quality, Synchronization & Fallback

**Status:** PROPOSAL ONLY — RESEARCH AND PLAN. NOT AUTHORIZED FOR IMPLEMENTATION.  
**Project:** RAVEN23  
**Baseline inspected:** main commit 6d12023e446db3d444716c3b407572a89cf545be  
**Baseline build:** GitHub Actions #249 passed (Flutter tests, Android tests, ARM64 release APK, ABI/size audit).  
**Language target:** Arabic (ar) as the automatic preferred subtitle language.  
**Cost constraint:** free provider/API tiers only. No paid AI-translation service, VIP plan, or paid provider is included in this proposal.

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
- Automatically translating English subtitles into Arabic in this provider phase. The target here is finding and applying actual Arabic subtitle files. Any future machine-translation path must be a separate proposal and must not be presented as a free feature when the provider marks it paid.
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
3. **SubDL:** already supported through api.subdl.com/api/v1/subtitles with SUBDL_API_KEY. It currently searches AR and EN together.
4. **ArabicSubs:** an optional adapter already exists behind ARABICSUBS_PROXY_URL. It expects the app's own proxy to forward search, title-subtitle listing, and download requests.
5. **RAVEN23 Scraper API:** retained as an additional provider-specific fallback.

### Important current behavior and weaknesses

- Provider requests are gathered using Future.wait with a global timeout of 48 seconds. If that wait times out, the timeout handler returns an empty result list rather than preserving the providers that already completed. A single slow provider can therefore delay or hide otherwise useful Arabic results.
- Arabic ordering is currently a fixed provider rank: SubSource, OpenSubtitles, SubDL, ArabicSubs, then other sources. That rank does not prove that a particular file matches the active release.
- Automatic application tries only the first five Arabic candidates after merging and sorting. Five weak results from one provider can consume the candidate budget before a better result from another provider is attempted.
- The OpenSubtitles legacy REST endpoint is not a suitable free-only fallback: OpenSubtitles announced that access to the old API was restricted to VIP users from January 2024. The new OpenSubtitles.com API remains the relevant free route.
- SubSource's current implementation is explicitly described in the source as an undocumented flow. The provider now publishes a documented API requiring an API key and advertising a free tier.
- SubDL's current integration calls the older v1 endpoint. Its current developer documentation describes v2 search and file-matching endpoints that expose release match scores.
- ArabicSubs is designed around an Arabic catalogue and exposes title/episode subtitle records, release labels, download counts, and translation-type metadata. Its current API contract is different from the custom proxy adapter already in RAVEN23 and needs to be mapped deliberately.
- If a preferred Arabic provider subtitle is already marked selectedByDefault, the automatic external-provider search is skipped. This can suppress better alternatives when the in-stream Arabic track is badly timed or otherwise poor.
- The current OpenSubtitles and SubDL queries include both Arabic and English even when Arabic is preferred. The final auto-apply filter is Arabic-only, but the provider search still spends quota/time on non-Arabic results.
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
- The free rate limit is much lower than SubDL/SubSource, so it must not be queried repeatedly for every video state change.
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

### Candidate C — SubDL API v2: large catalogue and release matching

Official developer documentation: https://subdl.com/developers  
Terms: https://subdl.com/terms

Documented free allowance:
- 2,000 searches per day;
- 50 downloads per day;
- subtitle search and download are available on the free key;
- AI translation is paid and is therefore excluded from this free-only plan.

Documented capabilities:
- 6 million-plus subtitle files across 90-plus languages;
- TMDB/IMDb title identifiers;
- movie, TV, episode, and season-pack search;
- release-filename matching;
- a match_score from 0 to 1 on the file-search endpoint, with the documentation identifying scores of 0.8 or higher as confident release matches;
- direct single-file download options.

Why evaluate it: its release-aware matching can help avoid subtitles that belong to another encode or release even when the title and episode are correct.

Important terms constraint:
- SubDL's terms say a free API key must not be used as a shared key to power a commercial service for its users.
- The terms allow an app to let each user bring their own API key, with each user's requests counted against that user's own account.
- Do not bundle one free shared key in the APK or use a free key pool to bypass limits.
- Use documented v2 endpoints; do not silently treat paid AI translation as free.

### Candidate D — SubSource documented API: replace the undocumented flow

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

### PHASE64.0 — Baseline and provider contract tests
- Record current provider results and failures for an agreed benchmark title set.
- Verify API documentation, required credentials, free limits, and exact request/response contracts for each candidate.
- Create mocked tests for every documented provider response and failure mode.
- No player UI or provider behavior changes in this stage.

### PHASE64.1 — Safe free-key configuration
- Define how the owner will provide free API credentials.
- Keep API keys out of source control, public .env assets, APK constants, and logs.
- Prefer per-user keys stored in Android secure storage where the provider permits BYOK.
- For APIs that explicitly require server-side secrets (especially ArabicSubs), use a protected user-controlled proxy. Respect each provider's free-key sharing rules.
- Add per-provider enabled/disabled state and quota/error status without changing unrelated settings.

### PHASE64.2 — Documented provider adapters
- OpenSubtitles.com API v1 only; remove reliance on the VIP-only legacy route for free operation.
- SubDL API v2 search/download and release match-score support.
- ArabicSubs documented v1 via a secure proxy, including translationType and exact episode metadata.
- SubSource documented API, only after verifying Arabic/episode coverage.
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
- API keys are not committed, logged, or embedded as public application secrets.
- All provider quotas and published terms are respected.
- Arabic text encoding, RTL rendering, and timing are checked on an actual Android device.
- No protected feature group is changed; every phase declares the protected-scope impact.

## 8. Owner decisions needed before implementation

1. **Free-key model:** use each user's own free API keys (BYOK) in RAVEN23, or use only providers that can legally be served through the owner's private backend/proxy without violating their free-tier terms? SubDL explicitly restricts using a free key as a shared key for a commercial service; its terms permit per-user keys.
2. **Arabic content policy:** automatically prefer human-authored Arabic subtitles and reject machine-generated results unless the user explicitly enables them?
3. **Low-confidence matches:** keep the currently available subtitle and show alternatives, rather than silently replacing it with a weak release match?

These decisions should be confirmed before PHASE64.1/64.2. No provider integration or player change is authorized by this proposal alone.

## 9. Official references checked on 2026-11-21

- OpenSubtitles API setup: https://opensubtitles.tawk.help/article/getting-started
- OpenSubtitles free access and old API migration: https://opensubtitles.tawk.help/article/about-the-api and https://blog.opensubtitles.com/opensubtitles/web/understanding-opensubtitles-websites-and-services
- SubDL current API v2 and free limits: https://subdl.com/developers
- SubDL terms and per-user free-key restriction: https://subdl.com/terms
- SubSource documented API and free limits: https://subsource.net/api-docs
- ArabicSubs API, free tier, Arabic endpoints, and key-handling guidance: https://arabicsubs.com/api-access and https://arabicsubs.com/api/v1/openapi.json
