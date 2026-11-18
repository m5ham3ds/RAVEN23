# RAVEN23 PHASE63.24 — Nullable Phosphor Icon Test Assertion Repair

## Source of truth

Based on `PHASE63.23_PHOSPHOR_ICON_ASSERTION_REPAIR` and the supplied GitHub Actions run `43769817214` (commit `171813492c9a373ee832fb1e60f953f493c7378f`).

## Confirmed build blocker

The workflow reached `Flutter analyze` and stopped there. Dependency resolution and the 146-file scoped Dart format check succeeded. The analyzer reported four errors at lines 229–232 of `test/mobile/mobile_nav_bar_test.dart` because the test helper dereferenced `Icon.icon` properties while `Icon.icon` is nullable.

The focused tests, Mihon ABI test, and APK build were skipped because Analyze failed. They must not be reported as passes or failures in this run.

## Repair

Updated `_expectIconGlyph` to store the nullable icon as `nullableActual`, assert `isNotNull`, and then explicitly promote it to a non-null `actual` before comparing the glyph fields (`codePoint`, `fontFamily`, `fontPackage`, and `matchTextDirection`).

## Scope preserved

- Test-only source change: `test/mobile/mobile_nav_bar_test.dart`.
- No production source or navigation behavior changed.
- Secondary dock still closes using its restored original behavior after a destination is selected.
- Phosphor icon choices, dimensions, press feedback, labels, and animation remain unchanged.
- The supplied Dart formatter patch was empty; no formatting changes were applied.

## Validation status

- Confirmed the four analyzer errors share one nullable receiver.
- Added the required null assertion before property access.
- Preserved the exact CI report and diagnostic uploads under `docs/build-reports/2026-11-15-phase63.23-run-43769817214/`.
- Verified the generated source archive's ZIP integrity.

Flutter/Dart are not installed in this editing environment. The analyzer, focused Flutter tests, Mihon ABI test, and APK build remain unverified and must be run by GitHub Actions.
