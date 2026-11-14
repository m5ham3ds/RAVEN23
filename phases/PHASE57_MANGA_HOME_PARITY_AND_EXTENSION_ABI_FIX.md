# PHASE57 — Manga Home Visual Parity & Mihon Extension ABI Normalization

**Date:** 2026-11-10  
**Base:** Owner-confirmed successful RAVEN23-PHASE56 build  
**Status:** Feature source prepared. Initial PHASE57 CI run 42857526541 failed in Flutter analysis before tests; PHASE57.1 repairs those analyzer errors and expands CI to the complete Flutter and Android unit-test suites. Release/device acceptance remains pending.

## 1. Device findings that define this phase

### 1.1 Mihon install failure for a supported 1.6 extension

The supplied Team X screenshot shows that the extension catalogue loads, the Install control is enabled, and the explicit install attempt reaches the Android loader. Installation fails with:

```text
Unsupported extensions-lib version 1.600000023841858 (supported: 1.4, 1.6)
```

The extension's manifest metadata stores `1.6` as an Android `float`. `Bundle.getFloat()` returns the nearest IEEE-754 Float value; widening that value to Double produces `1.600000023841858`. The old exact Double membership check therefore rejected the supported 1.6 ABI.

**Correction:** Normalize the supplied value only when it equals an already supported Double constant (`1.4`, `1.6`) or exactly equals that constant after the same Float-to-Double widening Android performs. Reject non-finite values and every other numeric representation; no approximate tolerance is used. The normalized ABI value, not the raw widened Float, is retained by `MihonLoadedExtension`.

No new ABI is introduced. Do not copy Zangetsu's broader range or infer compatibility from a nearby numeric version.

### 1.2 Manga/Manhwa pages must use the Home design, not a separate design

The user explicitly rejected the separate Manga catalogue presentation. Manga categories must use the same Home visual system as Movies, Series and Anime. Reuse the same RAVEN23 components and visual rules; only the selected catalogue content/category changes.

**Correction:** The Manga feed uses the shared Home components and layout primitives:

- `HomeHeaderDelegate` and the shared `HomeHeader`/filter-chip design.
- `HeroCarousel` and `HeroCard`, retaining Home dimensions, transitions, typography, controls and ambient-art tint treatment; when a primary shelf is empty, the hero falls back through all remaining non-empty catalogue shelves rather than disappearing while any category contains content. Top 10 likewise falls back to the first ten Popular titles when its dedicated shelf is empty. Action labels/handlers are Manga-specific only.
- `PosterRow` and `TopTenRow` for every catalogue shelf, retaining Home poster width, rank art, title headers, horizontal scrolling and reveal animations.
- `HomeSkeleton` for initial loading, plus the shared `HomeOptionalRow` spacing behaviour for the update notice.
- The same page background gradient/tint placement, using the exact poster/backdrop variant currently rendered by the shared Home hero, plus scroll/refresh physics, sliver row spacing and bottom safe-area spacing.

The old, separate primary-feed layout is not retained. The in-place Manga search results grid remains a search-only state; it does not replace the Home-style browsing feed.

## 2. Catalogue sections — preserve all of them

The following 18 MangaCatalogue shelves remain supported and are rendered whenever their data is non-empty:

1. Top 10
2. Recently Released
3. Trending
4. Popular
5. Top Rated
6. Upcoming
7. Completed
8. Action
9. Adventure
10. Comedy
11. Drama
12. Fantasy
13. Horror
14. Mystery
15. Romance
16. Sci-Fi
17. Supernatural
18. Slice of Life

The `All` feed also retains its Japanese Manga, Manhwa and Manhua regional rows. These rows are composed from the JP/KR/CN catalogues; the existing regional aggregation and duplicate removal are preserved. Manga, Manhwa and Manhua category filters continue to request their own region.

## 3. Security and scope boundaries

- Keep the exact repository `meta.signingKeyFingerprint` trust anchor and SHA-256 validation.
- Keep extension package identity validation and APK certificate verification before DEX loading.
- Keep explicit user confirmation before downloading/installing an extension.
- Keep APK size restrictions, app-private storage and the existing ABI allow-list (`1.4`, `1.6`).
- Do not enable ABI 1.5, 1.7 or any other version; do not use approximate version-family matching.
- Keep Mihon Protobuf repositories independent from the six video JSON repositories.
- Do not change Movies, Series, Anime, Live TV, BetterPlayer, player routing, video source engines, source priority lanes, subtitles or quality selection.
- Do not copy Zangetsu branding or redesign RAVEN23's Home components.

## 4. Focused source/test/CI changes

- `android/app/src/main/kotlin/com/m5ham3ds/raven23/mihon/MihonExtensionLoader.kt` — Float-safe normalization against the strict 1.4/1.6 allow-list.
- `android/app/src/test/kotlin/com/m5ham3ds/raven23/mihon/MihonExtensionLoaderAbiTest.kt` — accepts the exact widened `1.6f` representation and exact 1.4/1.6; rejects 1.6001, 1.5, 1.7, NaN and infinities.
- `lib/mobile/screens/manga_screen.dart` — same shared Home layout components for Manga/Manhwa/Manhua; no custom standalone main-feed visual system.
- `lib/mobile/widgets/home_optional_row.dart` — shared Home spacing primitive used by Home and Manga.
- `lib/mobile/widgets/home_header.dart`, `hero_card.dart`, `media_art.dart`, `media_rows.dart`, `poster_card.dart`, and `lib/catalog/media_item.dart` — shared Home widgets support direct AniList artwork and custom Manga actions while preserving their default video behaviour.
- `test/manga/phase56_manga_regression_test.dart` — added explicit coverage for uppercase colon-separated SHA-256 fingerprints while retaining exact trust-anchor checks.
- `test/manga/phase55_mihon_pb_index_test.dart` — retains Protobuf index parsing and malformed-input tests; duplicate sidecar fingerprint tests are consolidated into `phase56_manga_regression_test.dart`.
- `test/manga/phase57_manga_home_parity_test.dart` — verifies all 18 catalogue shelves survive combination.
- `test/manga/phase55_manga_catalogue_test.dart` — retains country mapping, title metadata and `isEmpty` contracts.
- `test/manga/phase55_mihon_pb_index_test.dart` — retains Protobuf index parsing and malformed-input tests; duplicate sidecar fingerprint assertions are consolidated into `phase56_manga_regression_test.dart`, which also covers raw-text JSON parsing.
- `tool/format_phase57_dart.sh` — formats only the 13 touched Dart files.
- `lib/mobile/screens/manga_screen.dart` — changed `_fade` to `late final` because the `AnimationController` uses the State as `vsync`; this matches the already accepted Home screen lifecycle pattern and removes the analyzer error.
- `test/home_screen_test.dart` — imports `HomeOptionalRow`, a public widget type matched by its Home row-description test.
- `.github/workflows/android-ci.yml` — full Flutter test discovery and all Android unit tests now gate APK assembly; test execution is sequenced after successful dependency resolution, formatting and analysis.

## 5. Complete test gate, ordering and removal policy

The uploaded run `42857526541` did **not** run the Phase57 tests. `flutter analyze` stopped first with two errors:

1. `lib/mobile/screens/manga_screen.dart:38` — `_fade` used `vsync: this` from a non-late field initializer. The existing Home state already uses the correct lazy `late final AnimationController` pattern; Manga now follows it.
2. `test/home_screen_test.dart:240` — the row-description pattern matched `HomeOptionalRow` without importing its defining library. The missing import is now explicit.

The formatter and dependency-resolution steps passed. Manga runtime tests, Kotlin tests, wrapper generation, APK packaging and APK auditing were all **skipped**, not failed and not passed. The diagnostic archive's file named `phase57-manga-runtime-test-log.zip` contains only formatter output; it is not evidence of a runtime test execution.

### Flutter suite

- Run `flutter analyze --no-fatal-infos` across the full project, including every test source.
- Only after analysis succeeds, run `flutter test --no-pub --reporter expanded --timeout 90s --concurrency=2` with no explicit test-file allow-list.
- This discovers every `test/**/*_test.dart` suite. The PHASE57 archive contains **259 Flutter test files**, including all earlier phase regressions and all five Manga suites. The number is counted again at runtime and logged; no hard-coded test selection is used.
- This restores accepted Phase52/53 tests and all other feature regression tests to the active gate. A future accepted phase must not silently remove them from the full suite.

### Android unit suite

- After the complete Flutter suite passes, generate the missing Gradle wrapper.
- Then run `./gradlew :app:testProdReleaseUnitTest --no-daemon` without `--tests` filters. This includes all **10** current Kotlin/Java Android unit-test source files, including Mihon ABI, downloads, playback, ads and TV tests.
- The discovered source-file count and complete Gradle output are retained as artifacts.

### Integration-only tests

- `test/integration/laravel_migration_e2e_test.dart` is part of the normal Flutter suite; its write/live-service cases use their explicit environment guard and are skipped when not configured.
- The root-level `integration/laravel_foundation_smoke_test.dart` is deliberately opt-in because it requires a live backend URL via `--dart-define=LARAVEL_SMOKE_URL=...`. It is not a deterministic offline unit test and must not be allowed to call a production backend by default.

### Strict sequence and APK gate

`pub get → PHASE57 formatter → project-wide analyze → all Flutter tests → Gradle wrapper → all Android unit tests → APK build → APK audit`.

If analysis fails, Flutter tests are explicitly marked skipped and the analyzer log remains in the build report. If any Flutter test fails, wrapper generation and Android tests are skipped. If any Android unit test fails, APK build and audit are skipped. The report and raw logs still upload with `if: always()` so a skipped test is never misreported as a pass.

### Test removal policy

No additional test file was deleted during PHASE57.1. The existing tests cover active contracts across repository CRUD, trust metadata, protobuf parsing, catalogues, playback, video providers, ads, downloads, TV, account/configuration and UI flows. Exact duplicate sidecar assertions were already consolidated in PHASE56; the two Phase57 analyzer faults were missing initialization/import issues, not redundant tests. Keep the complete suite until a test is proven obsolete by a code-level contract audit.

## 6. Acceptance gates

- [x] Exact device error reproduced and root cause identified.
- [x] Float representation normalized only to the existing 1.4/1.6 ABI constants.
- [x] Regression unit test added for the widened Float value and strict invalid boundaries including nearby unsupported decimals.
- [x] Manga uses Home's shared header, hero, poster rows, Top 10, skeleton, optional-row spacing and ambient tint primitives.
- [x] All 18 catalogue shelves and the three regional All rows are preserved in code and covered by the aggregation regression test.
- [x] Existing repository fingerprint, package identity, APK signer, explicit confirmation and APK restrictions remain in place.
- [x] PHASE57.1 restores the full project Flutter unit/widget test suite, including accepted Phase52/53 and unrelated active regressions, to the APK gate.
- [x] APK assembly is explicitly gated on successful dependency resolution, PHASE57 formatting, project-wide analysis, all Flutter tests, Gradle wrapper generation and all Android unit tests; a failed/skipped test cannot produce a candidate APK.
- [ ] PHASE57 Dart format and project-wide `flutter analyze` pass in GitHub Actions.
- [ ] All 259 current Flutter test files and all 10 Android unit-test source files pass in GitHub Actions.
- [ ] ARM64 Release build, APK archive audit and ABI audit pass.
- [ ] On-device installation of Team X / a trusted 1.6 extension completes fingerprint and certificate checks and exposes the source in Installed Manga Sources.
- [ ] On-device All, Japanese Manga, Manhwa and Manhua pages visually match Home's layout and retain all available sections.
- [ ] Confirm Movies, Series, Anime, Live TV and video playback remain unaffected.

**Execution limitation:** Flutter, Dart and Android build tools are not available in the archive-editing environment. The CI workflow is configured for the complete suites, but no local formatter, analyzer, Flutter test, Gradle test, APK build or device installation is claimed.
