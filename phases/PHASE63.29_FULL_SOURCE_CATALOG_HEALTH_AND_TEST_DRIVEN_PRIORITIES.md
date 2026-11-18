# PHASE63.29 — Full SOURCE CATALOG Health Audit and Test-Driven PRIMARY Ordering (2026-11-17)

## Scope

This phase continues from the uploaded `RAVEN23_PHASE63.28.3.zip` working tree and the uploaded CI diagnostics. It does not inspect or extract the Zangetsu, FlixQuest or OpenStream reference archives. It does not add Firebase, a backend, or a new external health service.

## CI failure diagnosis and repair

The supplied Release CI run `44088182815` (commit `66eb950770c93174498dc62f7e1c562dcf62fe7a`) completed dependency resolution, Dart formatting and `flutter analyze --no-fatal-infos`. The focused Flutter pre-build gate then ran 29 test files: 224 tests passed and two failed. Android Gradle wrapper generation, Android contract tests, APK assembly and APK audit were skipped; no APK was produced by that run.

Both failures were stale test expectations, not production build/compiler errors:

- `test/app_press_feedback_test.dart`: `PillButton` intentionally configures press scale `0.94`; the assertion expected the generic `0.985` default. The test now asserts `0.94`.
- `test/playback_action_test.dart`: `PlayerChoiceCard` uses the generic `AppPressFeedback` default `0.985`; the assertion expected `0.90`. The test now asserts `0.985`.

The production animation values were not changed to satisfy stale assertions.

## Complete SOURCE CATALOG activation and Hentai exclusion

`SourceHealthSessionController` now reads `SourceRepositorySyncResult.catalog`, not only `snapshot.sources`. Every entry from the full repository catalogue enters the scan result set. Every non-excluded entry is explicitly installed/enabled in one batch, including entries whose upstream manifest says `enabled: false`. Entries whose engine cannot be tested by the VOD health probe remain visible with an explicit `Unsupported` result instead of being silently removed from the scan.

The Hentai exclusion is applied before installation and probing. It checks source IDs/names, source tags, engine type/endpoint, source homepage, engine configuration and clear source-description indicators. `Hanime` is explicitly blocked even though its ID does not contain the literal `hentai`; `HentaiMama` is blocked by its normalized ID/name. Excluded entries are uninstalled and removed from all Movies, Series and Anime PRIMARY/BACKUP lanes, including stale matching keys already saved in preferences. A repository URL alone mentioning `hentai` does not exclude every source in that repository.

Bulk install/uninstall operations update the persisted lists once per batch and invalidate the shared repository catalogue cache so playback services immediately observe the new active set.

## Health-check evidence

Every safe catalogue entry is represented in `Check server status`. QuickJS providers are checked with `getInfo`, then every relevant search contract: movie and sub contracts are both tested for mixed or undeclared content. For each responding category, the probe attempts a sample extraction from up to two search results; series/anime results first try `getDetail` and then `getEpisodes` to locate an episode URL. The probe calls `getVideoSources` and retains only valid HTTP(S) stream options returned by the existing QuickJS stream mapper.

The saved result includes per-category response time, sample result count, extracted stream count, unique quality labels, container diversity, audio kinds and subtitle-track count. A search result with no valid sample stream is marked `Attention` and is not eligible for PRIMARY re-ranking. A valid extracted URL is evidence of successful extraction only; it is not proof that the media plays on the device. Actual playback verification remains separate and is required before any source can be promoted to BACKUP.

The page now shows the count of safely enabled catalogue entries and the count excluded as Hentai, plus extracted stream counts and quality labels per provider. Endpoint-only engines remain identified as endpoint-only; unsupported engines remain explicitly unsupported.

## PRIMARY ordering

The first twelve existing Movies/Series PRIMARY entries remain pinned. The first fourteen existing Anime PRIMARY entries remain pinned. Only the tail after those fixed prefixes is rebuilt from category-matched, healthy results with at least one extracted stream. Candidates already in BACKUP are not copied into PRIMARY.

The candidate ordering is deterministic: distinct quality count, container diversity, audio-kind diversity, extracted stream count, subtitle-track count, measured search-plus-extraction latency, then stable source key. This makes quality coverage and measured response time explicit rather than using repository order or display labels. Providers that only expose a reachable manifest/page, an unsupported engine, or a search response without sample extraction are not falsely promoted into the measured PRIMARY tail.

BACKUP is not automatically filled from health checks. This preserves the PHASE63.28.3 rule that BACKUP additions require real, sustained playback verification; the only automatic BACKUP edits in this phase are removals of excluded Hentai sources.

## Regression coverage and CI gate inventory

Added focused tests for:

- Hentai name/ID/tag exclusions, the Hanime exception, ordinary Anime retention and avoiding repository-wide false positives.
- Both movie and sub QuickJS search contracts, series episode selection, stream option parsing, quality/container/audio/subtitle evidence and persisted evidence round-trip.
- Search-only sources being marked for review when sample extraction fails.
- Fixed twelve-entry Movies/Series and fourteen-entry Anime PRIMARY prefixes, quality/latency sorting, BACKUP exclusion and retaining an existing safe tail when no sample stream evidence exists.

The CI workflow now runs 32 focused Flutter test files. The scoped formatter inventory now contains 171 unique Dart targets, including the new production and test files. The next CI run must pass dependency resolution, format, Analyze, all focused Flutter tests, Android ABI/offline-download contract tests and the ARM64 Release APK/audit gates.

## Validation boundary

This editing environment does not contain Flutter, Dart, Gradle or the Android SDK. The new Flutter tests, formatter, analyzer, Android tests and APK build have not been executed here. No claim is made that any live source has passed on-device playback. Opening the updated app and running `Check server status` will execute the full catalogue audit using the device's current network and repository responses; the results then supply the measured PRIMARY tail. A fresh CI run is required before installing the next APK.

The deny-list also recognizes the Arabic spelling `هنتاي` in source IDs, names and source metadata. Stable blocked keys containing Hentai/Hanime/هنتاي are removed from saved installation preferences even when their old manifest is no longer present in the refreshed catalogue.
