import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/constants/theme_data.dart';
import 'package:raven23/models/app_colors.dart';

void main() {
  test('the default theme swatch is exact RAVEN23 red in light and dark', () {
    const ravenRed = Color(0xFFFF0000);
    for (final isDark in <bool>[false, true]) {
      final swatch = AppColorsList()
          .appColors(isDark)
          .singleWhere((color) => color.index == AppColor.defaultIndex);
      expect(swatch.cs.primary, ravenRed);
      expect(swatch.cs.onPrimary, Colors.white);
    }
  });

  test('orange remains a separate available custom theme color', () {
    final colors = AppColorsList().appColors(true);
    final orange = colors.singleWhere((entry) => entry.index == 9);
    final baselineScheme = AppColor.colorGetter(const Color(0xFFF97316), true);

    // Phase 35.1 builds curated swatches from their seed colors. Keep that
    // palette generation unchanged rather than forcing a new primary tone.
    expect(orange.cs.primary, baselineScheme.primary);
    expect(orange.cs.secondary, baselineScheme.secondary);
  });

  test('default red reaches all base themes when Material 3 is disabled', () {
    final darkDefault = AppColorsList()
        .appColors(true)
        .singleWhere((entry) => entry.index == AppColor.defaultIndex);
    final lightDefault = AppColorsList()
        .appColors(false)
        .singleWhere((entry) => entry.index == AppColor.defaultIndex);
    const red = Color(0xFFFF0000);

    final themes = <ThemeData>[
      darkThemeData(false, null, darkDefault),
      lightThemeData(false, null, lightDefault),
      lightsOutThemeData(false, null, darkDefault),
    ];

    for (final theme in themes) {
      expect(theme.primaryColor, red);
      expect(theme.colorScheme.primary, red);
    }
  });

  test('custom theme uses the selected color as its exact primary', () {
    const selectedColor = Color(0xFFFF0000);
    for (final isDark in <bool>[false, true]) {
      final customColor = AppColorsList()
          .appColors(isDark, customColor: selectedColor.toARGB32())
          .singleWhere((color) => color.index == AppColor.customIndex);
      expect(customColor.cs.primary, selectedColor);
      expect(customColor.cs.onPrimary, Colors.white);
    }
  });
}
