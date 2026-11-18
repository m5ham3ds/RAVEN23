# PHASE63.31 — Build nullability repair and Movies/Series PRIMARY defaults (2026-11-18)

## Scope

This phase continues from the PHASE63.30.1 working tree and the owner-supplied CI diagnostics. It changes only RAVEN23. The Zangetsu, FlixQuest and OpenStream reference archives are not inspected or modified. No Firebase or backend integration is introduced.

## CI failure and repair

The supplied GitHub Actions run `44212516439` on commit `515e019bc8dc03b8d105bab82c569b051f10d710` completed checkout, Java/Gradle/Flutter/Android SDK setup, dependency resolution and the scoped Dart format stage. `Flutter analyze` then failed on one nullability error in `lib/screens/common/player.dart`: `networkBytesTransferred` is nullable, but the app-owned automatic-quality throughput sampler subtracted it from the starting byte count without first proving a value was available.

The sampler now treats a null byte counter as an unavailable sample, clears only the pending sample baseline, and retries once the player reports a concrete cumulative byte count. The existing three-second sample duration, conservative bandwidth budget, one-time automatic choice, manual-selection cancellation, and selected-quality behavior are unchanged. This fixes the analyzer error without inventing a zero-byte sample or selecting a quality from missing telemetry.

The uploaded CI report confirms that the focused Flutter tests, Android contract tests, Gradle wrapper generation, APK build and APK audit were skipped after Analyze failed. No APK was produced in that run. The other 43 analyzer findings were infos; two deprecation warnings were reported, but they did not fail this gate.

## New Movies and Series PRIMARY order

Movies and Series now share the following default PRIMARY order:

1. YaStream
2. Jett
3. HdHub
4. VixSrc (built-in)
5. VidSpark
6. VidFast
7. Sova
8. Sage
9. Phoenix
10. CineStream
11. VidZee
12. VegaMovies

The repository-backed source identifiers remain their stable repository/id keys. VixSrc remains the built-in native provider and is inserted at position four, after YaStream, Jett and HdHub. The Anime PRIMARY order and its existing VixSrc placement are unchanged. BACKUP ordering and the policy that only sustained real playback may promote a source into BACKUP are unchanged.

## Existing installation migration and user ownership

A one-time migration recognizes the exact untouched Movies/Series defaults from the immediately preceding build (VixSrc, Jett, YaStream, VidFast, VidSpark, HdHub, Sova, Sage, Phoenix, CineStream, VidZee, VegaMovies) and the older legacy default fingerprint. Only an exact match is replaced with the new requested order, filtered to sources that remain installed/available. Any manually reordered, added, removed or otherwise customized PRIMARY list is preserved. Anime is excluded from this new migration fingerprint.

## Regression coverage

- `test/video_providers/source_priority_policy_test.dart` now asserts the exact new Movies/Series order, VixSrc execution at position four (adjusted when a preceding source is not installed), and the previous-default migration fingerprint.
- The same test verifies that the previous untouched Movies/Series order can be recognized for migration and that Anime is not matched by this migration helper.
- Existing priority, VixSrc insertion and player-quality tests remain in the existing focused CI gate.

## Changed application and test files

- `lib/screens/common/player.dart` — null guard for the optional network byte counter in app-owned Auto throughput sampling.
- `lib/video_providers/unified/source_priority_policy.dart` — new Movie/Series recommended order, VixSrc fourth, previous-default fingerprint for safe migration.
- `lib/video_providers/unified/unified_source_service.dart` — migrate only exact previous defaults while preserving user-edited PRIMARY lists.
- `test/video_providers/source_priority_policy_test.dart` — exact-order and migration-fingerprint regression coverage.
- Thirteen Dart files received the exact formatting changes supplied in `RAVEN23-dart-format-patch(20261118-011422).zip` before the targeted code changes.

## Validation boundary

The diagnostics archive shows dependency resolution and the formatter stage succeeded, but Analyze failed on the nullable byte-counter subtraction. This editing environment does not contain Dart or Flutter, so the updated formatter, Analyze, focused Flutter tests, Android tests and Release APK build could not be rerun here. The original report, analyzer log, dependency log, environment and formatter patch are preserved in `docs/build-reports/2026-11-18-phase63.30.1-run-44212516439/`. A fresh GitHub Actions run is required; no PHASE63.31 build success is claimed. The previous run did not reach tests or APK generation.
