# RAVEN23 Phase 44–45 CI Recovery — 2026-11-08

## Run evidence

GitHub Actions run `42424422614` (commit `ec714da53d7d6ef60576a46f80ee53a463e4d1a0`) passed Flutter analyze (`No issues found`, 25.4s) and Dart format check (53 files, 0 changed). The selected 19-file critical test gate then finished with **175 passing and 4 failing tests**. Gradle wrapper generation, Android Release APK build and ABI audit were not reached; no APK was generated in this run.

## Four regressions corrected

1. **Repository preview activation:** the saved preview revision is reloaded to verify its manifest metadata and captured document bytes, then the exact in-memory `preview.candidateManifest` the user reviewed is passed to `_fetchCatalog` through an ephemeral identity-keyed snapshot. This avoids using the persistent rollback preference for a one-time approval and avoids applying the redacted on-disk representation as the runtime manifest. The test still verifies the approved content is used without a second network fetch and that later rollback/resume works.
2. **Stremio mocked-Dio tests (2):** fake `.example` hosts were blocked by the production-default DNS resolver before the fake adapter could run. `SourceEngineRegistry.standard` now permits a policy to be injected; strict DNS resolution remains the default. Only the two fake-adapter tests inject `SourceHostPolicy(resolveDns: false)`.
3. **Zangetsu Beta/fallback metadata:** the parser now preserves upstream `status` (clamped to 0–3), explicit `fallback`, and declared tags for `sources` entries. The fixture checks both Beta and fallback metadata.

## Scope preserved

- The 19 required CI test files are unchanged.
- No tests were deleted, skipped or weakened.
- Full Flutter test suite and unrelated UI batches remain excluded.
- Production host validation defaults remain strict.

## Validation status

The supplied CI run is the evidence for the original failures and successful analyzer/formatter stages. This container has no Flutter or Dart SDK, so the corrected tests and build cannot be rerun locally. The recovery ZIP is prepared for a new GitHub Actions run. Phase 44/45 remain **CI pending** until the 19-file gate, Release ARM64 APK and ABI audit pass. Phase 41–43 remain pending as previously recorded.
