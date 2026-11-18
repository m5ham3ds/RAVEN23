# RAVEN23 PHASE61.2 — Focused Test Failure Corrections

**Base:** RAVEN23 PHASE61.1
**Failed CI run:** `43105318844` (attempt 1)
**Commit under test:** `0e4865ee65520a92922dc33d016347db8b16fc1a`
**Toolchain in CI:** Flutter 3.35.7 / Dart 3.9.2, Java 17, Gradle 8.14

## CI diagnosis

The supplied run completed dependency resolution, scoped formatting and `flutter analyze` successfully. The analyzer reported `No issues found!`. The first blocking step was the eight-file focused Flutter test gate. It finished with 67 passing tests and two failing tests; no Android wrapper, Mihon ABI unit test or APK build was reached.

### Failure 1 — `test/home_catalog_test.dart`

The test expected `MediaItem.id` to be the episode ID (`71101` / `70102`). The model intentionally exposes the parent series ID as `MediaItem.id` so navigation, series-level identity and removal operate on the series. The episode-specific ID remains on `MediaItem.recentEpisode.id`, and the stable row identity is retained separately. Changing production `MediaItem.id` to the episode ID would break series navigation and the series-level removal contract.

**Correction:** the test now asserts the parent series IDs (`71` and `70`) on `MediaItem.id` and separately asserts the episode IDs (`71101` and `70102`) on `recentEpisode.id`. This strengthens the test to validate both identities rather than changing valid production behavior.

### Failure 2 — `test/home_screen_test.dart`

The `_rows` test helper invoked `homeRows()` without the optional `onMangaSeeAll` callback, making the row builder correctly omit See All actions. The test then expected every Manga `TopTenRow` to have a non-null callback. The production `MangaScreen` already provides `onMangaSeeAll` and opens `_MangaCollectionScreen` from that callback.

**Correction:** the `_rows` test helper now supplies a harmless callback, allowing the test to verify the actual See All wiring contract instead of constructing a test-only configuration where See All is disabled.

### Formatter patch

Applied the exact `dart-format.patch` captured by the supplied CI run to `test/home_screen_test.dart` before making the two test corrections.

## Files changed

- `test/home_catalog_test.dart` — assert parent-series identity and retained episode identity separately.
- `test/home_screen_test.dart` — apply CI formatter output and supply the Manga See All callback in the Home row test helper.
- `phases/PHASE61.2_TEST_FAILURE_FIX_2026-11-11.md` — this diagnostic and repair record.
- `phases/README_MASTER_IMPLEMENTATION.md` — append the PHASE61.2 record.
- `phases/README_CHANGED_FILES.txt` — append the PHASE61.2 change summary.

No production feed logic, Anime classification, Manga catalogue aggregation, Home rows, Continue Watching removal logic, source management, Gradle configuration, dependencies, or Android ABI settings were altered.

## Verification status

| Check | Result |
|---|---|
| Supplied CI dependency resolution | Passed |
| Supplied CI scoped Dart formatting | Passed |
| Supplied CI Flutter analyze | Passed — no issues |
| Supplied CI focused tests | 67 passed, 2 failed |
| Both failure causes mapped to source/test setup | Completed |
| Corrections applied to source | Completed |
| Patch application / archive integrity | To be checked during packaging |
| Flutter analyze after PHASE61.2 changes | Not run in this packaging environment |
| Eight focused Flutter test files after PHASE61.2 changes | Not run in this packaging environment |
| Mihon Android unit test | Not run; blocked by previous test failures in supplied run |
| Release ARM64 APK | Not built; blocked by previous test failures in supplied run |

The packaging environment does not contain Flutter/Dart, so PHASE61.2 is a targeted test-source correction, not a claimed successful CI build. Re-run the same workflow and require all eight focused test files, Mihon ABI tests, Release APK build and ABI audit to pass before accepting the phase.

## Non-blocking test log noise

The test run emits many Easy Localization “key not found” warnings because the row-builder/widget test harness uses a plain `MaterialApp` rather than the production EasyLocalization wrapper. These warnings did not cause the two test failures, did not fail `flutter analyze`, and were not suppressed or “fixed” by changing translation assets in this patch. A separate test-harness localization cleanup can be done without changing the app's translations.
