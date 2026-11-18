# Phase 48 — Pluto TV Live Adapter Implementation

**Status:** Implementation prepared — CI pending.  
**Functional status:** Experimental / external-only / in-app channel playback unavailable.

## Provider registration

`LiveTvServiceManager.standard()` registers `pluto-tv` with label `Pluto TV · Experimental`, namespace `pluto_tv_experimental`, `isExperimental: true`, no EPG capability, and the official HTTPS website. The new provider is not the default provider. The Mobile and Android TV screens consume the same provider metadata.

## Fail-closed service

`PlutoTvExperimentalLiveTvService` implements the existing `LiveTvService` interface. It intentionally makes no HTTP requests and returns no synthetic channels. Both `getCatalog()` and `getStream()` throw a typed `LiveTvProviderUnavailableException` that explains the official-app/site-only state. The manager converts that typed result into `LiveTvProviderState.unavailable` with no fabricated HTTP status code.

## User experience

The Mobile and Android TV Live screens show Pluto as an Experimental source, explain that RAVEN23 does not scrape its catalogue or extract streams, and expose an external action pinned to `https://pluto.tv/`. The external action uses the platform's application handler; it does not embed or re-host Pluto content.

## Data separation and VOD isolation

The provider uses its own `pluto_tv_experimental` database namespace. It has no channel catalogue, resolver, VOD manifest, Movie/Series source registration, or EPG integration. The original Spyhell index snapshot remains an unchanged representation of the upstream index and is not used to activate Pluto as a VOD source.

## Test and CI integration

- Added `test/pluto_tv_experimental_service_test.dart` for no-network fail-closed behavior, no fabricated channels/streams, manager health state, namespace, metadata and official HTTPS origin.
- Extended `test/live_tv_service_manager_test.dart` to assert the shared provider registry includes Pluto with Experimental metadata and isolated namespace.
- Added the new service and test to the maintained Dart format targets.
- Expanded the explicit CI contract list from 25 to 26 test files and retained the focused-test strategy (no full Flutter test suite).

## Validation status

Static file/path checks and workflow YAML validation are performed during packaging. Dart formatter, Flutter Analyze, Flutter tests, CI APK build, and real Android/Android TV external-link behavior were not run here. Phase48 therefore remains CI pending and must not be marked Passed.
