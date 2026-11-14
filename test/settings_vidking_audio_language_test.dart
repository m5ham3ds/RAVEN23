import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/constants/app_constants.dart';
import 'package:raven23/preferences/setting_preferences.dart';
import 'package:raven23/provider/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferences.getInstance();
  });

  test('new installs use automatic VidKing audio selection', () async {
    final preferences = SettingsPreferences();

    expect(await preferences.getPreferredVidkingAudioLanguage(), isEmpty);
    expect(
      sharedPrefsSingleton.containsKey(
        SettingsPreferences.PREFERRED_VIDKING_AUDIO_LANGUAGE,
      ),
      isFalse,
    );
  });

  test('saved language is normalized and restored independently', () async {
    final preferences = SettingsPreferences();

    await preferences.setPreferredVidkingAudioLanguage('  HI  ');

    expect(await preferences.getPreferredVidkingAudioLanguage(), 'hi');
    expect(
      sharedPrefsSingleton.getString(
        SettingsPreferences.PREFERRED_VIDKING_AUDIO_LANGUAGE,
      ),
      'hi',
    );

    final settings = SettingsProvider();
    await settings.getPreferredVidkingAudioLanguage();
    expect(settings.preferredVidkingAudioLanguage, 'hi');
    settings.dispose();
  });

  test(
    'automatic selection can be restored after clearing a saved language',
    () async {
      final preferences = SettingsPreferences();
      await preferences.setPreferredVidkingAudioLanguage('ar');
      await preferences.setPreferredVidkingAudioLanguage('');

      expect(await preferences.getPreferredVidkingAudioLanguage(), isEmpty);
    },
  );
}
