# PHASE63.8 — Source Management, Synchronize and Paged Catalogues

Date: 2026-11-13

## Scope

Continue from the PHASE63.7 RAVEN23 checkpoint. Only the RAVEN23 project was used. The Zangetsu, FlixQuest and OpenStream project archives were not opened or inspected.

## Navigation consolidation

- Removed the `SOURCE MANAGEMENT` / source-repositories entry from the mobile Settings screen and the TV Settings screen.
- Embedded the existing `SourceRepositoriesScreen` as the second tab of `Check server status`; the provider-health view remains the first tab.
- Kept repository refresh, add/remove/edit, revision history, pinning, import/export and duplicate-review actions in the embedded source manager.
- Removed the `REPOSITORIES` source-priority editor from the general source-manager view.
- Added a second tab to `Synchronize` for the complete per-media source-priority editor. The existing library synchronization panel remains in the first tab.

## Catalog usability

- Added source-catalog search by display name, stable key and source language.
- Only the first ten source cards are built initially; the page reveals another ten as the user approaches the end of the scroll view.
- Installed video sources sort ahead of not-installed entries, with alphabetical order preserved within each group.
- The combined Mihon `Installed Manga Sources` directory retains its search and installed-orphan behavior, pins installed sources at the top, and renders the first ten directory entries before revealing more in ten-entry batches while scrolling.
- The Mihon protobuf index is a single index response, so the full index is decoded once in the repository layer; pagination here limits card/widget creation and on-screen rendering, not the bytes returned by the upstream index endpoint.

## Requested default Mihon sources

A first-run, non-blocking Android startup task resolves these ten display names against the live Keiyoushi protobuf index:

1. AsgardScans
2. Azora
3. Manga Starz
4. Lava Scans
5. MangaSpark
6. MangaSwat
7. MangaTek
8. MangaTik
9. Team X
10. XCOMIC

No package ID or APK URL is hardcoded. The selector only accepts entries whose repository metadata signer equals the pinned Keiyoushi SHA-256 fingerprint:

`9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2`

The ordinary Mihon runtime still performs native APK certificate verification before loading an extension. The Keiyoushi default repository must remain configured; intentionally removing that repository disables automatic installation. Successful package IDs are stored individually, failures are retried on a later app launch, and an extension already present is recorded as complete. The user can uninstall an extension without the startup task silently reinstalling it on every launch.

When duplicate language variants are found, Arabic is preferred. If an item is missing from the current index or its signature metadata is unavailable/invalid, it is skipped rather than guessed or installed from an untrusted repository.

## Tests and CI

- Added `test/manga/mihon_default_extension_installer_test.dart` for exact requested-name matching, signer pinning, Arabic-variant preference and strict normalization.
- Expanded `test/manga/mihon_source_browser_screen_test.dart` to assert installed-first ordering and reveal the next page while scrolling.
- Focused Flutter pre-build test inventory: 15 files.
- Scoped Dart formatter inventory: 63 files.
- Added `search_sources` to Arabic, English, Spanish and Hindi translation JSON, generated loader and locale keys.
- Added the changed app, installer and test Dart files to `tool/format_phase57_dart.sh`.

## Static checks performed in packaging

- Translation JSON files parse and preserve equal root-key sets.
- Android CI workflow YAML parses.
- Formatter script passes `bash -n`; all 63 formatter paths exist and are unique.
- All 15 focused Flutter test paths exist.
- Embedded CI shell/Python sections are checked separately during packaging.

## Validation limitation / acceptance

Flutter, Dart, Gradle and the Android SDK are not installed in this editing environment. Therefore this phase does **not** claim that `dart format`, `flutter analyze`, Flutter tests, Android unit tests, Release APK creation, APK audit or device tests have run. A fresh GitHub Actions run and on-device verification are required before marking this phase accepted.
