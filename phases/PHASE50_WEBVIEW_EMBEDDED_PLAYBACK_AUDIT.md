# Phase 50 — WebView & Embedded Playback Audit

**Date:** 2026-11-08  
**Base:** `RAVEN23-PHASE49.zip`

## Existing architecture

- `OpenStreamWebEmbedSourceEngine` already attempts direct hoster resolution before asking the Android bridge to inspect an embed page.
- `OpenStreamWebEmbedBridge` uses a hidden WebView and a narrow `Raven23Sniffer` capture interface for network media/subtitle observations.
- `QuickJsProviderRuntime` and the existing source registry already own provider execution; no parallel registry is required.
- `UnifiedSourceResult` and the legacy `ProviderLoadResult` adapter previously represented only direct streams.
- Movie/TV loaders and `PlayerOne` built native source maps from all returned URLs, so an HTML page had no safe route to render.
- The hidden resolver injected a periodic nudge which muted/played `<video>` and clicked common play buttons.
- `resolveUrl` is also used by the OpenStream Anime engine and must keep its list response contract.

## Gaps addressed

1. No typed embedded-player result.
2. No visible WebView handoff after direct extraction returned no media URL.
3. Embedded pages could be counted as native video options by legacy result paths.
4. The provider queue could stop at the first page candidate instead of continuing for direct links.
5. The sniffer performed automatic interaction rather than observation only.
6. No explicit embedded-screen lifecycle/status/control contract existed.

## Constraints retained

- Existing direct hoster/QuickJS resolution remains first.
- BetterPlayer remains the native direct-stream player.
- Existing anime `resolveUrl` callers retain their legacy list response.
- The visible WebView does not receive an application JavaScript bridge.
- Standard Android WebView cookie storage is shared by the app process; this phase does not provide isolated cookie profiles.
