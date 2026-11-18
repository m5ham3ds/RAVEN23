# Phase 44 — Implementation Record

## Implemented

- Added `QuickJsSourceCatalogProfile` to describe known catalog-only routing constraints without hardcoding an entire repository as one media type.
- Extended `SourceManifest` with nullable upstream `declaredNsfw`, a three-state safety classification, `requiresLiveTvAdapter`, and `isArchiveCatalog` helpers.
- Extended the Zangetsu parser to preserve source type/version/language, avoid auto-installation, and attach profile metadata in engine config.
- Explicitly blocks known Spyhell `getHome()` channel groups from the VOD media resolver while leaving them visible in repository management.
- Labels archive candidates and account-backed TorBox candidate for review; no automatic activation or credential generation.
- Kept Serenity CineStream / StreamPlay series capability blocked while their current `getInfo()` declarations say Movie.
- Added translated source-manager chips in English, Arabic, Spanish and Hindi for undeclared safety, Live TV adapter pending, archive VOD, and credential review.
- Added deterministic parser/catalog tests, including duplicate candidate review without destructive deletion.

## Existing infrastructure reused

- `QuickJsProviderRuntime`, `QuickJsSourceEngine`, and `SourceEngineRegistry.standard()` were already present and remain the execution foundation.
- `SourceRepositoryManager.bundledRepositoryUrls` already contained the six intended repository indexes. No duplicate seed entries were added and no repository was auto-installed.
- The Phase 39 QuickJS settings subsystem remains responsible for provider-scoped settings and the sandbox; this phase does not create a second settings/runtime layer.

## Explicitly unchanged

- Player adapter, video URL extraction contract, media identity/season/episode matching, repository installation state, Android package/build configuration, and user activation choices.
- The official upstream indexes are not rewritten. `status`, `type`, `version`, `nsfw` and fallback signals remain upstream-driven.
