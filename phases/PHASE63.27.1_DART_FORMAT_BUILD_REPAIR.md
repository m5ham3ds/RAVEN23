# PHASE63.27.1 — Dart Formatter Gate Repair (2026-11-16)

## Source and confirmed CI failure

This hotfix is based only on the `RAVEN23_PHASE63.27_PRESS_FEEDBACK_QUALITY_DOWNLOADS.zip` working tree and the three diagnostics archives supplied for GitHub Actions run `43955069639` (commit `6978e1dc53ef848e2065ddedf0889bc90b4058e6`). No Zangetsu, FlixQuest or OpenStream archive was inspected or changed. Firebase and backend work remain out of scope.

The report confirms dependency resolution succeeded. The only failed step was `Scoped Manga/Home/Anime Dart format fix + strict check`. Flutter Analyze, the 26 focused Flutter test files, both Android unit-test classes, Gradle wrapper generation, APK build and APK audit were skipped because the formatter gate failed. There was no APK from this run.

The Dart formatter diagnostic identifies one syntax error:

```text
lib/video_providers/unified/legacy_provider_adapter.dart:236:30
Expected to find ')'.
value?.trim().toLowerCase(),
```

The switch expression's selector was followed by a trailing comma inside the selector parentheses. Dart's switch-expression grammar does not permit that comma. The selector is now expressed as a normal Dart switch expression:

```dart
StreamContainer? _containerFromDeclaredValue(String? value) =>
    switch (value?.trim().toLowerCase()) {
      'hls' || 'm3u8' => StreamContainer.hls,
      'dash' || 'mpd' => StreamContainer.dash,
      'mp4' => StreamContainer.mp4,
      'webm' => StreamContainer.webm,
      _ => null,
    };
```

## Formatter patch

Applied the exact `dart-format.patch` from the supplied diagnostics archive after verifying it applies cleanly to the PHASE63.27 source. It formats these eleven files using the formatter output produced by Dart 3.9.2 in CI:

- `lib/functions/video_utils.dart`
- `lib/screens/common/player.dart`
- `lib/video_providers/common.dart`
- `lib/video_providers/quality_catalog.dart`
- `test/adaptive_quality_scanner_test.dart`
- `test/app_press_feedback_test.dart`
- `test/pill_button_test.dart`
- `test/playback_action_test.dart`
- `test/provider_background_scan_test.dart`
- `test/quality_catalog_test.dart`
- `test/video_utils_download_format_test.dart`

The formatter patch contains formatting-only changes; it does not replace the PHASE63.27 functional changes.

## Static validation performed for this hotfix

- Verified the supplied diagnostics ZIP files and PHASE63.27 ZIP integrity.
- Verified the formatter patch applies to the exact PHASE63.27 files without rejected hunks.
- Corrected the one parser error reported by Dart 3.9.2.
- Verified the formatter script's Bash syntax, the unique formatter-target inventory, required target-file existence, CI YAML parsing, embedded CI Python blocks, and focused Flutter test inventory.
- Verified the resulting ZIP CRC and archive listing.

## Validation boundary

This environment does not contain `dart`, `flutter`, or the Android Gradle toolchain. Therefore this hotfix has **not** been run through `dart format`, `flutter analyze`, Flutter tests, Android unit tests, Gradle or a Release APK build here. The syntax repair and canonical formatter patch address the confirmed failing gate, but they do not prove that later gates will pass. A new GitHub Actions run is required to establish that.

PHASE63.27 remains unaccepted as a successful build until the new CI run passes all required gates and the APK is produced. No Firebase or backend integration has started.
