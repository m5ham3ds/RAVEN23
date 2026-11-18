# Validation checklist

- [x] Formatter target list contains 79 unique existing paths.
- [x] Formatter shell script passes `bash -n`.
- [x] GitHub Actions YAML parses.
- [x] Custom trailing-whitespace scan passed for changed Dart files and newly added documentation lines (the source package has no `.git` directory, so `git diff --check` was not available).
- [x] ZIP CRC/integrity verified after creation.
- [ ] `dart format --output=none --set-exit-if-changed ...` — requires CI.
- [ ] `flutter analyze --no-fatal-infos` — requires CI.
- [ ] Focused Flutter widget tests — requires CI.
- [ ] Android/Gradle compilation and ARM64 APK build/audit — requires CI.
- [ ] Physical device: cold launch in airplane mode, no-cache error placeholder, network restoration while tab active, network restoration while tab hidden, resume from background, no duplicate requests, tab-transition colour stability.
