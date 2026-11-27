# RAVEN23 Phase Status Reconciliation
**Audit date:** 2026-11-27  
**Repository:** `m5ham3ds/RAVEN23`  
**Verified ref:** `main`  
**Verified commit:** `9c78364e1d631cc26414b3b086a263cd4450e6b2`  
**Latest CI:** [Run #319](https://github.com/m5ham3ds/RAVEN23/actions/runs/46050802426) — completed successfully.

## 1. Scope and method

This document reconciles the current source tree, tests, Android implementation, CI workflow, and active phase plans. It is a point-in-time status record for the verified commit above. Historical phase reports retain the results and dates that were true when those reports were written; they are not rewritten to imply that a later build retroactively ran their original tests.

The audit covered the 244 files under `phases/`, the current master implementation index, the active PHASE63.39 / PHASE64 / PHASE64.7 specifications, the relevant Flutter and Kotlin implementation paths, the focused test inventory, and the latest Actions run.

## 2. Repository and build baseline

| Item | Verified state |
|---|---|
| Default branch | `main` |
| Commit | `9c78364e1d631cc26414b3b086a263cd4450e6b2` |
| Branches observed | `main` only |
| Phase documentation files | 244 |
| Flutter source files under `lib/` | 582 |
| Test files under `test/` | 312 |
| Android project files | 183 |
| Workflow files | 1 — `.github/workflows/android-ci.yml` |
| Latest run | #319, success |
| APK artifact | 45,405,099 bytes (about 43.3 MiB), ARM64 target |
| Physical-device acceptance | Not evidenced by CI |

### CI #319 evidence

The run completed with `conclusion=success`. Its job steps report success for dependency preparation, scoped formatting, `flutter analyze`, the exact focused Flutter test list, Gradle wrapper generation, selected Android contract tests, Release APK build, APK/ABI audit, and artifact/report uploads.

- The workflow currently enumerates **64 focused Flutter test files**. This is not all 312 files in the `test/` tree.
- The Android contract gate checks **25 selected methods**: 3 Mihon ABI cases and 22 Media3/offline-download cases.
- The build is an ARM64 CI/development build. The checked-in workflow passes `ENABLE_FIREBASE=false` and `RAVEN23_AUTH_ONLY=true`; therefore CI success is not evidence of Firebase-enabled production configuration or complete production release acceptance.
- Run #319 is useful evidence that the restored baseline compiles and passes the configured routine gate. It does not prove external APIs authenticate, provider links play, Arabic subtitles synchronize, or device-only offline flows work.

## 3. Active phase map

| Phase | Current state | Remaining acceptance |
|---|---|---|
| PHASE63.39 — offline subtitles/episode metadata/seasons/partial playback | **Partially implemented; not accepted** | Partial playback during active downloads is absent in the inspected code; physical-device scenarios remain open. |
| PHASE64.0 — provider discovery | **Partially complete; validation open** | Live credential/quota checks and fixed provider coverage corpus. |
| PHASE64.1 — credentials | **Temporary development exception active** | Keep owner-approved phone-test values unchanged until owner closes testing; production separation remains open. ArabicSubs key remains server-only. |
| PHASE64.2 — provider adapters | **Partially implemented** | Validate documented APIs and provider-specific exact-episode coverage; experimental sources remain conditional. |
| PHASE64.3 — search/fallback | **Partially implemented** | Current aggregate partial-result deadline is 48 seconds; per-provider deadlines and true incremental results are still open. |
| PHASE64.4 — best-subtitle selector | **IN PROGRESS — current focus** | Confidence classes/thresholds, strong release identity, evidence-backed ranking, and acceptance tests. |
| PHASE64.5 — Arabic encoding/RTL/sync | **Acceptance incomplete** | UTF-16 and verified Windows-1256 support, mixed-direction rendering, timing controls/verification, and device checks. |
| PHASE64.6 — benchmark/release acceptance | **Blocked pending 64.4 and 64.5** | Fixed movie/series/anime corpus, scorecard, selector version and thresholds, real-device acceptance, explicit PASS. |
| PHASE64.7 — shared subtitle intelligence/cache | **BLOCKED — test plan only** | PHASE64.6 PASS plus separate Laravel staging prerequisites and owner confirmation. |

## 4. PHASE63.39 — offline workflow

### Implemented in source

- The native download metadata path stores selected-subtitle metadata and the series/season/episode fields needed by the offline list.
- The offline screen reconstructs episode and season information from completed local downloads and switches among seasons represented by completed downloads.
- The companion player media provider exposes completed downloads to the player and can use the existing export path when a completed download does not yet have a validated MP4.
- CI exercises selected serialization, export validation helpers, subtitle SRT handling, the DCIM path, and related offline contracts.

### Not implemented / not accepted

- The provider exposes a video URI only for `Download.STATE_COMPLETED`.
- `openVideo` rejects a download that is still in progress.
- `StreamDownloadExporter.export` also requires `STATE_COMPLETED`.
- Therefore the completion pipe is only a way to deliver the post-completion export asynchronously; it is not an active-download cache bridge or verified partial playback.
- No physical-device acceptance report was found for the complete offline MP4/HLS/DASH, season, subtitle, DCIM, and restart scenarios.

**Disposition:** keep PHASE63.39 open as a separate acceptance item. PHASE64's protected-scope rule forbids opportunistic changes to this offline subsystem during subtitle-selector work.

## 5. PHASE64 — subtitle pipeline

### Present in code

- `ExternalSubtitleService`: OpenSubtitles API v1, documented SubSource API v1, optional ArabicSubs proxy path, and RAVEN23 Scraper fallback.
- `SubtitleProviderOrchestrator`: retains completed provider results when another request stalls.
- `SubtitleSelectionEngine`: requested-language normalization/filtering and deterministic ordering using available identity/release/uploader/rating/vote/download/date signals.
- `PlayerExternalSubtitles`: Arabic-preferred language path, cached subtitle restoration, external search, and manual candidate selection.
- `SubtitleFileNormalizer`: archive handling and SRT/VTT/ASS/SSA normalization to WebVTT.

### Remaining gaps

- Provider live authentication, quotas, actual Arabic coverage, and movie/series/anime fixed-corpus results remain undocumented as accepted.
- The orchestration uses a 48-second aggregate deadline; per-provider independent deadlines and a live incremental results stream are open.
- The selector has no accepted High/Medium/Low confidence classes or calibrated thresholds. The active video stream exposes a quality label rather than a full trusted release/timing fingerprint.
- The normalizer currently tries UTF-8 and falls back to Windows-1252. Explicit UTF-16 and verified Arabic Windows-1256 decoding are not present in the inspected implementation.
- Real Arabic/Latin RTL display and subtitle synchronization have not been accepted on a physical Android player.
- PHASE64.6's scorecard and explicit PASS report are absent.
- PHASE64.7 is blocked; the RAVEN23 repository does not itself define the required Laravel shared-subtitle API/schema/storage/publication contract. That backend is maintained separately.

## 6. Credential and content policies to preserve

- Do not print actual API keys, tokens, cookies, account passwords, or signed URLs in documentation, CI logs, diagnostics, or chat.
- The owner-approved temporary phone-testing values in `.env.example` must not be blanked, rotated, replaced, or migrated until the owner explicitly confirms that phone testing is complete.
- This temporary exception is not production approval. Do not use those exposed values for production traffic or production releases.
- ArabicSubs Bearer credentials must stay server-side; the mobile app may use only the protected proxy URL.
- Search for existing Arabic subtitle files; do not translate English subtitles or generate AI subtitles as a fallback.
- Shared publication, when eventually authorized, is allowlisted to normalized Arabic (`ar`) and English (`en`) only and must be enforced server-side.
- Keep the offline player, episode cards, season switching, download/export/DCIM, video source order, and quality behavior out of PHASE64 changes.

## 7. Canonical next steps and gates

1. Finish PHASE64.0–64.3 validation without changing protected playback/download behavior.
2. Complete PHASE64.4: hard rejection rules, confidence classes, strong release identity, deterministic recommendations/alternatives, and fallback regression tests.
3. Pass PHASE64.5 Arabic decoding, mixed-direction rendering, and synchronization checks on the actual Android player.
4. Run PHASE64.6 on a fixed corpus with movies, ordinary series, and anime; publish the scorecard and freeze selector version/thresholds; record explicit PASS.
5. Only then begin PHASE64.7 after the intended Laravel staging backend, contract, storage, queue/lock, permissions, and multi-client prerequisites are confirmed.
6. Separately plan and execute the remaining PHASE63.39 device acceptance and active-download partial-playback work, under its own scope authorization.

## 8. Historical-document policy

The older PHASE10–PHASE63 records remain historical evidence. Their original CI outcomes, dates, and change descriptions should not be silently rewritten. The master index now points to this reconciliation as the live status authority. When a phase is newly verified or closed, append a dated progress entry to that phase's document and update this index in the same documentation change.

---

