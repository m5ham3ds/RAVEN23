#!/usr/bin/env bash
set -euo pipefail

# Manga/Home/Anime, PHASE63 source management, synchronization, reader/translation and navigation
# formatter. Includes paged Mihon sources, default extension install and focused mobile menu tests;
# unrelated areas remain deliberately out of scope.
mode="${1:---check}"
files=(
  lib/catalog/media_item.dart
  lib/catalog/catalog_controller.dart
  lib/catalog/continue_watching.dart
  lib/catalog/home_feed_controller.dart
  lib/catalog/home_rows.dart
  lib/catalog/up_next.dart
  lib/controllers/recently_watched_database_controller.dart
  lib/mobile/collections.dart
  lib/mobile/my_list.dart
  lib/mobile/widgets/genre_sheet.dart
  lib/models/recently_watched.dart
  lib/screens/common/player/player_data_management.dart
  lib/screens/common/source_repositories_screen.dart
  lib/screens/common/server_status_screen.dart
  lib/screens/common/sync_screen.dart
  lib/screens/common/settings.dart
  lib/mobile/screens/home_screen.dart
  lib/mobile/screens/discover_screen.dart
  lib/mobile/screens/manga_screen.dart
  lib/mobile/app/mobile_nav_bar.dart
  lib/mobile/widgets/home_header.dart
  lib/mobile/widgets/home_optional_row.dart
  lib/mobile/widgets/page_kit.dart
  lib/mobile/widgets/hero_card.dart
  lib/mobile/widgets/media_art.dart
  lib/mobile/widgets/media_rows.dart
  lib/mobile/widgets/poster_card.dart
  lib/manga/anilist/anilist_manga_service.dart
  lib/manga/mihon/mihon_runtime.dart
  lib/manga/mihon/mihon_default_extension_installer.dart
  lib/manga/mihon/mihon_source_browser_screen.dart
  lib/manga/ui/manga_chapter_download_store.dart
  lib/manga/ui/manga_reader_screen.dart
  lib/manga/ui/manga_reader_crop.dart
  lib/manga/ui/manga_reading_store.dart
  lib/manga/ui/manga_source_matcher.dart
  lib/manga/ui/manga_work_screen.dart
  lib/manga/translation/manga_translation_models.dart
  lib/manga/translation/manga_translation_platform.dart
  lib/manga/translation/manga_page_translation_service.dart
  lib/manga/translation/manga_translation_overlay.dart
  lib/video_providers/unified/unified_source_service.dart
  lib/tv/screens/tv_settings_screen.dart
  lib/raven23_main.dart
  lib/translations/codegen_loader.g.dart
  lib/translations/locale_keys.g.dart
  test/manga/phase55_manga_catalogue_test.dart
  test/manga/phase55_mihon_pb_index_test.dart
  test/manga/mihon_source_browser_screen_test.dart
  test/manga/mihon_default_extension_installer_test.dart
  test/manga/phase56_manga_regression_test.dart
  test/manga/phase57_manga_home_parity_test.dart
  test/manga_detail_metadata_test.dart
  test/manga_reading_store_test.dart
  test/manga_source_matcher_test.dart
  test/search_screen_test.dart
  test/mobile/mobile_nav_bar_test.dart
  test/discover_screen_test.dart
  test/anime_media_classification_test.dart
  test/home_catalog_test.dart
  test/home_screen_test.dart
  test/provider_background_scan_test.dart
  test/video_providers/unified_source_service_execution_test.dart
)

for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    printf 'Manga/PHASE63 Dart format target is missing: %s\n' "$file" >&2
    exit 2
  fi
done

case "$mode" in
  --fix) dart format "${files[@]}" ;;
  --check) dart format --output=none --set-exit-if-changed "${files[@]}" ;;
  --help|-h) printf 'Usage: %s [--fix|--check]\n' "$0" ;;
  *) printf 'Unsupported mode: %s (expected --fix or --check)\n' "$mode" >&2; exit 2 ;;
esac
