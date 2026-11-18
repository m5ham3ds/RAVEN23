# PHASE63.15 — User-managed synchronization priority and local source health

**Date:** 2026-11-15
**Scope:** RAVEN23 only. No Zangetsu, FlixQuest or OpenStream project archives were inspected or modified.

## 1. Synchronize — one priority editor

- Replaced the old two-area `Sync now` / `Choose source priority` experience with a single `Choose source priority` screen backed by the existing source-priority editor.
- Synchronization in this screen no longer initiates the previous automatic/manual sync workflow. The user owns the local order until a future Firebase/backend policy is introduced by the administrator/developer.
- Kept separate Movies, Series and Anime priority categories and the two ordered lanes (Primary and Backup) inside the same priority section. The primary lane runs first; the backup lane follows.
- Removed the previous primary/backup and per-repository activation ceilings from priority storage/policy. Existing persisted v1 priorities remain compatible. Duplicate placement across Primary and Backup within one category is still prevented, while the same source may be used in another media category.
- Added a regression test that persists 75 primary and 85 backup entries, then adds further entries without a capacity limit.

## 2. Check server status — preserve both tabs

The existing two tabs remain:

1. **Provider Health** — checks installed VOD/video sources only.
2. **Source repositories & add-ons** — continues to host the repository and add-on manager.

Provider Health no longer calls the remote `ScraperApi.getProviderHealthStatus()` endpoint. It obtains the installed-and-enabled source set from `UnifiedSourceService.refreshRepositories()` / the same repository snapshot used by Source repositories & add-ons. Live-TV-only adapters are excluded. The catalogue is refreshed before probing; if a repository cannot refresh, the repository manager's last verified local snapshot can remain available and the UI reports the refresh warning.

A second section, **MIHON SOURCE HEALTH**, is placed below Provider Health and checks every installed Mihon catalogue source exposed by the native runtime.

## 3. Probe methods and what they prove

| Source engine | Check | Interpretation |
|---|---|---|
| QuickJS / JavaScript VOD | Validate `getInfo()`, then execute `search("M", 1, {category})`. Movie-only sources use `movie`; series/anime use `sub`; mixed or undeclared sources can try both contracts. | A valid list response proves the search contract completed. An empty list is still a valid response, and is shown as zero results rather than an offline failure. |
| Mihon catalogue | Invoke the existing native `search(sourceId, "M", page: 1)` route. | The native bridge passes the extension's own `getFilterList()` defaults to `getSearchManga`; it does not depend on a preselected title or a manually fabricated filter list. |
| Stremio add-on | Fetch and validate its `manifest.json` response and basic `id` / `resources` shape. | Reports manifest reachability; it does not prove that a particular stream can be extracted. |
| VidKing Direct | Validate its configured route, then call the provider's seed endpoint using its expected origin/referer headers. | HTTP 200 is reachability. HTTP 400/422 without a media ID is treated as an API that is responding but requires media metadata; it is not reported as extracted video. |
| VidKing WebView, WebEmbed and AnimeSite | Check the configured/public website host with HEAD and a bounded GET fallback only when HEAD is explicitly unsupported. | Reports host reachability, not video extraction. No movie, series, anime or manga title is hardcoded into these checks. |
| Engine with no supported local probe | Mark as unsupported. | Unsupported is neutral and is not placed in the failed-source deletion list. |

The checks use bounded request sizes and timeouts, a maximum of three concurrent provider probes, host validation, private/reserved address protection, redirect validation and HTTPS-downgrade prevention. These checks are designed to avoid treating a network, endpoint or configuration issue as proof that an entire provider is offline.

## 4. Failure classification

The result model distinguishes DNS/host lookup failure, general network failure, timeout, TLS certificate failure, authentication (401), forbidden/blocked request (403), rate limiting (429), missing/retired path (404/410), server errors (5xx), Cloudflare challenge, required configuration, invalid endpoint, invalid response, missing Mihon source, extension/runtime failure, unsupported engine and unknown errors.

Unknown errors remain **Attention** rather than being silently labelled offline. Cloudflare detection checks challenge headers and body markers even when the HTTP response is 200. A successful website/manifest check is labelled **Reachable** where the probe cannot prove stream extraction.

## 5. Failed/attention review and removal

- The `Review failed sources` button appears above Provider Health only after both provider and Mihon checks finish and at least one item needs attention.
- The review sheet lists each affected source and its classified reason. Tapping a Mihon entry opens that source's catalogue/settings screen. Tapping a QuickJS entry opens its existing settings editor. A Stremio entry opens its configuration URL after confirmation when the manifest supplies one.
- For fixed-engine providers without an existing local settings API/editor, the details screen shows the source ID, engine, endpoint, homepage and repository. It does not pretend that a read-only details view can save a new endpoint; changing those definitions currently requires a repository-manifest update.
- Multiple entries can be selected. The bottom action removes/uninstalls all selected entries after a confirmation dialog. Video providers are uninstalled and removed from all Movies/Series/Anime primary/backup priority lists. Mihon removal is performed by extension package; the confirmation explicitly warns that all language sources supplied by the selected Mihon package will be removed together.

## 6. Files changed

- `lib/screens/common/sync_screen.dart`
- `lib/screens/common/source_repositories_screen.dart`
- `lib/screens/common/server_status_screen.dart`
- `lib/screens/common/source_health_probe_service.dart` (new)
- `lib/video_providers/unified/source_priority_manager.dart`
- `lib/video_providers/unified/source_priority_policy.dart`
- `lib/video_providers/unified/source_repository_manager.dart` — restores installed-source visibility from the latest verified local repository revision when a remote repository refresh fails.
- `test/video_providers/source_priority_manager_test.dart`
- `tool/format_phase57_dart.sh`
- `.github/workflows/android-ci.yml`
- `phases/PHASE63.15_SYNCHRONIZE_AND_LOCAL_SOURCE_HEALTH.md`
- `phases/README_MASTER_IMPLEMENTATION.md`
- `phases/README_CHANGED_FILES.txt`
- `phases/IMPLEMENTATION_TRACKER_PHASE36_58.md`

The routine GitHub Actions Flutter pre-build gate now includes the new source-priority manager regression file (18 focused Flutter test files total). The formatter target list includes the new health-probe service and the priority-manager test.

## 7. Validation boundary

Static packaging checks are recorded separately from Flutter validation. The local editing environment does not provide the Dart or Flutter executables, so this phase does **not** claim a local `dart format`, `flutter analyze`, Flutter test run, Gradle test run, Android build, APK audit or device acceptance. The existing owner-reported successful build for earlier RAVEN23 phases is preserved as historical context; it is not represented as a build of this new PHASE63.15 change set.
