# PHASE56 — Manga Runtime, Catalogue Reliability & Extension Trust Fix

**Date:** 2026-11-10  
**Base:** Owner-confirmed successful RAVEN23-PHASE55 build  
**Status:** Build passed by owner confirmation after the archive was delivered. Device testing exposed the separate ABI Float representation rejection and requested exact Home visual parity; those follow-up items are assigned to PHASE57.

## 1. User-observed defects

The screenshots supplied after installing PHASE55 show four connected Manga/Mihon issues:

1. The Mihon/Keiyoushi extension list loads and reports 1,554 extensions, but every install control is disabled and Installed Manga Sources remains empty.
2. `All` can end in the empty-state screen despite Japanese Manga, Manhwa and Manhua category feeds returning content.
3. The category pages do not show their own rotating featured hero/banner and Top 10 shelf, unlike Movies, Series and Anime.
4. Initial Manga catalogue loading uses a lone progress indicator instead of the animated Home-style skeleton used by the other catalogue pages.

These are runtime/data-flow defects discovered after the PHASE55 build. They do not change the owner's confirmation that PHASE55 builds succeeded.

## 2. Root causes and corrections

### 2.1 Keiyoushi install buttons remain disabled

`MangaExtensionEntry.canInstall` intentionally requires a valid package name, HTTPS APK URL and 64-character SHA-256 signer fingerprint. The extension index is fetched as Protobuf, but the trusted fingerprint is published separately at the sibling `repo.json` object's `meta.signingKeyFingerprint` field.

The previous code requested that sidecar as `ResponseType.json`. Dio's JSON transformer depends on the response content type; the GitHub raw endpoint may serve the valid JSON body as `text/plain`. In that case the data does not reach the Map parser and the signer fingerprint becomes null. This disables installation by design, even though the extension catalogue itself loaded.

**Correction:** Fetch the sidecar as `ResponseType.plain` and parse its JSON text explicitly. Only the exact nested `meta.signingKeyFingerprint` field is accepted. Do not accept root-level aliases, legacy `signingKey`, or Protobuf field 3 as a trust anchor. The existing SHA-256, package-name, HTTPS, package identity and native APK signer checks remain mandatory.

### 2.2 `All` feed fails as one transaction

The former `All` loader requested one unfiltered catalogue plus three country-filtered catalogues, then awaited all four with one `Future.wait`. Any failure (including a redundant global request) rejected the entire operation and prevented successful regional catalogues from being displayed. A selected JP/KR/CN page also waited for an unrelated unfiltered request.

**Correction:** `All` now loads only the canonical JP, KR and CN catalogues. Each regional request is isolated; a failed region does not discard successful results. The aggregate is de-duplicated by AniList media ID and its shelves are sorted using their corresponding popularity/trending/score/date fields. Previously cached regional data is retained when a refresh fails. A category page requests only its own country feed.

The AniList query now includes the `trending` score used for the combined trending order. Top 10 is composed from the regional Top 10 lists (with a popularity fallback when the source lists do not provide a Top 10 list).

### 2.3 Category hero and Top 10 parity

The previous hero selector read only the mixed catalogue, so category pages had no banner. The Top 10 shelf was also rendered only for `All`.

**Correction:** The selected catalogue supplies the hero carousel for All, Japanese Manga, Manhwa and Manhua. Top 10 is rendered on every category page. The existing RAVEN23 carousel component, palette, typography, dimensions, transitions, reduced-motion handling and artwork selection are preserved.

### 2.4 Initial loading parity

The previous initial loading branch showed only a centered `CircularProgressIndicator`.

**Correction:** The Manga catalogue reuses `HomeSkeleton`, preserving the same animated hero and poster-row loading structure as the other home feeds. Search's smaller in-place progress state remains unchanged.

## 3. Scope and preservation rules

- No changes to movie, series, anime, Live TV or video-source repository behaviour.
- No changes to BetterPlayer, video engine dispatch, playback routing, source priority policy or video quality/subtitle logic.
- The six video JSON repositories remain entirely separate from the Mihon Protobuf index and repository manager.
- Mihon extension APKs are still installed only after explicit user confirmation.
- No weakening of package identity, HTTPS, APK size, signer fingerprint or certificate verification.
- No new extension ABI is enabled; the existing Mihon ABI 1.4/1.6 boundary remains unchanged.
- No copying of Zangetsu UI/branding into RAVEN23. Existing RAVEN23 components are reused.
- No changes to AniList account data or authentication; catalogue data remains public metadata only.

## 4. Changed source and verification files

- `lib/manga/mihon/keiyoushi_extension_repository.dart` — plain-text sidecar retrieval and strict JSON-text fingerprint parsing.
- `lib/manga/anilist/anilist_manga_service.dart` — trending metadata and de-duplicating regional catalogue aggregation.
- `lib/mobile/screens/manga_screen.dart` — isolated regional loading, All aggregation, category hero/Top 10 parity and `HomeSkeleton` loading.
- `test/manga/phase56_manga_regression_test.dart` — regional merge ordering/deduplication, raw `repo.json` fingerprint parsing, and proof that only a valid fingerprint plus a valid HTTPS/package identity makes an extension entry installable.
- `tool/format_phase56_dart.sh` — current-scope formatter targets.
- `.github/workflows/android-ci.yml` — PHASE56 formatter/test labels and focused regression invocation; prior accepted PHASE52/53 test suites remain excluded.
- `phases/README_MASTER_IMPLEMENTATION.md` and the Phase36–56 historical tracker — phase status at the time; the current tracker is `IMPLEMENTATION_TRACKER_PHASE36_57.md`.

## 5. Acceptance gates

- [x] User-provided PHASE55 build success is recorded as owner-confirmed.
- [x] Root cause of disabled extension buttons identified without bypassing signer verification.
- [x] Source changes prepared for raw-text sidecar parsing, region-isolated catalogue aggregation, per-category hero/Top 10 and Home-style skeleton.
- [x] Focused regression tests added for the new trust-parsing, strict install eligibility and aggregate-catalogue cases.
- [x] Owner confirmed the PHASE56 build completed successfully.
- [ ] The focused PHASE56 source behaviour is revalidated by the PHASE57 CI gate where still applicable.
- [ ] ARM64 Release APK audit for PHASE57 passes.
- [ ] On-device check: extension install buttons become enabled only after a valid sidecar fingerprint is read; explicit installation completes certificate verification and the source appears under Installed Manga Sources.
- [ ] On-device check: All, Japanese Manga, Manhwa and Manhua each show content, their own rotating hero, Top 10 and expected catalogue shelves.
- [ ] On-device check: initial catalogue loading shows the animated Home skeleton; retry/refresh and reduced-motion behaviour remain correct.
- [ ] Confirm Movies, Series, Anime, Live TV and playback paths remain unaffected.

**Execution limitation:** The user confirmed successful build completion for PHASE56. That does not prove the extension installation runtime passed on the device; the exact error and follow-up correction are documented in PHASE57. No local build claim is made by this archive-editing session.
