# RAVEN23 — PHASE63.1: Zangetsu source discovery, switching and chapter-list parity

**Date:** 2026-11-13  
**Baseline:** Owner-confirmed successful PHASE63 Analyze-repair build, followed by the owner's device screenshots.  
**Reference:** The owner-supplied `Zangetsu-main.zip` source and the nine screenshots supplied on 2026-11-12/13.  
**Scope:** Manga / Manhwa / Manhua work page source resolution, source switcher, and chapter catalogue actions.

## 1. Reference-first audit completed before RAVEN23 edits

The Zangetsu implementation was inspected first, before applying this follow-up to RAVEN23. Relevant reference files included:

- `lib/core/zmode/source_matcher.dart` — pinned source, last-good source and explicit auto-resolve behavior.
- `lib/core/models/media_item.dart` — title identity normalization and alias matching.
- `lib/features/detail/detail_screen.dart` — source card position and the matched-title / “Wrong title?” line.
- `lib/features/detail/wrong_title_sheet.dart` and `lib/core/ui/source_switcher.dart` — source selection, automatic re-resolution and title correction.
- `lib/features/detail/detail_episodes.dart` — list/grid chapter catalogue, bulk downloads, refresh, reverse and chapter actions.

The source behavior copied from that audit is deliberately conservative: an existing per-work source pin remains authoritative; the last successfully used manga source is tried alone before silently switching providers; an explicit Auto Resolve action clears that remembered preference and performs a full ordered scan. New automatic bindings require a whole normalized title match against an AniList title or alias. Similarity ranking is retained only for manual suggestions; partial/sub-string matches are never auto-bound because different providers may have different chapter numbering.

## 2. Automatic source discovery and source switcher

- Opening an unbound Manga / Manhwa / Manhua work now waits for the refreshed AniList detail so the English, display, native and synonym title set is available, then searches registered Mihon sources automatically.
- Search follows the installed-source order returned by Mihon. The first source result that passes strict whole-title identity matching is bound and its chapter list is loaded automatically.
- An existing per-title binding is reused as a firm pin; the app does not replace it with a different source during page initialization.
- A global last-good source preference is persisted after a successful catalogue load. Future unpinned works try that provider alone first. If it has no exact result, RAVEN surfaces the miss instead of quietly changing providers.
- The detail page header now follows the Zangetsu sliver sequence: a 320px expandable backdrop, a separate title/metadata block, a full-width white Continue/Find-source action, the source card and matched-title line, the synopsis, credits/genres and then the icon-over-label actions. The four-tab header is a pinned sliver after this content, not embedded at the bottom of the artwork banner.
- The source card is placed after Continue and before the synopsis, matching the supplied Zangetsu screenshot. It identifies the active provider as `Mihon · Source`, provides a dropdown source selector and an overflow menu.
- The matched Mihon catalogue title and `Wrong title?` action are presented together below the source card. Title correction and manual catalogue selection stay available when strict automatic matching cannot verify a result.
- The source picker includes an explicit **Auto Resolve** row. Choosing it removes the current work pin, clears the last-good provider preference, and runs the full installed-source sweep again.
- Refreshing the chapter catalogue now evicts the shared Mihon OkHttp response cache before requesting chapters, rather than only repeating a request against cached source JSON.
- Source-scan request generations prevent an earlier auto-scan from overwriting a newer manual source choice.

## 3. Chapter catalogue parity

- The chapter catalogue defaults to ascending order and provides list and grid presentations. The grid uses five columns at the same general density as the Zangetsu reference.
- List rows show a chapter thumbnail (source thumbnail when supplied; otherwise the work/source cover), title, chapter number, scanlator when available, relative publication time, reading progress and a direct download action.
- The toolbar provides bulk download, list/grid toggle, Refresh chapters and Reverse list.
- Bulk download offers **All** and **Custom**. Custom mode uses Start and End chapter selectors and downloads the inclusive visible range. The selectors are keyed to their selected index so a changed range cannot leave a stale FormField selection visible.
- Long-pressing a chapter opens the action sheet with Mark as read/unread and Mark this and all above as read/unread. Read state remains scoped to the current work, source and chapter URL.
- Download state and reading progress continue to use the existing PHASE62/63 stores and Mihon download pipeline; no duplicate download or progress database was added.
- Chapter dates render relative time for recent items and a localized absolute date for future timestamps.

## 4. Files changed in this follow-up

- `lib/manga/ui/manga_work_screen.dart` — Zangetsu-ordered sliver header, full-width Continue action, automatic resolution, source card/picker, refresh cache eviction, list/grid/download/range/read actions, relative chapter dates and keyed range dropdowns.
- `lib/manga/ui/manga_reading_store.dart` — persisted last-good source read/write/clear operations.
- `lib/manga/ui/manga_source_matcher.dart` — documented strict automatic identity matching versus suggestion ranking.
- `test/manga_reading_store_test.dart` — verifies last-good source persistence and clearing.
- `assets/translations/ar.json`, `en.json`, `es.json`, `hi.json` — Auto Resolve and relative month/year labels.
- `phases/README_MASTER_IMPLEMENTATION.md`, `phases/README_CHANGED_FILES.txt` — phase index and change log.
- this report.

The existing formatter gate already includes the modified Manga UI/store/matcher files and their focused tests; its 50-target count did not need to change.

## 5. Preserved behavior and boundaries

Mihon still owns extension loading, network clients, cookies, Cloudflare and chapter/page retrieval. Existing extension/repository installation, AniList identifiers, explicit title binding, chapter downloads, reading progress, OCR and online/offline translation code paths remain intact. No Movies, Series, Anime, Home feed, video providers, player or TV implementation was intentionally changed.

## 6. Known parity gaps — not represented as completed

- **Notify** is not shown as a working work-page action. RAVEN23 has no Manga chapter-subscription store plus scheduled/background checker equivalent to Zangetsu's notification integration. The existing app notification APIs alone do not implement chapter-release tracking, so a nonfunctional button was not added.
- **Tracking** is not shown as an external synchronization action. RAVEN23 currently keeps its Manga list/status locally and does not provide Zangetsu-equivalent external tracker synchronization.
- Zangetsu exposes saved source-order preferences and language narrowing/caps. RAVEN23 currently uses Mihon's registered-source order for the initial ordered sweep; a user-configurable per-language/source priority manager is still a separate follow-up.
- Strict auto matching may leave a work unbound when provider naming differs materially from AniList aliases. This is intentional; the user can choose a source and correct the title manually rather than risk an incorrect work/chapter mapping.
- A chapter-specific thumbnail is displayed only when the Mihon source supplies one. Otherwise the UI uses the source/work cover as the fallback.

## 7. Static checks and CI requirement

Static checks performed for this handoff:

- All four locale JSON files parse; each contains **2,303** keys and their complete key sets are identical.
- The new Auto Resolve and relative month/year keys exist in all four locales.
- The existing 50-target formatter script passes `bash -n`; all listed targets exist.
- Source/UI call sites, native Mihon cache bridge method and read/download store contracts were inspected for consistency.
- The custom chapter-range controls carry a stable value-derived key when the user changes the range.

Flutter, Dart, Gradle and Android SDK are unavailable in this editing environment. Therefore `dart format`, `flutter analyze`, `flutter test`, Kotlin/Gradle compilation, Release APK assembly and device interaction were **not** run here. The owner's successful build of the prior PHASE63 repair is baseline evidence only; this PHASE63.1 change requires a fresh GitHub Actions build and device verification before acceptance.

**Next gate:** run the repository's existing scoped CI formatter, Flutter Analyze and focused Manga reading-store/source-matcher/detail tests, then Mihon ABI/Gradle and ARM64 Release APK audit. On-device acceptance must verify opening an unbound work triggers an automatic search, existing work pins persist, Auto Resolve sweeps all registered sources, manual source switching/title correction works, and list/grid/download/read/refresh actions behave as shown in the reference screenshots.
