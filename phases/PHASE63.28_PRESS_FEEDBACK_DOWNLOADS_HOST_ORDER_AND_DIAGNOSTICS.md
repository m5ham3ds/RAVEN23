# PHASE63.28 — Press feedback, unified quality downloads, host ordering and diagnostics (2026-11-17)

## Baseline and scope

This phase continues from the owner-confirmed successful `PHASE63.27.3` build, CI run `43979104917` (ARM64 Release APK, 45.34 MiB). It does not restart the PHASE63.27 implementation and does not begin Firebase or backend integration. The reference archives Zangetsu, FlixQuest and OpenStream are not inspected.

## Press feedback

- `lib/mobile/app/mobile_nav_bar.dart` applies a clear `0.94` press scale to the four primary destinations (Home, New & Hot, Discover and My RAVEN23), keeping the shared default of `0.985` unchanged for unrelated controls.
- `lib/mobile/widgets/pill_button.dart` applies the same explicit scale to its Hero actions (Play / My List). New taps are disabled while busy, while a pointer that began before Play entered its loading state is allowed to complete its release pulse.
- `lib/design/app_press_feedback.dart` preserves the short post-release pulse for quick taps, cancels it for drag/scroll gestures, and continues respecting Android/iOS Reduce Motion settings.
- The Manga work-page Read/Find source and Find across sources actions use the same clear press scale. Regression coverage checks primary navigation taps, Play/My List taps and the Play-to-busy transition.

## One quality catalogue for downloads

- Movie and episode download requests scan eligible installed sources before presenting a chooser. They no longer show a provider/server-selection sheet first.
- The same `PlaybackQualityCatalog` and `DownloadSelectionSheets.showQualityCatalog` path is used by the player and the page-level download flow. The visible list contains one row per unique quality, with quality as the title and server/format as secondary information.
- The selected row retains the exact source/provider key, URL, request headers, format, optional subtitle/audio selection and media identity. No duplicate resolution rows are introduced by mirror links.
- The legacy provider picker remains only as a manual playback fallback when automatic source loading is disabled; it is not used by the new download flow.

## Durable download metadata

- `OfflineDownloadRequest.streamIdentity` carries the selected server label, provider code, source provider code, stable source key, quality and format.
- The Android `StreamDownloadStore` serializes this identity into the Media3 `DownloadRequest.data` payload and returns it with download rows. Media3's `DefaultDownloadIndex`/SQLite index persists requests; the stream cache is stored below `filesDir/offline_streams` and the recovery sidecar under `filesDir/offline_requests`.
- This is provenance/recovery metadata, not a general-purpose signed-URL refresh adapter. Unified-source signed URLs may still expire; no automatic renewal is claimed for engines without a supported refresh resolver.

## Stream-host ordering and evidence

The user-requested first-twelve order is pinned as the default stream-host order:

1. VixSrc
2. Jett
3. YaStream
4. VidFast
5. VidSpark
6. HdHub
7. Sova
8. Sage
9. Phoenix
10. CineStream
11. VidZee
12. VegaMovies

`StreamHostPriorityManager` is intentionally separate from `SourcePriorityManager`: these labels are returned inside video links and are not repository add-ons. The pinned order is now applied to returned links and provider failover choices. Additional hosts become eligible for the active list only after at least one successful real playback is recorded on the device, then rank by observed success/failure ratio and average first-play latency. Failure-only hosts remain in diagnostic metrics but are not promoted or shown as active extras. Aliases of the pinned twelve are filtered from the extras list.

The player records a successful startup either from BetterPlayer's `play` event or from the one-second player monitor observing initialized, playing and non-buffering state. Both paths share an exactly-once completion helper, preventing the monitor from clearing the timer before success metrics are persisted. A startup exception records a failure.

**Live-server validation boundary:** no live playback tests for the twelve named hosts or additional hosts are claimed in this editing environment. Actual per-host success and latency metrics are collected when the owner tests playback on the device. The Check server status probes establish endpoint/search/manifest responsiveness according to engine type; they do not by themselves prove that a real movie/episode stream plays.

## Source catalog and status screen

- Catalog search includes source name, id, stable key, description, language, authors, tags, homepage, repository URL, engine type, endpoint, media URLs and engine configuration.
- Catalog pagination remains lazy. On repository add/refresh, the current visible count and scroll offset are restored (clamped to the new extent) instead of jumping to the top. An actual search-term change intentionally resets to the top to show the first matching result.
- The status page retains separate video-source and Mihon probes and does not label endpoint reachability as verified video playback.

## Notifications

- Local Android notifications are initialized at app startup. Settings includes an immediate test-notification action that checks/request permission and posts through `flutter_local_notifications`.
- Download completion/failure and chapter-subscription notices use local channels. Chapter updates are checked when the work is opened or the app is resumed; this service does not poll while the app is closed.
- Remote push notifications are not considered enabled by this phase. The confirmed PHASE63.27.3 workflow used `ENABLE_FIREBASE=false`, and Firebase/backend integration remains explicitly out of scope until the owner authorizes the next phase.

## Validation boundary

The focused Flutter gate now contains 28 test files and the formatter scope contains 162 Dart targets. The editing container does not have Flutter, Dart, Gradle or Android SDK executables. Therefore this phase does not claim a local `dart format`, `flutter analyze`, Flutter test, Android unit-test, APK build or on-device visual/playback result. Static checks and archive integrity are recorded separately; GitHub Actions and physical-device testing must validate the new changes before acceptance.
