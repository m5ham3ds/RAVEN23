# Phase 51 — Integration & Regression Audit

**Base:** `RAVEN23-PHASE50.zip`  
**Date:** 2026-11-08

## Findings

- The project already contains a consolidated Android CI workflow with Java 17, Flutter 3.35.7, Android API 36/build-tools 36.0.0/NDK 28.2.13676358, Gradle 8.7, pinned `prod` flavor, local-development defines, and ARM64-only APK target.
- The workflow already formats the maintained Phase37–50 Dart file list, runs analyzer, runs 29 explicit phase contract test files, generates a Gradle wrapper in CI, builds the APK, and captures diagnostics/artifacts.
- The formatter script declares 91 Dart paths; all were verified to exist during the Phase50 report. The current pass rechecked the script path list.
- The test tree contains 256 `*_test.dart` files. Running all 256 tests as part of the bounded source gate would materially broaden runtime and expose unrelated flaky widget suites; the final gate therefore adds a deliberate set of ten cross-feature regression files rather than silently claiming a full-suite run.
- Added regression coverage paths: player route handoff, next-episode policy, player subtitle configuration, adaptive quality scanner, offline downloads, subtitle-language migration, TV remote navigation, TV back dispatcher, TV settings, and provider loader.
- The resulting explicit gate has 39 unique test files (29 source-contract + 10 cross-feature regression files).
- No `flutter` or `dart` executable is installed in this packaging environment.

## Risks still open

- Phases 36–50 do not all have observed CI acceptance evidence in the supplied archive. In particular, the last recorded successful CI run predates Phases46–50.
- Static test path existence does not prove Dart compilation or test success.
- ARM64 Release output, Android package installation, TV remote focus, and actual provider playback require CI/device evidence.
- Android WebView CookieManager remains process-shared; the app does not claim per-source cookie isolation.
- Pluto TV remains Experimental/Unavailable pending an authorized provider contract.

## CI failure follow-up — run 42486996579

- The first observed Phase51 Release workflow reached `flutter analyze` and stopped there. Dependency resolution and the canonical formatter step succeeded.
- The analyzer reported 1 error, 1 warning, and 12 informational lints. Because CI uses `flutter analyze --no-fatal-infos`, the informational items were not the failure trigger; the nullable access error and unused-import warning were.
- Root cause: `firstOrNull` made the cached Spyhell `channel` nullable. The old code checked `channel?.watchUrl` but later read `channel.name` unconditionally. The fix now checks `channel == null` explicitly before reading `watchUrl` or `name`.
- The unused `dart:convert` import was removed from the M3U repository test.
- All 12 reported curly-brace lints were corrected, and the IPTV dialog now checks `context.mounted` after its initial asynchronous playlist load before passing the context to `showDialog`.
- The exact formatter patch supplied by CI was applied to the Phase51 source tree before the targeted corrections.
- CI stopped before the 39 tests, Gradle Wrapper generation, APK build, and APK audit. These are **not executed**, not passed and not independently failed.
- The remediation has not yet been re-run with Flutter/Dart in this packaging environment. Re-run the same workflow to confirm a clean analyzer, then inspect the test/build stages.



## Third CI attempt — run 42497050504

- Run `42497050504` reached the required 39-file regression command after clean formatter and analyzer stages.
- Exactly one test failed: the epoch-millisecond string path in `_parseLiveTvExpiry`; 301 tests passed.
- Root cause was parser ordering: `DateTime.tryParse` accepted the digit-only millisecond string as an extended year before epoch parsing could run.
- The prepared fix parses integral numeric values first, retains ISO fallback for nonnumeric strings, and expands the existing parser test.
- The widget-test cache exception log is expected from an explicit negative-path test; localization warnings concern keys present in all shipped locale JSON files.
- Gradle Wrapper, Release APK build and APK audit were skipped. No Release output or ABI evidence exists for this run.
- No local Flutter/Dart execution is available in the packaging environment; a rerun is required.
