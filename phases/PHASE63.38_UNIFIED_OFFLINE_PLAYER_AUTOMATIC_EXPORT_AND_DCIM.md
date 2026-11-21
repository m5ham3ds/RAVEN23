# PHASE63.38 — Unified BetterPlayer offline playback, automatic export and DCIM library (2026-11-21)

## User requirements

The Downloads screen must play every completed offline title with the same RAVEN23 primary player used for online playback. It must retain the same controls, gestures, subtitle interface and episode selection. Network-only actions must not resolve a provider, quality or remote stream while offline. User-facing copies belong under `DCIM/RAVEN23`, not `Documents/RAVEN23`.

## Findings carried forward

- `OfflinePlayerScreen` previously selected an Android `AndroidView` registered as `com.m5ham3ds.raven23/offline_player`. That view hosted a separate Media3 `PlayerView`, while the BetterPlayer setup path was skipped on Android. This was the direct source of the inconsistent offline player surface.
- `StreamDownloadExporter` already validates the completed Media3 cache before exposing a persistent local MP4. The export was only requested by explicit playback / external-player operations; no listener queued it when a download completed.
- `StreamDownloadsBridge` limited exports to one at a time, so automatic preparation must serialize downloads and let manual play/save requests join the same pending export.
- The historical 63.35 / 63.37 decision to render a native Media3 offline PlatformView is superseded by this phase. The Media3 cache remains the download source; it is no longer a separate offline player UI.

## Implementation rules

1. `PlayerOne` is the only in-app movie / episode player surface. Offline playback receives a validated local MP4 through `BetterPlayerDataSource.file`; it does not receive the online URL, provider scan, or a second native player view.
2. The offline subtitles passed to the primary player are the cached subtitle files and the selected downloaded subtitle file. The existing subtitle menu and explicit online subtitle search remain available; subtitle toggling does not depend on changing the video source.
3. TV episode selection is built from completed downloads for the same series. It retains the online episode-card details (still image, name, rating, runtime and overview), and its season selector appears only when more than one season has downloaded episodes. Season switching reads downloaded episode metadata locally and resolves only completed downloads; it must never call TMDB or an online `TVVideoLoader` while offline.
4. Provider / quality / recommendation actions are guarded in offline mode. The watch-page provider, download and external-player chips use the existing disabled `onTap: null` presentation. The primary control row's existing action callbacks remain present but return without attempting a network operation.
5. Export preparation must begin concurrently with the active download as soon as there is cache data that can be safely staged. The final MP4 is still published only after full media validation. Preparation work, playable-prefix verification and final export are separate states; UI must not label an unverified partial file as ready. Existing completed downloads must still be recovered and prepared at startup.
6. Progressive MP4 is copied directly from the read-only download cache only when DownloadManager reports a completed MP4 with an exact known content-length match. HLS/DASH and all other cases use Media3 Transformer and the existing video/audio/duration validation.
7. Partial playback is a required capability, not an optional or permanently disabled design. Preparation must inspect the cache while download is active and expose only a verified contiguous playable timeline from time zero. A byte percentage (including 1% or 40%) is never treated as timeline availability. For HLS/DASH, verify the manifest, initialization data and every required audio/video segment up to the proposed boundary; for progressive MP4, verify the container/index and media data required by the player. Stop at the first missing, incomplete or undecodable range. Until the cache-only BetterPlayer bridge and these per-format checks pass their acceptance tests, keep the existing completed-file path as a safe fallback and do not claim partial playback is implemented.
8. Public copies, including downloaded subtitle files, use `DCIM/RAVEN23` on Android Q+ through MediaStore and `Environment.DIRECTORY_DCIM` on older Android versions. The app-private validated working MP4 remains under `filesDir/offline_exports`; it is not the user's public library folder.

## Validation

- Preserve the existing 200 MB storage reserve and incomplete-download guard.
- Preserve source priorities, default PRIMARY / BACKUP order, provider catalog, HLS/DASH headers, signed-link recovery, and the download cache identity.
- Persist the source series poster/backdrop, current-season episode metadata (still path, title, rating, runtime, air date and overview) and season metadata with each episode's native download request. Return them through the download event map so offline playback can reconstruct the same cards and build a local list of seasons that actually have downloaded episodes.
- A selected provider subtitle or selected external subtitle must be copied into the app-private offline subtitle directory. A selected subtitle that was requested but failed to persist must be reported as a subtitle-save failure; it must never be silently described as saved.
- Run focused Flutter and Android JVM gates through GitHub Actions after committing the changes. Add round-trip tests for episode/season metadata and tests that selected external subtitles are passed into the native offline request.
- Manual device checks remain required for an offline MP4, an HLS episode with multiple segments, switching between downloaded episodes, choosing cached/local subtitles, switching to an online subtitle after reconnecting, saving video and subtitle into DCIM, and opening the app with previously completed downloads.

## Scope and supersession

This phase changes only offline playback routing, export scheduling / progress reporting and public save location. It does not change backend APIs, Firebase, source catalog order, PRIMARY / BACKUP priority, quality selection policy, or the online primary player design. It explicitly supersedes the Android native offline-player route and Documents destination described in PHASE63.35 / PHASE63.37.
