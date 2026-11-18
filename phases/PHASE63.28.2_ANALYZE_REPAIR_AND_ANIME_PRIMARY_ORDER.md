# PHASE63.28.2 — Analyze repair and exact Anime PRIMARY LIST (2026-11-17)

## Build report diagnosis

The owner-supplied GitHub Actions report for run `44017610188` (commit `6870b51c94a4f82c0ab3cc1f01b6fb3cb7fc4459`) shows that Dart formatting passed but `flutter analyze --no-fatal-infos` failed before Flutter tests, Android unit tests, wrapper generation, APK build and APK audit. The three blocking diagnostics were:

- `movie_video_loader.dart`: `MovieStreamMetadata` does not define `seasonNumber` or `episodeNumber`; the two resulting local variables were not used. The invalid reads and unused locals have been removed from the movie-only download handler.
- `stream_host_priority_manager.dart`: `$candidate_` was parsed as an interpolation identifier. The prefix check now uses `${candidate}_` so the underscore remains a literal separator.

The same report recorded existing non-fatal info notices and warnings in `player.dart`. To keep the analyzer gate clean, the unused `stream_size_estimator.dart` import, unused size-token/cache fields and writes, and unused `_downloadResolutionHeight` helper were removed. No active player or download behavior reads those dead members.

## Anime PRIMARY LIST requested by the owner

The Anime first-run primary order is now expressed as stable source identities, with the built-in VixSrc entry inserted at position 6:

1. Anikoto — OpenStream `anikoto`
2. Re:Anime — OpenStream `reanime`
3. AnimeGG — OpenStream `animegg`
4. Jett — OpenStream `jett`
5. yastream — OpenStream `yastream`
6. VixSrc — RAVEN23 built-in direct provider (`local::direct-vixsrc`)
7. VidFast — Spyhell experiment repository `vidfast`
8. Sage — OpenStream `sage`
9. Phoenix — OpenStream `phoenix`
10. CineStream — Serenity sources `serenity-cinestream`
11. VidZee — Spyhell experiment repository `vidzee`
12. VegaMovies — Spyou Zangetsu providers `vegamovies`
13. Sova — OpenStream `sova`
14. VidSpark — Spyhell experiment repository `vidspark`

VixSrc is not a repository extension. The source-priority editor therefore represents it with a synthetic built-in manifest and persists its stable marker in the same editable Anime primary lane. The movie and series primary defaults and global stream-host order are unchanged. In the actual playback sequence, ProviderLoader inserts the native VixSrc provider at the number of installed/runnable Anime primary entries before that marker; missing or unsupported sources do not create phantom positions. If the user removes VixSrc from the Anime primary lane, it is retained at the end of the Anime provider list rather than silently promoted.

Existing users are migrated only when their saved Anime primary list exactly matches the untouched previous default order. A manually reordered/custom list is preserved. Newly selected sources are installed before being inserted; a disabled or failed-to-install source is omitted from the effective primary list. Tests cover exact stable-key order, the built-in marker position, missing installed predecessors, legacy mapping and the underscore host-name prefix.

## CI inventory

- Formatter scope: 165 unique Dart targets (was 162).
- Focused Flutter gate: 29 unique test files (was 28); `source_priority_policy_test.dart` now runs in CI to lock the requested Anime order and VixSrc insertion behavior.
- Android Mihon ABI and Media3/download contract tests remain unchanged.

## Validation boundary

The editing environment does not provide Dart, Flutter, Gradle or Android SDK executables. This phase has not been locally formatted/analyzed/tested and no APK is claimed. Static workflow/list/path checks and ZIP integrity checks are run when packaging. A fresh GitHub Actions run must pass formatter, Analyze, all 29 focused Flutter tests, the Android Mihon/Media3 tests and ARM64 APK audit. No live source playback was tested; the requested priority is a user preference, not a claim that each server works. Firebase/backend work remains out of scope.
