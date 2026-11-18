# RAVEN23 — PHASE63.11: Home and Manga loading/cache audit

**Date:** 2026-11-14  
**Baseline:** `RAVEN23_PHASE63.10_PAGED_CATALOG_TEST_REPAIR.zip`  
**Purpose:** consolidate and verify the Home / Movies / Series / Anime / Manga performance, cache and offline work already present in the workspace. This audit intentionally avoids reimplementing features that were already completed.

## 1. Result of comparing the workspace with PHASE63.10

The working directory `RAVEN23/` was compared file-by-file with the PHASE63.10 archive using SHA-256 hashes after stripping the archive's top-level `RAVEN23/` directory prefix.

- Baseline files: **1,683**
- Current files before this audit record: **1,685**
- Existing changed files: **24**
- Existing new files: **2**
- Files missing from the workspace: **0**

The 24 changed files and two added files listed below were already present before this audit. They were inspected and consolidated; their feature implementations were not recreated.

### Existing modified files

1. `.github/workflows/android-ci.yml`
2. `assets/translations/ar.json`
3. `assets/translations/en.json`
4. `assets/translations/es.json`
5. `assets/translations/hi.json`
6. `lib/catalog/catalog_controller.dart`
7. `lib/catalog/home_feed_controller.dart`
8. `lib/core/cache/cache_interceptor.dart`
9. `lib/core/cache/http_cache.dart`
10. `lib/core/network/interceptors/single_flight_interceptor.dart`
11. `lib/data/repositories/tmdb_repository.dart`
12. `lib/data/sources/tmdb_api.dart`
13. `lib/functions/network.dart`
14. `lib/manga/anilist/anilist_manga_service.dart`
15. `lib/mobile/screens/home_screen.dart`
16. `lib/mobile/screens/manga_screen.dart`
17. `lib/screens/common/settings.dart`
18. `lib/services/tmdb_connectivity.dart`
19. `lib/translations/codegen_loader.g.dart`
20. `lib/translations/locale_keys.g.dart`
21. `lib/tv/screens/tv_settings_screen.dart`
22. `test/data/tmdb_network_test.dart`
23. `test/home_screen_test.dart`
24. `tool/format_phase57_dart.sh`

### Existing added files

- `lib/manga/anilist/anilist_catalogue_cache.dart`
- `test/manga/anilist_catalogue_cache_test.dart`

No baseline file had been removed.

## 2. Verified behavior already implemented

### Home, Movies, Series and Anime (mobile)

These four destinations share `HomeScreen` and the same `HomeFeedController`; their media filters vary, but the core loading/cache policy is shared. Fixes in this controller therefore apply to all four rather than being duplicated page by page.

The current implementation already:

- Publishes primary catalogue rows progressively. Under `All`, Movies can be published before a slower Series request completes.
- Loads secondary shelves in small batches (maximum three concurrent optional loaders), instead of launching all enrichment requests at once.
- Uses `retryLimit: 0` and an eight-second per-request timeout for the main catalogue controller, so a cold offline open does not wait through repeated automatic retries.
- Checks connectivity before optional enrichment. If the device is offline, or primary loading failed and there is no usable base feed, it skips secondary shelves and returns the core result promptly.
- Keeps partial results if one media type succeeds and another fails.
- Distinguishes a successful empty catalogue from a network failure: a successful empty response can show the empty-result state, while an offline/error result with no usable cached data can show Retry.
- Supports explicit refresh/retry paths that bypass fresh cache entries and request updated data.

### TMDB persistent cache

The app configures a shared HTTP response cache before `runApp` and uses SQLite persistence when that store opens successfully. It falls back to an in-memory cache if persistent storage cannot be initialized.

The existing TMDB cache policy includes:

| Endpoint class | Fresh period | Maximum stale retention |
|---|---:|---:|
| Main trending/discover/popular/top-rated/upcoming/now-playing/on-the-air catalogue lists | 15 minutes | 7 days |
| Search | 5 minutes | 1 day |
| Genre/configuration | 7 days | 30 days |
| Other TMDB responses | 1 day | 30 days |

Expired-but-retained responses can be returned immediately while a background revalidation request runs (`stale-while-revalidate`). Manual refresh bypasses fresh-cache reads; if the network refresh fails, an allowed retained response can still be used as fallback. Cache generations prevent requests that began before `Clear Cache` from repopulating the store after it has been cleared.

### Manga / Manhwa / Manhua (AniList)

Manga uses its own `AniListMangaService`; the new durable `AniListCatalogueCache` is already present and stores separate catalogue entries by content kind.

- Fresh window: **15 minutes**.
- Stale/offline retention: **7 days**.
- The cache is persistent through SharedPreferences.
- Stale data can be returned immediately while refresh proceeds in the background.
- A manual refresh bypasses a fresh entry and can fall back to retained data if AniList is unreachable.
- The cache has generation checks to prevent an in-flight request from repopulating data after clearing.
- Catalogue GraphQL fields were reduced; descriptions/synonyms/credits/relations remain in the detail query rather than every home-list item.
- Shelf page sizes were reduced from 24 to 12 (Top 10 remains 10).
- In the `All` view, Manga/Manhwa/Manhua regional requests run concurrently, and each region is published as it completes. A slower region does not hold a completed region behind a full-page skeleton.
- Switching back to a content-kind tab re-enters the service cache policy rather than trusting only an in-memory screen map.

### Clear Cache

The mobile and TV settings actions already clear the shared HTTP cache, AniList catalogue cache, Flutter image cache (including live images), `DefaultCacheManager`, and temporary/image cache files.

## 3. Existing tests and CI coverage

The focused GitHub Actions gate currently lists **17 Flutter test files**. The formatter script has **72 unique Dart targets**. The Home and network test files already include coverage for progressive primary rows, Movies before delayed Series, offline short-circuiting of optional requests, partial failures, successful empty results, cold offline behavior, explicit refresh, stale TMDB fallback and persistent SQLite cache restart. The new AniList cache test file contains seven focused cases for persistence, freshness, stale offline fallback, service reuse, forced refresh, clear-generation protection and clearing entries.

The current workflow's diagnostic summary contained a stale formatter count of 73 even though the script has 72 unique targets. PHASE63.11 corrects that reporting text to 72; it does not alter the formatter target list or application behavior.

## 4. Remaining gaps identified by this audit

These are gaps to track, not features claimed as complete:

1. **Manga `All` query weight:** the current AniList home query still requests 18 shelves in each of the three regional requests. With Top 10 at 10 and the other 17 shelves at 12 each, that is up to 214 candidate media entries per region (up to 642 across three regions before duplicate overlap). The response is smaller than before, but genre/category shelves are not yet split into deferred, on-demand queries.
2. **Live update after background revalidation:** background stale-cache refresh updates persistent storage, but the already-open Home/Manga screen does not currently subscribe to a cache update event to replace its visible model immediately. The new value is picked up on a later page entry or explicit refresh.
3. **In-memory page models after Clear Cache:** durable/network/image caches are cleared, but mounted/offstage page models can still hold already-rendered feed/catalogue objects. They may continue showing old data until that page is refreshed or recreated.
4. **Android TV home loading is a separate pipeline:** `TvHomeScreen` uses a `FutureBuilder<TvHomeData>` and `TvHomeController.load()` starts multiple catalogue requests and waits for grouped futures. Its local `safe()` helper converts request errors to empty lists. It shares the application network cache, but it does not use the mobile `HomeFeedController` progressive publication and does not yet have equivalent staged/offline tests. Therefore the mobile audit should not be described as proof that Android TV has identical loading/error behavior.
5. **Cold offline with no cache:** mobile Home uses short catalogue timeouts and then reaches its error/retry state if no usable base data exists. Manga's first uncached regional AniList requests use an eight-second timeout; in `All`, the three regions may fail independently. A persistent-cache startup fallback to memory-only mode is possible if SQLite initialization fails.

## 5. Changes made specifically during PHASE63.11

No Home, Manga, TMDB, AniList, cache, source engine, or UI behavior was rewritten in this audit. Only project housekeeping was applied:

- Corrected the CI-generated diagnostic text from **73** formatter targets to the actual **72** unique targets.
- Added this audit record.
- Updated the master phase index and changed-files index to point to the current audit.

## 6. Validation limits and acceptance gate

Static checks completed for this package:

- GitHub Actions YAML parses successfully.
- All 72 formatter targets exist and are unique.
- All 17 focused Flutter test paths exist and are non-empty.
- All 12 shell scripts pass `bash -n`.
- Arabic, English, Spanish and Hindi translation JSON files parse; each has 2,345 keys and the four key sets match exactly.
- Project archive integrity is checked after packaging.

**Not executed in this environment:** `dart format`, `flutter analyze`, `flutter test`, Android Mihon unit tests, Gradle tasks or APK build. Flutter, Dart and Gradle are not installed in this environment. No successful build is claimed by this audit. Run GitHub Actions on the packaged tree before accepting the changes; separately validate the Android TV cold-offline and cached startup behavior on a TV/emulator.

---

**Conclusion:** The majority of the requested mobile Home/Movies/Series/Anime/Manga performance and cache work was already implemented in the working directory. PHASE63.11 records and verifies that existing implementation rather than redoing it, identifies the remaining gaps, and makes only a CI report-count correction plus documentation updates.
