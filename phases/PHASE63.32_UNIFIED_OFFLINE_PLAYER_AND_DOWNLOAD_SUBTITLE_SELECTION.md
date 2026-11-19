# PHASE63.32 — Unified Offline Player and Download Subtitle Selection

## Scope
Keep downloaded playback on the same BetterPlayer surface and gesture system used by online playback, while retaining a fully local source and the existing Media3 download cache/export implementation.

## Changes
- Completed Media3 downloads can be prepared by the existing cached MP4 exporter through the download bridge's `prepareForPlayback` method.
- Android offline playback now passes that local file to BetterPlayer instead of creating a separate Media3 `PlayerView`. This restores the app's BetterPlayer gesture handling, seek bar, fullscreen, crop, playback actions, and player timeline behavior.
- The offline player restores per-title cached subtitle tracks before setup; the downloaded sidecar subtitle is added as another local track. The subtitle sheet lists the tracks available locally and can open the existing online subtitle search/download flow.
- The episode picker filters to completed downloads for the same series and season, and switching replaces the current offline player with the selected downloaded episode.
- The download picker now asks for a subtitle track after the resolution choice. Choosing “Continue without subtitles” is always available; selecting a track stores its URL, language, and headers with the download.
- Audio is selected automatically: Media3 prefers English; when the manifest has no English track its normal default/original-track fallback remains in effect. The forced audio-selection dialog is removed from the download flow.

## Validation focus
- Verify the completed download is exported once and reused on subsequent offline plays.
- Verify offline playback starts from a local file and does not require a network URL.
- Verify downloaded and previously cached subtitle files are available immediately, and new external subtitle downloads are cached under the same title identity.
- Verify only completed same-series/same-season episodes appear in the offline episode picker.
- Verify download audio prefers English without presenting an audio picker, and subtitle choice occurs after video quality selection.
