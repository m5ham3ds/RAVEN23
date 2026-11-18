# Phase 46 — Implementation

## Unified manager

Added `lib/services/live_tv_service_manager.dart` with:

- Stable provider IDs for DaddyLive and EthioSports.
- Immutable provider definitions (label, unique database namespace, EPG capability and lazy factory).
- Shared `LiveTvServiceManager.standard(...)` registry used by both Mobile and Android TV; new provider registration is centralized rather than duplicated in either screen.
- Persisted provider selection under `live_tv_selected_provider_v1`; default/fallback remains DaddyLive.
- Lazy construction and ownership of service instances; all instantiated services are closed once by `close()`.
- Shared delegation for catalog, category, refresh and stream operations through the existing `LiveTvService` interface.
- Provider health states: `idle`, `loading`, `available`, `empty`, `error`, `unavailable`, `blocked`.
- Status mapping: HTTP 401/403 => Blocked; 404/408/410/425/429/5xx and network/client/timeouts => Unavailable; remaining failures => Error.
- Safe manager health messages; raw upstream error details are not used as the provider status label.
- Unique namespace validation to prevent accidental cross-provider persistence.
- Stream validation before playback: only absolute HTTP(S) URLs without embedded user-info are accepted; already-expired links are rejected as unavailable (HTTP-style 410 health classification).
- Playback headers are allow-listed to `Accept`, `Origin`, `Referer` and `User-Agent`, with empty, oversized and CR/LF-injected values discarded.
- Media types normalize known DASH/MPD forms to `dash`; other legacy/unknown values preserve the player's historical HLS fallback.
- ClearKey metadata is retained only when it is exactly a 32-hex key ID and 32-hex key pair. The player continues to create the standard Better Player ClearKey configuration only for that validated pair; no DRM bypass is added.
- Stream variants receive the same URL/header/media/Key validation, and expired variants are excluded. Variant expiry is retained in `LiveStreamVariant` and parsed from ISO-8601, epoch seconds or epoch milliseconds.
- The validated stream expiry is passed into `LivePlayer`. When the current link expires, automatic recovery skips stale backup variants and resolves a fresh provider stream through the manager.

## Service adapters

- `DaddyLiveService` still supplies the original DaddyLive catalog, EPG, streams, headers, expiry, media type, ClearKey metadata and variants.
- DaddyLive HTTP status is retained when non-JSON error bodies are returned. Watch-page/API failures preserve the last HTTP status for manager health classification.
- `EthioSportsService` remains an adapter to `LiveTvService`. Channel loading is independent of EPG: a failed optional guide produces an empty EPG while retaining the usable channel catalog.
- EthioSports keeps `ethio:` channel/EPG IDs and strips that prefix only when addressing the upstream stream endpoint.
- EthioSports stream URLs and variant URLs are resolved to absolute URLs while retaining headers, expiry, media type, ClearKey metadata, titles and variants.

## Mobile and Android TV integration

Both Live TV screens:

- Register DaddyLive and EthioSports via `LiveTvServiceManager`.
- Restore the selected provider and expose a provider selector.
- Use `manager.activeDatabase` for favorites, recents, cached channels, EPG and preferred sports.
- Pass the manager as the `LiveTvService` to `LivePlayer`, so in-player channel switching stays with the selected provider; the checked expiry is also passed through and used during recovery.
- Keep legacy DaddyLive share/focus deep links mapped to DaddyLive.
- Close the manager when the screen is disposed.
- Prompt for preferred sports independently per provider, after a provider is first selected and loaded.
- Expose the schedule mode only when the active provider declares EPG support.

## Storage compatibility

- DaddyLive namespace remains `daddylive`, preserving existing preference keys and cached data.
- EthioSports namespace is `ethiosports`.
- Provider namespaces are unique at manager construction.
- No destructive data migration or clearing of existing favorites/cache is performed.

## Runtime limitations

This implementation is prepared for CI. No Flutter/Dart SDK is available in this packaging environment, so compiler/analyzer/test/Release evidence must come from GitHub Actions. Mocked tests verify service contracts, not external provider uptime or physical-device playback.
