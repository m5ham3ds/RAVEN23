# Phase 50 — WebView & Embedded Playback Integration Plan

**Date:** 2026-11-08  
**Base archive:** `RAVEN23-PHASE49.zip`  
**Output:** `RAVEN23-PHASE50.zip`  
**Status:** `Implementation Prepared — CI Pending`

## Goal

Complete the existing `webEmbed` / `vidkingWebView` pathway without replacing BetterPlayer or creating a second source engine. A source can return either a direct HTTP media stream or a distinct HTML embedded-player handoff. The HTML page must never be represented as HLS/DASH or a native video URL.

## Scope

1. Audit the existing OpenStream Web Embed MethodChannel, QuickJS runtime boundary, source result model, provider loader, player menus and Android WebView implementation.
2. Model embedded pages separately from direct media streams and carry the result through the unified-to-legacy adapter.
3. Add a visible Android WebView platform view with explicit load/ready/verification/blocked/unsupported/failed states.
4. Restrict navigation to public HTTP(S), reject user-info URLs, local/reserved destinations, app deep links and HTTPS downgrade; disable mixed content and third-party cookies in the visible player.
5. Keep playback interaction user-driven. Do not auto-play, mute, click provider controls, inject page-facing application bridges or automate verification.
6. Dispose the WebView and cancel page loading when the screen exits. Preserve the existing `resolveUrl` response contract used by the anime engine.
7. Prefer direct streams during provider scans; use the first embedded page only when no direct provider succeeds.
8. Exclude embedded pages from native player maps, adaptive-quality probing, stream cache and downloads.
9. Add Mobile/TV navigation controls and focused contract tests.

## Security and privacy boundaries

- No CAPTCHA, Cloudflare, DRM, authentication, subscription or geographic restriction bypass.
- A challenge page may be presented for the user to handle manually; it is not solved by the application.
- The visible WebView exposes no `JavascriptInterface` to page JavaScript.
- Android's standard `CookieManager` remains process-wide. Third-party cookies are disabled for this view, but the implementation does not claim a per-source isolated CookieJar and does not delete the user's first-party cookies on exit.
- Native WebView DNS resolution cannot be pinned to the address checked by Dart. The native guard blocks local hostnames and private/reserved IP literals, while DNS rebinding remains a documented platform limitation.

## Acceptance criteria

- Direct media URLs still flow to BetterPlayer with existing headers/subtitles/expiry data.
- Embedded HTML opens only in the dedicated WebView screen.
- A provider returning only an embedded page does not prevent other providers from being tried for a direct stream.
- Download and adaptive-quality paths never treat an embedded page as a media file or manifest.
- Leaving the embedded screen stops loading and destroys its WebView instance.
- Verification is manual; navigation failure does not create an automatic reopen loop.
- CI, analyzer, device behavior and Release remain unaccepted until the configured gate actually runs.
