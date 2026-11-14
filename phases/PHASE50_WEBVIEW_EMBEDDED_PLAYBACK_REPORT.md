# Phase 50 — WebView & Embedded Playback Report

**Date:** 2026-11-08  
**Base:** `RAVEN23-PHASE49.zip`  
**Output:** `RAVEN23-PHASE50.zip`  
**Status:** `Implementation Prepared — CI Pending`

## Delivered

The existing OpenStream Web Embed flow now distinguishes captured direct streams from browser-only embed pages. Direct streams continue to BetterPlayer; embedded pages are opened in a dedicated visible Android WebView. The provider queue prefers direct results and uses an embedded page only as a final fallback. Embedded pages are excluded from native quality probing, direct stream maps, stream cache and downloads.

The hidden capture script no longer mutes/plays video elements or clicks provider controls. The visible WebView uses manual interaction and verification, a narrow network/navigation policy, localized status/action strings in the four shipped translation assets, and disposes its view on exit. The pre-existing anime `resolveUrl` List contract is preserved.

## Static packaging checks

- CI workflow YAML parses successfully.
- Formatter shell script passes `bash -n`; its declared file paths exist and are unique.
- Required test list contains 29 unique existing Dart paths; Phase50 contributes six focused contract cases in its dedicated test file.
- The formatter target list contains 91 unique existing Dart paths.
- Embedded handoff preserves the initial Referer/Origin metadata through a native allowlist; Cookie/Authorization/custom headers are not accepted.
- Embedded WebView bridge source has no autoplay / automatic play-button click logic.
- ZIP CRC/listing check is performed separately after packaging.

## Verification limits

- Dart and Flutter are unavailable in the packaging environment.
- No Dart formatting, Flutter analyzer, Flutter tests, Kotlin/Gradle build or Android APK build was run.
- No provider embed, authentication page, CAPTCHA page, or Android TV remote interaction was live-tested.
- Android WebView CookieManager is shared process storage; third-party cookies are disabled, but per-source cookie isolation is not claimed.
- DNS rebinding on WebView's internal DNS/socket path remains a platform limitation.

## Acceptance snapshot

| Requirement | Implementation | Actual runtime evidence |
|---|---|---|
| Direct stream vs embedded page distinction | Prepared | Pending CI |
| Visible Android WebView handoff | Prepared | Device test pending |
| Provider scan direct-first fallback | Prepared + focused test | Test not run |
| HTML exclusion from native maps/cache/download | Prepared + focused test | Test not run |
| Manual verification only | Prepared | Device/site test pending |
| Screen exit stops/destroys WebView | Prepared | Device test pending |
| Android TV remote focus | Controls provided | Device test pending |
| CI / Analyze / Release | 29-test gate configured | Pending |

## Next phase

**Phase51 — Integration, Regression & Release Gate.** This final phase will validate the combined Phase36–50 contracts and actual ARM64 Release build. It must not mark any phase accepted until CI and required device checks are observed.
