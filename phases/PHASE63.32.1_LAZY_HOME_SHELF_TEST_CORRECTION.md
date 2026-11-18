# RAVEN23 — PHASE63.32.1 Lazy Home Shelf Test Correction

## Root cause

GitHub Actions run #2 (`44223494397`) on commit `958de8c5fcca7eb3f7a93b9ba62261a86a884fd1` failed only one focused Flutter test:

`test/home_screen_test.dart`: `loads, fades in, and keeps only Live TV and Categories header chips`.

The test correctly scrolled through each lazy Home shelf and asserted its visibility. After it jumped the scroll position back to zero, it incorrectly asserted that `top_rated_anime` was still mounted. The Home feed uses lazy slivers, so off-screen rows are not required to remain in the widget tree.

## Correction

- Retained the forward scroll-and-visibility assertion for every shelf, including `top_rated_anime`.
- Removed only the stale post-scroll assertion for `top_rated_anime`.
- Kept the post-return checks for the Live TV and Categories header chips and the top Movies shelf.
- No production UI, feed ordering, repository, navigation, playback, or download logic was changed.

## Validation

The run #2 diagnostic log records one failed test out of the complete focused suite. The remainder of the focused tests completed without failures. Flutter analysis, dependency resolution, and scoped formatting passed. Android wrapper/ABI tests and release APK assembly were skipped because the Flutter test job failed.

This correction must be validated by a fresh GitHub Actions run before the phase is marked build-confirmed.
