# RAVEN23 PHASE63.17 — Persistent source-health session

**Date:** 2026-11-15  
**Source baseline:** `RAVEN23_PHASE63.16_BUILD_REPAIR.zip`  
**Result:** Source changes and static packaging checks prepared; no APK build claimed.

## Change summary

The source-health scan is now owned by one app-wide session controller and persists its progress/results. Navigating away and returning no longer creates a new scan. Both video-provider and Mihon scans run concurrently, source rows are rendered as `Checking` immediately after their list is available, and each row is updated independently.

A native Android foreground service publishes current progress and opens `Check server status` when its notification is tapped. The Flutter engine remains alive while that service is active. Completion stops the service directly through `Context.stopService()` so a background `startService(ACTION_STOP)` request is not needed. Repository view state is retained across route re-entry, and repository indexes now load through a bounded three-request pool instead of serial network fetches. Health lists use lazy Sliver builders; the failed-source review action is fixed above the bottom safe area.

## Static checks

See `static-checks.txt` for the checks performed in this package. The local environment has no `dart` or `flutter` executable, so formatter/analyzer/widget tests/Gradle/APK/device validation were not run locally.

## Acceptance still required

Run the repository's GitHub Actions workflow against this revision and confirm: all 76 scoped Dart targets format, `flutter analyze --no-fatal-infos` succeeds, the eighteen focused Flutter test files pass, the Mihon Android ABI unit test passes, the Release ARM64 APK builds, and the APK audit succeeds. Then test app backgrounding, pressing Back, swiping the app from Recents, notification permission denial/grant, tapping the notification while warm/cold, and session restore after an OS process kill. A user force-stop is outside the app's ability to keep executing.
