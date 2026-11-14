# Phase 47 — Tests and validation

## Added deterministic test files

1. `test/services/iptv/m3u_playlist_parser_test.dart`
   - quoted EXTINF metadata and VLC header allow-list
   - relative stream/logo URL resolution
   - stable source-scoped IDs and per-playlist `tvg-id` deduplication
   - HLS media playlist detection
   - unsupported/credentialed/unresolved URL rejection
   - category mapping and unknown group preservation
2. `test/services/iptv/m3u_live_tv_service_test.dart`
   - local import → channel catalog → Live TV stream contract
   - local file is copied into app-private storage without persisting the picker path
- local channel entries must use absolute HTTP(S) stream URLs; relative resolution is supported for remote lists with an HTTP(S) base URI
   - HLS media file is rejected as a channel list
3. `test/services/iptv/m3u_playlist_repository_test.dart`
   - remote fetch, cache reuse, conditional `ETag` / `Last-Modified` revalidation with 304
   - redirect to loopback is rejected
   - playlist count is bounded and duplicate URLs do not consume another slot
4. `test/services/iptv/spyhell_live_tv_adapter_test.dart`
   - curated adapter ID list is explicit and bounded
   - `requiresLiveTvAdapter` preserves the VOD exclusion
   - live content group mapping remains distinct

`test/live_tv_service_manager_test.dart` was updated to cover the four registered services and unique storage namespaces.

## CI gate

The Android workflow now calls `tool/format_phase37_47_dart.sh` and selects 25 explicit contract-test files, including the three Phase47 tests and Spyhell adapter test. It does not run the full Flutter test suite or general UI widget batches. When GitHub Actions runs, Analyze, the selected tests and ARM64 Release APK gate remain required.

## Execution status in this archive

**Not executed here.** `dart` and `flutter` executables are not installed in the working environment. No analyzer, formatter execution, Flutter test, Gradle/Android build, or device playback test is claimed. Only static file/path/shell/YAML/workflow checks can be performed in this pass. The workflow changes are instructions for a future CI run, not a CI result.

## Acceptance evidence still required

- Phase46 and Phase47 Analyzer + the 25-file CI contract suite pass.
- ARM64 Release APK and package/ABI audit pass on the same commit.
- Android phone and Android TV smoke tests confirm provider switching, channel lists, playlist removal/refresh and playback.
- At least one legal/available channel is played through LivePlayer for each provider class that is to be advertised as supported; unavailable/geo-restricted providers remain honestly unavailable.
