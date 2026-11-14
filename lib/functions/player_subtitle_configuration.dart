import 'package:better_player_plus/better_player_plus.dart';

import 'subtitle_style.dart';

/// Builds a Better Player subtitle appearance from the persisted app settings.
BetterPlayerSubtitlesConfiguration buildPlayerSubtitleConfiguration({
  required String backgroundColor,
  required String foregroundColor,
  required int fontSize,
  required String textStyle,
}) {
  return BetterPlayerSubtitlesConfiguration(
    backgroundColor: parseStoredSubtitleColor(
      backgroundColor,
      fallback: defaultSubtitleBackgroundColor,
    ),
    fontColor: parseStoredSubtitleColor(
      foregroundColor,
      fallback: defaultSubtitleForegroundColor,
    ),
    fontFamily: subtitleFontFamily(textStyle),
    outlineEnabled: false,
    fontSize: normalizeSubtitleFontSize(fontSize).toDouble(),
  );
}
