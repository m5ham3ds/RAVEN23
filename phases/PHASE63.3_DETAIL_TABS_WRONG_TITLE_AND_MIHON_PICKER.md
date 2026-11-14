# PHASE63.3 — Detail Tab Pinning, Synopsis Navigation, Wrong Title Search, and Mihon Picker

**Date:** 2026-11-13  
**Baseline:** RAVEN23 PHASE63.2  
**Reference:** Zangetsu detail screen, wrong-title search sheet, and Mihon source picker

## Scope

This phase addresses the remaining detail-screen interaction differences reported after testing PHASE63.2. It is deliberately limited to the manga/manhwa work-detail route, its source picker/search UI, translations, and phase documentation.

## Implemented changes

### 1. Keep the four detail tabs at a consistent pinned position

- Added a stable `GlobalKey` to the pinned tab strip.
- After a tab tap or a settled `TabBarView` swipe, the screen now uses `Scrollable.ensureVisible` on the tab strip itself, rather than relying on an estimated outer-scroll extent.
- The reveal alignment leaves the collapsed app bar above the tabs, following Zangetsu's pinned-header arrangement.
- The reveal is coalesced while an animation is active to avoid repeated scroll animations during page swipes.
- The tab-strip reveal also works for short and empty tab states because the empty/loading widgets remain scrollable.

### 2. Read more opens the full synopsis at its position in Details

- Read more selects the Details tab.
- It first reveals the pinned tab strip beneath the collapsed app bar.
- It then calls `Scrollable.ensureVisible` on the Synopsis section's `GlobalKey`, taking the reader to the full description rather than simply switching tabs.

### 3. Wrong title search matches the Zangetsu interaction

- The sheet header is “Which one is it?” (localized in English, Arabic, Spanish, and Hindi).
- A source pill at the right displays “Searching [source]” and opens a source-switch menu.
- The rounded search field is prefilled with the work's primary title alias.
- The search icon and keyboard submit both run the query against the selected source.
- Results remain in the poster grid and can be selected to bind that result.
- Latest, Popular, and filter controls are not included in this sheet.

### 4. Mihon source picker opens compact and remains draggable

- Initial height is bounded to 40–48% of the available screen height, so the sheet opens below half-screen height.
- Source rows and the Auto Resolve row use compact vertical density, targeting approximately two visible source entries at first open.
- The sheet remains draggable up to 92% height.
- All/Manga tabs, Auto Resolve, source icons, selected-source indication, and long-press pinning remain available.

### 5. Source overflow menu contains only the three Zangetsu actions

The source overflow menus now expose only the supported actions from this set:

1. Solve Cloudflare
2. Sign in
3. Source settings

Items remain capability-gated: unsupported actions are not shown for a source that cannot provide them. Change source is handled by the source selector, Wrong title? remains a separate action, and open-website/unlink actions are not in this overflow menu.

### 6. Opening a work starts at Chapters

- The detail screen initializes the tab controller at index `0` (Chapters) on every new route instance.
- Persistence writes `selectedTab: 0` for compatibility with existing preference records.
- Per-work preferences such as list/grid mode, ascending/descending order, scanlator, notification preference, source binding, and reading progress are otherwise retained.

### 7. Localization

Added `manga_source_searching` to all four supported translation assets and the generated loader:

- English: Searching
- Arabic: جارٍ البحث
- Spanish: Buscando
- Hindi: खोज रहा है

## Files changed

- `lib/manga/ui/manga_work_screen.dart`
- `assets/translations/en.json`
- `assets/translations/ar.json`
- `assets/translations/es.json`
- `assets/translations/hi.json`
- `lib/translations/codegen_loader.g.dart`
- `phases/PHASE63.3_DETAIL_TABS_WRONG_TITLE_AND_MIHON_PICKER.md`

## Static verification performed

- Parsed all four translation JSON files successfully.
- Verified all four locales contain the same 2,319 keys.
- Verified the new search-state key appears once in each generated locale map.
- Verified all 51 Dart formatter targets exist and include `manga_work_screen.dart`.
- Verified `tool/format_phase57_dart.sh` passes `bash -n`.
- Verified the source-search sheet no longer references the previous Latest/Popular/filter-sheet implementation.
- Verified the project archive passes ZIP integrity testing after packaging.

## Not verified in this environment

Flutter, Dart, Gradle, and the Android SDK are not available in the editing environment. Therefore this phase has **not** been Flutter-analyzed, formatted with `dart format`, widget-tested, Android-tested, or built into an APK here. GitHub Actions remains the authoritative build gate.

## Manual acceptance checks

1. Scroll the work page until the four tabs pin beneath the collapsed app bar, then tap each tab and swipe between tabs. The tab strip should remain at the same vertical position.
2. Tap Read more in the header. Details should open and the Synopsis heading/full text should be brought into view.
3. Open Wrong title?. Confirm the sheet contains only the prompt, source-switch pill, search field, result count, and matching results. Confirm no Latest, Popular, or filter controls appear.
4. Open the Mihon picker. It should initially show approximately two sources and expand when dragged upward.
5. Open a source's three-dot menu. Only Solve Cloudflare, Sign in, and Source settings should be available when supported.
6. Open a work, switch to Details, leave the work route, and open the same work again. It should start on Chapters while preserving the other per-work preferences.
