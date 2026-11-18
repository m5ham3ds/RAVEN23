# Phase 39 — QuickJS Settings System — Audit

**Audit date:** 2026-11-06
**Base:** `RAVEN23-PHASE38-MEDIA-EPISODE-NORMALIZATION-IMPLEMENTATION-PENDING-CI.zip`

## Existing implementation found

- `lib/video_providers/unified/quickjs/js_bootstrap.dart` already initialized `globalThis.__settings` and registered a `getSettings` function reference in the provider namespace.
- `lib/video_providers/unified/quickjs/quickjs_provider_runtime.dart` loaded each provider into the shared runtime and mediated calls, but did not invoke `getSettings`, persist settings, or inject saved values.
- `lib/video_providers/unified/source_manifest.dart` supplies the existing `stableKey` identity used by installed-source preferences.
- `lib/screens/common/source_repositories_screen.dart` already lists installed/uninstalled sources; no provider-specific configuration editor existed.
- `flutter_secure_storage` and a reusable vault abstraction are already dependencies/patterns in this project. The phase reuses the installed package rather than adding another storage dependency.
- Repository export/import serializes repository URLs and install flags. Settings secrets must stay out of that export path.

## Six-repository applicability review

The Phase 36 repository catalog was rechecked to decide which entries belong to this QuickJS-only phase. The review deliberately separates repository presence from the presence of a `getSettings()` contract:

- OpenStream Official: the inspected index declares VidKing Direct and native source engine types (including its Anikoto/Re:Anime engines), not QuickJS provider scripts. These entries are not routed through this QuickJS settings editor; their configuration belongs to their own engine contracts.
- Spyou Zangetsu Providers: sampled `providers/anikoto.js` and `providers/uhdmovies.js` do not declare `getSettings()`. They receive no invented settings fields.
- Serenity-MIST Zangetsu Sources: includes concrete `getSettings()` schemas and provider-side reads from `__settings[__SOURCE_ID]`; this is the positive compatibility sample for the new UI/runtime contract.
- Spyhell Experiment: sampled `providers/animesuge.js` does not declare `getSettings()`. The same repository also catalogs Live TV-oriented providers; they remain outside this QuickJS VOD settings UI and are handled by the dedicated Live TV phases.
- Spyou Additional Providers: sampled `providers/animesalt.js` does not declare `getSettings()`.
- Spyhell Latin Sources: sampled `providers/animeav1.js` does not declare `getSettings()`.

The indexes and the above source samples were checked against their current raw repository files on 2026-11-06. The implementation does not infer settings from repository name, source type, or source title: each installed QuickJS provider is queried for its own `getSettings()` declaration at runtime. A missing declaration results in the explicit no-settings state. This is intentionally narrower and safer than pretending every entry in all six repositories supports the same configuration API.

## Real provider schema samples inspected

- Serenity-MIST `serenity-anikoto.js` (repository version 0.2.9) defines `getSettings()` with `enum` fields for audio language, timeout, episode audio and home ordering, plus a `bool` subtitle toggle. Its `setting()` helper reads `__settings[__SOURCE_ID]`, validates enum values against declared options, and contains the `multiEnum` read path. Source: `https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/serenity-anikoto.js`.
- Serenity-MIST `serenity-cinestream.js` (repository version 0.2.9) defines movie/series catalog settings using `enum` and `bool`: timeout, audio language, stream server, same-title preference, catalog selection and subtitles. It uses the same provider-scoped settings contract. Source: `https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/serenity-cinestream.js`.
- The inspected Spyou `providers/uhdmovies.js` and `providers/anikoto.js` do not expose a `getSettings()` implementation. These sources must remain configurable-free rather than receiving guessed controls.

## Required preservation boundaries

- Keep the current `QuickJsProviderRuntime`, provider namespace and engine registry.
- Do not change source `stableKey`, installed source preferences, repository configuration export, QuickJS extraction contract or player output.
- Do not enable sources automatically.
- Do not add provider-provided validation JavaScript or execute schema expressions.
- Keep credentials and other sensitive settings out of logs and non-secure preferences.

## Audit conclusion

The missing pieces are bounded schema parsing, an installed-source settings entry point, encrypted persistence, runtime injection, required-value gating, and deterministic tests for isolation and schema upgrades. These are addressed additively in the Phase 39 implementation files.
