# PHASE63.19 CI failure — diagnosis and repair

GitHub Actions run: `43733713753`  
Commit reported by CI: `49f02d045647f8600108348382d72fb5667b3cd2`

## What actually failed

The runner successfully completed checkout, Java 17, Gradle 8.14, Flutter 3.35.7 / Dart 3.9.2 setup, Android SDK setup, `flutter pub get`, and the formatter pass. The only failed workflow step was `Flutter analyze`.

The report contains 40 analyzer errors:

- 38 `list_element_type_not_assignable` errors: `AppPressFeedback` had been placed outside typed `PopupMenuItem` / `DropdownMenuItem` entries. A menu-entry list must contain the menu-entry type, not a general `Widget`.
- 1 undefined `unawaited` call in `server_status_screen.dart` because `dart:async` was not imported.
- 1 non-Boolean condition in the delayed Home source test where the inherited failure flag was captured without an explicit receiver/type.

The pre-build Flutter tests, Android Mihon ABI test, Gradle wrapper generation, APK build, and APK audit did not run. The separate focused-test diagnostics archive contains only the formatter log; it does not contain a test execution log.

## Applied repair

- Moved press feedback inside each menu entry's `child`, keeping `PopupMenuItem` and `DropdownMenuItem` as the direct typed list elements. No menu action or value was changed.
- Added `dart:async` to the server status screen.
- Changed the Home test capture to `final bool failThisRequest = this.fail;`.
- Removed an unnecessary `flutter/gestures.dart` import from `AppPressFeedback`.
- Applied the exact 88-file Dart formatter patch emitted by this CI run to this project baseline before repairing the affected call sites.

## Acceptance status

This source repair has not been run through Flutter in this workspace. Require a new GitHub Actions run to pass `flutter analyze`, all 18 focused Flutter test files, the Mihon ABI unit test, and the arm64 release APK build before accepting PHASE63.20.
