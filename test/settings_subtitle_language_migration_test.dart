import 'package:raven23/constants/app_constants.dart';
import 'package:raven23/preferences/setting_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  test('applies the new subtitle defaults once for pre-release installs', () async {
    await sharedPrefsSingleton.setInt(
      SettingsPreferences.SUBTITLE_FONT_SIZE,
      17,
    );
    await sharedPrefsSingleton.setString(
      SettingsPreferences.SUBTITLE_BACKGROUND_COLOR,
      '0x73000000',
    );
    await sharedPrefsSingleton.setString(
      SettingsPreferences.SUBTITLE_TEXT_STYLE,
      'regular',
    );
    await sharedPrefsSingleton.setBool(SettingsPreferences.SUBTITLE_MODE, true);
    await sharedPrefsSingleton.setString(
      SettingsPreferences.DEFAULT_SUBTITLE_V3,
      'fr',
    );

    final preferences = SettingsPreferences();
    await preferences.applyPlayerSubtitleDefaultsIfNeeded();

    expect(await preferences.subtitleFont(), 12);
    expect(await preferences.subtitleForeground(), '0xffffffff');
    expect(await preferences.subtitleBackground(), '0x00000000');
    expect(await preferences.getSubtitleStyle(), 'bold');
    expect(await preferences.getSubLanguage(), 'ar');
    expect(await preferences.getSubtitleMode(), isFalse);
    expect(await preferences.getAppColorIndex(), -1);

    // The one-time initializer must not overwrite a later user selection.
    await preferences.setSubtitleFont(22);
    await preferences.applyPlayerSubtitleDefaultsIfNeeded();
    expect(await preferences.subtitleFont(), 22);
  });

  test('uses Arabic as the new default and persists the migration', () async {
    final preferences = SettingsPreferences();
    expect(await preferences.getSubLanguage(), 'ar');
    expect(
      sharedPrefsSingleton.getString(SettingsPreferences.DEFAULT_SUBTITLE_V3),
      'ar',
    );
  });

  test('migrates the previous inherited English default to Arabic', () async {
    await sharedPrefsSingleton.setString(
      SettingsPreferences.DEFAULT_SUBTITLE,
      'en',
    );
    final preferences = SettingsPreferences();
    expect(await preferences.getSubLanguage(), 'ar');
    expect(
      sharedPrefsSingleton.getString(SettingsPreferences.DEFAULT_SUBTITLE),
      'ar',
    );
  });

  test('preserves a previously selected non-English subtitle language', () async {
    await sharedPrefsSingleton.setString(
      SettingsPreferences.DEFAULT_SUBTITLE,
      'fr',
    );
    final preferences = SettingsPreferences();
    expect(await preferences.getSubLanguage(), 'fr');
  });

  test('preserves the explicit Any language choice', () async {
    final preferences = SettingsPreferences();
    await preferences.setDefaultSubtitle('');
    expect(await preferences.getSubLanguage(), '');
  });

  test('does not overwrite a language already saved in version three', () async {
    await sharedPrefsSingleton.setString(
      SettingsPreferences.DEFAULT_SUBTITLE_V3,
      'it',
    );
    final preferences = SettingsPreferences();
    expect(await preferences.getSubLanguage(), 'it');
  });
}
