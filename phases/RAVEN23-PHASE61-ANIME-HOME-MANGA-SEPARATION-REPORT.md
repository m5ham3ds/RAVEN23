# RAVEN23 — PHASE61: Anime/Home separation, Manga parity, and build repair

## 1. Purpose

PHASE61 addresses the PHASE60 pre-build analyzer failure and the reported content/UI regressions across Series, Anime, and Manga. The phase is a source-code and CI update; it is **not marked build-verified** until the updated GitHub Actions run completes.

## 2. PHASE60 analyzer failure repaired in source

The uploaded `flutter-analyze.log` showed two errors and two diagnostics in `lib/screens/common/source_repositories_screen.dart`:

- `_supportsRuntime` was called at the repository list and source-add dialog but had no state method.
- An unnecessary null assertion was used while resolving the selected priority lane.
- A `BuildContext` from an outer dialog was referenced after an asynchronous confirmation.

PHASE61 adds `_supportsRuntime(SourceManifest)` as a delegation to `UnifiedSourceService.supportsSource`, removes the unnecessary assertion through an explicit nullable-lane guard, and uses the appropriate nested dialog contexts with mounted checks after confirmation. The analyzer has **not** been rerun locally because this environment has no Flutter or Dart SDK.

## 3. Anime versus general Animation

Anime identity is deliberately strict for series: TMDB genre `16` (Animation) **and** original language `ja` are both required. Therefore:

- English/French/Spanish/Chinese animation series are not automatically classified as Anime.
- Japanese live-action drama is not Anime because it has no Animation genre.
- Japanese animation TV series can enter the dedicated Anime feed.
- Animated feature films remain in the Movies destination; the Anime destination remains an episodic TV-series feed.

This predicate is applied at feed creation, genre/service rows, random Hero discovery, My List, search/collection routes, and See All collection queries. The normal Series page and its category/collection pages filter Japanese Anime out. The Anime page uses the shared `HomeScreen`/Home feed architecture and receives Anime-specific shelves and categories rather than a reduced, separate four-row view.

Continue Watching and Up Next now retain the media identity. Local episode history is migrated to include `is_anime`; the identity is persisted in local/cloud maps. The legacy Laravel payload deliberately excludes this new property to preserve its existing API contract. Previously saved history whose Anime identity is unknown (`null`) stays in All and is not guessed into either Series or Anime until new playback metadata is recorded.

## 4. Manga/Manhwa/Manhua Home behavior

The Manga page remains a Manga data destination, but it uses the shared Home frame and `homeRows()` rendering path. On a first uncached load, it displays `HomeSkeleton` until the catalogue request completes; a previously cached non-empty catalogue remains visible during refresh/outage.

The All catalogue is assembled by fetching the three regional catalogues (Manga, Manhwa, and Manhua) and combining/deduplicating them. Row policy is:

- Three separate Top 10 rows: one each for Manga, Manhwa, and Manhua.
- Three separate Trending rows: one each for Manga, Manhwa, and Manhua.
- Other rows, including Action, Adventure, Comedy, Drama, Fantasy, Horror, Mystery, Romance, Sci-Fi, Supernatural, Slice of Life, Popular, Top Rated, and release shelves, use the combined regional catalogue.
- A region-specific tab uses only that region's catalogue.

All Manga PosterRow and TopTenRow shelves receive a See All callback and open a dedicated grid containing the exact items from that shelf.

## 5. Regression tests added/updated

The CI focused pre-build gate now includes eight Flutter test files:

1. `test/manga/manga_repository_manager_test.dart`
2. `test/manga/phase55_manga_catalogue_test.dart`
3. `test/manga/phase55_mihon_pb_index_test.dart`
4. `test/manga/phase56_manga_regression_test.dart`
5. `test/manga/phase57_manga_home_parity_test.dart`
6. `test/anime_media_classification_test.dart`
7. `test/home_catalog_test.dart`
8. `test/home_screen_test.dart`

Coverage includes strict Anime classification, no Anime leakage into Series through discovery/services/See All, the shared Anime Home layout, typed Continue Watching, Manga skeleton behavior, three regional Top 10 and Trending shelves, merged regional genre shelves, and See All actions on every Manga shelf. A serialization regression test confirms the Anime flag survives local/cloud persistence but is omitted from Laravel payloads.

The scoped Dart formatter now checks 37 changed Dart sources. The Android CI still gates the build on dependency resolution, formatting, `flutter analyze`, the eight Flutter test files, and the focused Mihon ABI test.

## 6. Verification status and limitations

Verified in this workspace:

- The exact PHASE60 analyzer diagnostics were traced to the source and the corresponding code paths were edited.
- All 37 formatter target paths exist; the formatter shell script passes `bash -n`.
- The GitHub Actions workflow YAML parses successfully.
- The source tree contains the new regression assertions and the DB migration for the `is_anime` column.

Not executed in this workspace:

- `dart format`, `flutter analyze`, `flutter test`, Gradle/Android ABI tests, and APK build.

No APK is included and PHASE61 must not be treated as a successful build until GitHub Actions reports the analyzer, all eight tests, Android ABI test, and APK build as successful. CI is configured to run those gates in order and preserve diagnostics if a later gate fails.
