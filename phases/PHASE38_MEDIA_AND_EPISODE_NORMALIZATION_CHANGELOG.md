# Phase 38 — Changelog

**Date:** 2026-11-06

## Added

- `lib/video_providers/unified/episode_identity_normalizer.dart`
- `test/video_providers/unified/episode_identity_normalizer_test.dart`
- `test/video_providers/unified/quickjs_source_engine_test.dart`
- `test/video_providers/vidking_direct_provider_test.dart`
- Six Phase 38 documents: Plan, Audit, Implementation, Tests, Changelog, Report.

## Changed

- `lib/video_providers/unified/media_identity.dart`: normalized playback type, content classification, validated episode predicate, stable identity/cache representation.
- `lib/video_providers/provider_loader.dart`: normalized movie/episode identity factories and diagnostics.
- `lib/video_providers/unified/media_identity_resolver.dart`: normalized type for TMDB external-ID lookup.
- `lib/video_providers/unified/source_contracts.dart`: normalized source content identity and classification-aware capability checks.
- `lib/video_providers/unified/source_manifest.dart`: Donghua specialist detection and normalized type routing.
- `lib/video_providers/unified/quickjs_source_engine.dart`: exact episode identity resolution and explicit parent-season handling.
- `lib/video_providers/unified/stremio_addon_provider.dart`: rejects incomplete series identities before network calls.
- `lib/video_providers/unified/vidking_direct_provider.dart`: rejects incomplete series identities and removes series coordinate fallbacks.
- `lib/video_providers/unified/openstream_web_embed_engine.dart`: uses normalized type for movie/TV templates.
- `lib/video_providers/unified/openstream_anime_engine.dart`: uses normalized type while retaining AniList/ani.zip Movie-vs-TV mapping.
- Existing provider, identity, parser, source-contract and resolver tests were extended; exact episode fixtures additionally reject title/name and malformed-alias conflicts.
- `.github/workflows/android-ci.yml`: added Phase 38 test/format paths and repaired line-continuation syntax.

## Not changed

- Application `MediaKind`, catalog APIs, player implementations, native Android files, package/application ID, signing configuration, `pubspec.yaml`, repository activation preferences, and Live TV services.

## Rollback

Revert the files listed in this changelog and remove the six Phase 38 documents. No user-data migration or repository installation was performed.
