# PHASE63.21 — Restore Secondary Dock Auto-Collapse

## Source of truth

Based on `PHASE63.20_GLOBAL_PRESS_FEEDBACK_BUILD_REPAIR` and the original
`PHASE63.18` implementation of `MobileShell` secondary navigation behavior.

## Confirmed regression

`PHASE63.19` changed `MobileShell._onTabChanged` and `_selectTab` so the
secondary dock remained expanded when Movies, Series, Search, Anime, or Manga
was selected. This differed from the established behavior in `PHASE63.18`,
where selecting any destination closed the secondary dock.

## Fixes

1. Restored the original close-on-selection behavior in `_onTabChanged` for
   every destination, including all secondary destinations.
2. Restored immediate secondary-dock closure in `_selectTab` for every selected
   destination.
3. Kept the active destination in `MobileTabController`; collapsing the dock
   does not clear or change the selected destination.
4. Preserved the existing `MobileTab.primarySelectionFor` mapping, so Home
   remains selected while Movies, Series, or Anime is active.
5. Preserved the selected secondary destination's identity and icon. When the
   secondary dock is reopened, the active secondary item is highlighted next
   to Home. While collapsed, the centre action reflects the active destination.
6. Updated the navigation widget test to assert auto-collapse after selection
   and simultaneous Home/secondary highlighting when the dock is reopened.

## Preserved behavior

- No changes to the dock's `AnimatedSize`, `AnimatedOpacity`, or `AnimatedSlide`
  collapse animation or timing.
- No changes to icon sizes, labels, `AppPressFeedback`, or tap callbacks.
- No changes to primary-dock selection behavior.

## Verification status

- Compared the changed state transitions with the original `PHASE63.18`
  implementation.
- Confirmed the final code closes the secondary dock from both the tab
  listener and selection callback.
- Updated the navigation widget test for the restored behavior.
- Flutter tests and APK build still require GitHub Actions; this environment
  does not have the Flutter/Dart SDK installed.
