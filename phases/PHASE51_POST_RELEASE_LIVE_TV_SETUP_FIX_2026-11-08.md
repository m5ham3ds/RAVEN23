# Phase51 Post-Release Live TV Setup Fix — 2026-11-08

## Reported device symptoms

The supplied screenshots show five/six bundled source repository entries returning HTTP 200, while four manually added items show `FormatException: Unexpected character`:

- Free-TV M3U playlist URL;
- two direct Akamai HLS stream URLs;
- iptv-org M3U playlist URL.

The same screenshots show the Live TV error state without the provider selector or IPTV playlist manager.

## Root causes

1. **Wrong URL category:** Source Repositories accepts JSON repository indexes/manifests. M3U channel playlists and HLS/DASH media URLs are not JSON source repositories, so adding them there leads to a JSON `FormatException`. The green HTTP 200 entries demonstrate that the app can reach the bundled GitHub repository endpoints; the red entries are a content/format mismatch, not evidence that all Internet access is offline.
2. **Live TV error-state navigation trap:** `ChannelList._buildBody()` returned only an `EmptyState` for most provider failures. This skipped `_buildHeader()`, which contains the provider selector and, when IPTV / M3U is selected, the Manage IPTV playlists action. With DaddyLive unavailable, the user could not switch to the M3U provider from the error screen.

## Changes

- Keep `_buildHeader()` visible above the Live TV error panel for every provider, including DaddyLive, Ethio Sports, Spyhell and IPTV / M3U.
- Preserve the Pluto TV external-launch action while using the same error-page layout.
- Reject `.m3u`, `.m3u8` and `.mpd` URL paths from Source Repository registration with a guidance message directing users to Live TV > IPTV / M3U.
- Detect extensionless remote responses that begin with `#EXTM3U` (including a UTF-8 BOM) and return a format-specific message instead of exposing a JSON parser error.
- Add explanatory text in the Source Repositories page distinguishing JSON indexes from M3U lists and direct HLS/DASH stream URLs.
- Localize the add-repository validation message in Arabic and English.
- Add regression coverage to the existing `source_repository_client_test.dart` target for `.m3u`, `.m3u8`, `.mpd`, extensionless M3U bodies with BOM, and a valid JSON index URL.
- Bump app version from `4.3.0+10` to `4.3.1+11` for installation as an update over the successful 4.3.0 release.

## User migration required

The four incorrect entries are already stored in the installed app's SharedPreferences. This source change intentionally does not silently delete user-added repositories. Remove only the red M3U/HLS entries from Source Repositories using each row's three-dot menu > Remove. Keep the green JSON source indexes.

Then:

1. Open Live TV. The provider selector remains visible even if DaddyLive shows an unavailable message.
2. Select `IPTV / M3U`.
3. Open `Manage IPTV playlists`.
4. Import `RAVEN23-Live-TV-Test-Playlist.m3u` as a local file, or add a channel-list URL such as the Free-TV or iptv-org regional M3U URL.
5. Return to Channels and confirm the channel catalog appears. Try playback separately; external streams may be geographically restricted or temporarily offline.

Direct HLS links belong as entries inside an M3U channel playlist; they should not be added to Source Repositories or pasted as if they were M3U channel-list URLs.

## Validation status

- Reviewed screenshots and the current successful `4.3.0+10` project source.
- Confirmed the previous error branch omitted `_buildHeader()` and the provider picker.
- Updated the repository client tests in a file already included by the 39-file Phase51 CI command.
- ZIP integrity and static file checks are performed when packaging this fix.
- Flutter Analyze, Dart formatting, the 39-file integration suite, Kotlin compilation, Release APK build and on-device Live TV playback have **not** been rerun for this post-release fix. The prior successful CI results apply to `4.3.0+10`, not this `4.3.1+11` hotfix archive.
