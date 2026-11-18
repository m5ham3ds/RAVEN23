# Phase 40 — CI Stremio Test Recovery

**Date:** 2026-11-07  
**Observed run:** GitHub Actions run `42321267991`, job `128246125959`  
**Status:** Local correction prepared; CI rerun required.

## Observed result

- `dart format`: reached/passed in this observed workflow.
- `flutter analyze`: passed; the job proceeded to focused tests.
- Focused tests: **138 passed, 7 failed**.
- Full test suite and Android Release build: not reached.

The supplied log names the seven failures but does not include assertion diffs or stack traces. No exact Expected/Actual values are claimed.

## Failing tests named by CI

1. `source_repository_client_test.dart`: enriches Stremio entries from OpenStream-style indexes with manifest IDs.
2. `source_repository_parser_test.dart`: parses a Stremio manifest URL as a source entry.
3. `source_repository_parser_test.dart`: `configurationRequired` remains authoritative when `configurable` is false.
4. `source_repository_parser_test.dart`: configurable but not configuration-required add-ons remain runnable.
5. `source_repository_parser_test.dart`: `configurationRequired` is distinct from `configurable` and remains explicit.
6. `source_repository_parser_test.dart`: preserves configured manifest path/query but omits fragment and config token.
7. `source_repository_parser_test.dart`: rejects a Stremio manifest without a resources array.

## Root causes found in code review

### 1. Empty URI fragment was retained

`Uri.replace(fragment: '')` means an empty fragment component, not the absence of a fragment component. The parser used it while deriving the base Manifest URL and `/configure` URL. This could append an empty `#` to generated URLs and break exact URL comparisons. It also meant the implementation did not fully satisfy the documented fragment-removal requirement.

**Correction:** switch to `Uri.removeFragment()` after path/query transformations. Query behavior is intentionally distinct: runtime Manifest/stream requests retain source-specific query parameters; the external configuration URL clears them to avoid exposing tokens. The repository client also removes fragments from generated HTTP URLs.

### 2. Malformed Manifest without resources was not identified as a Manifest

`_isStremioManifest` originally required both `id` and `resources`. A document that clearly had Stremio manifest fields but omitted `resources` was therefore treated as a generic repository, bypassing the parser's `FormatException` for missing resources.

**Correction:** identify a Manifest candidate by `id` plus any recognized Stremio-specific field (`resources`, `types`, `idPrefixes`, `catalogs`, `behaviorHints`, or `config`). The Stremio parser then validates `resources` and rejects missing/empty arrays.

## Code/test changes

- `lib/video_providers/unified/source_repository_parser.dart`
- `lib/video_providers/unified/source_repository_client.dart`
- `test/video_providers/source_repository_parser_test.dart`
- `test/video_providers/source_repository_client_test.dart`
- `.github/workflows/android-ci.yml` — expanded reporter for targeted and full test commands.
- `phases/PHASE40_STREMIO_MANIFEST_CONFIGURATION_{IMPLEMENTATION,TESTS,CHANGELOG,REPORT}.md`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_56.md`
- `phases/MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md`
- `phases/README_MASTER_IMPLEMENTATION.md`

## Regression coverage added

- Direct Manifest endpoint has no fragment component.
- `/configure` URL has neither query token nor fragment component.
- Client-generated Manifest request URL keeps configured query parameters but has no fragment.
- Existing no-resources test now routes to Stremio validation and must throw `FormatException`.

## Validation status

Static source review and workflow syntax checks are performed at packaging. Dart/Flutter SDK is unavailable in the packaging environment, so the focused tests, full tests, analyzer, formatter, Release ARM64 build, and Android device checks were **not rerun locally**. CI must be rerun.

**Acceptance:** `In Progress`. Do not mark Phase 40 accepted until CI passes Analyze, focused tests, full tests, and Release ARM64 build. Earlier Phase 37/37.1/38/39 gates remain unchanged and pending.


## Follow-up CI result — empty query delimiter (2026-11-07)

The next expanded CI log narrowed the previous seven failures to **5 failed / 140 passed**. The formerly failing tests for Manifest-candidate detection and the basic Stremio URL parse now pass. All five remaining failures have the same exact assertion difference:

- Expected: `https://addon.example/config/configure`
- Actual: `https://addon.example/config/configure?`
- Path-config case: expected `https://addon.example/users/secret/configure`, actual the same URL with a trailing `?`.

The earlier `Uri.removeFragment()` correction was necessary but incomplete: `_stremioConfigurationUrl` then called `.replace(query: '')`. Dart serializes an explicitly empty query component as a trailing `?`; it is not the same as an absent query. The same empty-query marker could also remain on a source URL that explicitly ended in `?`.

**Correction prepared:**

- `_stremioConfigurationUrl` now constructs the browser URL from scheme, host, explicit port, and normalized path segments only. Query and fragment components are not represented at all, ensuring private manifest tokens are not exposed and no empty `?` is emitted.
- `_stremioBaseUrl` still preserves non-empty configured query material for runtime Manifest/stream requests, but removes the trailing delimiter when the query component is explicitly empty. Fragments remain removed.
- Added a regression test using a Manifest URL ending in `?#ignored-fragment`; it asserts that neither the derived runtime endpoint nor `/configure` URL has a query or fragment component.
- Existing path/query regression continues to assert that non-empty runtime query values are retained while the `/configure` link excludes them.

**Validation:** the source/test changes are reviewed and the test is included in the Dart format target list. Dart/Flutter are unavailable in the packaging environment, so no new test/analyze/Release pass is claimed. Re-run CI; the expected targeted suite should now cover the empty-query and non-empty-query cases independently.

**Acceptance remains:** `In Progress` until CI passes Analyze, focused tests, full tests, and Release ARM64 build.
