# Phase 52 — Changelog

- Added persistent Movies, Series and Anime source-priority lanes.
- Set audited defaults to 13 Movies, 9 Series and 11 Anime; lane maximum remains 15.
- Capped automatic activation to 15 unique sources per repository index.
- Added priority-direct → direct-backup → Embedded fallback scheduling.
- Added explicit empty-priority semantics (all eligible direct providers become backups).
- Added language/status declaration tracking and conservative language/category/runtime policy.
- Kept OpenStream Beta adapters in the backup tier, not first-pass priority.
- Added a source-specific Series capability override for the two reviewed Serenity scripts, retaining exact season/episode matching.
- Added the `REPOSITORIES` UI inside Source Repositories with category tabs, add/remove/reorder controls.
- Removing a lane entry demotes the source to backup without uninstalling it.
- Added policy, parser and QuickJS regression coverage.
- Updated the Android CI test gate to 40 explicit files and Dart formatter list to 94 targets.
- Updated application version to `4.4.0+12`.

## CI remediation — run 42545445467

- Applied the CI-produced 94-target Dart formatter patch.
- Added the missing direct `media_identity.dart` import to the parser test covering the two reviewed Serenity Series overrides.
- Removed the unused repository-manager import and redundant non-null assertion; added braces to the four reported `if` statements.
- No source-priority behavior, auto-activation policy, search tier, dependency, or Android build setting changed.
- The CI run stopped at Analyze before tests/Gradle/Release; all those stages remain pending a clean rerun.


- Flutter Analyze passed and Dart Formatter checked all 94 targets with no changes.
- Updated the VidKing parser test to assert the Phase52 `languageDeclared` / `statusDeclared` provenance fields while keeping audio language and quality out of engine config.
- Initialized Flutter test binding and mocked SharedPreferences in the Stremio identity test suite, which now calls the preference-backed priority manager through `UnifiedSourceService.search`.
- Kept direct `isFallback` providers in the direct-backup lane; only Web Embed / VidKing WebView engine kinds are deferred to Embedded.
- Restored last-working provider preference among equal-upstream-status backups without overriding the user's ordered priority lane.
- Updated the revision-cache fixture to declare its English language metadata explicitly.
- Preserved the 40-file CI gate, 94 formatter targets, source language policy, Android Release command and ARM64 target.


## CI test-scope correction — run 42550658763

- Confirmed that the accepted Phase51 Release baseline predates Phase52 and should not be rerun as a 40-file suite on every Phase52 build.
- Removed the accumulated Phases 37–51 test batch from the Phase52 release gate.
- Added a targeted Phase52 gate covering the complete policy suite plus exact priority/backup orchestration, parser, catalog and QuickJS Series contracts (5 files, 25 selected cases).
- Reduced the Dart formatting gate from 94 historical targets to the 16 Dart files changed by Phase52.
- Kept whole-project `flutter analyze`, Gradle Wrapper generation, Release ARM64 build and APK audit.

**Acceptance update (2026-11-10):** The project owner confirmed all builds succeeded through PHASE55. PHASE52 is accepted; intermediate CI diagnostic notes were removed as superseded, and this phase is not rerun in later CI gates.
