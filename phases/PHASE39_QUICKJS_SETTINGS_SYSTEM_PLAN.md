# Phase 39 — QuickJS Extension Settings System — Plan

**Status:** Implementation added; Flutter CI validation pending.
**Dependencies:** Phase 36 audit and Phase 37 source identity/runtime contracts. This work does not declare the earlier Phase 37/37.1/38 acceptance gates passed.

## Goal

Complete the existing QuickJS `getSettings()` / `__settings` support with per-extension schema parsing, a source-settings editor, secure persistence, schema-change reconciliation, and runtime injection. Reuse the current `QuickJsProviderRuntime`, `SourceManifest.stableKey`, source manager and source catalog UI. Do not create a second source registry or a second JavaScript runtime architecture.

## In-scope behavior

1. Read each extension's own `getSettings()` result; do not infer settings from its name or repository.
2. Normalize supported types: text/string/password, number/integer, bool/boolean, enum/select, and multiEnum/multi-select; integer aliases enforce integral values.
3. Validate key/label/options/required/default/min/max/maxLength and a small allowlist of deterministic validation rules (`url`, `email`, `integer`, `number`). Never evaluate a validation expression supplied by an extension.
4. Limit schemas to 32 fields, 50 options per field, 120-character labels, 256-character option values and 4096-character text values, 64 KB schema envelopes and 64 KB persisted settings payloads.
5. Show settings only for installed QuickJS extensions. Sources without `getSettings()` show an explicit no-settings state.
6. Persist values by a SHA-256 hash of the existing stable source key. Keep source version and normalized schema fingerprint in the record.
7. Store values in Android secure storage; do not add them to repository configuration export, diagnostics or logs.
8. Preserve only values that still validate against the new schema when a provider changes its schema; discard removed and incompatible values.
9. Inject settings before `getInfo`, `search`, `getDetail`, `getEpisodes` and `getVideoSources` execute.
10. Isolate the lexical `__settings` object per provider. A provider must not read another provider's settings through a shared global map.
11. Do not dispatch a provider operation when its declared required settings are incomplete.
12. Keep the existing Release/ARM64 build path and Mobile/Android TV source-manager screen responsive.

## Acceptance criteria

- Schema fixtures cover observed `bool`, `enum`, and `multiEnum` contracts plus text/number extensions.
- Invalid schemas are bounded and safely ignored for playback; invalid fields are not rendered.
- Values persist independently per repository/source identity.
- Schema changes retain compatible values and remove obsolete/incompatible keys.
- Required values are validated and cannot be bypassed by direct runtime calls.
- Settings values are stored only through the secure vault abstraction.
- Provider JS receives only its own settings object; no shared populated `globalThis.__settings` map is exposed.
- `dart format`, `flutter analyze`, focused settings tests, full `flutter test`, and Release CI are all green before acceptance.

## Out of scope

- Automatically installing sources or enabling any repository extension.
- Importing/exporting secrets with repository configuration.
- Adding a global user settings migration unrelated to QuickJS sources.
- Changing OpenStream Native, Stremio, VidKing, Web Embed, Live TV, playback routing, package identity or signing.
