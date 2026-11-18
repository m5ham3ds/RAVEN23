# Phase 40 — Full Flutter Test Suite Failure Analysis

**CI run:** `42328559177`  
**Commit:** `e0bd14ddf418162a979afe0d26a9f512166746d4`  
**Build mode:** Release  
**Observed result:** 2,143 passed, 34 failed, 11 skipped.  
**Workflow outcome:** failed at `Complete Flutter test suite`; Gradle Wrapper generation, Android APK build, and APK audit were skipped. No APK was produced.

## Gates that passed

- `flutter pub get`
- Dart format fix and strict check
- `flutter analyze`
- Focused architecture/Stremio suite: `147` passed

## Confirmed systemic defect fixed

`ProviderScanSession._run()` waited for `await _updates.close()` before completing `_completed`. `_updates` is a single-subscription `StreamController`. When a caller never subscribes, the close future can remain pending until a listener attaches, even though provider workers have finished and `[PlaybackScan][FINISHED]` has already been logged. This left `session.completed` pending and caused repeated per-test 60-second timeouts.

The code now starts stream closure with `unawaited(_updates.close())` and completes the scan lifecycle without waiting for a consumer to drain UI updates. The provider background scan test file is also added to the focused CI gate so this regression is checked before the full application suite. This preserves the single-subscription stream's buffered events for a late listener. A regression test was added to assert both behaviours: `session.completed` resolves with no listener, and a later listener still receives the buffered `started` and `completed` updates.

The systemic issue accounts for **11** failures in `test/provider_background_scan_test.dart`. This is a code fix, not a timeout increase or test skip.

## Remaining full-suite failures requiring triage

The following **23** non-timeout failures span 17 other test files. The report does not establish that they were introduced by Phase 40; they touch existing UI, settings, storage, OneSignal, subtitle and legacy adapter areas. They have not been “fixed” by changing expected values.

| Test file | Failed test / observed symptom |
|---|---|
| `test/search_screen_test.dart` | `nothing found: say so, and suggest genres that match`; two tablet RTL layout tests. The invariant stack reports pending timers after widget disposal; the first includes `pumpAndSettle()` in the test path. |
| `test/mobile/widgets/reveal_item_test.dart` | Zangetsu rise animation expected a positive visible offset; actual value was `0.0`. |
| `test/data/onesignal_messaging_client_test.dart` | SDK/platform-tag test expected `true`; actual `false`. |
| `test/discover_screen_test.dart` | Anime filter test could not find the `anime_status` localization/text key. |
| `test/tv_remote_navigation_test.dart` | Subtitle-settings semantics expected `17px, Regular`; actual `12px, Bold`. |
| `test/playback_stream_cache_test.dart` | Restored subtitle language expected `English`; actual `null`. |
| `test/app_colors_test.dart` | Orange custom theme color expectation returned `false`. |
| `test/poster_grid_test.dart` | Artwork-only widget test failed; the captured report excerpt does not preserve its exact assertion. |
| `test/occasional_theme_test.dart` | Unavailable selection expected `christmas`; actual `new_year`. |
| `test/tv_settings_screen_test.dart` | Subtitle language selection expected `English, Selected`; actual `Arabic, Selected`. |
| `test/new_and_hot_screen_test.dart` | Ad placement after the third date group failed. |
| `test/title_details_screen_test.dart` | Movie hierarchy finder found two `Opacity` ancestors instead of exactly one; two series episode/season tests also failed without a complete assertion excerpt in the report. |
| `test/external_subtitle_service_test.dart` | Arabic SRT fixture passed to `http.Response` hit Latin-1 encoding invalid-character error; gzip test expected `TemporaryUserAgent` but observed `null`. |
| `test/video_providers/quickjs_stream_mapper_test.dart` | Container expectation was `mp4`; actual was `unknown` for the malformed/non-HTTP fixture. |
| `test/video_providers/legacy_provider_adapter_test.dart` | Expected quality label `540p`; actual label included `540p · Provider`. |
| `test/presentation/config_source_controller_test.dart` | Unavailable theme selection expected `null`; actual retained an `OccasionalTheme` instance. |
| `test/home_screen_test.dart` | Two widget tests failed: row/ad ordering and load/fade/filter switching. |

## Warnings and non-failure diagnostics

- Flutter test emitted tap warnings for an Arabic “Top 10 Anime” text finder.
- Flutter test warned that at least one test creates an `HttpClient`; with `TestWidgetsFlutterBinding`, real HTTP requests return status `400` unless a test-specific client is injected.
- The expanded log contains many Easy Localization `[WARNING]` messages for keys such as `new_episodes_anime`, `popular_movies`, `anime_status`, `search_hint`, and others. The previous report's warning regular expression did not count `[WARNING]` bracket markers correctly; the Workflow parser has been corrected to include them in the next report.
- Existing `[ContentAds]`, `[TvMediaDetails]`, and TV cache failure messages include explicit offline/mock exceptions; these are test logs and do not by themselves establish a production runtime failure.

## CI report improvements

The Workflow report generator now parses every expanded reporter `[E]` line, deduplicates failed test names, lists all unique failures with nearby `Expected`/`Actual`/exception/timeout details, counts timeout failures, and recognizes bracketed `[WARNING]` messages. This avoids truncating the failure inventory to an arbitrary excerpt limit.

## Acceptance status

- The provider scan completion fix and regression test are implemented.
- The full Flutter test suite has **not** been rerun after this fix.
- The 23 other listed failures remain unresolved pending focused diagnosis and should not be marked passed.
- Gradle Wrapper and Release ARM64 build have not been reached in the observed run.
- Phase 40 remains `In Progress`; Phase 41 must not start until its acceptance gates are satisfied.
