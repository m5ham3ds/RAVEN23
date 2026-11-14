# RAVEN23 PHASE59.1 — Flutter Analyze Failure Fix

**Base:** `RAVEN23_PHASE59_UNIFIED_MANGA_HOME.zip` (PHASE59)
**Source diagnostics:** GitHub Actions run `43038549875`, commit `a38b570781e5e6a38edca47f1b07c6a17accfd92`
**Failure stage:** `Flutter analyze` (the APK build was never reached)

## Root cause and changes

1. `lib/mobile/widgets/home_page_frame.dart`
   - Added the explicit `package:flutter/foundation.dart` import for `ValueListenable`.
   - This resolves the reported `Undefined class 'ValueListenable'` analyzer error.

2. `test/home_screen_test.dart`
   - Made the Manga-isolation assertion null-safe by evaluating
     `(item.stableKey ?? '').startsWith('manga:')`.
   - This resolves the reported nullable receiver error without weakening the assertion: a missing stable key still cannot match a Manga key.

3. `lib/catalog/home_rows.dart`
   - Removed `@visibleForTesting` from `homeRows()`. The function is used by the production Home and Manga screens, so restricting it to tests was incorrect and created three `invalid_use_of_visible_for_testing_member` warnings.
   - Removed the now-unused `foundation.dart` import that existed only for that annotation.
   - Removed unused `genres.dart` and `mobile/my_list.dart` imports.
   - Removed the redundant `intl` import; the analyzer had confirmed that the required `DateFormat` symbols are already available through `easy_localization`.

## Exact CI diagnostics addressed

The failed analyzer log reported nine diagnostics:

- 2 informational unnecessary-import diagnostics.
- 5 warnings (2 unused imports and 3 invalid uses of a test-only member).
- 2 errors (`ValueListenable` undefined and nullable `startsWith`).

The source changes above address each reported diagnostic. No unrelated product behavior or dependency versions were intentionally changed by this repair.

## Scope preserved

- The shared `HomePageFrame` remains the shared visual/scroll/refresh frame.
- `homeRows()` remains the shared row builder for Movies, Series, Anime, and Manga.
- Manga catalogue data remains in the `HomeFilter.manga` branch; the normal Home feed remains separate.
- The existing AniList/Mihon loading, Manga filters, and the 18 catalogue shelves were not rewritten as part of this repair.

## Validation status

- Source inspection: completed for all nine diagnostics in the supplied analyzer log.
- ZIP integrity and required focused test-file presence: checked during packaging.
- `flutter analyze`, focused Flutter tests, Android unit test, and APK build: **not run in this environment** because Flutter/Dart SDK is not installed here.
- Therefore this package is an analyzer-fix candidate, **not a confirmed successful APK build**. CI must run the previously skipped gates after upload.

## Required CI sequence

1. `flutter analyze --no-fatal-infos`
2. The five focused Manga/Mihon Flutter test files configured in the workflow.
3. `:app:testProdReleaseUnitTest --tests com.m5ham3ds.raven23.mihon.MihonExtensionLoaderAbiTest`
4. The existing ARM64-only production APK build and APK ABI audit.

Do not mark PHASE59.1 stable until all required steps pass.
