# Phase 38 — Implementation Record

**Date:** 2026-11-06  
**Status:** Implementation drafted; automated and runtime verification pending; acceptance blocked by Phase 37 / 37.1 prerequisites.

## 1. Implemented changes

### Identity model

- Added `MediaContentClassification` values: `general`, `anime`, `donghua`, `animation`, and `documentary`.
- Added `MediaIdentity.normalizedType`; legacy `UnifiedMediaType.anime` normalizes to `UnifiedMediaType.series` for source routing, without changing the public app `MediaKind` enum.
- Retained the `isAnimeContent` named constructor input as a compatibility path and retained an `isAnimeContent` getter. Anime and Donghua classify as anime-provider-compatible; Animation remains a distinct classification.
- Added `isAnimationContent` for the wider Animation classification.
- `isEpisode` now requires non-negative season and episode values and excludes Movie.
- Stremio type/ID and playback cache identity use normalized playback kind. The cache key separately includes normalized editorial classification.
- `copyWithExternalIds` preserves the identity classification and legacy flag.

### Exact episode identity

- Added `EpisodeIdentityNormalizer` and `EpisodeCoordinate`.
- Supports explicit season/episode fields, clear `SxxEyy`, `Season N Episode N`, Arabic `الموسم N الحلقة N`, and `NxNN` forms.
- A parent season can be inherited only when explicitly declared and non-conflicting. A conflicting declaration in a later `getEpisodes()` wrapper blocks fallback to a previously read parent season; absent and invalid declarations are distinguished.
- Conflicting aliases or coordinates across title/ID/URL/metadata are rejected, including conflicting episode numbers in separate title/name fields and malformed populated coordinate aliases. Non-integer, negative, and fractional coordinates are rejected.
- A missing season is never treated as a wildcard.
- The compact `NxNN` parser is limited to plausible one/two-digit season forms to avoid interpreting common video dimensions such as `1920x1080` as episode coordinates.

### Engine integration

- QuickJS now uses exact season + episode matching and supports both a detail response containing `episodes` and a wrapped `getEpisodes()` response. It does not extract streams from an ambiguous episode.
- Anime and Donghua QuickJS provider declarations are checked against the editorial classification while the playback type remains Series.
- Stremio rejects an incomplete series identity before requesting add-on streams.
- VidKing rejects incomplete series identities before seed/network requests and no longer substitutes placeholder season/episode values for series.
- Web Embed and OpenStream Anime use the normalized playback type for movie-vs-TV routing.
- IMDb lookup uses the normalized type, so legacy Anime episodes query the TV external-ID endpoint.
- `SourceContentIdentity` stores normalized playback kind and a separate classification component.
- `SourceManifest` treats `donghua` tags/provider type as anime-specialist capability while preserving mixed movie/series declarations.

### CI gates

- Extended the existing Android CI format list and focused test step with Phase 38 files/tests.
- Corrected shell line continuations in the workflow to a single backslash. The workflow still runs format, full `flutter analyze`, focused tests, full `flutter test`, and the existing ARM64 production APK build in that order.
- Existing Release configuration, package/application ID, signing setup, and ARM64 target were not changed by Phase 38.

## 2. Files modified

- `.github/workflows/android-ci.yml`
- `lib/video_providers/provider_loader.dart`
- `lib/video_providers/unified/media_identity.dart`
- `lib/video_providers/unified/media_identity_resolver.dart`
- `lib/video_providers/unified/openstream_anime_engine.dart`
- `lib/video_providers/unified/openstream_web_embed_engine.dart`
- `lib/video_providers/unified/quickjs_source_engine.dart`
- `lib/video_providers/unified/source_contracts.dart`
- `lib/video_providers/unified/source_manifest.dart`
- `lib/video_providers/unified/stremio_addon_provider.dart`
- `lib/video_providers/unified/vidking_direct_provider.dart`
- `test/provider_loader_test.dart`
- `test/video_providers/source_contracts_test.dart`
- `test/video_providers/source_repository_parser_test.dart`
- `test/video_providers/stremio_addon_provider_test.dart`
- `test/video_providers/unified/media_identity_resolver_test.dart`
- `test/video_providers/unified_models_test.dart`
- `test/video_providers/unified/quickjs_source_engine_test.dart`

## 3. Files added

- `lib/video_providers/unified/episode_identity_normalizer.dart`
- `test/video_providers/unified/episode_identity_normalizer_test.dart`
- `test/video_providers/unified/quickjs_source_engine_test.dart`
- `test/video_providers/vidking_direct_provider_test.dart`

## 4. Compatibility and non-changes

- No duplicate source registry or engine was introduced.
- Existing engine entry points and player adapters remain in place.
- No repository is newly enabled or auto-installed.
- No catalog title or stream URL was hardcoded as a fallback.
- No changes were made to `MediaKind`, Android package/application ID, production signing identity, `pubspec.yaml`, or native player code.
