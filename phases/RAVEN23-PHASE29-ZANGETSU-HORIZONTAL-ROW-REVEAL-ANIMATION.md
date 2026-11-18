# RAVEN23 — Phase 29: Zangetsu horizontal shelf item-reveal animation

## Scope

Reference project: the supplied `Zangetsu-main.zip`.
Target project: RAVEN23 Phase 28.

This phase ports the item entrance animation used by Zangetsu's `ContentRow` into RAVEN23's corresponding mobile shelf implementation. It does not redesign poster cards, section headers, row spacing, row direction, card dimensions, badges, typography, colors, or the underlying horizontal scroll interaction.

## What the Zangetsu inspection established

Zangetsu does not implement a custom left/right drag controller or custom horizontal scroll physics for ordinary content shelves. `ContentRow` uses a normal horizontal `ListView.builder`. The visible animation associated with swiping through the shelf is `RevealItem`: as a previously unseen card becomes visible, it enters with a one-shot fade, upward lift, and slight scale. The list itself continues to use Flutter's normal horizontal scrolling behavior.

The reference implementation is:

- `lib/core/ui/content_row.dart`
- `lib/core/ui/reveal_item.dart`
- `lib/core/ui/animation_prefs.dart`
- `lib/main.dart` (VisibilityDetector update interval)

The default Zangetsu `rise` animation uses:

- `AnimationController`: 380 ms.
- Translation: from 28 logical pixels below the final position to zero.
- Scale: from 0.94 to 1.0.
- Movement curve: `Curves.easeOutCubic`.
- Fade: `Curves.easeOut` applied to `controller.value * 1.4`, clamped to `[0, 1]`.
- Stagger: `45 ms * (index % 8)`.
- Trigger: first `VisibilityDetector` callback with `visibleFraction > 0`.
- Replay policy: one reveal per widget state. A card that has already appeared does not replay when the user scrolls back over it; an unseen card reveals when it first enters from either side.
- Row cache: 600 px, or unbounded when `accessibleNavigation` is enabled.
- Detector cadence: 80 ms in normal runtime; tests set it to zero to avoid pending timers.

Zangetsu also has a separate 120 ms, 0.97 press-scale animation on its poster cards. RAVEN23 already has a press-scale interaction; this phase deliberately leaves it unchanged because the requested behavior is the reveal-on-horizontal-scroll animation, not a redesign of the press interaction.

## RAVEN23 baseline finding

RAVEN23's mobile `lib/mobile/widgets/media_rows.dart` already builds its shelves using `ListView.separated(scrollDirection: Axis.horizontal)`, but each item was inserted directly. There was no visibility-gated item reveal wrapper. The existing `visibility_detector` package was already a dependency and `lib/main.dart` already imported it, so no new package was required.

The shared private `_Row` is the correct integration point. `PosterRow`, `TopTenRow`, and `ContinueRow` all use it. This also covers callers such as Home and category shelves that compose `PosterRow`, while leaving the TV row widgets untouched.

## Changes

### 1. New `lib/mobile/widgets/reveal_item.dart`

Added a mobile shelf reveal widget matching Zangetsu's default `rise` behavior:

- Waits until the item is actually visible; it does not animate merely because the lazy list built it ahead of the viewport.
- Uses a unique stable `VisibilityDetector` key.
- Runs once per card state.
- Uses the same 380 ms duration, 28 px lift, 0.94-to-1 scale, easing curves, fade progression, and modulo-8 stagger as Zangetsu.
- Guards delayed callbacks with `mounted` and disposes its controller.

### 2. `lib/mobile/widgets/media_rows.dart`

The shared `_Row` now wraps each existing item-builder result in:

`RepaintBoundary -> RevealItem -> existing child`

No child widget was replaced. No card dimensions, item spacing, separators, section headers, or visual styling were changed. `cacheExtent` now follows the Zangetsu shelf behavior: 600 px for normal navigation and infinite when accessibility navigation is enabled.

Because `PosterRow`, `TopTenRow`, and `ContinueRow` share `_Row`, they receive the same entrance behavior consistently.

### 3. `lib/main.dart`

RAVEN23 already set `VisibilityDetector` to zero interval when the ads migration is enabled. That existing behavior is preserved. When ads are disabled, the interval is now explicitly 80 ms rather than relying on the package's 500 ms default. This matches Zangetsu's runtime cadence and prevents cards entering during a swipe from remaining transparent until a slow visibility batch.

### 4. Tests

Added `test/mobile/widgets/reveal_item_test.dart` for the visible-item rise/fade/scale behavior.
Added `test/flutter_test_config.dart` to set `VisibilityDetector`'s interval to zero in widget tests, matching Zangetsu's test setup and preventing its batched visibility timer from leaking between tests.

## Files changed

- `lib/mobile/widgets/reveal_item.dart` (new)
- `lib/mobile/widgets/media_rows.dart`
- `lib/main.dart`
- `test/flutter_test_config.dart` (new)
- `test/mobile/widgets/reveal_item_test.dart` (new)
- `RAVEN23-PHASE29-ZANGETSU-HORIZONTAL-ROW-REVEAL-ANIMATION.md` (root and `phases/` copy)

## Explicitly unchanged

- `PosterCard` drawing, dimensions, badges, artwork, title, colors, and border radii.
- Existing press-scale animation and tap/long-press handling.
- The `ListView` horizontal scroll direction and default scroll physics.
- Featured hero/banner carousel animation; it is a separate component and not the shelf-card reveal.
- Discover/genre chip layout and filters.
- TV browse rows and TV focus/remote interactions.
- Data sources, catalogue APIs, playback, and all media models.
- All prior phase files and the Phase 28 Anime behavior.

## Validation performed

- Confirmed Zangetsu `ContentRow` wraps each shelf item in `RepaintBoundary(RevealItem(...))` and that `RevealItem` uses the values listed above.
- Confirmed the target package already declares `visibility_detector: ^0.4.0+2`.
- Confirmed the target's `main.dart` has the `VisibilityDetectorController` setup and retained zero interval for ads-enabled visibility tracking.
- Confirmed all three target row variants (`PosterRow`, `TopTenRow`, `ContinueRow`) flow through the shared `_Row` wrapper.
- Confirmed no player, provider, API, catalogue, media-card paint, theme, or TV-row source was modified.
- Added a widget test for the visible-card reveal.

Flutter/Dart SDK is not installed in this editing environment. Therefore `dart format`, `flutter analyze`, `flutter test`, and an APK build could not be run here. On-device behavior still requires a release/debug run to confirm the animation timing under actual scroll velocity and frame scheduling.
