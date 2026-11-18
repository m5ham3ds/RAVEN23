# PHASE60 — Source Priority Lanes (Movies / Series / Anime)

## Goal

Replace repository media-type filtering and the old 15-source repository cap with user-owned, per-media ordered source lanes. A source's `movie`, `series`, `anime`, language, status, and fallback labels are descriptive metadata; they must not prevent the user from placing or attempting that source in another VOD category.

## User-facing management

- Each category (Movies, Series, Anime) has independent Primary and Backup lists.
- Primary limit: 20 sources.
- Backup limit: 30 sources.
- Total editable entries: up to 50 per category.
- The same source may be used in different media categories, but may appear only once across Primary + Backup within one category.
- Existing entries appear at the top of the Add / Manage dialog. Existing entries show a remove icon; removal asks for confirmation and only removes the source from the selected lane. It does not uninstall the repository source.
- Add / Manage opens on Primary by default; it selects Backup automatically when Primary is full and Backup has room. When both lanes are full, it opens on Primary and displays an error-colored no-empty-slots message. Existing entries can still be removed.
- The row-level delete control is replaced by Swap. The swap dialog separates Primary and Backup entries; a second confirmation is required before exchanging positions. Cross-lane swaps preserve each entry's slot and lane position.
- Both lists retain independent reorder controls.

## Persistence and migration

- The existing `raven23.source_priorities.v1.<category>` key remains the Primary lane so old Primary order is retained.
- Backup uses `raven23.source_backups.v1.<category>`.
- The previous implicit backup pool is seeded once only when a Backup key does not yet exist. An empty user-saved Backup list is preserved and never re-seeded.
- Existing v1 priorities are not rewritten by routine refreshes.
- Removing a repository removes its source keys from both lanes for all media categories.

## Runtime behavior

- The selected category is derived from the current media identity: Anime content uses Anime, movies use Movies, and episodic non-anime content uses Series.
- The per-media sequence is Primary, Backup, remaining eligible direct sources, then remaining embedded/fallback sources.
- Movie and TV playback now ask `ProviderLoader.installedSourceProviders` for the current media identity. Repository source ordering is therefore applied before the player queue is created; the old global provider-order preference no longer re-sorts and overrides repository lists.
- Any user-selected source bypasses upstream `isFallback` scheduling hints so a selected entry stays in its requested order.
- QuickJS `getInfo().type` is treated as descriptive metadata. The engine attempts the requested movie or episode route and judges support from the actual search/detail/stream response instead of rejecting a source before its first attempt.
- The old 15-active-sources-per-repository ceiling is removed. The 20 + 30 limits apply to each editable lane only.
- Media labels, language metadata and status labels no longer filter source attempts. A source can be tried even when its repository says `movie-only`, `series-only`, or `anime-only`.

## Intentional execution boundaries

- A catalog entry whose engine has no implementation registered in RAVEN23 can be displayed and organized, but cannot be executed until the app supports that engine.
- Sources explicitly requiring the dedicated Live TV adapter remain in the Live TV pipeline rather than being dispatched as VOD streams.
- Playback still depends on the source's actual endpoint, search route and stream extraction working for the selected title. Removing a metadata gate does not guarantee every source can resolve every title.

## Tests added / updated

- `source_priority_manager_test.dart`: 20/30 limits, duplicate prevention across lanes, independent categories, Primary migration, one-time Backup migration, reorder, swap, and repository cleanup.
- `source_priority_policy_test.dart`: cross-category acceptance for Anime/Movie-tagged providers, user-selected fallback override, and the unsupported-engine / Live TV boundaries.
- Existing source execution tests: Primary and Backup order override media tags; QuickJS anime-tagged provider uses the requested series route; provider scan attempts an anime-tagged source for a movie when it is first in the supplied order.

## Validation status

- Static structural scan of all 21 changed Dart files: passed (balanced delimiters and closed strings/comments).
- Static requirement checks for 20/30 limits, media-specific runtime wiring, no QuickJS media-type rejection, and removal of the 15-source cap: passed.
- `flutter analyze`, `flutter test`, and APK build were **not run** because the current working environment has neither Flutter nor Dart installed (`flutter: command not found`). The tests are included for execution in the project's GitHub Actions workflow; this phase is not marked as build-verified.
