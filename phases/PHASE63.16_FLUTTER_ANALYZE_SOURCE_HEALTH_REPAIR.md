# PHASE63.16 — Flutter Analyze repair for local source health

**Date:** 2026-11-15  
**Base:** PHASE63.15 — User-managed Synchronize priority and local source health  
**CI evidence:** Run `43661952329`, commit `947811bd2c366a3311a113f08495cd4b9adcfd3b`  
**Scope:** RAVEN23 only.

## 1. Diagnosed build failure

The CI run completed dependency resolution and the scoped 74-file Dart format check. It then stopped at `Flutter analyze`, so the 18 focused Flutter tests, Gradle wrapper generation, Mihon Android unit test, Release ARM64 APK build and APK audit were skipped.

The analyzer reported three blocking errors:

1. `server_status_screen.dart` called `_message` in the Stremio configuration launch failure paths, but `_ServerStatusScreenState` did not define that helper.
2. `source_health_probe_service.dart` passed `maxContentLength` to Dio `BaseOptions`, although the project's locked Dio 5.9.0 API does not expose that named parameter.

It also reported one unnecessary non-null assertion on `lastSearchError`. The remaining 37 findings were informational under the workflow's `flutter analyze --no-fatal-infos` command.

## 2. Repairs applied

- Added `_message(String)` to `_ServerStatusScreenState`, using the same ScaffoldMessenger/SnackBar behavior already used by the source-repositories screen. Both Stremio launch failure paths now resolve to a defined method.
- Removed the unsupported `BaseOptions.maxContentLength` argument.
- Preserved and strengthened the original 512 KiB response-size guard by switching the health-check HTTP reads to `ResponseType.stream`. Response chunks are accumulated only while they remain within the limit; oversized responses are cancelled and classified as `Attention / invalid response`.
- Applied a 12-second inactivity timeout while consuming the response stream.
- Redirect response bodies are cancelled before following redirects. Redirect destinations continue to pass through the existing host policy, redirect limit and HTTPS downgrade protection.
- Removed the unnecessary `!` when throwing the promoted, non-null `lastSearchError`.

## 3. Files changed in this repair

- `lib/screens/common/server_status_screen.dart`
- `lib/screens/common/source_health_probe_service.dart`
- `phases/PHASE63.16_FLUTTER_ANALYZE_SOURCE_HEALTH_REPAIR.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/README_CHANGED_FILES.txt`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_58.md`
- `docs/build-reports/2026-11-15-phase63.15-run-43661952329/*` — original CI diagnostics and formatter patch retained as evidence.

## 4. Validation boundary

The two uploaded diagnostics archives were inspected. Their report confirms the failure is confined to Flutter Analyze; dependency resolution and formatting passed in that CI run. The current editing environment does not contain `dart` or `flutter` executables, so this repair has **not** been represented as locally formatted, analyzed, tested or built. A new GitHub Actions run must pass Flutter Analyze, all 18 focused Flutter tests, the Mihon Android unit test, the Release ARM64 APK build and APK audit before PHASE63.16 can be considered CI-verified.
