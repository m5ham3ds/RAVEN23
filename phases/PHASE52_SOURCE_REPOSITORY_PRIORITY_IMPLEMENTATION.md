# Phase 52 — Implementation

## Core components

- `lib/video_providers/unified/source_priority_manager.dart`
  - Persists independent Movies/Series/Anime orders using stable source keys.
  - Enforces a 15-entry per-lane cap, a 15-unique-active-source repository cap for manual additions, deduplication, add/remove/reorder and first-run initialization.
  - Removing a source from priority leaves its installation and backup eligibility untouched.

- `lib/video_providers/unified/source_priority_policy.dart`
  - Declares the audited priority lists: 13 Movies, 9 Series, 11 Anime.
  - Enforces language declarations, category capability, runtime support, status=Unavailable exclusion, Live TV isolation, credential-review exclusion, known script/index language mismatches, adult exclusions and unsupported torrent-only runtime exclusions.
  - Treats missing status as `Unrated`, not `Listed OK`.
  - Auto-activates the union of priority sources plus a small backup allow-list, with a maximum of 15 unique records per repository.
  - Keeps OpenStream Beta adapters in the backup list instead of the first-pass priority list.

- `lib/video_providers/unified/quickjs_source_catalog_profile.dart`
  - Keeps all 15 known Spyhell Live TV adapters outside the VOD resolver.
  - Marks only Serenity `serenity-streamplay` and `serenity-cinestream` as having a reviewed Series contract. This is a narrow override for their Movie-declared metadata, not a general relaxation.

- `lib/video_providers/unified/source_repository_parser.dart`
  - Preserves whether language/status were actually declared.
  - Adds the Series capability tag only for the two explicitly reviewed Serenity source IDs.

- `lib/video_providers/unified/quickjs_source_engine.dart`
  - Allows the exact two reviewed Movie-declared Serenity providers through the initial type guard for Series.
  - Still requires explicit season and episode coordinates and exact episode matching. A missing or ambiguous season is rejected; no episode-number-only guessing is introduced.

- `lib/video_providers/unified/unified_source_service.dart`
  - Executes the user's category-specific priority list first.
  - If the priority tier yields no direct stream, scans all remaining installed/eligible direct providers for that category as backups.
  - If direct sources still yield nothing, tries Embedded/WebView fallback sources. Direct backups are sorted by declared upstream lifecycle status, then last-working source among equal-status candidates, then the existing engine-priority/observed-health tie-breakers. Direct sources marked `isFallback` remain in the direct-backup tier and retain the reserved-worker scheduling behavior; only Embedded/WebView engine kinds enter the final tier.
  - An intentionally empty priority list makes all eligible direct sources backups; it never reverts to arbitrary legacy ordering.
  - Multi-category providers are considered independently for each supported media type and are installed once.

- `lib/screens/common/source_repositories_screen.dart`
  - Adds the `REPOSITORIES` management section within Source Repositories.
  - Provides Movies, Series and Anime tabs, ordered source rows, upstream status labels, move-up/down, remove-from-priority and an add dialog.
  - Removing a lane entry demotes it to backup; it does not uninstall the source.

## First-run automatic activation

| Repository | Unique sources selected |
|---|---:|
| OpenStream Official | 14 |
| Spyou Zangetsu Providers | 5 |
| Serenity-MIST | 5 |
| Spyhell Experiment | 15 |
| Spyou Additional | 1 |
| Spyhell Latin | 0 |

The maximum 15 unique entries per repository is enforced in code. The per-category UI allows up to 15 entries; actual defaults are 13/9/11 because the audit did not justify filling all lanes with unreviewed, wrong-language or unsupported sources.

## Version

`pubspec.yaml`: `4.4.0+12`.

## Build acceptance status

The project owner confirmed that all builds completed successfully through PHASE56, which includes this Phase52 implementation. The earlier transient analyzer/test attempts were superseded by the later successful build milestone; their dedicated failure-note files have been removed from the active `phases/` folder. PHASE52 is accepted, and its test suite is not repeated in the PHASE57 CI gate.

## CI scope decision

The PHASE52 workflow was narrowed to its own priority-policy and direct-backup orchestration contracts rather than re-running accumulated Phase37–51 suites. This historical scope decision remains in force: accepted earlier phases are not unnecessarily re-tested by later phase-specific gates.
