# RAVEN23 PHASE62 — Manga Work Detail and Reader

> **Historical baseline note (2026-11-12):** This document records the PHASE62 implementation snapshot, not the reconciled UI after PHASE63. Its historical statements about five tabs, a separate Sources tab and Recommendations are superseded by `RAVEN23-PHASE63-ZANGETSU-MANGA-WORK-READER-PARITY.md`. The current work screen has exactly four tabs: Chapters, Characters, Relations and Details; source management opens from Chapters, and Recommendations/Volumes are not part of the current Manga work UI. The current reader's chapter arrows and page slider follow the actual Zangetsu `_buildBottomBar` implementation.

## Objective

Replace the minimal manga metadata hand-off with a complete Manga/Manhwa/Manhua work page and a Mihon-backed chapter reader. This phase is intentionally limited to manga-family content; it does not reuse or alter the Anime/Series detail flow.

## Zangetsu reference audit

Inspected the Zangetsu manga detail, tab composition, reader and reading-progress architecture. Reimplemented the user-facing behavior and structure independently in RAVEN23, using RAVEN23's existing Mihon native extension runtime and AniList client. No Zangetsu GPL source files or implementation code were copied.

## Work detail page

- Collapsible artwork header with banner, cover, title, English title, format, origin and score.
- Read/continue action wired to the chapter reader.
- Local Manga Library save toggle, locally persisted reading status (Planning, Reading, Completed, Paused, Dropped, Repeating), share action and external AniList link.
- Local Manga Library save toggle, local reading-list status (Planning, Reading, Completed, Paused, Dropped, Repeating), share action and external AniList link.
- Five work tabs: Chapters, Characters/Creators, Relations/Recommendations, Sources and Details.
- AniList detail-only query for character, staff, relation and recommendation metadata; catalogue/home queries remain on the smaller field set.
- Relations and recommendations are constrained to `type == MANGA` and exclude `format == NOVEL`; Anime entries are not shown or navigable from this Manga detail flow.
- Recommendations are presented separately from canonical relations, and all recommendation cards navigate through the Manga work screen.

## Source binding and chapter catalogue

- Each AniList work can be bound to an exact Mihon source ID and source catalogue URL.
- Source lookup searches installed extensions in bounded batches; title similarity ranks possible matches, but the user selects the final match before the binding is saved.
- A source-specific picker supports Search, Popular, Latest, extension filters and pagination.
- Bound source can be changed or detached; extension settings and source website actions are exposed where supported.
- Chapter catalogue supports scanlator/group filters, source-order/numeric sorting, read/unread state, individual offline downloads and batch download of remaining chapters.
- Source binding and chapter progress are scoped by AniList ID, source ID and chapter URL so two extensions cannot collide on the same path.

## Reader

- Mihon remains responsible for extension HTTP, cookies, headers and Cloudflare session; page bytes are fetched through the native source runtime.
- Vertical/webtoon and paged reader modes, RTL direction, fit-height preference and pinch zoom.
- Page slider, chapter picker, previous/next chapter controls, retry and Cloudflare recovery action.
- Page progress is restored and saved per work/source/chapter; reaching the final page marks the chapter read.
- Offline chapters are written to app-private storage through staging and atomic replacement; corrupt/incomplete manifests are ignored, and interrupted `.previous` downloads can be recovered.
- Batch download is sequential, shows chapter/page progress, and cancellation takes effect after the active chapter to avoid leaving a half-written chapter marked complete.

## Persistence additions

- Per-work source binding.
- Per-chapter reading position and read/unread state.
- Reader preferences (vertical, RTL and fit-height).
- Local Manga Library membership and reading status.
- Store writes are serialized so concurrent progress updates do not overwrite one another.

## Regression coverage and CI gate

- `test/manga_detail_metadata_test.dart`: characters/staff separation, manga-only relations and recommendations, Anime/Novel exclusion and absent optional fields.
- `test/manga_reading_store_test.dart`: source binding, source-scoped progress, serialized concurrent progress, read/unread reset, local library membership and reading status.
- `test/manga_detail_metadata_test.dart` also verifies that recommendation cards retain Manga/Manhwa records and reject Anime/Novel records.
- `test/manga_source_matcher_test.dart`: exact title, punctuation/case, alternate-language title and unrelated result ranking.
- The routine CI gate now includes these three test files in addition to the existing eight focused Manga/Home/Anime/Mihon test files (11 focused Dart test files total).
- Scoped formatter now includes the six PHASE62 Dart implementation files plus the three feature tests (46 Dart targets total across the previously scoped files and new PHASE62 files).

## Validation status

- Static delimiter/lexical structure scan of changed Dart source and tests: passed.
- All four translation JSON files: parsed successfully, duplicate keys checked, and literal translation keys referenced by the new Manga screens are present.
- CI workflow YAML parsed successfully; all 46 scoped formatter files and all 11 focused test paths exist.
- Formatter shell script passes `bash -n`.
- Flutter/Dart SDK is not installed in the current editing environment. `flutter analyze`, `flutter test`, Android Mihon ABI test and APK build were not run here. The repository CI workflow is configured to run these gates; PHASE62 must not be treated as build-confirmed until CI is green.

## Non-goals / backend limitations

- AniList account mutations and remote list synchronization are not implemented because this RAVEN23 integration uses public, unauthenticated AniList queries. Saved membership and reading status are local to this app installation.
- Push notifications for new chapter releases are not claimed; there is no Manga chapter notification backend in the current project.
- A source can only deliver chapters/pages that its installed Mihon extension actually supports. The page uses the selected source's native runtime; it does not fabricate missing chapter/image URLs.
