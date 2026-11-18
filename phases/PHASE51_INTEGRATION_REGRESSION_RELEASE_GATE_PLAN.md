# Phase 51 — Integration, Regression & Release Gate Plan

**Date:** 2026-11-08  
**Base:** `RAVEN23-PHASE50.zip`  
**Status (updated 2026-11-10):** `Accepted — final Release gate passed in run 42507906881`; physical playback/provider checks remain a separate device-level validation.

## Goal

Validate the combined Phase36–50 implementation without claiming acceptance from static inspection alone. Preserve the existing app, player, media identity, repositories, Live TV, EPG, embedded playback, package identity, signing configuration, and ARM64 Release settings.

## Gate sequence

1. Canonical Dart formatting for the maintained Phase37–50 source-contract files and their required tests.
2. `flutter analyze --no-fatal-infos`; analyzer errors and warnings remain fatal.
3. Explicit contract tests for source engines, repository security/versioning, QuickJS, Stremio, VidKing, OpenStream, Live TV, M3U, Spyhell, Pluto fallback, XMLTV/EPG, and Embedded WebView.
4. Phase51 regression tests for player handoff, next episode, subtitle configuration/migration, adaptive quality, offline downloads, TV remote/back navigation, TV settings, and provider loading.
5. Generate the Android Gradle Wrapper in CI using the pinned Gradle version and Flutter SDK path.
6. Build the production `prod` ARM64 APK with the existing Release flavor/defines. Debug remains an explicit manual diagnostic choice only.
7. Audit APK presence, ABI payload, size, diagnostics, and artifacts. Never treat the CI development signing key as a production distribution key.
8. Perform separate physical Android Mobile and Android TV smoke tests; CI fixtures do not prove provider uptime or playback.

## Scope controls

- No new provider integrations or feature work in this phase.
- No changes to application ID, package namespace, signing identity, Release flavor, Firebase defines, or ARM64-only target.
- Do not change `Playback Verified` status without a real stream/player test.
- Do not mark Phase36–50 accepted merely because the aggregate workflow is configured.
- Preserve Phase45 and Phase50 source archives as immutable references.

## Acceptance criteria

- Formatter and analyzer pass on CI.
- All explicit source-contract and Phase51 regression tests pass.
- ARM64 Release APK is produced and passes ABI/package artifact checks.
- No known regression remains in player handoff, subtitles, downloads, quality selection, source selection, Mobile/TV navigation, Live TV, EPG, or Embedded WebView.
- Device smoke tests are documented separately, including unavailable external providers.
- CI run URL, commit SHA, APK artifact metadata, and test totals are recorded.

## Current limitation

The packaging environment has no `flutter` or `dart` executable and no Android SDK/Gradle toolchain. Therefore no formatter, analyzer, Flutter test, Kotlin/Gradle compilation, APK build, or physical-device test is claimed by this preparation pass.
