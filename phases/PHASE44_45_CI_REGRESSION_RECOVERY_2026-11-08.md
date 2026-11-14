# Phase 44–45 CI Regression Recovery — 2026-11-08

## Observed run

- Workflow: `RAVEN23 Local Android APK Build`
- Run ID / attempt: `42424422614` / `1`
- Commit tested: `ec714da53d7d6ef60576a46f80ee53a463e4d1a0`
- Result: failed in `Required Phase 37–45 critical source-contract tests`.
- Static checks: `flutter analyze` passed with `No issues found` (25.4s); the 53-file Dart format check passed with 0 changes.
- Tests: **175 passed, 4 failed** in the selected 19-file gate.
- Gradle wrapper generation, Android Release build and APK ABI audit were skipped after the test-gate failure. No APK was produced by this run.

## Failure analysis and corrections

### 1. Approved repository preview was not activated

`SourceRepositoryManager.applyPreviewedRepositoryUpdate` saved a verified revision, then routed activation through a temporary SharedPreferences rollback override before rebuilding the catalog. That transient handoff did not produce an activated repository in CI. The method now reloads the saved revision through `SourceRepositoryArtifactStore.loadRevision` (which verifies manifest metadata and captured document bytes), then supplies the exact in-memory `preview.candidateManifest` that the user reviewed to `_fetchCatalog` using an ephemeral identity-keyed snapshot map. It does not apply the sanitized on-disk manifest as the runtime payload, and the persistent rollback selection is left untouched. A set of activated staged repository keys confirms the staged snapshot was actually consumed. The existing test still checks that applying the preview causes no second repository network fetch and that explicit rollback/resume works afterward.

### 2–3. Mocked Stremio registry tests were blocked by real DNS preflight

The two failing tests use `.example` endpoints and a fake Dio adapter. `SourceEngineRegistry.standard` always created a default `SourceHostPolicy` with DNS resolution enabled, so the host policy could reject the non-resolvable test host before Dio's fake adapter saw a request. The registry factory now accepts an optional `SourceHostPolicy`; its default remains `const SourceHostPolicy()` (strict DNS validation). The two mocked-Dio tests explicitly pass `const SourceHostPolicy(resolveDns: false)`. Production security behavior is unchanged.

### 4. Zangetsu Beta/fallback metadata was discarded

The Zangetsu `sources` parser generated tags and engine metadata but did not copy the upstream `status`, `fallback` or declared `tags`. As a result, an upstream Beta entry (`status: 3`) defaulted to status 1. The parser now preserves the numeric status bounded to 0–3, the explicit fallback flag, fallback tags and declared tags. The focused test now includes both a Beta entry and a fallback entry.

## Scope and CI gate

- The required CI gate remains the same 19 explicit test files.
- No tests were removed, skipped or downgraded.
- No full Flutter test suite or broad widget regression suite was added.
- Only the two tests using mocked Dio inject DNS-disabled host policy; application defaults remain strict.

## Current acceptance status

- Phase 44: remediation prepared; CI rerun pending.
- Phase 45: dedicated execution and fairness tests passed in the observed run; overall shared gate failed due to the repository preview, Stremio test-fixture and Zangetsu metadata cases. Phase 45 acceptance remains pending the full combined gate and Release ARM64 build.
- Phase 41–43 validations remain pending as previously recorded.
- No Phase 46 work has started.

The container used to prepare this patch does not have Flutter/Dart installed. The corrected focused tests, `flutter analyze`, Release ARM64 build and ABI audit must be rerun in GitHub Actions before acceptance.
