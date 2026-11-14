# Phase 46 — Existing Live TV Audit

## Inputs inspected

- `lib/services/daddylive_service.dart`
- `lib/services/ethio_sports_service.dart`
- `lib/models/live_tv.dart`
- `lib/controllers/live_tv_database_controller.dart`
- `lib/screens/common/live_tv_screen.dart`
- `lib/tv/screens/tv_live_screen.dart`
- `lib/screens/common/live_player.dart`
- `lib/provider/app_dependency_provider.dart`
- `MASTER_IMPLEMENTATION_BLUEPRINT_PHASE36_51.md`
- `IMPLEMENTATION_TRACKER_PHASE36_56.md`

## Root cause of the disabled EthioSports selector

The EthioSports import, provider enum/registration, service and database getters, and source-selector UI had been commented out in both Mobile and TV screens. The active catalog load, stream lookup, cache, favorites, recents, EPG and preferred-sports persistence were consequently DaddyLive-only. Restoring only a selector would have routed EthioSports into DaddyLive's local keys and mixed channel IDs/history.

## Existing reusable capabilities

- `EthioSportsService` already implements the `LiveTvService` interface.
- `DaddyLiveService` already implements the same interface.
- `LiveTVDatabaseController` already accepts a namespace and derives cache/favorites/recents/EPG/preferred-sports keys from it. Its default remains `daddylive`, so existing users are not migrated or reset.
- `LivePlayer` already accepts a `LiveTvService` for channel switching, so the manager can be passed without changing the player API.
- EthioSports channel IDs were already namespaced with `ethio:` in the service adapter.

## Gaps addressed

- No common provider selector or service lifecycle owner.
- Both screens were constructing/using only DaddyLive.
- EthioSports EPG was previously fetched with channels as a hard prerequisite; an EPG outage could prevent the channel list from appearing.
- Provider-specific favorites, recents, catalog cache and preferred sports needed separate namespaces.
- Provider health/status classification was not available to the screens.
- Non-JSON HTTP error pages did not always preserve their HTTP status, preventing reliable Blocked/Unavailable classification.

## Compatibility and safety boundaries

- Existing DaddyLive database keys and link IDs are preserved.
- EthioSports uses `ethiosports_*` storage and prefixed channel IDs.
- `clearKey`/DRM metadata is passed through the existing stream model only when it matches the documented ClearKey pair format; the player retains its standard ClearKey configuration validation. This phase does not implement decryption or DRM bypass.
- Provider endpoint URLs are not rewritten beyond EthioSports' existing relative-URL resolution. Playback stream URLs are validated as absolute HTTP(S), approved headers are allow-listed, HLS/DASH is normalized to the existing player contract, and expired or malformed links/variants are rejected.
- No external provider is auto-enabled or marked verified by this phase.
