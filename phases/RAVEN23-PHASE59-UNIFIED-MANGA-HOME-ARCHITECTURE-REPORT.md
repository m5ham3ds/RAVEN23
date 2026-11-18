# RAVEN23 — PHASE59: Unified Manga Home Architecture

## Objective

Correct PHASE58 so the Manga / Manhwa / Manhua catalogue uses the same Home presentation pipeline as Movies, Series and Anime. The change must not expose manga data in the regular Home feed or alter the existing video feeds.

## Implemented architecture

- `HomePageFrame` is now the shared page shell used by `HomeScreen` and `MangaScreen`. It owns the pinned Home header, background tint, pull-to-refresh, scroll controller, update-notice slot, and bottom safe-area spacing.
- `HomeHeaderDelegate` and `HomeHeader` are public shared widgets in `lib/mobile/widgets/home_header.dart` rather than HomeScreen-private implementations.
- The row builder was extracted to `lib/catalog/home_rows.dart`. Both `HomeScreen` and `MangaScreen` call this exact `homeRows()` function.
- `homeRows()` has a Manga adapter branch that builds the hero carousel, Top 10 row and catalogue rows from `MangaCatalogue.homeShelves`. The Manga catalogue retains all 18 canonical shelves. The All filter additionally exposes the three regional feature rows (Manga, Manhwa and Manhua); a narrowed regional filter only renders that region's 18-shelf catalogue.
- Manga cards use the common `HeroCarousel`, `TopTenRow` and `PosterRow` presentation widgets, while direct taps open Manga detail and the hero's secondary action opens the Mihon source browser.
- AniList catalogue loading, search, region filters, refresh state and the Mihon source browser remain owned by the Manga adapter. They are data/source responsibilities, not a separate visual feed implementation.

## Data isolation guarantees

- `HomeFilter.manga` has no TMDB `MediaKind` values.
- `HomeFeedController.load(HomeFilter.manga)` returns an empty video feed before invoking the video source. Manga content is supplied only by the independent AniList-backed Manga adapter.
- The regular Home filters (`all`, `movies`, `series`, `anime`) continue through their existing TMDB feed paths. The Manga branch in `homeRows()` is selected only for `HomeFilter.manga`.
- The Manga catalogue is not added to the ordinary Home feed, Home's My List, or the existing video `HomeFeed` model.

## Tests added / expanded

`test/home_screen_test.dart` now covers:

1. `HomeFeedController` does not query the video source for `HomeFilter.manga`.
2. The shared Home row builder creates the hero + 18 Manga shelves + 3 regional feature rows for the All Manga view.
3. The regular Home (All) feed does not render Manga cards even when a Manga catalogue is supplied to the row builder.
4. A Manhwa-only view keeps the same 18 shelves and draws from the Manhwa catalogue only.

The existing Manga shelf parity test remains in place.

## Validation status

Source-level architecture and references were inspected. The execution environment for this delivery does not include the Flutter or Dart SDK, so `dart format`, `flutter analyze` and `flutter test` could not be executed here. The project pins Flutter `3.35.7` in `.fvmrc`; run formatting, analysis and the targeted tests with that SDK before merging or publishing a build.

Suggested checks:

```bash
dart format lib/catalog/home_feed_controller.dart lib/catalog/home_rows.dart lib/mobile/screens/home_screen.dart lib/mobile/screens/manga_screen.dart lib/mobile/widgets/home_header.dart lib/mobile/widgets/home_page_frame.dart test/home_screen_test.dart
flutter analyze
flutter test test/home_screen_test.dart test/manga/phase57_manga_home_parity_test.dart
```
