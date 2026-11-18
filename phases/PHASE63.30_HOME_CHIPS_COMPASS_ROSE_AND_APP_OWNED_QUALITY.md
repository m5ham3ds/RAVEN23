# PHASE63.30 — Home filters, compass-rose menu toggle, and app-owned quality selection (2026-11-18)

## Scope

This phase continues from the owner-confirmed PHASE63.29 build baseline. It changes only the RAVEN23 application. It does not inspect or modify the Zangetsu, FlixQuest or OpenStream reference archives, and it does not introduce Firebase or backend integration.

## Home header filters

The shared Home header chips used by the Home, Movies, Series and Anime feeds now expose only `Live TV` and `Categories`. The redundant `All`, `Movies` and `Series` chips are removed because those destinations are already available in the primary bottom-navigation/secondary destination system. The existing Live TV visibility preference remains respected.

## Secondary-navigation toggle icon

The centre secondary-dock control uses `PhosphorIcons.compassRose()` as its default glyph. The existing destination-aware behavior is preserved: after choosing Movies, Series or Anime, the control changes to that destination's icon as before; while the secondary menu is open, it shows `PhosphorIcons.x()`. The follow-up PHASE63.30.1 correction changed only the default glyph and restored the original destination-aware toggle behavior.

## Provider Auto versus app-owned Auto

Provider-owned `Auto`, `Automatic`, `Adaptive` and `Master` labels are implementation details and are no longer exposed as selectable quality rows in the playback or download pickers. An adaptive master URL may still be used internally to bootstrap playback when it is the only available URL; the master row itself is not offered to the user.

The application owns one initial automatic-quality decision for a playback session when the saved default resolution is Auto (`defaultVideoResolution == 0`). Once real playback is stable, the player samples the increase in transferred media bytes across an initial three-second window. It estimates available throughput, applies a conservative 72% budget, and selects a concrete rendition. If the measured rate cannot afford any advertised rendition, it chooses the lowest available rendition; if there is no usable sample, it falls back to 720p or the best lower/lowest rendition actually available. This is a short in-session throughput estimate, not an independent speed-test service.

When adaptive tracks are available from the active master, the app pins the selected concrete BetterPlayer track. Otherwise, it can choose an exact concrete quality URL from the catalog and switch to that link. The automatic decision runs once; it is not re-applied on each provider change. Any manual quality choice increments the automatic-selection generation and cancels a queued/in-flight automatic choice so it cannot overwrite the user's selection. An explicit saved resolution continues to take precedence over Auto.

## Quality catalogue and duplicate handling

The quality catalogue expands adaptive manifests into concrete resolution entries only. It retains the exact provider/source key, server, URL, headers and format data for each choice. Same-height entries from different servers remain separate choices (for example, `1080p · HdHub` and `1080p · PeerTube Films`). When BetterPlayer exposes native tracks for the currently active adaptive stream, only duplicate entries belonging to that exact active source are suppressed; equal resolutions from other servers remain visible and selectable.

Manifest discovery is bounded to three concurrent requests and only scans likely adaptive masters or ambiguous manifest URLs. Fixed HLS/DASH URLs already labelled with a concrete resolution are not needlessly rescanned. The picker does not invent an Auto option when a manifest cannot be inspected.

## Download selection

The player’s in-session download action, the unified download flow, and the older per-provider movie/TV download paths use the same quality catalogue. The in-session action performs a bounded adaptive-manifest discovery pass before presenting the chooser so it does not rely only on whichever background scans happened to finish first. The selected row passes its exact URL, format, headers, server/source identity and selected maximum video height into the download request. The native Media3 download selector applies the selected height ceiling for HLS/DASH, while fixed-resolution URLs are downloaded from the exact selected link. The legacy raw-resolution helper also filters provider Auto labels as a defensive guard.

## Focused regression coverage

- `test/home_screen_test.dart`: the shared Home header exposes Live TV and Categories and no longer exposes All/Movies/Series chips; the initial All feed shelves remain intact.
- `test/mobile/mobile_nav_bar_test.dart`: closed menu toggle remains the Phosphor compass-rose after Movies, Series and Anime are selected; open state remains X.
- `test/quality_catalog_test.dart`: provider Auto is not a user-facing catalogue item; Auto-only master URLs remain usable internally; same-height sources stay separate; legacy download keys keep distinct server alternatives; app-owned bandwidth policy chooses a concrete quality and handles very low bandwidth.
- `test/adaptive_quality_scanner_test.dart`: fixed labelled HLS/DASH renditions are not treated as adaptive masters; Auto and ambiguous manifest links remain discoverable.

The existing formatter inventory already includes all modified Dart source and test files. The existing focused CI test gate already includes the navigation, quality-catalogue and adaptive-scanner test files; no CI workflow broadening was made.

## Changed application files

- `lib/mobile/screens/home_screen.dart`
- `lib/mobile/app/mobile_nav_bar.dart`
- `lib/functions/video_utils.dart`
- `lib/screens/common/player.dart`
- `lib/screens/common/download_selection_sheets.dart`
- `lib/screens/movie/movie_video_loader.dart`
- `lib/screens/tv/tv_video_loader.dart`
- `lib/video_providers/adaptive_quality_scanner.dart`
- `lib/video_providers/quality_catalog.dart`
- `test/mobile/mobile_nav_bar_test.dart`
- `test/quality_catalog_test.dart`
- `test/adaptive_quality_scanner_test.dart`

## Validation status

Static source review and project packaging checks only. The editing environment has no Dart or Flutter executable, so `dart format`, `flutter analyze`, the focused Flutter tests and Android Release/APK build were not run here. No post-PHASE63.30 build success is claimed. Run the existing GitHub Actions gate and test on a real Android device before accepting this phase. In particular, verify that an adaptive VixSrc stream exposes each concrete rendition, that changing resolution switches to the chosen rendition without reverting to provider Auto, and that the download file's actual resolution matches the selected row.
