# PHASE53 — Zangetsu Navigation & Manga Catalogue Integration

**Date:** 2026-11-09  
**Status:** Accepted — owner confirmed successful Release build and working device behaviour on 2026-11-09; Phase54 changes are tracked separately.  
**Base:** RAVEN23 Phase52 workspace, with Zangetsu inspected as a read-only reference.

## 1. Baseline audit and phase status

- The audit reviewed 173 pre-existing documents in `phases/` covering the plan, audits, implementation records, CI remediation and acceptance boundaries; this Phase53 report is the 174th file added to preserve the new implementation record.
- Phase51 is the latest accepted Release baseline: GitHub Actions run `42507906881` passed Flutter Analyze, Dart formatting, 302 tests, Kotlin/Gradle, `assembleProdRelease` and the ARM64 APK audit. The recorded APK was `com.m5ham3ds.raven23`, version `4.3.0+10`, 28,111,482 bytes, `arm64-v8a` only.
- PHASE52 Release build has been confirmed successful by the project owner on 2026-11-09 and is treated as accepted. Its historical CI test-scope diagnostics remain in `phases/`, but PHASE52-specific tests are not rerun or retained as an active gate in this phase.
- Phase53 is additive. It does not reopen or replace Phase36–51 work; PHASE52 remains accepted based on the owner-confirmed successful Release build.

## 2. Zangetsu reference findings

- Its dock hides labels by folding their allocated height and fading opacity, while reducing icon dimensions and dock width/spacing. A vertical-scroll threshold around 60 px controls collapse; returning toward the top expands it. The main animation is approximately 340 ms.
- Its manga catalogue uses AniList GraphQL for anonymous public manga metadata and offers browsing, search and title details.
- Its Keiyoushi/Mihon integration consumes a protobuf index (`index.pb`) and decodes extension/resource/source records. This is not a JSON video repository.
- Zangetsu's chapter reader/source execution is coupled to its native Mihon/Android extension runtime. RAVEN23 does not currently contain that compatible runtime. Copying only the index parser does not make APK extensions executable or chapters readable.
- RAVEN23 retains its own dock artwork, palette, Phosphor icon family, spacing tokens, typography and selected-item treatment. Only the motion pattern and relevant catalogue/data concepts were adapted.

## 3. Navigation implementation

### Primary dock

1. Home
2. New & Hot
3. Expand/collapse action (list icon becomes X)
4. Discover
5. My RAVEN23

Home remains the first item and retains its original position. The action is not treated as a route or tab.

### Secondary dock

1. Movies
2. Series
3. Search
4. Anime
5. Manga

The secondary row expands above the primary dock. It closes when the central action is pressed again, a route is selected, the user touches/swipes the page outside the dock, or Android Back is pressed. Selecting a secondary destination closes it immediately. Search has been removed from the primary row and is the centre item in the secondary row.

Movies, Series and Anime reuse the existing RAVEN23 Home feed screen and data layer. Anime calls only the four anime shelves (trending, popular, new episodes and top rated), avoids normal TV shelves/genre rows, and keeps non-anime TV out. A discovered empty-row mapping bug was also fixed so the Anime feed returns an explicit empty Series row rather than indexing an empty list.

### Collapse motion

- Vertical scroll accumulates 60 px before collapsing; upward movement expands it and returning to the top expands immediately.
- The RAVEN23 nav height contracts from 60 to 52 px, the bar width contracts to a five-item compact dock (54 px per item, bounded by screen width), icon bounds/sizes shrink, and labels fold to zero height with opacity fading.
- The secondary dock reuses the same compact item state while open.
- System-level reduced-motion preference disables the relevant navigation animations.
- Tablet rail retains the same destinations and expandable secondary destinations; the phone's original bottom-dock appearance is not replaced with Zangetsu styling.

## 4. Manga catalogue and data sources

### Metadata provider — AniList

RAVEN23 now uses `https://graphql.anilist.co` for public manga metadata, browse rows, search and details. Results are restricted to `type: MANGA`, non-adult titles and non-NOVEL formats. The title model includes titles, cover/banner artwork, synopsis, score, popularity, status, format, chapter/volume counts, genres and start date.

- Public catalogue queries do not require a client API key or OAuth token.
- AniList describes its API as free for public use, subject to its terms. Commercial use is conditional: its published terms require a commercial licence when a service's monthly revenue exceeds USD 150; the API must not be used as a bulk storage/backing database or to create a prohibited competing service. Review the current AniList API terms before commercial distribution.
- AniList is a data/API platform; it should not be described as an open-source project merely because its GraphQL endpoint is publicly accessible.

### Manga extension repository — Keiyoushi

The dedicated index is:

`https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb`

It is stored and displayed as one separate Manga/Mihon repository, alongside the six existing JSON video repositories (seven repositories in the combined UI). The video `SourceRepositoryManager` and its six JSON URLs remain unchanged. A protobuf decoder adapted from Zangetsu is attributed in `lib/manga/mihon/mihon_pb_index.dart` and parses extension name, package, version, APK URL, content warning, language, source name and source home URL.

- The index is a public GitHub raw resource; it does not require a separate API key.
- It is an extension index, not a content metadata service and not a direct video-source JSON manifest.
- Current Phase53 UI can fetch and browse extension metadata and source identities. It does **not** install or execute extension APKs, resolve chapters, or provide a Manga reader. Those functions require a dedicated compatible native Mihon extension runtime, secure APK install/trust handling, and reader integration. No controls were added that falsely claim those operations work.

## 5. Files changed and added

- Navigation and page routing: `lib/mobile/app/mobile_tabs.dart`, `mobile_nav_bar.dart`, `mobile_shell.dart`, `mobile/screens/home_screen.dart`.
- Anime data contract: `lib/catalog/home_feed_controller.dart`.
- Manga UI: `lib/mobile/screens/manga_screen.dart`.
- AniList service/model: `lib/manga/anilist/anilist_manga_service.dart`.
- Mihon repository and protobuf parser: `lib/manga/mihon/keiyoushi_extension_repository.dart`, `mihon_pb_index.dart`.
- Separate repository card: `lib/screens/common/source_repositories_screen.dart`.
- EN/AR labels: `assets/translations/en.json`, `assets/translations/es.json`, `assets/translations/ar.json`, `assets/translations/hi.json`.
- Tests: `test/mobile_shell_test.dart`, `test/home_feed_controller_test.dart`, `test/manga/anilist_manga_service_test.dart`, `test/manga/keiyoushi_extension_repository_test.dart`.
- CI at initial delivery: `tool/format_phase53_dart.sh` and `.github/workflows/android-ci.yml`; the PHASE53 formatter script was retired after acceptance and replaced by a PHASE54-only formatter.

## 6. Test and release gate

Phase53 adds a dedicated formatter target list (14 Dart files) and focused test groups for:

1. Anime-only Home shelves and no ordinary TV rows.
2. AniList manga metadata mapping and null-field behaviour.
3. Keiyoushi protobuf structure, version/package/APK/source records, exact index URL and malformed record rejection.
4. Secondary menu order, menu toggle/close, outside-page/system-Back/swipe dismissal, and scroll-collapse/expand behaviour.

The workflow does not rerun PHASE52 tests or upload a PHASE52 test-log artifact. It formats only the 14 PHASE53 Dart targets, runs whole-project analysis, then runs the focused PHASE53 tests before the Android Release build.

**Local verification limitation:** the packaging environment does not have Dart or Flutter installed. The workflow YAML and translation JSON were parsed locally; the targeted Dart tests, Dart formatter, `flutter analyze`, Gradle/Kotlin compilation, Release APK and device UI were not run here. The CI gate is configured but not claimed as passed. The Zangetsu-native Mihon runtime remains an explicit follow-up phase.

## 7. Acceptance checklist

- [x] Source/phase audit and Zangetsu reference review.
- [x] Preserve RAVEN23 palette, icons and original dock styling.
- [x] Primary and secondary item order implemented.
- [x] Menu toggle, route selection, outside-page and Android Back dismissal wired.
- [x] Scroll collapse/expand motion and reduced-motion handling implemented.
- [x] Movies/Series/Anime route through the existing Home feed.
- [x] Manga AniList catalogue/search/detail screens added, including empty results and stale-request protection.
- [x] Keiyoushi `.pb` repository separated from six video JSON repositories.
- [x] Focused tests and CI format/test gates added.
- [x] PHASE52 Release build accepted (owner-confirmed 2026-11-09); no PHASE52 test rerun is required.
- [x] Phase53 Release build and device behaviour confirmed by the project owner on 2026-11-09.
- [x] Main navigation and manga catalogue baseline accepted by the project owner.
- [ ] The new Phase54 manga layout and repository-management refinements are validated separately in GitHub Actions and on-device.
- [ ] Compatible native Mihon runtime and manga chapter reader implemented (out of Phase53 scope).

## 8. CI analyzer failure follow-up — 2026-11-09

The first PHASE53 CI attempt stopped at `flutter analyze`; no PHASE53 tests, Gradle wrapper generation, APK build or APK audit ran. The captured analyzer output reported:

- `MobileTab.primarySelectionFor` was declared `static` while its switch expression used `this`, and callers accessed it as an instance getter. It is now an instance getter, preserving the existing Home-selected behavior for Movies, Series and Anime.
- The private `_MangaPoster.imageHeight` optional argument was never supplied. It is now a fixed internal card-image dimension, removing the `unused_element_parameter` analyzer warning.

The failed CI attempt also showed that the workflow still contained an obsolete PHASE52-only test/format/artifact path despite the already-successful PHASE52 Release build. That PHASE52 execution path and its report references were removed from the active workflow. PHASE53's formatter and focused tests remained active through acceptance. A focused `MobileTab` selection test was added to `test/mobile_shell_test.dart`; after PHASE53 was confirmed successful, its test files and formatter path were removed from the active test set.

**Verification boundary:** the supplied CI logs identify the analyzer failures precisely. This packaging environment does not include Flutter or Dart, so the repaired `flutter analyze`, PHASE53 tests, Gradle compilation and APK build still require a fresh GitHub Actions run; none is claimed as passed in this handoff.


## 9. Navigation test correction — 2026-11-09

The next CI run (`42650246488`, commit `5e2909b18bba26a2b655575cc90ae04c00af508e`) passed `flutter analyze` and the focused Anime, AniList and Keiyoushi groups. The remaining navigation test failed because it expected the secondary destination widgets to be unmounted immediately after closing. The implementation deliberately retains the outgoing dock subtree for the `AnimatedSize` collapse while wrapping it in `IgnorePointer` and reducing its height to zero. The test now checks the actual interaction contract (`hitTestable()` finds no closed destination) and confirms that the primary menu toggle remains hit-testable. No production navigation behavior or animation was weakened to satisfy the test.

The CI warning messages about missing localization keys were emitted because this widget test pumps `MobileShell` under a bare `MaterialApp` instead of the production `EasyLocalization` wrapper; they are test-harness localization warnings, not missing keys in the shipped translation JSON. They did not cause the test failure. `flutter analyze` reported two non-failing `curly_braces_in_flow_control_structures` info notices in `anilist_manga_service.dart`; both guards have now been given explicit blocks as part of this correction.

**Verification boundary:** the previous CI run had not reached Gradle wrapper generation or APK building. This packaging environment has no Flutter/Dart executable, so the amended navigation test could not be executed locally. A new GitHub Actions run is required to verify the test and continue through the Release APK gate.


## Post-acceptance test cleanup (2026-11-10)

PHASE53 Release was confirmed successful by the project owner. Its focused CI-only test files (`test/home_feed_controller_test.dart`, `test/mobile_shell_test.dart`, `test/manga/anilist_manga_service_test.dart`, and `test/manga/keiyoushi_extension_repository_test.dart`) were removed after acceptance. They are no longer rerun by the Release gate. Later phases retain only tests for active, not-yet-accepted Manga/Mihon changes; the current PHASE57 CI gate is limited to those contracts. This cleanup does not remove runtime functionality or alter the accepted implementation.
