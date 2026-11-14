# Phase 44–45 CI Recovery — 2026-11-08

## Observed CI run

- Workflow: `RAVEN23 Local Android APK Build`
- Run ID: `42422826322`, attempt `1`
- Commit: `79b601d6052f08fd5aab8de85fb522643bd88d96`
- Result: failed at `Flutter analyze` after dependency resolution and formatting.
- The 19 required source-contract tests, Gradle wrapper generation, APK build and ABI audit were **not reached**. They were skipped, not failed.

## Findings and corrections

| Finding | Correction |
|---|---|
| Three `const StateError(...)` expressions in `source_repository_manager.dart` | Removed `const`; `StateError` has no const constructor. |
| `SourceManifest.engineIdentity` unresolved in `unified_source_service.dart` | Imported `source_contracts.dart`, where `SourceManifestContracts` declares the extension getter. |
| `Headers.locationHeader` unresolved in the Stremio redirect test | Replaced the unavailable Dio constant with the standard case-insensitive HTTP header key `'location'`. |
| Unused `dart:io` import in `quickjs_provider_runtime.dart` | Removed; this runtime makes network requests through Dio and uses no `dart:io` types. |
| Unused `dart:typed_data` import in `stremio_addon_provider_test.dart` | Removed; `Uint8List` is already available through `flutter/foundation.dart` in this test. |
| Unused `nextFallback` local in `unified_source_service.dart` | Removed the abandoned local; it had no reads or writes beyond its declaration. |
| `prefer_interpolation_to_compose_strings` info | Rewrote the source summary as adjacent interpolated string literals. |
| `curly_braces_in_flow_control_structures` info | Added an explicit block around the `if` body in `js_engine.dart`. |

The Dart formatter patch supplied by CI was applied to the 35 tracked Dart files it changed, excluding the generated localization loader. The loader was removed from the maintained format target list: the SDK formatter produced approximately 18,000 lines of mechanically changed generated output without a functional change. The maintained format list now has 53 existing Dart targets.

## Build gate preserved

The workflow remains intentionally narrow:

- `flutter analyze --no-fatal-infos` (errors and warnings remain fatal).
- The same 19 explicit Phase 37–45 contract/regression test files.
- No full Flutter test suite and no unrelated widget regression batch.
- Release ARM64 APK build and ABI audit after the test gate.

No new tests were added solely to work around this analyzer failure, and no test files were removed. The 19-file list is unchanged.

## Validation limits

The supplied analyzer log is the evidence for the failure. The corrections above address every finding in that log. This container does not have Flutter or Dart installed, so a fresh `flutter analyze`, the 19 tests, and the Android Release build could not be executed here. The next CI run is required to verify the corrections and reveal any later-stage failures.

## Acceptance status

- Phase 44: implementation prepared; CI rerun pending.
- Phase 45: implementation prepared; CI rerun pending.
- This recovery does not mark either phase as accepted and does not alter the pending status of Phase 41–43.
