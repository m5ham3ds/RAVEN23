# Phase 39 — QuickJS Settings System — Tests

## Added deterministic tests

`test/video_providers/quickjs_extension_settings_test.dart` covers:

- `bool`, `enum`, `multiEnum`, `password`, text and numeric schema normalization.
- Defaults, options, numeric bounds, required values and allowlisted validation.
- Rejection of oversized schemas and ignored invalid, duplicate or unsupported fields.
- Source isolation using separate repository/source identities.
- Secure-vault storage keys containing only a SHA-256 identity digest.
- Schema evolution preserving compatible values while dropping removed settings.
- Rejection of invalid required values without overwriting prior settings.
- Provider wrapper lexical settings scope.

## Actual execution status in this environment

- JSON translation files: parsed successfully with Python.
- GitHub Actions workflow YAML: parsed successfully with PyYAML.
- CI references to the new Dart source and test paths: statically verified to exist.
- `dart format`: **not run**; Dart SDK is unavailable in this environment.
- `flutter analyze`: **not run**; Flutter SDK is unavailable in this environment.
- `flutter test`: **not run**; Flutter SDK is unavailable in this environment.
- Android Release build: **not run**; must be confirmed by GitHub Actions.

CI includes the new settings test in both its formatting gate and focused source-contract test command, as well as the full Flutter test suite.


## Additional deterministic coverage

- Required enum fields with no explicit default remain unselected and block runtime dispatch until the user chooses a value.
- Secure-storage payloads above 64 KB are rejected before writing.
- Provider console output is redacted against the current extension’s sensitive settings before logging.
- The normalized `getSettings()` schema itself is limited to 64 KB in addition to field and option count limits.
