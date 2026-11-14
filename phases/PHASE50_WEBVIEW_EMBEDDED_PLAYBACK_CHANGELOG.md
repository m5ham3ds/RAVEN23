# Phase 50 — WebView & Embedded Playback Changelog

**Date:** 2026-11-08

## Added

- `lib/video_providers/unified/embedded_player_option.dart`
- `lib/screens/common/embedded_web_playback_screen.dart`
- `android/app/src/main/kotlin/com/m5ham3ds/raven23/streaming/EmbeddedWebPlaybackView.kt`
- `test/video_providers/phase50_embedded_playback_test.dart`
- `tool/format_phase37_50_dart.sh`
- Embedded playback status/action translations for English, Arabic, Spanish and Hindi.
- Six Phase50 planning/audit/implementation/test/changelog/report documents.

## Updated

- Unified source result model and OpenStream Web Embed engine.
- Legacy provider adapter and `RegularVideoLinks` mapping used by the player.
- Provider scan selection and player/movie/TV loader routing.
- VideoUtils maps and adaptive-quality/cache guards for embedded pages.
- `OpenStreamWebEmbedBridge.kt` observation-only script and structured `resolveEmbed` status result.
- `MainActivity.kt` platform-view registration.
- Android CI contract-test gate and formatter path list.
- Master blueprint, phase tracker and documentation index.

## Compatibility

- BetterPlayer remains responsible for direct media URLs.
- `resolveUrl` keeps its existing List return contract.
- Embedded results use an explicit marker and are not persisted as native stream-cache entries.
- No source registry, player engine or existing user cookie store was replaced.
