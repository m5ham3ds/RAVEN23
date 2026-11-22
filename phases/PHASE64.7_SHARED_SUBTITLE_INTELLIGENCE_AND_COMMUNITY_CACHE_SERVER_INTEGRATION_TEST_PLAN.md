# PHASE64.7 — Shared Subtitle Intelligence & Community Cache
## Post-Laravel Integration Test Plan

**Status:** TEST PLAN ONLY — BLOCKED until BOTH prerequisites are satisfied: (1) PHASE64.0–64.6 subtitle selection/quality engine has passed its benchmark and been accepted; and (2) the Laravel backend is connected to RAVEN23 with the required shared-subtitle API contract deployed.  
**Project:** RAVEN23  
**Created:** 2026-11-22  
**Related phase:** PHASE64 — Arabic Subtitle Providers, Matching Quality, Synchronization & Fallback  
**Execution rule:** Do not run live shared-cache tests, create backend tables, add endpoints, change player behavior, or migrate provider calls as part of this document-only task. Execute this plan only after the owner confirms that the app is connected to the intended Laravel staging backend.

---

## 0. Purpose and expected outcome

This document defines how to test the owner's proposed cross-user subtitle workflow after the Laravel server is connected:

1. A user starts a movie or episode.
2. RAVEN23 checks the shared subtitle cache before starting another provider search.
3. If a suitable shared subtitle already exists, the server returns it directly. The client does not call ArabicSubs, SubSource, or OpenSubtitles for that cache hit.
4. If there is no suitable shared subtitle, the server grants one client a temporary discovery lease. Other clients requesting the same title, episode, language, and release wait for that same discovery operation instead of starting duplicate searches.
5. The discovery client runs the current subtitle filtering workflow, chooses the strongest usable result, downloads and normalizes it, and uploads the permitted subtitle file plus its matching/provenance metadata to the server.
6. The server validates and stores the file, then makes the shared result available to the waiting and later users.
7. Each client retains its own local subtitle cache as an offline and fast-start fallback.

**Primary success condition:** after a valid shared subtitle has been published for an exact media/release identity, later users receive the shared file without generating new requests to the external subtitle providers.

### Mandatory prerequisite — selector must already be accepted

PHASE64.7 is downstream of PHASE64.0–64.6. It must not begin merely because Laravel is connected.

Before any shared-cache implementation or test:
- PHASE64.0–64.2 must have established and tested the eligible provider adapters and credentials.
- PHASE64.3 must have reliable independent search and fallback behavior.
- PHASE64.4 must have one deterministic, evidence-based subtitle selector with hard rejection gates, confidence classes, and a single recommended result plus alternatives.
- PHASE64.5 must have passed Arabic decoding, RTL, and synchronization checks.
- PHASE64.6 must have passed the movie/series/anime benchmark and real-device playback acceptance. The accepted selector version and confidence thresholds must be recorded in the Phase64.6 report.

If any prerequisite fails or the accepted selector version changes later, pause publication of new globally recommended results until the relevant selector acceptance tests pass again.

The shared cache must store and deliver the output of the accepted selector. It must not independently rank provider results, assume that the first downloadable file is best, or elevate a merely downloaded Candidate to Verified. A cache hit is eligible as the recommended result only if its status and release-match evidence satisfy the same accepted selector rules.

This phase is about verification of the shared-cache behavior, not re-running the provider integration or selector-development work.

---

## 1. Owner-confirmed permissions and constraints

### 1.1 Provider file permissions confirmed by the owner

On 2026-11-22, the owner explicitly confirmed that RAVEN23 has permission from all three providers below to download subtitle files and republish those files:

- ArabicSubs — https://arabicsubs.com
- SubSource — https://subsource.net
- OpenSubtitles — https://www.opensubtitles.com

For this test plan, that owner-confirmed permission is the basis for testing the download → normalize → upload → shared delivery flow for files from those three sources. The test must preserve provenance and attribution metadata for every shared file. Do not silently strip or replace the original translator, uploader, release, or provider information when that information is supplied by the source.

Do not copy actual provider API keys, credentials, session cookies, or tokens into this document, test fixtures, test output, or CI logs.

If a particular provider response or individual file carries a narrower restriction, expiry, removal request, or other condition, the shared record must honor that condition. A provider/file takedown must invalidate the shared delivery record and remove or quarantine the stored object according to the provider's instruction.

### 1.2 Existing product decisions remain active

- Search for existing subtitle files only.
- Do not translate English subtitles into Arabic.
- Do not generate replacement subtitles with AI or machine translation.
- Use free provider access only and respect published quotas.
- SubDL remains completely excluded: do not add SubDL v1, v2, website scraping, mirrors, or alternate SubDL routes.
- SubtitleCenter remains excluded.
- The user's existing primary subtitle-language setting remains the source of truth. Arabic is currently the default preference, but the shared cache must work for any language the user selects.
- Do not alter video-provider order, stream URL selection, video quality behavior, offline player behavior, downloads, episode cards, season switching, or DCIM export.

### 1.3 Development-key arrangement

The previously confirmed temporary phone-testing arrangement for `.env.example` remains in force until the owner says phone testing is complete. This plan does not blank, remove, or migrate those values.

ArabicSubs' documented server-only key requirement remains applicable: the phone app must communicate through the protected test proxy, and the ArabicSubs Bearer key must not be embedded in the APK. The receiving client must never need an external provider key to read a shared cached subtitle.

---

## 2. Current repository baseline relevant to this plan

The following is the inspected RAVEN23 Flutter baseline. These are existing client behaviors, not features of the proposed shared Laravel cache.

### 2.1 Existing local subtitle storage

`lib/services/subtitle_playback_store.dart` already:

- normalizes an external subtitle to WebVTT before saving it;
- stores the file and a `tracks.json` manifest in the app's private support directory;
- keeps up to 10 tracks per media key;
- rejects empty/invalid WebVTT and files above its current 12 MiB text limit;
- restores a cached preferred-language track before the player is initialized;
- does not upload any file to Laravel.

The shared server cache must complement this local store, not replace it. On a successful shared-cache download, the client should continue saving the normalized file locally through the same local persistence path.

### 2.2 Existing player search and automatic selection

`lib/screens/common/player/player_external_subtitles.dart` currently:

- restores local cached subtitles using the media cache key;
- honors the configured preferred language;
- skips external search when the active video provider already supplied a preferred-language subtitle;
- otherwise calls `ExternalSubtitleService` after video setup;
- tries up to five preferred-language candidates and applies the first one that downloads and normalizes successfully;
- stores a successfully downloaded external subtitle locally;
- does not publish it to a shared server cache.

The shared-cache lookup must occur before provider search, but must not delay video startup.

### 2.3 Existing language menu behavior

`lib/functions/subtitle_options.dart` deliberately keeps different tracks as distinct selectable rows, even when they share the same language. It numbers repeated same-language tracks and supports up to four same-language fallback tracks per network row.

The planned shared-cache UI must make one recommended result prominent and place other same-language candidates under an expandable alternatives area. It must not destroy the user's ability to choose another track. This UI behavior is a later implementation check; this document does not change the menu.

### 2.4 Existing API contracts must not be confused

The root `openapi.json` describes the **RAVEN23 Scraper API v2**, including:

- `GET /api/v2/subtitles/search` — a combined provider catalogue;
- `GET /api/v2/subtitles/{provider}/{id}` — a subtitle-file passthrough.

That Scraper API contract is not, by itself, the proposed persistent shared subtitle repository on Laravel. Its documented short response/file cache policies do not prove that a cross-user, quality-reviewed, persistent subtitle store exists.

The Flutter repository also contains a generic `LaravelApi` client and Laravel migration scaffolding. This inspected RAVEN23 repository does not currently define the shared-subtitle Laravel endpoints, database tables, object-storage contract, or cross-user publication workflow required by this test plan. The Laravel backend is maintained separately.

Do not mark any test below as passed merely because the Scraper API subtitle endpoints respond successfully or because the current device-local cache works.

---

## 3. Target workflow to test

### 3.1 Cache-first request

For each playback request, construct a normalized lookup identity from:

- media type: movie or series episode;
- TMDB ID;
- season and episode for series;
- requested subtitle language (normalized, e.g. `ara` → `ar`);
- release-match identity for the active video where reliable information is available.

The server should return one of these states:

| State | Meaning | Client behavior |
|---|---|---|
| `hit` | A suitable permitted shared subtitle exists | Download/stream it from Laravel; do not query external providers |
| `miss` | No suitable shared subtitle exists and no discovery is running | Request a discovery lease |
| `pending` | Another client already owns discovery for the same identity | Wait/poll the existing job; do not query providers |
| `stale` | A previous record exists but needs revalidation | Use only if its policy permits; otherwise start/join discovery |
| `unavailable` | No suitable subtitle was found after discovery | Use existing provider/local/stream fallback behavior |

The server response must distinguish an exact release match from a broader media/episode match. A generic episode subtitle must not be represented as an exact match to a different release.

### 3.2 One discovery owner (single-flight)

On a cache miss, the backend must atomically grant one short-lived discovery lease for the normalized lookup identity.

- The first eligible client receives the lease and becomes the discovery owner.
- Concurrent clients receive the same job identifier and a `pending` state.
- A follower must not call any external provider while that job is active.
- The lease must expire safely if the discovery owner disconnects or crashes.
- After lease expiry, exactly one waiting client may claim the retry; there must never be two active owners for the same identity at the same time.
- Idempotency keys must prevent duplicate upload/publication if the owner retries after a timeout.

During the temporary phone-testing arrangement, the discovery owner may run the currently configured client-side provider adapters and upload the chosen normalized file. After provider credentials are moved to the backend, the same discovery job contract may be serviced by a Laravel worker instead. The client-facing cache-hit behavior must remain the same in both configurations.

### 3.3 Publish and store the winning subtitle

The discovery owner uploads the selected file only after the existing filtering/download/normalization path has produced a valid subtitle and the candidate has passed the configured matching checks.

The publication payload must include, at minimum:

- media type and TMDB identity;
- season/episode where applicable;
- normalized language;
- original provider name and provider-side subtitle/file ID where available;
- original filename, release label, and translator/uploader attribution where provided;
- original file format/encoding and normalized format;
- normalized content SHA-256 and byte size;
- release-match fingerprint and match confidence;
- publication timestamp and publisher account identifier in a privacy-safe form;
- permission/provenance state and a status such as candidate, verified, rejected, or withdrawn.

The server must validate the actual bytes, not trust a filename or client-supplied status alone. It must store the file in shared object storage (or an equivalent durable server-side store), store searchable metadata in the database, and return a stable server-owned file identifier/URL to clients. Provider download tokens and temporary upstream URLs must not be used as permanent shared file URLs.

### 3.4 Quality status and recommendation

A file that merely downloads successfully is not automatically the permanent best subtitle.

Use separate quality states:

- **Candidate:** correct file structure and language, but not sufficiently confirmed as the best match.
- **Verified:** passes exact media/episode checks, release matching where available, decoding/normalization checks, and successful application/playback verification.
- **Rejected/Withdrawn:** wrong language, wrong episode, wrong release, unreadable, out of sync, removed by provider/rightsholder, or otherwise unsuitable.

The application should show one recommended result for the selected language. Alternative same-language subtitles remain available behind an expandable control. User selection must be respected and must not be silently overwritten by a global recommendation.

A verified shared result may be promoted or demoted as new evidence arrives. Do not let one unverified rating or one transient network error immediately replace a working verified result.

### 3.5 Shared cache key and release matching

Do not use TMDB ID alone as the unique subtitle-file key.

Use a layered identity:

1. **Media identity:** media type + TMDB ID + season/episode + language.
2. **Release identity:** normalized release filename/group, source provider/release label, resolution, source type (WEB-DL/WEBRip/BluRay), and other stable tags available from the stream metadata.
3. **Optional content/video hash:** use only when the actual video file or a trustworthy provider hash is available. Do not invent a hash from a remote HLS/DASH URL.

Keep multiple release-specific subtitle records under the same media identity. Prefer an exact release match. A broader match may be offered as a lower-confidence alternative, but it must not silently replace a verified exact match.

---

## 4. Proposed Laravel API contract for the test

The following route names are **provisional test-contract names only**. They are not claimed to exist in the current Laravel backend. Before execution, map them to the actual deployed routes and freeze the request/response schemas in the Laravel OpenAPI specification.

| Proposed operation | Purpose |
|---|---|
| `GET /api/v1/subtitle-cache/resolve` | Look up the best shared track by media, episode, language, and release fingerprint |
| `POST /api/v1/subtitle-discovery/claim` | Atomically claim or join one discovery operation |
| `GET /api/v1/subtitle-discovery/{jobId}` | Read discovery status and the published result |
| `POST /api/v1/subtitle-discovery/{jobId}/publish` | Upload the selected normalized file and provenance metadata |
| `GET /api/v1/subtitle-cache/{subtitleId}/file` | Deliver the shared subtitle file |
| `POST /api/v1/subtitle-cache/{subtitleId}/feedback` | Report correct timing, wrong episode, unreadable file, or other quality feedback |

The actual Laravel implementation may use different route names, but it must preserve these semantics.

### Required response semantics

- Shared lookup must distinguish `hit`, `miss`, `pending`, `stale`, and `unavailable`.
- A cache hit must return the stable subtitle ID, media/release match level, normalized language, source attribution, file format, content hash, and a server-owned file URL.
- A pending response must return the existing discovery job ID and retry/poll guidance, not an instruction to query providers.
- A publish response must be idempotent and return the single canonical record if the same content is submitted again.
- A file response must include correct content type, content length, cache validators where supported, and a stable content hash/ETag.
- Errors must use the Laravel response envelope already expected by RAVEN23 and must not expose stack traces, provider credentials, signed URLs, or internal filesystem paths.
- Server authorization must protect write/claim operations from abuse. Read access to permitted shared subtitle files may follow the public/guest policy chosen for RAVEN23, but must not reveal the uploader's private account data.

---

## 5. Test environment and prerequisites

Do not start this phase until every prerequisite below is met.

### Backend prerequisites

- [ ] The intended Laravel staging server is deployed and reachable from the test phone.
- [ ] The RAVEN23 app is connected to that Laravel environment through the configured app environment selector.
- [ ] Laravel database migrations for shared subtitle metadata are deployed.
- [ ] Durable file/object storage is configured and survives application/server restarts.
- [ ] The distributed lock/queue mechanism required for single-flight discovery is active (for example, Redis-backed locks/queue).
- [ ] The proposed API contract has been mapped to real routes and added to the Laravel OpenAPI specification.
- [ ] Authentication and guest/read policy are explicit; write operations cannot be abused anonymously unless the owner intentionally permits that policy.
- [ ] Provider credentials are configured according to each provider's rules. ArabicSubs uses its protected server-side proxy/key path.
- [ ] A staging-only quota/usage counter exists for each external provider so API requests can be measured without exposing keys.
- [ ] A file-removal/takedown path exists for provider requests, owner requests, or invalidated files.

### Client prerequisites

- [ ] A RAVEN23 build points to the staging Laravel URL, not production.
- [ ] The existing local `SubtitlePlaybackStore` still works before and after server cache integration.
- [ ] The active subtitle-language setting is passed into the shared-cache lookup.
- [ ] Cache lookup runs after enough media/release identity is available, but does not delay the first video frame.
- [ ] External provider search is not started by a follower while a discovery job is active.
- [ ] Diagnostic logging uses job IDs and masked provider names only; it never prints keys or cookies.

### Test data and devices

- [ ] At least two independent Android clients are available (two phones, or a phone plus Android TV).
- [ ] Use separate staging test accounts where authentication is required.
- [ ] Prepare a fixed corpus: at least 3 movies, 3 ordinary TV episodes, and 3 anime episodes with known Arabic subtitle files.
- [ ] Include at least two different releases for one movie and two releases for one episode.
- [ ] Include negative controls: wrong episode, wrong season, wrong language, multi-episode pack, and a deliberately malformed subtitle fixture.
- [ ] Record each test title's TMDB identity and known video release fingerprint before running the test.

---

## 6. Detailed post-connection test cases

### T00 — Staging isolation and contract preflight

**Procedure**
1. Install the staging build on both test devices.
2. Sign in with staging test accounts.
3. call the real Laravel bootstrap/health contract.
4. Resolve the deployed shared-subtitle routes through the actual Laravel OpenAPI document.
5. Confirm that the app is not accidentally pointing at production or the Scraper API subtitle routes.

**Expected**
- Both devices reach the same staging environment.
- API version and response envelope are consistent.
- No provider search starts during preflight.
- No production data or quotas are touched.

### T01 — First-user cache miss

**Procedure**
1. Select a movie absent from the shared cache.
2. Start playback on Device A.
3. Confirm that video playback starts without waiting for subtitle lookup.
4. Request the shared cache entry for the selected primary subtitle language.
5. Claim discovery and record the returned owner/job identifier.
6. Run the existing eligible provider filtering flow.
7. Download and normalize the best candidate.
8. Publish the normalized file and metadata to Laravel.

**Expected**
- Initial lookup returns `miss`.
- Exactly one active discovery owner is created.
- A valid Arabic file can be published with the original provider and release attribution.
- Laravel stores a durable file and metadata record.
- The player continues running throughout the discovery/upload flow.
- The client also saves the file into its existing local subtitle cache.

### T02 — Concurrent requests share one discovery job

**Procedure**
1. Empty the relevant staging cache entry.
2. Start the same movie/episode + language + release request concurrently from Device A and Device B.
3. Repeat with a load test of at least 20 simultaneous identical lookup/claim requests.
4. Inspect discovery job records and provider request counters.

**Expected**
- Exactly one client receives the discovery-owner lease.
- Every other client joins the same pending job.
- Exactly one provider discovery run is active for that normalized identity.
- Duplicate claims do not create duplicate uploads or records.
- Followers do not independently call OpenSubtitles, SubSource, or the ArabicSubs proxy.

### T03 — First publication and server integrity

**Procedure**
1. Publish one valid normalized subtitle from T01.
2. Read the record back through the shared-cache resolve endpoint.
3. Download the server-owned file URL.
4. Compare the returned content SHA-256 with the published bytes.
5. Restart the Laravel application/worker and repeat the download.

**Expected**
- The stored file survives restart.
- Content hash and byte count match.
- Metadata preserves language, source provider, provider file ID, release, translator/uploader attribution when supplied, and normalized format.
- The server URL is not the original provider's temporary URL or token.
- The file is not associated with another episode or release accidentally.

### T04 — Second-user cache hit (core cost-saving test)

**Procedure**
1. Keep the shared record published from T03.
2. Open the same title/episode/release from Device B.
3. Run the normal player initialization and preferred-language lookup.
4. Inspect provider request counters and server access logs.

**Expected**
- Laravel returns `hit`.
- Device B receives the shared file directly from the RAVEN23 server.
- Device B does not issue a search or download request to any external subtitle provider.
- External API request counters remain unchanged during the cache-hit flow.
- The file applies successfully and is also saved in Device B's local `SubtitlePlaybackStore`.
- Device B does not need any of the original external provider keys to retrieve the shared file.

### T05 — Repeated cache hit after app restart

**Procedure**
1. Close RAVEN23 on Device B.
2. Reopen the same media and release.
3. Test once while online and once with the network disabled after the local cache has been populated.

**Expected**
- Online playback uses the current shared result or the valid local copy.
- Offline playback can use the local copy.
- Neither path triggers external provider requests when a valid shared/local subtitle already exists.
- Failure of the shared API does not block video playback.

### T06 — Exact episode and season isolation

**Procedure**
1. Publish a subtitle for S01E02.
2. Request S01E20, S02E02, and S01E03 for the same series.
3. Repeat with episode identifiers that contain similar digits.

**Expected**
- Only S01E02 can resolve to the published subtitle.
- No prefix/substring matching can return a neighboring episode.
- Wrong-season or wrong-episode cache hits are impossible.

### T07 — Movie and episode release matching

**Procedure**
1. Publish a subtitle matched to a WEB-DL 1080p release.
2. Request the same movie with a BluRay release fingerprint.
3. Request the same movie with an exact WEB-DL fingerprint.
4. Repeat for a series episode.

**Expected**
- Exact release gets the highest match.
- A different release is not represented as an exact match.
- Multiple release-specific subtitle records can coexist under the same media identity.
- A compatible broad match may be offered as a lower-confidence alternative, but cannot silently replace an exact verified track.
- A remote HLS/DASH URL is never treated as a trustworthy file hash.

### T08 — Preserve the already-accepted selector result and collapsed alternatives

**Procedure**
1. Import the accepted PHASE64.6 selector benchmark fixtures and selector version into the staging test environment.
2. Seed at least four Arabic subtitle records for one media/release identity, including the selector's verified exact winner and several alternatives.
3. Open the subtitle menu with Arabic as the preferred language.
4. Open the alternatives section.
5. Change the user's primary subtitle language and repeat.

**Expected**
- Laravel/client presentation uses the exact recommended candidate produced by the accepted selector version; PHASE64.7 does not independently recalculate or override the winner.
- Same-language alternatives are grouped behind an explicit expandable control.
- Provider names/release labels remain available when the user opens alternatives.
- The configured primary language is respected; no second competing language preference is introduced.
- A manual user selection remains selected and is not silently overwritten by a later global cache refresh.
- A Candidate or low-confidence file cannot be promoted to the recommended Verified result solely because it was uploaded or popular.

### T09 — Quality feedback and promotion/demotion

**Procedure**
1. Apply a candidate on Device A and verify Arabic text, episode identity, and timing.
2. Submit positive feedback.
3. Submit an out-of-sync or wrong-episode report from Device B using a controlled test case.
4. Inspect status transitions and recommendation changes.

**Expected**
- Candidate and verified states are distinct.
- Positive feedback updates evidence but does not create duplicate files.
- Wrong-episode or severe mismatch evidence prevents the file remaining the preferred result.
- One unverified report does not arbitrarily demote a verified file without the configured moderation/threshold rule.
- Users can still access valid alternatives.

### T10 — Provider quota is not consumed by shared hits

**Procedure**
1. Capture provider API usage counters immediately before a cache-hit test.
2. Repeat 100 cache-hit requests across the two clients (including app restarts).
3. Capture counters again.
4. Separately run one cache miss/discovery job and record its provider calls.

**Expected**
- 100 shared cache-hit requests cause zero new provider search/download requests.
- The one cache-miss discovery uses only the minimum calls required by the configured search/selection process.
- Duplicate concurrent requests are coalesced.
- 429 responses and Retry-After values are honored; no quota circumvention occurs.

### T11 — Discovery owner crash and lease recovery

**Procedure**
1. Create a cache miss and let Device A acquire the discovery lease.
2. Force-stop Device A before publication.
3. Wait for lease expiry.
4. Allow Device B to claim/retry the pending job.
5. Simulate a late retry from Device A after Device B has become owner.

**Expected**
- The expired lease is recoverable.
- Only one active owner exists after recovery.
- A stale owner cannot publish over the new owner's result unless the server's idempotency rules identify it as the same accepted publication.
- No duplicate provider search is started while a valid lease is held.

### T12 — Failed or empty provider search

**Procedure**
1. Use a test title for which no provider returns an Arabic file.
2. Repeat with one provider returning 429, one timing out, and one returning malformed data.
3. Inspect discovery status and negative-cache behavior.

**Expected**
- One provider's failure does not erase valid results from other providers.
- A no-result state is recorded with a bounded retry/negative-cache policy.
- Concurrent users join the same unsuccessful discovery instead of immediately repeating the same provider calls.
- A later retry is possible after the negative-cache/Retry-After window.
- Video playback is never blocked.

### T13 — Upload validation and hostile-file rejection

**Procedure**
Attempt to publish controlled test files that are:
- empty;
- HTML error content renamed to `.srt`;
- invalid SRT/VTT timing;
- malformed ZIP;
- ZIP with path traversal entries;
- oversized payload;
- file with no subtitle cues;
- unsupported or mislabeled format;
- non-Arabic content submitted as Arabic.

**Expected**
- Invalid files are rejected before becoming shared.
- ZIP expansion limits and path safety are enforced.
- File size limits are enforced on both compressed and expanded content.
- Language metadata is checked against file content where feasible.
- Rejected files never become cache hits.
- Error responses do not reveal server filesystem paths or stack traces.

### T14 — Duplicate file and metadata deduplication

**Procedure**
1. Submit identical normalized bytes from two provider records.
2. Submit a different release file for the same episode.
3. Submit the same bytes with different metadata/attribution records.

**Expected**
- Identical content may share one stored object by SHA-256 while preserving separate provenance links as required.
- Distinct subtitle content or distinct release timing remains separately selectable.
- Deduplication does not erase translator/uploader/provider attribution.
- A metadata-only duplicate does not cause a second full file object unnecessarily.

### T15 — Permission, attribution, and takedown

**Procedure**
1. Publish one permitted subtitle from each of ArabicSubs, SubSource, and OpenSubtitles.
2. Verify provider, source file ID, original filename/release and attribution are retained.
3. Trigger a staging takedown/withdrawal for one controlled record.
4. Request that record from a second device and inspect the result.

**Expected**
- All three provider origins can be traced.
- Source attribution is not stripped during normalization or shared delivery.
- A withdrawn/taken-down file is no longer returned as a valid hit.
- The file is removed or quarantined according to the provider/owner instruction.
- Other unrelated subtitle records remain available.

### T16 — User data isolation and abuse controls

**Procedure**
1. Attempt to publish without a valid discovery lease.
2. Attempt to publish under another job ID.
3. Attempt to modify another user's private metadata.
4. Send repeated claim/upload requests beyond the staging rate limit.
5. Inspect API responses and logs.

**Expected**
- Only authorized operations can publish.
- Lease ownership and idempotency are enforced server-side.
- No user's email, username, token, or private profile details are exposed in shared metadata.
- Upload size and request rate limits are enforced.
- Logs contain correlation/job IDs and safe diagnostics, not credentials or bearer tokens.

### T17 — Local and server cache independence

**Procedure**
1. Populate the shared server cache and the local cache.
2. Clear only the local cache and verify the server can repopulate it.
3. Disable the server and verify the local cache still works.
4. Clear/withdraw the server object and verify an old local copy follows the chosen revocation policy.

**Expected**
- Local and shared caches have independent lifecycles.
- The local cache remains useful when Laravel is temporarily unreachable.
- The app does not repeatedly call providers just because one cache layer is unavailable.
- Revocation rules are explicit: a legally/officially withdrawn file must not be re-published from a stale client cache after the client receives the withdrawal state.

### T18 — Shared cache storage, bandwidth, and cleanup

**Procedure**
1. Publish representative SRT, VTT, and normalized WebVTT files across movie, TV, and anime records.
2. Record original and normalized byte sizes.
3. Measure storage use, response bytes, download latency, and cache hit rate.
4. Run retention/cleanup on expired, rejected, duplicate, and withdrawn records.

**Expected**
- File storage is bounded and cleanup does not delete files still referenced by valid records.
- Compression may be used for transfer/storage where beneficial, without changing subtitle text.
- File URLs and content validators remain stable for unchanged content.
- Metrics show how much provider traffic and bandwidth the cache actually saves.

### T19 — Android phone and TV playback smoke

**Procedure**
1. Repeat T01–T10 on a physical Android phone.
2. Repeat the relevant cache-hit, language selection, and fallback tests on Android TV.
3. Test Arabic text, mixed Arabic/Latin names, punctuation, multiple lines, and timing.
4. Confirm stream URL, selected video provider, and quality remain unchanged during subtitle lookup.

**Expected**
- The same shared subtitle behavior works on phone and TV.
- Arabic renders correctly and is synchronized with the selected release.
- Subtitle retrieval does not change the active video stream or delay the first frame.
- Existing offline subtitle behavior remains intact.

---

## 7. Required benchmark and measurements

Capture these measurements for each test corpus item:

| Metric | What to record |
|---|---|
| Shared cache hit ratio | Hits / total eligible lookup requests |
| External request count | Provider search/download requests per unique cache miss |
| Avoided provider requests | Requests not made because the shared cache answered |
| Duplicate discovery count | Number of simultaneous jobs for the same normalized identity |
| Publish success rate | Accepted valid publications / publication attempts |
| Exact episode match rate | Correct season/episode results / tested results |
| Exact release match rate | Exact release matches / tested results |
| Download and parse success | Files normalized and applied successfully |
| User correction rate | Wrong language, episode, release, or sync reports |
| Cache-hit latency | p50/p95 from Laravel lookup to client-available file |
| File footprint | Stored bytes and average bytes per shared track |
| Fallback success | Successful playback after cache miss/provider outage |

Report movie, ordinary series, and anime results separately. A combined average must not hide poor anime or episode-specific coverage.

---

## 8. Acceptance criteria

PHASE64.7 can be marked passed only when all required checks below are evidenced on the connected Laravel staging environment:

- [ ] A first cache miss creates one discovery job and one active lease owner.
- [ ] Concurrent identical requests join that job instead of repeating external provider searches.
- [ ] A successful candidate is validated, published, durably stored, and traceable to its source.
- [ ] A later user receives the stored file directly from the RAVEN23 server.
- [ ] A shared cache hit generates **zero** new requests to ArabicSubs, SubSource, and OpenSubtitles.
- [ ] A cache hit works without the receiving device having external provider API keys configured.
- [ ] Exact episode and release matching prevent a wrong subtitle being silently served.
- [ ] One recommended track is presented for the configured primary language, with alternatives available on demand.
- [ ] User-selected subtitles are not silently overwritten.
- [ ] Invalid, oversized, malformed, wrong-language, or wrong-episode files cannot become verified shared entries.
- [ ] Provider attribution and required translator/uploader metadata are preserved.
- [ ] The confirmed republishing permissions are respected, including takedown/withdrawal handling.
- [ ] Local subtitle cache and offline playback continue to work when Laravel is unavailable.
- [ ] Playback startup, active video URL, provider order, and video-quality selection remain unchanged.
- [ ] Phone and Android TV smoke tests pass.
- [ ] No API key, bearer token, cookie, or signed provider URL appears in the APK diagnostics, app logs, server logs, or uploaded artifacts.
- [ ] Full relevant Flutter tests, Laravel feature/integration tests, static analysis, and ARM64 release build pass.

A test suite that only proves that `GET /api/v2/subtitles/search` works on the Scraper API, or that a subtitle exists in the local phone cache, does **not** satisfy this phase.

---

## 9. Failure handling and rollback

- If Laravel cache lookup fails, video playback continues and the existing permitted local/provider fallback path remains available.
- If shared publication fails, the selected subtitle remains usable locally; it may be queued for a safe retry, but it must not block playback or create duplicate uploads.
- If a discovery owner disappears, the lease expires and one waiting client may retry.
- If a shared file is withdrawn, the server must stop serving it and clients must respect the withdrawal state when online.
- If the shared cache returns a wrong episode/release, disable that shared record and use the existing discovery/provider fallback. Do not silently retry the same invalid record.
- If the shared cache increases API calls or creates repeated discovery jobs, stop the cache experiment in staging and inspect idempotency/locking before enabling it again.
- Do not roll the feature into production until all acceptance criteria pass and the owner approves the rollout.

---

## 10. Evidence package required to close the phase

Attach or link the following evidence in the phase completion report:

1. Laravel staging API/OpenAPI contract and deployed commit/version.
2. Database migration and storage configuration test results (no secrets).
3. T01 first-user miss and publication trace.
4. T02 concurrent 20-client/single-flight trace.
5. T04 second-user cache-hit trace with provider counters unchanged.
6. Before/after API usage counters for the three provider accounts, with keys masked.
7. SHA-256 and byte-size comparison for the shared test file.
8. Movie/series/anime result matrix.
9. Phone and Android TV playback smoke results.
10. Flutter, Laravel, and Android ARM64 CI links.
11. Takedown/withdrawal test evidence.
12. The PHASE64.6 selector acceptance report, accepted algorithm/version, confidence thresholds, and benchmark corpus reference.
13. A final statement listing any deferred tests or known limitations.

Never include actual API keys, passwords, bearer tokens, signed URLs, or private user information in this evidence package.

---

## 11. Current execution status

**Not executable yet.** Two independent prerequisites remain:
1. The owner has stated that RAVEN23 is not yet connected to the Laravel server.
2. PHASE64.0–64.6 has not yet completed the selector-development, quality benchmark, and real-device acceptance gate.

The repository contains Flutter Laravel-client foundations and a separate RAVEN23 Scraper API subtitle contract, but this shared Laravel subtitle cache is not currently established in the inspected client contract. The approved best-subtitle selector is also not yet implemented/accepted.

No shared-cache endpoint, table, object-storage bucket, discovery lock, upload flow, accepted selector version, or second-user delivery test is claimed to exist or to have passed.

This file is a forward-looking test plan. Begin execution only after BOTH the PHASE64.6 selector gate passes and the owner confirms that the Laravel backend has been connected and deployed to staging. Do not treat this document's proposed endpoint names as existing APIs.

## 12. Inspected RAVEN23 files

- `lib/services/subtitle_playback_store.dart` — existing device-local normalized subtitle cache.
- `lib/screens/common/player/player_external_subtitles.dart` — current preferred-language search, auto-apply, and local-save flow.
- `lib/functions/subtitle_options.dart` — current separate same-language rows and fallback grouping behavior.
- `lib/services/external_subtitle_service.dart` — current external provider adapters and provider aggregation.
- `lib/data/sources/laravel_api.dart` — generic Laravel API client.
- `openapi.json` — separate RAVEN23 Scraper API v2 subtitle search and file passthrough routes.
- `docs/flutter_laravel_migration_phases.md` — Laravel client migration and backend integration sequencing.
- `docs/migration_prd_firebase_to_laravel.md` — target Laravel backend architecture.
- `phases/PHASE64_ARABIC_SUBTITLE_PROVIDER_QUALITY_AND_FALLBACK_PLAN.md` — parent subtitle quality/provider phase.
