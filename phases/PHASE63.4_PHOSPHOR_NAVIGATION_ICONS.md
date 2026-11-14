# RAVEN23 — PHASE63.4: Phosphor Navigation Icons and Destination-Aware Menu Toggle

**Date:** 2026-11-13  
**Baseline:** Owner's successful PHASE63.3 project archive  
**Scope:** Mobile bottom navigation and tablet navigation rail only.

## Requested icon mapping

| Navigation destination | Phosphor icon | Selected treatment |
|---|---|---|
| Main/Home | `radioButton` | Fill |
| Movies | `video` | Fill |
| Series | `televisionSimple` | Fill |
| Search | `magnifyingGlass` | Existing Bold treatment; unchanged |
| Anime | `maskHappy` | Fill |
| Manga | `bookOpenText` | Fill |

The implementation uses the existing `phosphor_flutter: ^2.1.0` dependency. All five new icon names (`radioButton`, `video`, `televisionSimple`, `maskHappy`, and `bookOpenText`) were verified against the package's published 2.1.0 API documentation before editing: https://pub.dev/documentation/phosphor_flutter/2.1.0/phosphor_flutter/PhosphorIcons-class.html.

## Destination-aware secondary-menu button

The button between New & Hot and Discover follows this state machine:

1. **Menu closed on a primary destination:** show the original `list` icon.
2. **Menu open:** show `x`, preserving the existing close affordance.
3. **A secondary destination selected and menu closed:** show that destination's selected Phosphor icon (Movies `video`, Series `televisionSimple`, Search `magnifyingGlass`, Anime `maskHappy`, Manga `bookOpenText`).
4. **Return/back to a primary destination (for example Home):** restore the original `list` icon.

The shared `_MenuAction` is used by both `MobileNavBar` and `MobileNavRail`, so behavior remains consistent on phones and tablets. The secondary menu continues to open/close through the same callback; no routing or tab-persistence behavior was changed.

## Implementation

- `lib/mobile/app/mobile_nav_bar.dart`
  - Centralized the destination icon mapping in `_navLookFor` so the dock and dynamic menu button use the same source of truth.
  - Changed Home, Movies, Series, Anime, and Manga to the requested Phosphor icons.
  - Kept Search's regular and bold magnifying-glass icons unchanged.
  - Passed the active `MobileTab` into `_MenuAction`; its animated switcher now transitions between `list`, `x`, and the selected destination icon.
- `test/mobile/mobile_nav_bar_test.dart`
  - Verifies the requested icons are rendered in the navigation docks.
  - Verifies the menu toggle shows `x` while open, changes to the Movies selected icon after selecting Movies, and restores `list` after returning Home.
- `tool/format_phase57_dart.sh`
  - Added the navigation source and widget test; formatter target count increased from 51 to 53.
- `.github/workflows/android-ci.yml`
  - Added the navigation widget test to the focused Flutter pre-build test gate.
  - Updated focused test and formatter counts in the CI summary.
- `phases/README_MASTER_IMPLEMENTATION.md` and `phases/README_CHANGED_FILES.txt`
  - Recorded PHASE63.4 as the latest implementation increment.

## Verification performed in the editing environment

- Confirmed all requested Phosphor symbols exist in the published `phosphor_flutter` 2.1.0 API.
- `bash -n tool/format_phase57_dart.sh` passed.
- All 53 explicit formatter targets exist.
- Android CI workflow YAML parsed successfully.
- Confirmed the new navigation test appears in the focused CI test list.
- Confirmed no other app navigation destinations, labels, routing, player, media pages, or manga logic were changed.

## Not run / acceptance gate

Flutter and Dart SDKs are unavailable in this editing environment. Therefore `dart format`, `flutter analyze`, `flutter test`, Gradle compilation, and APK assembly were not run. GitHub Actions must pass dependency resolution, the 53-target format check, analyzer, the 12 focused Flutter test files (including `mobile_nav_bar_test.dart`), the Mihon Android unit tests, and Release APK assembly before this increment is considered build-accepted.

## Manual device checks

1. Confirm Home shows `radio-button` in the main dock.
2. Open the secondary dock and confirm Movies `video`, Series `television-simple`, Search unchanged, Anime `mask-happy`, and Manga `book-open-text`.
3. Close the secondary dock and select Movies; the middle menu button should animate from `x` back to the selected `video` icon.
4. Use Android Back to return Home; the middle button should restore the original `list` icon.
5. Repeat for Series, Search, Anime, and Manga, and confirm tablet rail has the same behavior.
