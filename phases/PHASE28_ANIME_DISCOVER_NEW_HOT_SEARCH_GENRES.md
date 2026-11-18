# RAVEN23 — Phase 28: Anime Discovery, New & Hot, and Search Genres

## Scope

Target: the complete RAVEN23 Phase 27 project supplied in this conversation.

This phase adds Anime as a distinct browsing category in the mobile Discover, New & Hot, and Search experiences. It deliberately does **not** add a third app-wide playback media kind. Anime series remain episodic TV (`MediaKind.series`) so existing title details, season/episode selection, anime provider mapping, playback, progress, and next-episode behavior continue to work.

## Existing project rules preserved

- Phase 8 defines Anime series as episodic content and routes them through the series season/episode identity and playback path.
- Phase 11's Anime identity rule is retained: a TMDB TV item is considered likely Anime when it has TV genre ID `16` (Animation) and `original_language == ja`.
- Existing Movie and Series discovery, search suggestions, New & Hot segments, and TV detail/player paths are not replaced.
- No source extraction engine, provider, playback loader, route, or player implementation was changed.
- Existing Laravel ad-placement contract is preserved. Anime Discover and Anime genre collections use the established TV placements (`discover_tv` and `genre_tv`); no new backend placement identifiers were invented.

## 1. Discover: third category — Anime

Added `DiscoverKind.anime` to the Discover-specific filter model. The app-wide `MediaKind` remains unchanged.

Anime requests use TMDB `/discover/tv` and constrain every result with:

- `with_genres=16` (Animation, the mandatory Anime discriminator)
- `with_original_language=ja`
- `include_adult` from the user's existing content preference

Other Discover filters continue to work: popularity/rating sorting, year (`first_air_date_year`), TV status, minimum vote count, watch providers, and result counts.

Anime-specific selectable genres are secondary TV genres such as Action & Adventure, Comedy, Drama, Sci-Fi & Fantasy, Mystery, and others. Animation itself is intentionally not offered as a secondary toggle because it is already mandatory in every Anime query; showing it as a selectable filter would create a no-op control.

When the viewer opens results, the collection is created as `MediaKind.series` and uses the normal TV details and episodic flow. The Discover page title and ad slot remain separately labelled for Anime, while the ad slot maps to the existing `discover_tv` backend placement.

## 2. New & Hot: Top 10 Anime

Added `HotSegment.topAnime` and its visible `Top 10 Anime` segment.

The source calls TMDB `/discover/tv` sorted by `popularity.desc`, with Animation genre `16`, Japanese original language `ja`, a minimum vote count of 30, page 1, and the user's adult-content preference. Returned rows are defensively filtered again with the project's existing `TV.isLikelyAnime` rule before applying the Top 10 cap.

Anime cards remain TV `MediaItem`s, so tapping or long-pressing them opens the established episodic details/actions. Screen-reader text identifies the ranked entries as Anime without changing the underlying media kind.

This Top 10 is a popularity-ranked Japanese-animation TV list. It is not represented as TMDB's general daily TV trending list, because that list is not Anime-filtered.

## 3. Search: Anime genres

`SearchSuggestions` now carries `animeGenres`. The existing TV genre response is reused (no additional genre endpoint call); it is filtered through a curated set of useful episodic Anime genre IDs.

Search now displays three separate genre sections:

- Movie genres
- Series genres
- Anime genres

Selecting an Anime genre opens an Anime-only TV collection. Its request always combines the mandatory Animation genre `16`, the selected secondary genre, Japanese original language `ja`, and the existing adult-content preference. The collection's media kind remains Series/TV. The visible kicker says Anime genre, while the ad placement uses the existing `genre_tv` contract.

The no-match suggestions can also suggest matching Anime genres and route them through the same Anime-only collection path.

## 4. Localization

Added and generated the following keys in English, Arabic, Spanish, and Hindi:

- `anime`
- `discover_anime`
- `anime_genres`
- `anime_genre`
- `top_10_anime`
- `anime_status`

Updated both the JSON translation files and the generated Easy Localization loader/key files.

## 5. Files changed

Application code:

- `lib/api/endpoints.dart`
- `lib/catalog/catalog_controller.dart`
- `lib/catalog/discover_query.dart`
- `lib/catalog/new_and_hot.dart`
- `lib/mobile/collections.dart`
- `lib/mobile/screens/discover_screen.dart`
- `lib/mobile/screens/new_and_hot_screen.dart`
- `lib/mobile/screens/search_screen.dart`
- `lib/mobile/widgets/poster_card.dart`
- `lib/translations/codegen_loader.g.dart`
- `lib/translations/locale_keys.g.dart`

Localization and documentation:

- `assets/translations/en.json`
- `assets/translations/ar.json`
- `assets/translations/es.json`
- `assets/translations/hi.json`
- `README.md`

Tests:

- `test/discover_screen_test.dart`
- `test/new_and_hot_screen_test.dart`
- `test/new_and_hot_test.dart`
- `test/search_screen_test.dart`
- `test/tv_search_screen_test.dart` (updated shared suggestions fixture)

The existing ad placement manifest and backend fixture were intentionally left unchanged.

## 6. Added/updated test coverage

- Anime Discover builds `/discover/tv` requests with mandatory Animation + Japanese language and supports status/year/provider/rating/adult filters.
- Anime Discover opens an Anime-labelled collection whose request remains the episodic TV endpoint.
- Anime genre options do not expose the mandatory Animation discriminator as a meaningless second filter.
- Search displays a separate Anime genres section and Anime genre collections preserve their Anime kicker and episodic TV kind.
- Top 10 Anime uses Japanese animation filters, honors adult-content settings, and rejects Japanese non-animation and non-Japanese animation rows.
- New & Hot widget tests select Top 10 Anime and render its Anime item.
- Arabic tablet and narrow-screen overflow coverage now includes Top 10 Anime.
- Existing ad-placement contract remains unchanged and is statically checked against its 36-entry manifest.

## 7. Static verification performed

- Parsed all four translation JSON files and checked for duplicate keys.
- Verified all six new translation keys exist in each locale and match the generated loader's locale-specific values.
- Verified generated locale-key declarations contain each new key once.
- Scanned 16 changed Dart files for balanced delimiters while excluding strings/comments.
- Verified all `NewAndHotSource` implementations provide `trendingAnime` and all `SearchSuggestions` constructors supply `animeGenres`.
- Re-ran a static extraction of banner ad tags from Dart source and confirmed every emitted tag is present in the existing `bannerPlacements` manifest. No new backend tag was introduced.
- Compared the target tree with Phase 27: changes are limited to the files listed above plus this Phase 28 report in the project root and `phases/`.

## 8. Build/test limitation

Flutter and Dart SDKs are not installed in the editing environment. Therefore `dart format`, `dart analyze`, `flutter test`, and the Android release build could not be executed here. Static checks passed, but this is not a claim that a Flutter build or runtime test has succeeded. Run the repository's normal CI (`flutter test` and `assembleProdRelease`) before publishing the APK.

## Anime identification note

The implementation intentionally follows the existing RAVEN23 project rule (TMDB TV Animation genre + Japanese original language). It may not classify non-Japanese animation or catalog entries that TMDB does not tag with both fields as Anime. Changing that policy would be a separate content-classification decision, not part of this browsing-surface phase.
