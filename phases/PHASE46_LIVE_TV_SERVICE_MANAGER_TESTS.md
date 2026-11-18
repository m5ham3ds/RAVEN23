# Phase 46 — Tests and CI Gate

## New focused tests

- `test/live_tv_service_manager_test.dart`
  - restores a persisted provider and its database namespace;
  - lazy service factory creation;
  - catalog/refresh/category and health delegation;
  - provider selection persistence;
  - favorites/recents namespace isolation;
  - Empty, Blocked and Unavailable health classification;
  - unique namespace validation;
  - idempotent lifecycle close;
  - ISO/epoch-seconds/epoch-milliseconds expiry parsing;
  - expired stream rejection;
  - stream/variant HTTP(S) URL checks, header allow-list, HLS/DASH normalization and strict ClearKey shape validation.
- `test/ethio_sports_service_test.dart`
  - channel catalog remains available when optional EPG returns an HTTP failure;
  - EthioSports channel IDs are namespaced;
  - local `ethio:` ID is stripped for upstream stream lookup;
  - relative stream/variant URL resolution and stream metadata preservation;
  - HTTP 403 is retained for HTML/non-JSON responses;
  - DaddyLive watch-page and API fallback preserve HTTP status for health mapping.

## Bounded CI test list

The CI source-contract gate now runs 21 explicit test files. The previous 19 files are retained; only the two Phase46-focused files are added. It continues to use:

- `flutter test --no-pub --reporter expanded --timeout 30s --concurrency=4`;
- job timeout: 10 minutes;
- no full `flutter test` suite;
- no unrelated broad widget regression group.

The exact file list is maintained in `.github/workflows/android-ci.yml` and described in the generated build report. The formatter list is `tool/format_phase37_46_dart.sh`.

## Validation status

- Test source files and workflow paths are statically checked during packaging.
- Flutter format, Analyze, the 21-file test gate, Release ARM64 build, APK audit and physical Android Mobile/TV playback have not been run in this environment.
- The Phase46 additions currently contain 14 deterministic test cases across the two focused files (10 manager/stream-contract cases and 4 service-adapter cases). CI result is pending; do not mark Phase46 Passed before the workflow and device/runtime checks are reviewed.
