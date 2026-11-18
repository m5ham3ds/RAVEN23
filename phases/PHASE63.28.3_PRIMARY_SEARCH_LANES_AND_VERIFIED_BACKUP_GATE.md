# PHASE63.28.3 — Primary Search Lanes and Verified Backup Promotion (2026-11-17)

## Build diagnosis

The owner-supplied GitHub Actions report for run `44070913382` (commit `ff0a10c11293cf4237fcc487dce632ea14d6f364`) shows that dependency resolution and the scoped formatter step passed, then `flutter analyze --no-fatal-infos` stopped on one warning: the local variable `sizeTokens` was unused in `lib/screens/common/player.dart`. The report also contains 43 non-fatal info notices; no Dart errors were recorded. The run did not reach focused Flutter tests, Android Mihon/Media3 tests, Gradle wrapper generation, APK build or APK audit.

The six-file `dart-format.patch` supplied with the run was applied to the existing PHASE63.28.2 working tree. The unused local in `player.dart` was removed. No claim is made that the formatter or analyzer was re-run locally; this container does not have Dart or Flutter.

## Owner clarification: PRIMARY means the first search tier

The PRIMARY lane is the first group the unified source search tries. The user's requested first-search order is stored independently for Movies/Series and Anime. VixSrc is the built-in native provider and is represented by a stable synthetic marker in the same editable lane. Repository source names/IDs are not evidence that they work; these orders express search preference only.

### Movies and Series — shared PRIMARY LIST

| Slot | Source | Stable source identity |
|---:|---|---|
| 1 | VixSrc | `local::direct-vixsrc` |
| 2 | Jett | OpenStream `jett` |
| 3 | yastream | OpenStream `yastream` |
| 4 | VidFast | Spyhell Experiment `vidfast` |
| 5 | VidSpark | Spyhell Experiment `vidspark` |
| 6 | HdHub | OpenStream `hdhub` |
| 7 | Sova | OpenStream `sova` |
| 8 | Sage | OpenStream `sage` |
| 9 | Phoenix | OpenStream `phoenix` |
| 10 | CineStream | Serenity `serenity-cinestream` |
| 11 | VidZee | Spyhell Experiment `vidzee` |
| 12 | VegaMovies | Spyou `vegamovies` |

### Anime — separate PRIMARY LIST

| Slot | Source | Stable source identity |
|---:|---|---|
| 1 | Anikoto | OpenStream `anikoto` |
| 2 | Re:Anime | OpenStream `reanime` |
| 3 | AnimeGG | OpenStream `animegg` |
| 4 | Jett | OpenStream `jett` |
| 5 | yastream | OpenStream `yastream` |
| 6 | VixSrc | `local::direct-vixsrc` |
| 7 | VidFast | Spyhell Experiment `vidfast` |
| 8 | Sage | OpenStream `sage` |
| 9 | Phoenix | OpenStream `phoenix` |
| 10 | CineStream | Serenity `serenity-cinestream` |
| 11 | VidZee | Spyhell Experiment `vidzee` |
| 12 | VegaMovies | Spyou `vegamovies` |
| 13 | Sova | OpenStream `sova` |
| 14 | VidSpark | Spyhell Experiment `vidspark` |

The VixSrc marker is inserted at slot 1 for Movies/Series and slot 6 for Anime. The playback loaders calculate its actual insertion index from installed/runnable predecessors, so unavailable repository entries do not create phantom execution positions.

## BACKUP lane and real-playback verification

- Newly configured installations start with an empty visible BACKUP lane. Remaining eligible installed sources are still scanned after PRIMARY and BACKUP; they are not represented as tested or verified simply because they exist in a repository.
- A repository source is promoted into BACKUP only after the player reports five consecutive seconds of non-buffering playback on that exact `unified:source:<stableKey>`. A manifest, health probe, successful search result, returned URL, or player-open event is not sufficient.
- Startup time is captured from the real player-start measurement. Actual startup failures are recorded separately. Automatically promoted entries are ordered using measured failure ratio, average startup time, and successful sample count.
- Existing or newly manually curated BACKUP entries are pinned. Playback metric updates cannot silently rearrange the user's chosen order. A one-time migration marks an existing non-auto-generated BACKUP list as curated.
- This code implements on-device verification as the app is used; this editing environment has not played live sources. No claim is made that each requested or additional source has been tested or works. The user must exercise playback on Android to populate verified BACKUP entries.

## Regression coverage and CI inventory

- `source_priority_policy_test.dart` locks the exact Movies/Series and Anime PRIMARY stable-key order and VixSrc's actual insertion behavior.
- `source_priority_manager_test.dart` verifies that only explicit verified-playback promotions create automatic BACKUP entries, ranks automatic entries by observed metrics, and preserves manual/legacy curated positions even after those entries gain metrics.
- Focused Flutter gate: 29 unique test files.
- Dart formatter gate: 166 unique targets, including `source_priority_manager.dart`.

## Validation boundary

Static inventory and file-presence checks are performed for this package. Dart, Flutter, Gradle and Android SDK executables are unavailable in this editing environment, so no local Dart format, Flutter Analyze, Flutter tests, Android tests, APK build or device playback is claimed. A fresh GitHub Actions run must pass all gates and produce the ARM64 Release APK. Real source viability can only be promoted after the on-device sustained-playback rule succeeds. Firebase/backend work remains out of scope.
