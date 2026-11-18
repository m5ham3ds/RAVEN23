# Phase 43 — OpenStream Sources Implementation

## Base and preservation

- Base archive: `RAVEN23-PHASE42-IMPLEMENTATION-PENDING-CI.zip`.
- Phase 42 and Phase 41 are carried forward with their prior `CI pending` status; starting Phase 43 was explicitly requested by the user.
- Existing engine registry and playback pipeline are retained. No player engine, player adapter contract or fallback ranking changes were made.

## Implementation changes

### Source manifest and lifecycle contracts

Extended the official OpenStream fixture test so each VidKing id is matched to its exact route, all nine entries stay runnable and status 1, default-install flags are preserved exactly, Web Embed entries remain status 3 fallbacks with both movie/TV placeholders, and the five Anime entries remain status 3 and experimental in lifecycle state, while Anikoto/Re:Anime default-install flags are retained exactly as upstream declares.

### VidKing request dispatch

Added a deterministic Dio-interceptor test that parses the official fixture, issues one movie request through each of the nine declared VidKing routes, and asserts the route path associated with each id. A separate series request checks `mediaType=tv`, the exact `seasonId`, and exact `episodeId`. The stub responds with 503 after recording the request, so no playback claim is made.

### Native Anime identity mapping

Added deterministic Re:Anime tests with stubbed ani.zip and AniList responses. The fixture checks exact season 2 episode 4 mapping to AniList episode 8, and confirms a mapped anime film is requested through episode slot 1. The Re:Anime embed HTML fixture intentionally has no player id; this tests identity/routing only.

### Unified stream expiry metadata

Added `parseStreamExpiry`, which accepts source-provided ISO-8601 values, `DateTime`, epoch seconds and epoch milliseconds. VidKing Direct forwards explicit expiry from source-entry or payload fields (`expiresAt`, `expires_at`, `expiry`, `expiration`). OpenStream Anime adapters forward explicit expiry from returned payload maps where those fields exist, including Re:Anime, FourAnimo, WebView-captured Anikoto results and the shared MegaPlay resolver. No fallback TTL is created. FourAnimo now preserves expiry while copying the common stream option into its extended metadata object.

### CI scope

The automatic APK gate is a finite, explicit 15-file list, combining only the required dependency and current phase contracts from Phase 37/38/40/41/42/43. It retains 10-minute step timeout, 30-second per-test timeout and concurrency 4. It does not run the full Flutter test tree or unrelated widget regression batches.

## Updated files

- `lib/video_providers/unified/stream_option.dart`
- `lib/video_providers/unified/vidking_direct_provider.dart`
- `lib/video_providers/unified/openstream_anime_engine.dart`
- `lib/video_providers/unified/openstream_web_embed_engine.dart`
- `test/video_providers/source_repository_parser_test.dart`
- `test/video_providers/vidking_direct_provider_test.dart`
- `test/video_providers/source_host_policy_test.dart`
- `.github/workflows/android-ci.yml`
- `tool/format_phase37_42_dart.sh` (retained filename for workflow compatibility; now covers Phase 43 changes)
- `phases/PHASE43_OPENSTREAM_SOURCES_*.md`
- Phase tracker, blueprint, source catalog and compatibility matrix.

## Not changed

- Player engine and player adapter.
- `ProviderLoader` and global fallback ranking.
- OpenStream source names, ids, declared status, endpoint and priority metadata in the fixture.
- AnimePahe anti-bot / Cloudflare bypass behavior.
- Existing Phase 41/42 acceptance state.
