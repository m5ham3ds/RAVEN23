# Phase 38 — Test Plan and Results

**Date:** 2026-11-06  
**Execution state:** Source-level test cases added; Dart/Flutter execution unavailable in this environment.

## 1. Added/extended deterministic tests

| Test file | Cases covered |
|---|---|
| `test/video_providers/unified/episode_identity_normalizer_test.dart` | Duplicate episode numbers across seasons; no season wildcard; explicit parent season; SxxEyy / 2x08 / English and Arabic season labels; conflicting metadata; conflicting season aliases; absent-vs-conflicting parent declarations; title-vs-URL and title-vs-name conflicts; malformed populated aliases; identical repeated coordinates; invalid fractional/negative values; parent conflict; video dimensions not mistaken for `SxE`; season-zero specials |
| `test/video_providers/unified/quickjs_source_engine_test.dart` | Exact S02E08 selection; refuses number-only episode; inherits only explicit parent season; rejects stale parent fallback after conflicting getEpisodes wrapper; anime-only source runs through Series episode path; Japanese/Korean/Chinese/Arabic/Latin exact-title fixtures; rejects incomplete request |
| `test/video_providers/vidking_direct_provider_test.dart` | Rejects incomplete series request before any network request |
| `test/video_providers/stremio_addon_provider_test.dart` | Rejects incomplete series request before any add-on request; existing movie/episode routing and header/subtitle behavior retained |
| `test/video_providers/unified_models_test.dart` | Legacy Anime normalized to Series; Anime/Donghua/Animation classification; anime feature film remains Movie |
| `test/provider_loader_test.dart` | Episode factories use Series for Anime/Donghua; anime feature film remains Movie |
| `test/video_providers/source_contracts_test.dart` | Donghua capability resolves through the Series path; source content identity keeps classification separate |
| `test/video_providers/source_repository_parser_test.dart` | Donghua tag and QuickJS provider type are recognized as anime-specialist declarations |
| `test/video_providers/unified/media_identity_resolver_test.dart` | IMDb lookup uses TV identity for legacy Anime episode |

## 2. Available static checks — executed on 2026-11-06

- Base archive integrity: passed before modification.
- All 30 project `.json` files: parsed successfully with Python's JSON parser.
- `.github/workflows/android-ci.yml`: parsed successfully with PyYAML.
- All 9 workflow `run` blocks: passed `bash -n` syntax checks.
- All 26 distinct source/test paths referenced by the formatter and focused-test steps: exist.
- Full-tree comparison against the supplied base archive: 1,329 baseline files preserved, 10 files added, 22 existing files modified, zero files deleted.
- Android project files, `pubspec.yaml`, package/application ID, and signing/build configuration: byte-identical to the supplied base archive.
- Dart/Flutter executables: not installed in the execution environment.

## 3. Not executed — do not infer success

| Gate | Result | Reason |
|---|---|---|
| `dart format` | Not run | Dart SDK unavailable |
| `flutter analyze` | Not run | Flutter SDK unavailable |
| Focused `flutter test` | Not run | Flutter SDK unavailable |
| Full `flutter test` | Not run | Flutter SDK unavailable |
| Android Release APK build | Not run | Flutter/Android build environment unavailable |
| Android Mobile / TV runtime | Not run | No device runtime attached |
| Live external-source playback | Not run | No sources activated; external runtime tests remain separate |

The GitHub Actions workflow includes these automated gates, but no run on this modified archive was initiated or observed. CI must pass before Phase 38 acceptance.
