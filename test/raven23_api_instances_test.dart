import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:raven23/constants/api_constants.dart';
import 'package:raven23/constants/app_constants.dart';
import 'package:raven23/provider/app_dependency_provider.dart';
import 'package:raven23/services/app_remote_config.dart';
import 'package:raven23/singleton/sharedpreferences_singleton.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeFirebaseRemoteConfig implements FirebaseRemoteConfig {
  final Map<String, dynamic> _values = {};

  void setMockString(String key, String value) {
    _values[key] = value;
  }

  void setMockBool(String key, bool value) {
    _values[key] = value;
  }

  void setMockInt(String key, int value) {
    _values[key] = value;
  }

  @override
  String getString(String key) => (_values[key] as String?) ?? '';

  @override
  bool getBool(String key) => (_values[key] as bool?) ?? false;

  @override
  int getInt(String key) => (_values[key] as int?) ?? 0;

  @override
  RemoteConfigValue getValue(String key) {
    final value = _values[key];
    if (value != null) {
      return RemoteConfigValue(
        utf8.encode(value.toString()),
        ValueSource.valueRemote,
      );
    }
    return RemoteConfigValue(
      const [],
      ValueSource.valueDefault,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.testLoad(
      fileInput: '''
        TMDB_API_KEY=test_tmdb
        MIXPANEL_API_KEY=test_mixpanel
        RAVEN23_API_URL=https://fallback-default.example.com
      ''',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPrefsSingleton = await SharedPreferencesSingleton.getInstance();
  });

  group('AppRemoteConfig.parseApiInstances', () {
    test('parses object with instances array', () {
      const raw = '''
      {
        "instances": [
          "https://raven23-scraper.onrender.com",
          "https://raven23-scraper-2.onrender.com"
        ]
      }
      ''';
      final instances = AppRemoteConfig.parseApiInstances(raw);
      expect(instances, [
        'https://raven23-scraper.onrender.com',
        'https://raven23-scraper-2.onrender.com',
      ]);
    });

    test('parses plain JSON array', () {
      const raw = '["https://inst-a.example", "https://inst-b.example"]';
      final instances = AppRemoteConfig.parseApiInstances(raw);
      expect(instances, [
        'https://inst-a.example',
        'https://inst-b.example',
      ]);
    });

    test('filters out whitespace and empty entries', () {
      const raw = '{"instances": [" https://a.example ", "", "   ", "https://b.example"]}';
      final instances = AppRemoteConfig.parseApiInstances(raw);
      expect(instances, [
        'https://a.example',
        'https://b.example',
      ]);
    });

    test('gracefully handles empty string and malformed JSON', () {
      expect(AppRemoteConfig.parseApiInstances(''), isEmpty);
      expect(AppRemoteConfig.parseApiInstances('   '), isEmpty);
      expect(AppRemoteConfig.parseApiInstances('not-json'), isEmpty);
      expect(AppRemoteConfig.parseApiInstances('{"other_key": 123}'), isEmpty);
      expect(AppRemoteConfig.parseApiInstances('{"instances": "not-a-list"}'), isEmpty);
      expect(AppRemoteConfig.parseApiInstances('{"instances": []}'), isEmpty);
    });
  });

  group('AppDependencyProvider multi-instance routing', () {
    test('randomly selects across multiple configured instances', () {
      final provider = AppDependencyProvider();
      final instances = [
        'https://instance-1.example.com',
        'https://instance-2.example.com',
      ];
      provider.raven23APIInstances = instances;

      expect(provider.raven23APIInstances, instances);

      final counts = <String, int>{
        'https://instance-1.example.com': 0,
        'https://instance-2.example.com': 0,
      };

      for (var i = 0; i < 100; i++) {
        final selected = provider.raven23APIURL;
        expect(instances.contains(selected), isTrue);
        counts[selected] = (counts[selected] ?? 0) + 1;
      }

      // Both instances should have received a share of requests
      expect(counts['https://instance-1.example.com']!, greaterThan(0));
      expect(counts['https://instance-2.example.com']!, greaterThan(0));

      provider.dispose();
    });

    test('returns single instance deterministically when length is 1', () {
      final provider = AppDependencyProvider();
      provider.raven23APIInstances = ['https://single-instance.example.com'];

      for (var i = 0; i < 10; i++) {
        expect(provider.raven23APIURL, 'https://single-instance.example.com');
      }

      provider.dispose();
    });

    test('falls back to flixquest_api_url_v2 when instances is empty', () {
      final provider = AppDependencyProvider();
      provider.raven23APIInstances = const [];
      provider.raven23APIURL = 'https://legacy-url.example.com';

      expect(provider.raven23APIURL, 'https://legacy-url.example.com');

      provider.dispose();
    });

    test('falls back to default raven23ApiUrl constant when both instances and legacy url are empty', () {
      final provider = AppDependencyProvider();
      provider.raven23APIInstances = const [];
      provider.raven23APIURL = '';

      expect(provider.raven23APIURL, 'https://fallback-default.example.com');

      provider.dispose();
    });

    test('raven23APIURLV2 always returns the legacy flixquest_api_url_v2 directly', () {
      final provider = AppDependencyProvider();
      provider.setRaven23ApiConfig(
        instances: ['https://inst-1.example', 'https://inst-2.example'],
        url: 'https://v2-direct.example',
      );

      expect(provider.raven23APIURLV2, 'https://v2-direct.example');
      expect(provider.configuredRaven23APIURL, 'https://v2-direct.example');

      provider.dispose();
    });
  });

  group('Persistence & Hydration', () {
    test('persists and restores instances and fallback url', () async {
      final provider = AppDependencyProvider();
      provider.setRaven23ApiConfig(
        instances: [
          'https://p1.example.com',
          'https://p2.example.com',
        ],
        url: 'https://fallback.example.com',
      );

      final restoredProvider = AppDependencyProvider();
      await restoredProvider.getFQUrl();

      expect(restoredProvider.raven23APIInstances, [
        'https://p1.example.com',
        'https://p2.example.com',
      ]);
      expect(restoredProvider.configuredRaven23APIURL, 'https://fallback.example.com');

      provider.dispose();
      restoredProvider.dispose();
    });
  });

  group('AppRemoteConfig.apply integration', () {
    test('configures provider with both new instances and legacy fallback', () {
      final mockConfig = FakeFirebaseRemoteConfig();
      mockConfig.setMockString(
        'flixquest_api_instances',
        '{"instances": ["https://rem-1.example.com", "https://rem-2.example.com"]}',
      );
      mockConfig.setMockString(
        'flixquest_api_url_v2',
        'https://rem-fallback.example.com',
      );

      final provider = AppDependencyProvider();
      AppRemoteConfig.apply(mockConfig, provider);

      expect(provider.raven23APIInstances, [
        'https://rem-1.example.com',
        'https://rem-2.example.com',
      ]);
      expect(provider.configuredRaven23APIURL, 'https://rem-fallback.example.com');

      provider.dispose();
    });

    test('uses legacy flixquest_api_url_v2 when instances is empty in remote config', () {
      final mockConfig = FakeFirebaseRemoteConfig();
      mockConfig.setMockString('flixquest_api_instances', '');
      mockConfig.setMockString(
        'flixquest_api_url_v2',
        'https://legacy-only.example.com',
      );

      final provider = AppDependencyProvider();
      AppRemoteConfig.apply(mockConfig, provider);

      expect(provider.raven23APIInstances, isEmpty);
      expect(provider.raven23APIURL, 'https://legacy-only.example.com');

      provider.dispose();
    });
  });

  group('TMDB_API_KEY Remote Config fallback and override', () {
    tearDown(() {
      // Restore fallback to .env
      TMDB_API_KEY = '';
    });

    test('initially falls back to .env key when remote key is not provided or empty', () {
      final mockConfig = FakeFirebaseRemoteConfig();
      mockConfig.setMockString('tmdb_api_key', '');

      final provider = AppDependencyProvider();
      AppRemoteConfig.apply(mockConfig, provider);

      expect(TMDB_API_KEY, 'test_tmdb');
      provider.dispose();
    });

    test('retains .env key when remote key is whitespace only', () {
      final mockConfig = FakeFirebaseRemoteConfig();
      mockConfig.setMockString('tmdb_api_key', '   ');

      final provider = AppDependencyProvider();
      AppRemoteConfig.apply(mockConfig, provider);

      expect(TMDB_API_KEY, 'test_tmdb');
      provider.dispose();
    });

    test('overrides TMDB_API_KEY when remote config supplies a non-empty key', () {
      final mockConfig = FakeFirebaseRemoteConfig();
      mockConfig.setMockString('tmdb_api_key', 'remote_override_key_12345');

      final provider = AppDependencyProvider();
      AppRemoteConfig.apply(mockConfig, provider);

      expect(TMDB_API_KEY, 'remote_override_key_12345');
      provider.dispose();
    });

    test('clearing TMDB_API_KEY restores fallback to .env', () {
      TMDB_API_KEY = 'temporary_key';
      expect(TMDB_API_KEY, 'temporary_key');

      TMDB_API_KEY = '';
      expect(TMDB_API_KEY, 'test_tmdb');
    });
  });
}
