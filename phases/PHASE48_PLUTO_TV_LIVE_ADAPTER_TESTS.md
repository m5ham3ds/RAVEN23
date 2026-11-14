# Phase 48 — Pluto TV Live Adapter Tests

**Status:** Tests authored — execution pending.

## Focused service contracts

1. `getCatalog()` fails closed with `LiveTvProviderUnavailableException`.
2. `getStream()` fails closed with the same explicit unavailable contract.
3. No catalogue or stream data is fabricated.
4. The service does not require a network client or issue a request.
5. The official handoff URL remains HTTPS and host-pinned to `pluto.tv`.

## Manager contracts

1. `pluto-tv` is registered once in the standard provider registry.
2. Pluto has `isExperimental == true`, no EPG and its own `pluto_tv_experimental` namespace.
3. The manager records `LiveTvProviderState.unavailable` for catalogue and stream requests, with a human-readable message and no invented HTTP status.
4. Existing provider IDs, default selection, and namespaces remain unchanged.

## UI integration review

- Mobile and Android TV both expose Pluto from the shared provider registry.
- The external action validates `https`, the exact `pluto.tv` host, and uses the system external-app handler.
- In-app error states retain provider selection and provide the external handoff.
- No WebView iframe, in-app stream player, channel catalogue, or VOD source is created.

## CI gate

The combined Phase37–48 workflow runs the existing 25 critical contract files plus `test/pluto_tv_experimental_service_test.dart` (26 explicit test files total), along with formatting, Flutter Analyze and ARM64 Release APK build. These commands are configured for CI but were not run in this editing pass.

## Manual checks still required

- Confirm the official site opens from both Android phone and Android TV form factors.
- Confirm Pluto's official app/site itself reports market, device or access restrictions without RAVEN23 attempting to bypass them.
- Only after Pluto provides written authorization and a documented API should a real channel/stream contract suite be designed.
