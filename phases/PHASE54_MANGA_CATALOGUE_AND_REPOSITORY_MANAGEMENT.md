# PHASE54 — Manga Catalogue Visual Parity & Repository Management

**Date:** 2026-11-09
**Status (updated 2026-11-10):** The project owner confirms that all builds completed successfully through PHASE56, including the PHASE54 code carried forward into that build. Runtime acceptance is not considered complete: screenshots from the installed PHASE55 build expose missing Manga catalogue parity and an empty All feed. These observed defects are the All-feed reliability defect was corrected under PHASE56. The later extension ABI and exact Home visual-parity findings are tracked under PHASE57. Historical CI failure notes for this phase were superseded and removed from the active phase folder.
**Base:** Owner-accepted RAVEN23 Phase53 Release build.

## 1. Scope and compatibility

This is an additive refinement of the accepted Phase53 Manga work. It does not reopen the confirmed Phase52 gate or its tests. Existing video JSON repositories and `SourceRepositoryManager` remain unchanged. Manga/Mihon protobuf indexes are persisted by a separate `MangaRepositoryManager`.

## 2. Manga catalogue visual parity

- Replaced the standalone compact Manga page layout with the same structural language used by the Movies / Series / Anime Home catalogue: the Home-style RAVEN23 pinned blurred header and its horizontally scrolling shared filter chips, the same large hero-card sizing and crossfade carousel, section headers, matching 2:3 poster cards/rows and a responsive search-result grid. The Manga-specific search field expands only when the header search action is tapped, so the idle layout keeps the same vertical rhythm as Home.
- The featured banner draws from the unfiltered all-origin AniList trending results, so Japanese manga, Korean manhwa and Chinese manhua may appear together. It uses the same phone portrait/tablet landscape sizing, crossfade/scale transition, swipe direction and reduced-motion/visibility pause rules as the Home hero carousel.
- Separate catalogue chips filter Japanese manga (`countryOfOrigin: JP`), Korean manhwa (`KR`) and Chinese manhua (`CN`). Search uses the same selected country filter, so results do not cross catalogue categories.
- AniList `countryOfOrigin` is included in the metadata model and detail page. AniList documents this as the media's country of origin and supports it as a GraphQL media filter.
- RAVEN23 palette, typography, brand mark, spacing tokens and card radii remain the sole visual source of truth.

## 3. Repository management ownership

- Removed extension/repository navigation actions from the Manga catalogue and Manga detail page. Manga browsing no longer exposes repository add/edit/remove controls.
- `Sources > Manga / Manhwa Repositories` is now the single management location. It supports adding a repository, editing its URL and removing it, with persisted user configuration and duplicate prevention.
- A repository must be an HTTP(S) Mihon Protobuf index ending in `.pb`; video JSON indexes are rejected so the two repository types cannot be mixed accidentally.
- The initial first-run seed remains the Keiyoushi index. Removing all entries persists an intentionally empty list instead of silently re-adding Keiyoushi.
- The Sources page passes its configured repository URL list to a separate read-only extension catalogue screen. That screen has no repository-manager dependency and cannot change repository configuration.
- The Video Repositories list remains managed by its existing implementation and its six current entries are not changed by this phase.

## 4. Data and API contract

AniList continues to provide metadata only. Japanese/Korean/Chinese separation is based on AniList's documented ISO country code field. It does not claim every title tagged by genre or format is a Manga/Manhwa by platform convention; the explicit origin filter is the deterministic separation used here.

Mihon repository management continues to accept protobuf `.pb` index URLs only. Extension packages, chapter scraping and native extension execution remain outside this phase and are not represented as available features.

## 5. Files changed

- `lib/mobile/screens/manga_screen.dart` — home-style catalogue layout, cross-origin trending hero, Manga/Manhwa/Manhua chips, filtered search and AniList detail metadata.
- `lib/manga/anilist/anilist_manga_service.dart` — `MangaContentKind`, country-origin field, country-filtered Home/search requests.
- `lib/manga/mihon/manga_repository_manager.dart` — new persistent CRUD manager for Protobuf repositories.
- `lib/manga/mihon/keiyoushi_extension_repository.dart` — fetches an explicitly configured protobuf index URL.
- `lib/screens/common/source_repositories_screen.dart` — Manga/Manhwa repository add/edit/remove controls in the dedicated Sources section only.
- `lib/screens/common/manga_extensions_screen.dart` — read-only Protobuf extension catalogue, opened only from the Sources Manga/Manhwa section; separated from the Manga catalogue screen.
- `assets/translations/{ar,en,es,hi}.json` — type and repository-management labels.
- `test/manga/manga_repository_manager_test.dart` — current-phase repository CRUD, URL normalization and duplicate-prevention tests. PHASE53-only test files were removed after the phase was accepted.
- `tool/format_phase54_dart.sh` — the original PHASE54 formatter; current Manga runtime regression scope is tracked by `tool/format_phase57_dart.sh` and `.github/workflows/android-ci.yml`.

## 6. Build acceptance and superseded CI history

The project owner confirms that all build operations succeeded through PHASE56, which includes the PHASE54 implementation. Intermediate PHASE54 CI failure notes described earlier attempts and are no longer active blockers; their separate note files were removed from the active `phases/` directory to prevent confusion. This acceptance is specifically a build milestone, not proof that every Manga screen behaved correctly on the installed device. The screenshots supplied after PHASE55 show the All-feed reliability defect addressed in PHASE56. The later device screenshots exposed a separate ABI 1.6 representation issue and the remaining Home visual-parity requirement, both assigned to PHASE57.

## 7. Validation gates

- [x] Static JSON parsing for all translation files.
- [x] Source-page-only Manga/Mihon repository management; no add/edit/remove action is exposed from the Manga catalogue or detail page.
- [x] Idle Manga header/hero/rows use the same Home layout dimensions and shared visual components/tokens.
- [x] Shell syntax check for the focused formatter script.
- [x] Phase53 video repository code and six JSON repository URLs left unchanged.
- [x] Manga repository manager accepts only HTTP(S) `.pb` indexes.
- [x] Dart formatter and `flutter analyze` pass in the latest GitHub Actions run.
- [x] Project owner confirms all build operations succeeded through PHASE56, including the PHASE54 implementation.
- [ ] The on-device Manga UI parity check is not accepted: the screenshots show missing per-category hero/Top 10 sections and an empty All tab. PHASE56 addresses these defects.
- [ ] Arabic RTL, tablet layout, refresh and reduced-motion behaviour still need device verification.

**Verification distinction:** Build success through PHASE56 is owner-confirmed. It does not override the runtime defects visible in the supplied screenshots and does not mark the Manga user experience as fully accepted.
