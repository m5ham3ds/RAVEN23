# Phase 39 — QuickJS Settings System — Implementation

**Status:** Code and fixtures added; Dart/Flutter validation pending local/CI execution.

## Application changes

- Added `quickjs_extension_settings.dart` with bounded schema parsing, supported type aliases (with integer-only validation for integer aliases), field validation, schema fingerprints, secure-vault interface, source-key hashing, and a 64 KB schema/storage bound.
- Added `quickjs_extension_settings_service.dart` to call provider `getSettings()`, parse its declared schema, and load/save/reset validated values.
- Updated `quickjs_provider_runtime.dart` to discover/cache each provider schema, load secure settings, reject incomplete required settings, and inject values before normal provider calls.
- Updated `js_bootstrap.dart` so each provider wrapper owns a lexical `__settings` object and the host injects values using the registered source-specific setter. The shared `globalThis.__settings` object remains empty; no populated cross-provider settings map is exposed.
- Added `quickjs_source_settings_dialog.dart` to render boolean, enum, multi-enum, text/password and numeric settings dynamically, using provider labels/options/defaults. Reset recreates dropdown and multi-select controls so every input returns to its default state.
- Added a settings button for installed QuickJS providers in `source_repositories_screen.dart`. Providers without `getSettings()` display a clear no-settings message.
- Added English, Arabic, Spanish and Hindi labels for the settings UI.
- Extended Android CI format and focused-test lists for the Phase 39 files.

## Persistence and schema evolution

- Storage key: `raven23.quickjs.settings.v1.` + SHA-256 of `SourceManifest.stableKey`.
- The secure payload records the storage schema version, provider version, normalized settings-schema fingerprint and only validated values.
- A schema refresh preserves values only when the same key remains present and its value still validates against the new field. Removed or incompatible values are dropped; new fields receive validated defaults.
- All values use Android secure storage, including ordinary preferences, so future secret fields are not accidentally placed in plain preferences.
- Repository config export/import is unchanged and does not include source settings.

## Runtime behavior

- The first ordinary method call in a runtime discovers `getSettings()` once per loaded source version.
- A malformed/absent schema does not block ordinary operations; the settings UI surfaces malformed schemas and identifies sources with no settings.
- Valid settings are loaded before `getInfo`, `search`, `getDetail`, `getEpisodes` and `getVideoSources`.
- Required values are checked before dispatch; error text includes field labels only, never values. Console messages from an extension are scrubbed against that extension’s current sensitive settings before they reach `debugPrint`.
- Each extension's lexical settings object is kept outside the shared `globalThis.__settings` map; there is no populated global settings dictionary for another provider to read. This is logical scope isolation inside the existing shared QuickJS runtime, not a claim that third-party JavaScript is a separate OS-level security sandbox. The settings-dialog runtime is disposed after schema retrieval to avoid leaving a dedicated QuickJS engine alive after the dialog closes.

## Non-goals preserved

No source was installed or enabled, no repository URLs were changed, and no OpenStream/Stremio/VidKing/Web Embed/Live TV/player implementation was replaced.
