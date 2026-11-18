# RAVEN23 — PHASE63.13: Dio request-option and CatalogController override repair

**Date:** 2026-11-14  
**Input CI run:** [43611499257](https://github.com/m5ham3ds/RAVEN23/actions/runs/43611499257)  
**Commit reported by CI:** `8f8efac7edac7dfa4dda8cf7ce46464484ac9c67`  
**Baseline:** PHASE63.12 formatter/syntax-repair project.

## 1. Actual CI outcome

The run completed dependency resolution and the scoped formatter check (72 Dart files, zero changes), then stopped at `flutter analyze --no-fatal-infos`.

The focused Flutter tests, Gradle wrapper generation, Android Mihon ABI unit test, Release ARM64 APK build and APK audit were skipped because Analyze failed. No APK was produced. The formatter patch was empty; there were no formatter edits to apply.

## 2. Blocking analyzer errors

The analyzer reported exactly three errors:

1. `lib/data/sources/tmdb_api.dart:23` — `Options` did not accept the named parameter `connectTimeout` under the project's locked Dio `5.9.0` API.
2. `lib/manga/anilist/anilist_manga_service.dart:592` — the same unsupported `Options.connectTimeout` argument.
3. `test/new_and_hot_test.dart:60` — `_FakeCatalogController.loadTrendingAnimePage` did not match the current `CatalogController` override signature because the production method also exposes optional `bool strict = false`.

The remaining 37 analyzer findings were informational lints. The workflow uses `--no-fatal-infos`, so they were not the blocking cause.

## 3. Repairs applied

- Removed the unsupported per-request `connectTimeout` arguments from the two `Options` objects.
- Kept the per-request `receiveTimeout` and `sendTimeout` values unchanged.
- Kept connection timeouts at the existing Dio-client `BaseOptions` layer: the shared TMDB public client is configured by `DioFactory`/`AppEnvironment`, and the private AniList client retains its existing 12-second connection timeout. No global timeout values were weakened or removed.
- Updated `_FakeCatalogController.loadTrendingAnimePage` to include the matching optional `bool strict = false` named parameter. The fake's existing test behavior is unchanged.
- Did not change cache policy, stale fallback, retry policy, catalog pagination, Manga queries, or production Home/Movies/Series/Anime behavior.

## 4. Formatter and dependency evidence

- The workflow's scoped formatter step passed for all 72 targets; the captured formatter patch contains zero bytes and its summary says no Dart formatter changes were produced.
- Dependency resolution completed successfully. The CI log reports a lockfile update during `flutter pub get`; no dependency constraint or lockfile change was made as part of this repair.
- The original analyzer log, environment snapshot, dependency log, formatter log/summary, empty patch and report are preserved under `docs/build-reports/2026-11-14-phase63.12-run-43611499257/`.

## 5. Validation boundary and next gate

The packaging environment does not have Flutter or Dart installed. Therefore the three source edits were reviewed against the exact compiler diagnostics and project method signatures, but `flutter analyze`, the 17 focused Flutter tests, the Android Mihon ABI test and APK build were **not rerun locally**.

Run GitHub Actions again. Acceptance requires Analyze to pass, all 17 focused Flutter test files to pass, the Mihon ABI unit test to pass, and the Release `arm64-v8a` APK to be produced and audited. Do not mark PHASE63.13 build-accepted until those stages complete.
