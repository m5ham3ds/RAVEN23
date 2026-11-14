# RAVEN23 — PHASE63.6: Phosphor navigation refinement and unified Manga source directory

**Date:** 2026-11-13  
**Baseline:** `RAVEN23_PHASE63.5_CI_REPAIR`  
**Scope:** RAVEN23 only. The separately supplied Zangetsu, FlixQuest and OpenStream archives were not opened or inspected.

## Navigation changes

- The Home destination now uses `PhosphorIcons.house()` / `house.fill` instead of `radioButton`.
- New & Hot remains unchanged (`fire`). Search and all other primary/secondary destination icons remain unchanged.
- When the expandable secondary dock is closed and a primary destination is selected, the centre menu control now shows `radioButton` instead of `list`. It continues to show `x` while the secondary dock is open and the selected secondary destination icon after a secondary destination is selected; this preserves the PHASE63.4 destination-aware transition.
- The centre control icon is 30 px (25% above the 24 px regular dock icon); its collapsed value scales proportionally to 26.875 px.
- The main and secondary phone docks are each constrained to 87.5% of their prior available width, reducing the equal item centre-to-centre spacing by 12.5% while keeping the group centred. Tablet rail behavior and vertical spacing are unchanged.

## Unified Installed Manga Sources directory

- Replaced the separate `MangaExtensionsScreen` entry point and the installed-only `MihonSourceBrowserScreen` list with one combined screen titled by the existing `mihon_sources` localization key (`Installed Manga Sources`).
- The directory combines repository extension entries with sources actually loaded by the Mihon runtime, deduplicated by extension package and sorted alphabetically.
- Installed entries display the book artwork, source name, language/version metadata and a single forward action. Tapping opens the source catalogue; the manga title supplied by the work page is passed to the catalogue search only after the user selects an installed source.
- Available entries display the same row identity with website and download actions. Installation still requires explicit confirmation, a trusted repository signer fingerprint and Android native extension support. Installed entries can be removed from the long-press details sheet.
- Installed sources missing from the currently configured repository index remain visible. Their details sheet can still remove the installed package.
- Existing repository add/edit/remove controls remain in Settings > Sources. The settings entry point now opens the unified directory; repository CRUD itself was not moved or duplicated.
- Search covers extension/source names, package names and languages. Website launching, package details, install/uninstall confirmation and the installation security note are retained.
- The standalone `lib/screens/common/manga_extensions_screen.dart` was removed after its behavior was migrated into the unified screen.

## Tests and CI

- Added `test/manga/mihon_source_browser_screen_test.dart` to cover a combined installed and available directory and the row actions shown in the supplied references.
- Added the new page and test to `tool/format_phase57_dart.sh`; the scoped formatter list now contains 55 unique paths.
- Added the test to the focused Flutter pre-build gate; the gate now checks 13 test files.
- Updated the CI report inventory and descriptions to include the unified Mihon directory.

## Static verification and acceptance status

- `bash -n tool/format_phase57_dart.sh` passes.
- All 55 unique formatter targets exist.
- All 13 focused Flutter test files exist and are non-empty.
- The Android CI workflow YAML parses successfully.
- No remaining active source, test, formatter-script or workflow references to the deleted `MangaExtensionsScreen` or `manga_extensions_screen.dart` remain; historical phase notes retain their original descriptions.
- Dart/Flutter/Gradle/Android SDK are unavailable in the editing environment. Therefore `dart format`, `flutter analyze`, the 13 Flutter tests, Android Mihon ABI test, Gradle compilation, Release APK assembly, ABI audit and device behavior were **not** run or claimed. A fresh GitHub Actions run is required for build acceptance.

## Changed files

- `lib/mobile/app/mobile_nav_bar.dart`
- `lib/manga/mihon/mihon_source_browser_screen.dart`
- `lib/mobile/screens/manga_screen.dart`
- `lib/manga/ui/manga_work_screen.dart`
- `lib/screens/common/source_repositories_screen.dart`
- `lib/screens/common/manga_extensions_screen.dart` (removed)
- `test/mobile/mobile_nav_bar_test.dart`
- `test/manga/mihon_source_browser_screen_test.dart` (added)
- `tool/format_phase55_dart.sh` and `tool/format_phase56_dart.sh` (removed the deleted widget from legacy formatter inventories)
- `tool/format_phase57_dart.sh`
- `.github/workflows/android-ci.yml`
- `phases/PHASE63.6_NAVIGATION_AND_UNIFIED_MIHON_DIRECTORY.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/README_CHANGED_FILES.txt`
