import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/constants/app_constants.dart';
import 'package:raven23/preferences/app_dependency_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDependencies dependencies;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    sharedPrefsSingleton = preferences;
    dependencies = AppDependencies();
  });

  test('migrates the saved scraper URL to its RAVEN23 preference key', () async {
    await preferences.setString('flixquestAPIURL', 'https://legacy.example');

    expect(await dependencies.getRaven23ApiURL(), 'https://legacy.example');
    expect(preferences.getString('raven23APIURL'), 'https://legacy.example');
  });

  test('migrates saved scraper instances to the RAVEN23 preference key', () async {
    const instances = ['https://one.example', 'https://two.example'];
    await preferences.setStringList('flixquestAPIInstances', instances);

    expect(await dependencies.getRaven23ApiInstances(), instances);
    expect(preferences.getStringList('raven23APIInstances'), instances);
  });

  test('migrates the saved logo override to the RAVEN23 preference key', () async {
    await preferences.setString('flixquestLogoUrl', 'https://cdn.example/logo.png');

    expect(await dependencies.getRAVEN23Logo(), 'https://cdn.example/logo.png');
    expect(preferences.getString('raven23LogoUrl'), 'https://cdn.example/logo.png');
  });
}
