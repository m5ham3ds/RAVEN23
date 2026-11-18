# RAVEN23 PHASE63.25 — Selected Phosphor Glyph Test Expectation Repair

## Source of truth

Based on the supplied GitHub Actions run `43773980544`, attempt `1`, commit
`cf8cc78e8d17897c695bdac0687c2b0f5e7df06c`, and its focused pre-build
diagnostics, build report, and Dart formatter patch.

## Confirmed CI result

- Dependency resolution: success.
- Scoped Dart format check (146 targets): success.
- `flutter analyze --no-fatal-infos`: success (40 informational diagnostics; exit code 0).
- Focused Flutter pre-build tests: failed with one failing test; 143 tests passed.
- Mihon ABI test: skipped because the focused Flutter test step failed.
- APK build and ABI audit: skipped because the prerequisite test step failed.
- No APK was produced.

## Confirmed failure

The sole failing test was
`test/mobile/mobile_nav_bar_test.dart`:
`secondary dock collapses after selection and restores both selections when reopened`.

The assertion at the Movies selection expected the centre menu icon's font family
to be `PhosphorRegular`, while the actual font family was `PhosphorFill`.
The production navigation implementation intentionally selects the filled
variant for the active secondary destination: `_MenuAction` reads
`_navLookFor(current).$2`, and `_navLookFor` returns the Fill variant for
Movies, Series, and Anime.

This was a test expectation mismatch, not a production navigation defect.

## Repair

Updated only the expected glyph variants in
`test/mobile/mobile_nav_bar_test.dart`:
- Movies: `PhosphorIcons.video(PhosphorIconsStyle.fill)`
- Series: `PhosphorIcons.televisionSimple(PhosphorIconsStyle.fill)`
- Anime: `PhosphorIcons.maskHappy(PhosphorIconsStyle.fill)`

The default centre-menu `radioButton` assertions remain Regular. The test now
matches the actual selected-destination icon contract used by the production
widget.

## Scope preserved

- Production Dart files changed: none.
- Test Dart files changed: one (`test/mobile/mobile_nav_bar_test.dart`).
- No change to secondary dock open/close behavior or animation.
- No change to navigation destination selection or icon dimensions.
- No change to global press-feedback behavior.
- Supplied Dart formatter patch was empty (`dart-format.patch`, 0 bytes);
  no unrelated formatter changes were applied.
- Original CI report and diagnostic uploads are retained under
  `docs/build-reports/2026-11-15-phase63.24-run-43773980544/`.

## Validation status

- Confirmed there was one failing assertion and the failure was
  Regular-vs-Fill font family at the Movies centre-toggle icon assertion.
- Confirmed production `_MenuAction` uses the selected destination's Fill icon.
- Confirmed all three secondary-destination expectations now use the matching Fill variant.
- Confirmed only the focused navigation test file changed in Dart source.
- Verified ZIP CRC/integrity for the generated archive.

Flutter/Dart are not available in this editing environment. Therefore the
repaired focused tests have not been rerun here. GitHub Actions must confirm
the focused tests, Mihon ABI test, and release APK build before PHASE63.25
is considered a successful build.
