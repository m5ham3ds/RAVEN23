# PHASE63.28.1 — Require successful playback before activating extra hosts (2026-11-17)

## Baseline and scope

This is a narrow correction on top of the existing PHASE63.28 workspace. It does not repeat or replace the press-feedback, unified-download, notification, source-catalog, durable-download, or host-order work already present in PHASE63.28. It does not inspect the Zangetsu, FlixQuest or OpenStream reference archives and does not begin Firebase/backend integration.

## Host activation rule

- The user's twelve requested stream-host labels remain pinned in the exact configured order. Their presence in that preference list is not a claim that they have been tested or verified on this device; the status panel continues to show "No playback test recorded on this device" until a real player startup is observed.
- An additional host is eligible to appear in the active extra-host list only after at least one successful real playback has been recorded by the player on this device.
- A host with failures but zero successful playbacks remains in the performance snapshot for diagnostics. It is not shown as an active extra host and it ranks behind an entirely unobserved host, so a failure-only observation cannot promote it in quality selection or failover ordering.
- Additional hosts that have at least one successful playback continue to rank by measured failure ratio and average first-play latency; the manager does not use alphabetical/name-based ranking as a performance proxy.

## Implementation

- `lib/video_providers/unified/stream_host_priority_manager.dart` — `observedHostOrder` now includes only hosts whose recorded success count is greater than zero; failure-only metrics remain available through `performanceSnapshot` / `metricsFor`; `rankOf` places failure-only hosts behind never-observed hosts.
- `lib/screens/common/source_repositories_screen.dart` — clarify in Arabic and English that an additional host requires at least one successful real video playback before joining the active order.
- `test/video_providers/stream_host_priority_manager_test.dart` — add regression coverage proving a failure-only host is not activated, retains diagnostic metrics, and is ranked behind an unobserved host.
- `phases/PHASE63.28_PRESS_FEEDBACK_DOWNLOADS_HOST_ORDER_AND_DIAGNOSTICS.md`; `phases/README_MASTER_IMPLEMENTATION.md`; `phases/README_CHANGED_FILES.txt` — clarify the host activation evidence rule.

## Validation boundary

The Dart manager and its focused test are included in the existing formatter and Flutter test inventories; target counts remain 162 Dart files and 28 focused test files because this correction extends an already-listed test file. The editing environment does not provide Dart, Flutter, Gradle or Android SDK executables, so this document does not claim local Dart formatting, Flutter test execution, Android tests, APK production or live-server playback. The existing PHASE63.27.3 success report is baseline evidence only and is not evidence that PHASE63.28.1 has built.
