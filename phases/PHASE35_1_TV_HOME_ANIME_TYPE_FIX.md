# RAVEN23 — Phase 35.1: Android TV Anime Feed Type Correction

## Build failure addressed

The Phase 35 Android TV home controller passed `CatalogController.loadTrendingAnimePage()` results through `TvMediaItem.fromSeries`. That conversion was incorrect: `loadTrendingAnimePage()` already returns `List<MediaItem>`, while `TvMediaItem` is a type alias for `MediaItem` and `fromSeries` accepts a raw `TV` model. The invalid callback also caused Dart to infer a dynamic list, producing a second error when assigning the value to `TvHomeData.trendingAnime`.

## Source correction

- Removed the redundant and type-incompatible `map(TvMediaItem.fromSeries)` conversion.
- Declared `trendingAnimeFuture` explicitly as `Future<List<TvMediaItem>>`.
- Declared the awaited `trendingAnime` value as `List<TvMediaItem>` so the result passed to `TvHomeData` remains statically typed.
- Left the catalog loader, Anime classification, query ordering, ranking, adult filtering, and TV navigation untouched.

## Verification

- Confirmed the loader signature is `Future<List<MediaItem>>` and the TV alias resolves to the same catalog model.
- Checked all other `fromSeries` mappings: the remaining TV mappings receive raw `TV` objects and are valid.
- Confirmed the project archive is structurally valid after the patch.
- Flutter/Dart SDK is not available in this environment, so `flutter analyze`, `flutter test`, and `assembleProdRelease` were not run here. The GitHub Actions Release build remains the authoritative compile verification.
