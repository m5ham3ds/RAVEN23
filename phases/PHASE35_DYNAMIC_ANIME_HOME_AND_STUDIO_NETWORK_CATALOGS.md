# RAVEN23 — Phase 35: Dynamic Anime Home Feeds and Studio / Network Catalogs

## Scope and preserved rules

This phase is based only on the supplied `RAVEN23` project archive. The existing `phases` directory was reviewed before source changes, with particular attention to Phases 11, 17, 20, 27, 28, 31, 32 and 34.

The following rules remain authoritative:

- Anime identity continues to use the existing Phase 11 classifier: TV genre `16` (Animation) **and** original language `ja` (`TV.isLikelyAnime`).
- Anime remains `MediaKind.series`; no third media kind, alternate episode model, or new player route is introduced.
- Phase 28's Anime discovery, New & Hot, and genre-query rules remain in force.
- Phase 32's Search Anime, provider Anime tabs, and Top Rated Anime remain present.
- Phase 34 remains the source of truth for preserved Phase 32 files and player defaults. No older Phase 33 copies were restored over the current files.
- Existing player, subtitle, source-provider, watch-progress, ads, and theme implementations were not intentionally changed.
- The two supplied service-logo assets already existed in `assets/images/` and were preserved byte-for-byte.

## 1. Streaming services: studio and network catalogs

`AppStreamingService` now distinguishes a JustWatch watch-provider from a studio/network catalog. Watch-provider records retain their existing IDs and stable identifiers. Studio/network records use their own `catalogKey`; they do not borrow watch-provider IDs.

New catalog entries:

| Card | Movie production company | TV production company | TV network |
|---|---:|---:|---:|
| Nickelodeon | 2348 — Nickelodeon Movies | — | 13 — Nickelodeon |
| Warner Bros. | 17 — Warner Bros. Entertainment; 174 — Warner Bros. Pictures | 17 — Warner Bros. Entertainment; 1957 — Warner Bros. Television | — |

The discover requests use `with_companies` for production companies and `with_networks` for TV networks. When a brand has multiple applicable sources, results are merged, deduplicated, ranked by TMDB popularity, and capped to the existing row size. The Anime tab still adds the existing Japanese-animation filters and applies `TV.isLikelyAnime` on the client. Ordinary Series results exclude Anime.

The mobile service cards retain the existing three-tab flow (Movies, Series, Anime). The Android TV shortcut cards now correctly describe these two additions as studio/network catalogs rather than calling them streaming providers.

Assets used without recompression or replacement:

- `assets/images/nickelodeon.png`
- `assets/images/warner_bros.png`

## 2. Home: dynamic Anime rows

Added separate Home data and rows for:

- Trending Anime
- Popular Anime
- New Episodes Anime

The existing New Episodes row is now labelled **New episodes series** in the Home feed; movie releases retain their existing Movies label. The previously existing Top Rated Anime row is preserved.

Anime discovery is data-driven and uses TMDB results rather than a manually curated title list:

- Popular Anime uses `/discover/tv`, `sort_by=popularity.desc`, `with_genres=16`, and `with_original_language=ja`.
- Trending Anime combines TMDB's weekly TV trending feed (retaining only titles that satisfy the Anime identity rule) with the popularity-ranked Anime discover feed. Results are deduplicated and ranked in source order, with Anime discover results filling the remaining row positions. The Home and New & Hot feeds share this implementation.
- New Episodes Anime uses `/discover/tv` with `air_date.gte` and `air_date.lte` spanning the preceding seven days, plus the existing Animation and Japanese-language filters. `air_date` is intentional: it checks episode air dates, so currently running older anime can qualify when a new episode airs.
- Adult filtering is respected for discover requests and also applied to results taken from the global trending endpoint.

The regular Series rows and their See all collections now exclude Anime, preventing the same title from appearing in both the Series and Anime feeds. Anime See all collections apply the opposite filter. The composite Trending Anime See all page uses the same two-source loader as its Home row.

## 3. Android TV parity

Android TV Home now includes Trending Anime, New episodes series, New episodes anime, and Popular anime. Its regular Series feeds are filtered using the same Phase 11 classifier; Anime rows use TV media items and existing detail / season / episode navigation. The Trending Anime See all action uses the composite source, while Anime Popular and New Episodes collections retain their dedicated query filters.

The TV Movies / Series catalog separates ordinary Series from Anime as well, including its See all collections and provider shelves.

## 4. Localization

Added and generated the new Home and catalog labels in English, Arabic, Spanish, and Hindi. The TV studio/network shortcut description has a dedicated localized string. Existing `new_episodes` translations remain for backward compatibility with unrelated UI surfaces.

Updated:

- `assets/translations/en.json`
- `assets/translations/ar.json`
- `assets/translations/es.json`
- `assets/translations/hi.json`
- `lib/translations/codegen_loader.g.dart`
- `lib/translations/locale_keys.g.dart`

## 5. Tests updated

- `test/anime_home_and_streaming_test.dart`: Anime discovery endpoints, recent-episode date bounds, studio/company/network identifiers, brand collections, and composite Trending Anime URL semantics.
- `test/home_feed_controller_test.dart`: separate Trending, Popular, and New Episodes Anime rows with regular Series filtering.
- `test/home_screen_test.dart`: expected mobile Home Anime rows.
- `test/new_and_hot_test.dart`: composite Trending Anime query behavior and Japanese-animation classification.

## 6. Verification and limitations

Static checks completed:

- All four translation JSON files parse and contain no duplicate keys.
- All newly introduced translation keys exist once in each locale JSON and once per locale in the generated loader.
- `pubspec.yaml` parses and already declares `assets/images/`.
- The Warner Bros. and Nickelodeon PNG files match the two user-supplied images byte-for-byte.
- No player or source-provider implementation files were changed as part of this phase.

The supplied environment does not contain the Flutter or Dart SDK. Therefore `dart format`, `flutter analyze`, `flutter test`, and an APK build could not be run here. The updated tests are included in the project for execution in the user's Flutter build environment; the static checks above are not represented as a substitute for a Flutter build.
