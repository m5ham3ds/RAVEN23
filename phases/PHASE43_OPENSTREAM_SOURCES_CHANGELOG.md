# Phase 43 — Changelog

## Application code

- `lib/video_providers/unified/openstream_web_embed_engine.dart`
- `lib/video_providers/unified/stream_option.dart`: added public `parseStreamExpiry` backed by the existing expiry parser; accepts ISO-8601, DateTime, epoch seconds and epoch milliseconds.
- `lib/video_providers/unified/vidking_direct_provider.dart`: forwards explicit expiry fields from individual streams or the adaptive payload into `UnifiedStreamOption`.
- `lib/video_providers/unified/openstream_anime_engine.dart`: forwards explicit expiry from native source payloads through Re:Anime/FourAnimo/MegaPlay/WebView-captured stream paths and preserves it in the FourAnimo and Anikoto copied objects.
- `lib/video_providers/unified/openstream_web_embed_engine.dart`: preserves explicit expiry from captured Web Embed stream metadata.

## Tests

- `test/video_providers/source_repository_parser_test.dart`: exact source-id-to-route map for all nine VidKing sources; preserve default-install flags, status, web embed fallback/templates and Anime Beta lifecycle.
- `test/video_providers/vidking_direct_provider_test.dart`: all nine route dispatches, exact TV coordinates and expiry parsing.
- `test/video_providers/source_host_policy_test.dart`: deterministic Re:Anime episode/feature-film identity mapping.

## CI and tooling

- `.github/workflows/android-ci.yml`: 15-file finite gate; adds Phase41 required dependencies and Phase43 deterministic contracts; log/artifact renamed to Phase43. Final review also fixed a malformed string in the embedded Python report generator and statically revalidated all 3 Python heredocs and 13 Bash blocks.
- `tool/format_phase37_42_dart.sh`: retained stable filename; adds `stream_option.dart` and updates coverage comment to Phase43.

## Documentation

- Added Phase43 plan, audit, implementation, tests, changelog and report.
- Updated master blueprint, tracker, README, source catalog and compatibility matrix.
