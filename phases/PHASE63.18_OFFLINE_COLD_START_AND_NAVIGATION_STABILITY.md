# PHASE63.18 — Offline cold-start loading and navigation stability

**Date:** 2026-11-15
**Base:** RAVEN23 PHASE63.17
**Scope:** Home, Movies, Series, Manga, app connectivity state, mobile tab transition

## Findings before modification

1. Home/Movies/Series use the shared `HomeScreen` but each tab body is retained by `MobileShell` with `Offstage`/`TickerMode`. The page models retain their state; however, the screen had no app-wide signal to retry a cold-load failure when connectivity returned.
2. Manga has its own `AniListMangaService` and persistent catalogue cache. Its cold failure state was also local to the screen and had no connectivity-recovery hook. Existing persistent cache behavior is retained.
3. The first empty/offline response could replace the skeleton immediately. The user therefore saw an error before the page structure had a meaningful first-paint interval.
4. `MobileShell` faded the entire page subtree. Where the page content/background was transparent, the fading subtree exposed the parent Scaffold for part of the transition, creating a brief background/colour flash.
5. Android 8.0+ does not deliver connectivity-change broadcasts to backgrounded apps. Checking connectivity on app resume is therefore necessary.

## Changes

- Added `AppNetworkState`, a process-wide connectivity snapshot shared by the root app and catalog pages. It listens to the existing `connectivity_plus` stream, performs an initial `checkConnectivity()`, and is force-notified after app resume.
- Network-interface changes schedule one debounced retry for a failed visible Home/Movies/Series or Manga cold catalogue. The actual TMDB/AniList request determines success; an available Wi-Fi/mobile interface is never treated as proof of Internet/API reachability.
- Returning to a previously failed tab performs one real API probe when the network interface has been restored while the tab was hidden. The retry still observes a two-second cooldown, and it only runs for a failed cold catalogue (not for a page with usable content/cache or an active Manga search).
- Connectivity revisions are captured when each cold request starts. If the interface changes while the first request is still in flight, the page checks the revision after publishing its failure and schedules the recovery attempt; this closes the race where a reconnect event arrived before the visible error state existed.
- Added a 650 ms minimum visibility window for the existing `HomeSkeleton` on fast cold failures. Successful loads and cached content are not deliberately delayed. Slow requests continue to show the skeleton until completion.
- Changed the tab stack so an opaque page-colour backdrop remains outside `FadeTransition`. Added a `RepaintBoundary` around each retained tab body to isolate repaint work during navigation. The transition duration and navigation model are unchanged.
- Added widget coverage for automatic Movies/Series recovery, recovery after returning to a hidden Home tab, recovery after returning to a hidden Manga tab, and connectivity restoration while the initial cold request is still in flight. Existing direct reconnection tests remain.
- Expanded the scoped Dart formatter inventory from 76 to 79 unique files by adding `mobile_shell.dart` and the two new service files. The focused Flutter CI gate remains 18 test files.

## Important behavior limits

`connectivity_plus` reports network-interface types, not verified Internet access. A Wi-Fi connection can still lack usable Internet; the catalog request is the final authority. Android background connectivity broadcasts are limited from Android 8.0 onward, so the app performs a fresh connectivity snapshot on resume. Android force-stop or process termination can still stop all in-process work; these catalog requests are normal foreground screen fetches, not a promised background job.

## Files changed

- `lib/services/app_network_state.dart` (new)
- `lib/services/minimum_loading_visibility.dart` (new)
- `lib/raven23_main.dart`
- `lib/mobile/screens/home_screen.dart`
- `lib/mobile/screens/manga_screen.dart`
- `lib/mobile/app/mobile_shell.dart`
- `test/home_screen_test.dart`
- `tool/format_phase57_dart.sh`
- `.github/workflows/android-ci.yml`
- `phases/PHASE63.18_OFFLINE_COLD_START_AND_NAVIGATION_STABILITY.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/README_CHANGED_FILES.txt`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_58.md`
- `docs/build-reports/2026-11-15-phase63.18-offline-loading/`

## Validation boundary

Static checks in the editing environment: formatter target inventory contains 79 unique existing Dart files; Bash syntax check for the formatter script; YAML parse for the workflow; no whitespace errors in the patch; archive CRC check after packaging.

**Not run:** Dart formatter, `flutter analyze`, Flutter widget tests, Gradle/Kotlin compilation, APK build, GPU/device transition test, real offline/online device test. Dart and Flutter SDK executables were not available in the editing environment. A new GitHub Actions run and device verification are required before this phase can be treated as build/device accepted.

## Official references checked

- `connectivity_plus` package documentation: https://pub.dev/packages/connectivity_plus/versions/6.1.5 — network interface types are not a guarantee of Internet access; Android 8.0+ background connectivity broadcasts are not delivered, and connectivity should be checked on resume.
- Flutter `didChangeDependencies`: https://api.flutter.dev/flutter/widgets/TickerProviderStateMixin/didChangeDependencies.html — inherited dependency changes notify the State, and the method is called immediately after `initState`.
- Flutter `FadeTransition`: https://api.flutter.dev/flutter/widgets/FadeTransition-class.html — documents opacity transition behavior and hit-testing implications.
- Flutter `RepaintBoundary`: https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html — provides a separate display list to contain repaint work when subtrees repaint independently.
