# RAVEN23 — Phase 34: Preserve Phase 32 Anime Features + Player Subtitle Defaults 12

## Scope and source of truth

This phase is based on the complete `RAVEN23-PHASE32-ANIME-HOME-SERVICES-SEARCH.zip` project and the user's supplied Phase 32 report. Phase 32 is the source of truth for the anime features. Phase 33's theme and player-subtitle changes were selectively integrated; Phase 33's older copies of anime-related files and translations were intentionally not used.

## 1. Restored and preserved Phase 32 anime implementation

The following Phase 32 functionality remains present and unchanged:

- Home `Top rated anime` as a separate `HomeList.topRatedAnime` feed.
- Anime results from TMDB TV discovery with `with_genres=16`, `with_original_language=ja`, popularity/vote requirements and the user's adult-content setting.
- Anime tab in every streaming-service catalog, using the selected provider and the existing TV ad placement.
- Search filter order: All, Movies, Series, Anime, People.
- Anime remains `MediaKind.series` for details, seasons, episodes and playback.
- `top_rated_anime` translation keys and generated localization entries.
- Phase 32 anime tests, including `test/anime_home_and_streaming_test.dart`.

The following Phase 32 files were retained from Phase 32 and were not replaced by Phase 33 copies:

- `lib/api/endpoints.dart`
- `lib/catalog/catalog_controller.dart`
- `lib/catalog/home_feed_controller.dart`
- `lib/catalog/media_search.dart`
- `lib/mobile/screens/home_screen.dart`
- `lib/mobile/screens/search_screen.dart`
- `assets/translations/{ar,en,es,hi}.json`
- `lib/translations/codegen_loader.g.dart`
- `lib/translations/locale_keys.g.dart`
- anime-related Phase 32 tests.

## 2. Default theme color

- `#FF0000` remains the first/default Custom Theme Color swatch (`index = -1`).
- The existing orange `#F97316` remains a separate selectable palette entry.
- Base Dark, Light and Lights Out theme builders now apply the default red swatch even though its stable preference index is `-1`.
- Seasonal theme priority was not changed. Active seasonal themes continue to override the base theme as before.
- Material 3 Dynamic Color behavior was not changed.

## 3. Player Settings defaults

The requested clean-install defaults are now:

| Setting | Default |
|---|---|
| Text size | **12** |
| Text color | White `#FFFFFFFF` |
| Background color | Fully transparent `#00000000` |
| Text weight | Bold (`FigtreeSB`) |
| Subtitle language | Arabic (`ar`) |
| Fetch all subtitles for a specific language | Off |

These defaults are applied consistently through SettingsPreferences, SettingsProvider, Player Settings preview, TV Settings, movie/episode playback, offline playback and live playback.

A one-time pre-release initializer now uses version **2**. This deliberately updates test devices that previously ran Phase 33's version-1 initializer (which set text size 10) to the new size 12. After version 2 is recorded, later launches do not overwrite user changes.

## 4. Theme correction

The `AppColor.defaultPrimaryColor` constant is used to identify the default red swatch. The base theme builders no longer fall through to the legacy orange primary when the default swatch has index `-1`.

## 5. Important merge correction

Phase 33 had been produced from a source tree that did not include Phase 32's anime implementation. Its copies of the Home, Search, catalog controller, endpoint and translation files removed the Phase 32 anime sections. This phase does not copy those files from Phase 33; it starts with Phase 32 and selectively merges only the intended theme and player-settings implementation.

The Phase 32-corrected imports in `lib/main.dart` are retained. The new one-time player-default initializer is added without reverting those imports.

## 6. Files changed

- `lib/models/app_colors.dart`
- `lib/constants/theme_data.dart`
- `lib/functions/subtitle_style.dart`
- `lib/functions/player_subtitle_configuration.dart`
- `lib/preferences/setting_preferences.dart`
- `lib/provider/settings_provider.dart`
- `lib/main.dart`
- `lib/screens/common/player_settings.dart`
- `lib/screens/common/live_player.dart`
- `lib/tv/screens/tv_settings_screen.dart`
- `test/app_colors_test.dart`
- `test/player_subtitle_configuration_test.dart`
- `test/settings_subtitle_language_migration_test.dart`

No Phase 32 anime catalog, endpoint, search, Home, streaming-service or translation file was replaced.

## 7. Validation performed

- Verified Phase 32 anime enum, API query parameters, streaming catalog `animeOnly` path, Search Anime filter and translation key presence.
- Verified orange `#F97316` remains in the palette alongside default red `#FF0000`.
- Verified default subtitle font size is 12 in style constants, SettingsProvider and tests.
- Verified the one-time preference marker is version 2 and writes the 12px default exactly once.
- Verified Phase 32 imports in `lib/main.dart` remain correct and the initializer is called before subtitle preference hydration.
- Checked JSON, XML, YAML parsing, Dart delimiter balance and archive structure.

Flutter/Dart SDK was unavailable in the editing environment. `flutter analyze`, `flutter test` and APK compilation were not run; GitHub Actions must perform those checks before release.
