#!/usr/bin/env bash
set -euo pipefail

# PHASE56-only formatter. Accepted PHASE52/53 implementation tests remain out
# of the phase gate; only current Manga catalogue and Mihon integration files
# are formatted here.
mode="${1:---check}"
files=(
  lib/mobile/screens/manga_screen.dart
  lib/manga/anilist/anilist_manga_service.dart
  lib/manga/mihon/keiyoushi_extension_repository.dart
  lib/manga/mihon/manga_repository_manager.dart
  lib/manga/mihon/mihon_pb_index.dart
  lib/manga/mihon/mihon_runtime.dart
  lib/manga/mihon/mihon_source_browser_screen.dart
  lib/screens/common/source_repositories_screen.dart
  test/manga/manga_repository_manager_test.dart
  test/manga/phase55_manga_catalogue_test.dart
  test/manga/phase55_mihon_pb_index_test.dart
  test/manga/phase56_manga_regression_test.dart
)

for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    printf 'PHASE56 Dart format target is missing: %s\n' "$file" >&2
    exit 2
  fi
done

case "$mode" in
  --fix) dart format "${files[@]}" ;;
  --check) dart format --output=none --set-exit-if-changed "${files[@]}" ;;
  --help|-h) printf 'Usage: %s [--fix|--check]\n' "$0" ;;
  *) printf 'Unsupported mode: %s (expected --fix or --check)\n' "$mode" >&2; exit 2 ;;
esac
