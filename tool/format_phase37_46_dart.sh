#!/usr/bin/env bash
set -euo pipefail

# Keep this list aligned with the maintained Phase 37–46 source contracts
# and the targeted tests required by the automatic APK build gate, including Phase 46 Live TV.
mode="${1:---check}"
# Generated localization output is intentionally excluded: formatting it with
# the CI SDK creates a large, semantically empty diff and it is regenerated upstream.
files=(
  lib/video_providers/unified/media_identity.dart
  lib/video_providers/unified/stream_option.dart
  lib/video_providers/unified/media_identity_resolver.dart
  lib/video_providers/unified/episode_identity_normalizer.dart
  lib/video_providers/unified/source_contracts.dart
  lib/video_providers/unified/source_engine.dart
  lib/video_providers/unified/source_manifest.dart
  lib/video_providers/unified/vidking_audio_quality_normalizer.dart
  lib/video_providers/unified/source_repository_manager.dart
  lib/video_providers/unified/source_repository_revision.dart
  lib/video_providers/unified/source_host_policy.dart
  lib/video_providers/unified/source_repository_client.dart
  lib/video_providers/unified/source_repository_parser.dart
  lib/video_providers/unified/quickjs_source_engine.dart
  lib/video_providers/unified/quickjs/quickjs_extension_settings.dart
  lib/video_providers/unified/quickjs/quickjs_extension_settings_service.dart
  lib/video_providers/unified/quickjs/quickjs_provider_runtime.dart
  lib/video_providers/unified/quickjs/js_bootstrap.dart
  lib/video_providers/unified/quickjs/js_engine.dart
  lib/video_providers/unified/stremio_addon_provider.dart
  lib/video_providers/unified/openstream_web_embed_engine.dart
  lib/video_providers/unified/openstream_anime_engine.dart
  lib/video_providers/unified/unified_source_service.dart
  lib/video_providers/unified/vidking_direct_provider.dart
  lib/video_providers/provider_loader.dart
  lib/preferences/setting_preferences.dart
  lib/provider/settings_provider.dart
  lib/main.dart
  lib/screens/common/player_settings.dart
  lib/tv/screens/tv_settings_screen.dart
  lib/screens/common/source_repositories_screen.dart
  lib/screens/common/quickjs_source_settings_dialog.dart
  test/video_providers/stremio_addon_provider_test.dart
  test/video_providers/source_contracts_test.dart
  test/video_providers/source_engine_contract_test.dart
  test/video_providers/source_repository_manager_test.dart
  test/video_providers/vidking_direct_provider_test.dart
  test/video_providers/vidking_audio_quality_normalizer_test.dart
  test/video_providers/source_repository_client_test.dart
  test/video_providers/source_repository_revision_test.dart
  test/video_providers/source_host_policy_test.dart
  test/video_providers/quickjs_bridge_security_test.dart
  test/video_providers/source_repository_parser_test.dart
  test/video_providers/unified_source_service_stremio_identity_test.dart
  test/video_providers/unified/episode_identity_normalizer_test.dart
  test/video_providers/unified/quickjs_source_engine_test.dart
  test/settings_vidking_audio_language_test.dart
  test/video_providers/quickjs_extension_settings_test.dart
  test/video_providers/phase44_quickjs_catalog_test.dart
  test/video_providers/unified_source_service_execution_test.dart
  test/video_providers/provider_scan_engine_fairness_test.dart
  test/live_tv_service_manager_test.dart
  test/ethio_sports_service_test.dart
  lib/video_providers/unified/quickjs_source_catalog_profile.dart
  lib/services/daddylive_service.dart
  lib/services/ethio_sports_service.dart
  lib/services/live_tv_service_manager.dart
  lib/models/live_tv.dart
  lib/screens/common/live_player.dart
  lib/screens/common/live_tv_screen.dart
  lib/tv/screens/tv_live_screen.dart
  lib/video_providers/unified/source_execution_policy.dart
)

for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    printf 'Dart format target is missing: %s\n' "$file" >&2
    exit 2
  fi
done

case "$mode" in
  --fix)
    dart format "${files[@]}"
    ;;
  --check)
    dart format --output=none --set-exit-if-changed "${files[@]}"
    ;;
  --help|-h)
    printf 'Usage: %s [--fix|--check]\n' "$0"
    ;;
  *)
    printf 'Unsupported mode: %s (expected --fix or --check)\n' "$mode" >&2
    exit 2
    ;;
esac
