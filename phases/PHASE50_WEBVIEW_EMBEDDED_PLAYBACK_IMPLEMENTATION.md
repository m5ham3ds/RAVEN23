# Phase 50 — WebView & Embedded Playback Implementation

**Date:** 2026-11-08  
**Status:** `Implementation Prepared — CI Pending`

## Result model and provider flow

- Added `UnifiedEmbeddedPlayerOption` with source identity, URL and readiness (`interactive` / `verificationRequired`).
- `UnifiedSourceResult` now carries `embeddedPlayer` separately; `success` continues to mean a direct playable media stream, while `hasPlaybackCandidate` is used for attempt diagnostics/circuit health.
- `OpenStreamWebEmbedSourceEngine` reads the structured `resolveEmbed` response. It returns direct streams when captured, otherwise an embedded handoff only for a page that loaded or requires visible verification.
- The `resolveUrl` method preserves its original List contract for the anime engine.
- The unified-to-legacy adapter serializes embedded handoffs as explicitly marked `RegularVideoLinks` options (`isEmbeddedPlayer`), not as HLS/DASH streams. The legacy-to-unified adapter also maps a flagged legacy page into `embeddedPlayer` and omits it from direct stream results.

## Visible Android WebView

- Added `EmbeddedWebPlaybackViewFactory` and the `embedded_web_player` PlatformView registration.
- Added `EmbeddedWebPlaybackScreen` with mobile and TV controls, back/reload/close behavior and status banner; all user-facing status/actions are localized through the existing `en`, `ar`, `es` and `hi` translation assets.
- Main-frame and subresource requests are limited to HTTP(S) public destinations; local/reserved literals, local hostnames, user-info URLs, deep links and HTTPS downgrade are rejected. Initial navigation accepts only `Referer`, `Origin` and `User-Agent` headers after validation; Cookie, Authorization and arbitrary headers are not forwarded.
- JavaScript and DOM storage are enabled for compatible player pages, but no JavaScript interface is injected into the visible page. Multiple windows, automatic window opening, third-party cookies and mixed content are disabled.
- Web playback requires user gesture; there is no automatic play/mute/button click.
- The platform view stops loading, navigates to `about:blank`, clears history, detaches clients and destroys the WebView on dispose. It does not call the process-wide `WebView.clearCache()` because that would flush unrelated WebViews.

## Player / loader integration

- Movie and TV loaders send embed-only results directly to the embedded screen; downloads reject embed-only results with an explicit explanation.
- `PlayerOne` displays embed options as `WEB EMBED`, opens them in the dedicated screen and resumes prior native playback after the embedded route closes.
- Provider scanning continues after an embedded-only candidate and prefers any later direct stream.
- Embedded pages are filtered from native video/format/header maps, adaptive-quality probes and playback-stream cache.

## Privacy caveats

Android's standard `CookieManager` is app-process-wide. The visible player disables third-party cookies but does not claim a private per-source cookie jar, and it intentionally does not wipe user first-party cookies when the view closes. DNS rebinding cannot be fully prevented because WebView does not expose a way to pin every internal DNS lookup to the validated address.
