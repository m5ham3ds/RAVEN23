# RAVEN23 — Phase 30: Cross-Screen Reveal Animation

## Scope

Extend the existing Zangetsu-style `RevealItem` animation from Phase 29 to the browsing, details, season/episode, cast, and See All surfaces requested for RAVEN23. This phase reuses the existing reveal implementation; it does not introduce a second animation system or redesign any UI.

## Animation behavior retained

The existing `lib/mobile/widgets/reveal_item.dart` remains the single source of truth:

- Trigger: first time the item becomes visible in the viewport (`VisibilityDetector`).
- Duration: 380 ms.
- Entrance: opacity fade, 28 px vertical rise, scale 0.94 → 1.0.
- Easing: `easeOutCubic` for movement/scale and `easeOut` for the fade curve.
- Stagger: 45 ms per item, capped by `index % 8`.
- One-shot state: the reveal does not restart while the same widget state remains mounted.

For horizontal rails, the same Zangetsu reveal is triggered when an item enters the horizontal viewport from either direction. The reveal itself remains the same vertical rise + fade + scale used by Zangetsu; it is not changed into a sideways slide.

## Coverage added

### Search

- Browse/filter entry card.
- Recent-search pills.
- Top-search rows (single-column and multi-column layouts).
- Movie, Series, and Anime genre tiles.
- No-match genre suggestions.
- Search result poster grid.
- Horizontal people results.
- Shared horizontal `FilterChips` rows, including Search's filter selector.

### Discover

- Vertical filter sections (sort, genres, services, ratings, and TV/anime status).
- Active-filter chips in the horizontal rail.
- Individual Year rail pills. The Year section parent is intentionally not wrapped, avoiding a nested parent-plus-child reveal while each year pill enters the viewport.

### New & Hot

- Coming-soon premiere cards, individually within each date group.
- Everyone Watching cards.
- Top 10 movie/series/anime cards.
- Shared horizontal `FilterChips` selector.

### Title details and related content

- Main title summary block.
- Trailers & More video cards.
- Backdrop and poster artwork cards.
- Details/info and social-link sections.
- More Like This poster grid.
- Horizontal Cast, Video, and Image rows through shared components.

### Series and Anime episode flow

- Season/about-this-season summary.
- Vertical episode rows in the season page and shared `EpisodesSection`.
- Horizontal episode rail on the episode page.
- Cast, video, and still-image rails through shared row components.
- Anime remains on the same episode/season path as series; no separate player or content flow was introduced.

### Cast and See All pages

- Cast, guest-star, and crew rows in Credits.
- Person filmography grid.
- Collection/genre/service See All grid.
- Playlist and shared-playlist poster grids.
- Playlist list and horizontal playlist shelf.
- Shared `PosterGrid` component now animates cards for any screen that uses it.
- Existing home content rails from Phase 29 remain in place; the shared FeatureCard and FilterChips surfaces are also covered.

## Gesture and visual preservation

No changes were made to card artwork, card dimensions, typography, colors, spacing tokens, border radii, list physics, scroll controllers, paging, navigation, or tap/long-press behavior. The `RevealItem` wrapper only applies the established fade/transform while an item enters the visible area.

`ReorderableListView` in playlist edit mode is intentionally not wrapped. Its drag handles and reorder gesture must remain direct and uninterrupted. Skeleton placeholders, form fields, menu options, and non-content controls are also left unchanged.

## Files changed

18 mobile source files:

- `lib/mobile/screens/collection_screen.dart`
- `lib/mobile/screens/credits_screen.dart`
- `lib/mobile/screens/discover_screen.dart`
- `lib/mobile/screens/episode_screen.dart`
- `lib/mobile/screens/my_raven23_screen.dart`
- `lib/mobile/screens/new_and_hot_screen.dart`
- `lib/mobile/screens/person_screen.dart`
- `lib/mobile/screens/playlist_screen.dart`
- `lib/mobile/screens/playlists_screen.dart`
- `lib/mobile/screens/search_screen.dart`
- `lib/mobile/screens/season_screen.dart`
- `lib/mobile/screens/shared_playlist_screen.dart`
- `lib/mobile/screens/title_details_screen.dart`
- `lib/mobile/widgets/category_section.dart`
- `lib/mobile/widgets/details_parts.dart`
- `lib/mobile/widgets/episodes_section.dart`
- `lib/mobile/widgets/filter_chips.dart`
- `lib/mobile/widgets/poster_grid.dart`

One test file:

- `test/mobile/widgets/reveal_item_test.dart`

The Phase 29 `RevealItem` implementation and all previous phase reports are preserved.

## Validation performed

- Delimiter-balance scan passed for all 19 changed Dart/test files.
- Relative import existence check passed for every relative import in the modified files.
- Project-wide Dart relative-import scan reported no missing relative imports in the changed files; the project contains pre-existing root-absolute-style imports that are outside this phase's changes.
- Existing `test/flutter_test_config.dart` sets `VisibilityDetectorController.instance.updateInterval = Duration.zero`, so visibility-based widget tests do not wait on the production batching interval.
- Added widget coverage for visibility-triggered reveal on both vertical and horizontal scroll axes.
- Confirmed the changed-file set is limited to the 18 mobile source files and the reveal widget test, plus this report in the project root and `phases`.

## Not run

Flutter/Dart SDK is not installed in the editing environment. Therefore `dart format`, `flutter analyze`, `flutter test`, and a release APK build were not run. Static source checks are not a substitute for those commands; GitHub Actions should run the full analyzer and tests before release.
