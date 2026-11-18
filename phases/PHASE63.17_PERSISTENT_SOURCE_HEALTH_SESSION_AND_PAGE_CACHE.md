# PHASE63.17 — Persistent source-health session and page caching

**Date:** 2026-11-15  
**Base:** PHASE63.16 — Flutter Analyze repair for local source health  
**Scope:** RAVEN23 only.

## 1. Problems addressed

The two source-management pages were rebuilding their state on route re-entry. The health page created a new probe lifecycle on each visit and triggered another catalogue/check cycle. The repository page also rebuilt its view model and could refetch repository indexes. First-load latency was amplified because the six bundled repository indexes were fetched one after another. Result lists were built eagerly even when most rows were below the fold.

## 2. Persistent health session

- Added the app-wide `SourceHealthSessionController` as the single owner of the scan, catalogue snapshot, progress, result lists and probe runtime. Route disposal now removes only the page listener; it does not cancel probes or dispose QuickJS.
- The first opening starts the initial scan. Re-entering the page restores the same result snapshot and does not start another scan.
- The session is serialized to `SharedPreferences`, including the source identity/config needed to review or remove a failed item after app process recreation. Large Mihon icon Base64 payloads are intentionally omitted from the saved health snapshot.
- An interrupted session restores its checking rows and resumes only unfinished probes. A completed session is left unchanged until the user explicitly requests a new scan and confirms the replacement of results.
- Video-provider and Mihon phases now run concurrently. Both source lists appear as soon as their own catalogue resolves, with a per-item `Checking`/`جاري` state; each row is replaced immediately when its own probe returns.

## 3. Android foreground progress and notification navigation

- Added `SourceHealthForegroundService` with an ongoing progress notification for installed video sources and Mihon sources.
- The session updates notification counters while it runs and removes the notification on completion through `Context.stopService()`, avoiding a background `startService(ACTION_STOP)` call.
- The main Flutter engine is retained while the foreground service is active, so leaving the page or backgrounding the app does not dispose the Dart health session. The existing engine is reused without re-registering platform views on a notification-driven Activity reattachment.
- Tapping the notification opens `Check server status` directly on the Provider Health view. A pending-open flag covers cold starts; a method-channel callback covers warm starts.
- Android notification permission is requested on Android 13+. If the user denies notification permission, Android may not show the notification in the notification shade. Force-stopping the app remains an Android system stop action and cannot be prevented by the application.

## 4. Repository/catalogue load performance

- `UnifiedSourceService` instances share one `SourceRepositoryManager`, preserving the existing five-minute in-memory catalogue cache across pages and service facades.
- `SourceRepositoriesScreen` now keeps a fully assembled in-memory view model. Re-entering the route restores the last completed view immediately instead of showing a fresh loading state and re-reading its catalogue metadata. Explicit refresh actions still force a new repository fetch.
- Repository metadata reads (priority lanes, repository URLs, installed/disabled keys, revision history and pins) are requested concurrently rather than as serial preference lookups.
- `SourceRepositoryManager._fetchCatalog` uses a bounded three-worker pool for the independent bundled/custom repository indexes. Results are folded in the original URL order so source ordering and duplicate-resolution remain deterministic. A failed network refresh still uses the last verified local repository revision when present.
- Health-result rows now use lazy sliver builders. Only visible rows are built; the complete installed source list remains available through scrolling.
- The `Review failed sources` action is a bottom-floating extended button. Extra scroll tail space keeps the final list rows reachable above it.

## 5. Explicit user controls

- Opening the page does not rerun a completed scan.
- The toolbar refresh and pull-to-refresh are explicit recheck actions. When prior results exist, a confirmation dialog explains that a new scan replaces them.
- Results are retained until an explicit recheck or a source is removed. The failed-source review flow remains available after the scan completes.

## 6. Files changed

- `lib/screens/common/source_health_session_controller.dart` (new)
- `lib/screens/common/source_health_probe_service.dart`
- `lib/screens/common/server_status_screen.dart`
- `lib/screens/common/source_repositories_screen.dart`
- `lib/video_providers/unified/source_repository_manager.dart`
- `lib/video_providers/unified/unified_source_service.dart`
- `lib/raven23_main.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/MainActivity.kt`
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/Raven23Application.kt`
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/health/SourceHealthForegroundService.kt` (new)
- `tool/format_phase57_dart.sh`
- `.github/workflows/android-ci.yml`
- `phases/PHASE63.17_PERSISTENT_SOURCE_HEALTH_SESSION_AND_PAGE_CACHE.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/README_CHANGED_FILES.txt`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_58.md`

## 7. Validation boundary

Static checks are run during packaging: AndroidManifest XML parsing, GitHub Actions YAML parsing, shell syntax, all scoped formatter-target paths, all eighteen required Flutter test paths, method-channel/notification wiring, and ZIP CRC validation. This editing environment does not contain Dart or Flutter executables, so PHASE63.17 is **not** represented as locally formatted, analyzed, widget-tested, Gradle-compiled, APK-built or device-accepted. The next GitHub Actions run must pass the 76-file formatter gate, `flutter analyze --no-fatal-infos`, the existing eighteen focused Flutter tests, the Mihon Android ABI test, Release ARM64 APK creation and APK audit. Device testing should specifically cover home/back/task-swipe behavior, notification permission granted/denied, cold notification tap, warm notification tap, and restoration after Android process recreation.
