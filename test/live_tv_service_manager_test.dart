import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/models/live_tv.dart';
import 'package:raven23/services/daddylive_service.dart';
import 'package:raven23/services/live_tv_service_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late _FakeLiveTvService daddy;
  late _FakeLiveTvService ethio;
  late LiveTvServiceManager manager;
  var daddyCreations = 0;
  var ethioCreations = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    daddyCreations = 0;
    ethioCreations = 0;
    daddy = _FakeLiveTvService(catalog: _catalog('daddy'));
    ethio = _FakeLiveTvService(catalog: _catalog('ethio'));
    manager = _manager(
      preferences: preferences,
      createDaddy: () {
        daddyCreations++;
        return daddy;
      },
      createEthio: () {
        ethioCreations++;
        return ethio;
      },
    );
  });

  tearDown(() => manager.close());

  test('standard registry centralizes the Mobile and TV provider list', () {
    final standard = LiveTvServiceManager.standard(
      daddyLiveBaseUrl: 'https://daddy.example',
      ethioSportsBaseUrl: 'https://ethio.example',
      preferences: preferences,
    );
    addTearDown(standard.close);

    expect(standard.providers.map((provider) => provider.id), <String>[
      'daddylive',
      'ethiosports',
      'iptv-m3u',
      'spyhell-live',
      'pluto-tv',
    ]);
    expect(standard.selectedProviderId, 'daddylive');
    expect(standard.providers[2].supportsEpg, isTrue);
    expect(standard.providers[3].supportsEpg, isFalse);
    expect(standard.providers[4].supportsEpg, isFalse);
    expect(standard.providers[4].isExperimental, isTrue);
    expect(standard.providers[4].externalLaunchUrl, 'https://pluto.tv/');
    expect(
      standard.providers.map((provider) => provider.databaseNamespace),
      <String>[
        'daddylive',
        'ethiosports',
        'iptv_m3u',
        'spyhell_live',
        'pluto_tv_experimental',
      ],
    );
  });

  test(
    'restores a persisted provider and selects its own data namespace',
    () async {
      await preferences.setString(
        'live_tv_selected_provider_v1',
        'ethiosports',
      );

      await manager.initialize();

      expect(
        manager.selectedProviderId,
        LiveTvServiceManager.ethioSportsProviderId,
      );
      expect(manager.activeDatabaseNamespace, 'ethiosports');
      expect(manager.selectedProvider.supportsEpg, isTrue);
      expect(daddyCreations, 0);
      expect(ethioCreations, 0);
    },
  );

  test(
    'delegates catalog and refresh to the selected provider lazily',
    () async {
      await manager.initialize();

      expect(daddyCreations, 0);
      final catalog = await manager.getCatalog();
      expect(daddyCreations, 1);
      expect(catalog.channels.single.id, 'daddy-channel');
      expect(manager.categories, <String>['Sports']);
      expect(manager.selectedHealth.state, LiveTvProviderState.available);

      await manager.refresh();
      expect(daddy.refreshFlags, <bool>[false, true]);
      expect(daddyCreations, 1);
    },
  );

  test(
    'provider selection persists and namespaces favorites and recents',
    () async {
      await manager.initialize();
      expect(manager.activeDatabaseNamespace, 'daddylive');

      final daddyDatabase = manager.activeDatabase;
      await daddyDatabase.toggleFavorite('shared-channel-id');
      await daddyDatabase.addRecent('shared-channel-id');

      await manager.selectProvider(LiveTvServiceManager.ethioSportsProviderId);

      expect(manager.selectedProviderId, 'ethiosports');
      expect(manager.activeDatabaseNamespace, 'ethiosports');
      expect(
        preferences.getString('live_tv_selected_provider_v1'),
        'ethiosports',
      );
      final ethioDatabase = manager.activeDatabase;
      expect(await ethioDatabase.getFavoriteIds(), isEmpty);
      expect(await ethioDatabase.getRecentIds(), isEmpty);
      await ethioDatabase.toggleFavorite('ethio:shared-channel-id');
      await ethioDatabase.addRecent('ethio:shared-channel-id');

      await manager.selectProvider(LiveTvServiceManager.daddyLiveProviderId);
      expect(await manager.activeDatabase.getFavoriteIds(), <String>{
        'shared-channel-id',
      });
      expect(await manager.activeDatabase.getRecentIds(), <String>[
        'shared-channel-id',
      ]);
      await manager.selectProvider(LiveTvServiceManager.ethioSportsProviderId);
      expect(await manager.activeDatabase.getFavoriteIds(), <String>{
        'ethio:shared-channel-id',
      });
      await manager.getStream('ethio:channel-1');
      expect(ethio.streamRequests, <String>['ethio:channel-1']);
      expect(ethioCreations, 1);
      expect(daddyCreations, 0);
    },
  );

  test('health distinguishes empty, blocked and available providers', () async {
    await manager.initialize();
    daddy.catalog = _catalog('daddy', channels: const <Channel>[]);
    await manager.getCatalog();
    expect(manager.selectedHealth.state, LiveTvProviderState.empty);

    daddy.catalogError = const DaddyLiveException('Forbidden', statusCode: 403);
    await expectLater(manager.refresh(), throwsA(isA<DaddyLiveException>()));
    expect(manager.selectedHealth.state, LiveTvProviderState.blocked);
    expect(manager.selectedHealth.httpStatusCode, 403);
    expect(manager.selectedHealth.message, isNot(contains('Forbidden')));

    daddy.catalogError = const DaddyLiveException(
      'Upstream unavailable',
      statusCode: 503,
    );
    await expectLater(manager.refresh(), throwsA(isA<DaddyLiveException>()));
    expect(manager.selectedHealth.state, LiveTvProviderState.unavailable);
    expect(manager.selectedHealth.httpStatusCode, 503);

    daddy.catalogError = null;
    daddy.catalog = _catalog('daddy');
    await manager.refresh();
    expect(manager.selectedHealth.state, LiveTvProviderState.available);
  });

  test('parses Live TV expiry timestamps as ISO, seconds or milliseconds', () {
    final iso = DateTime.utc(2032, 4, 5, 6, 7, 8);
    final seconds = DateTime.utc(2030, 1, 1).millisecondsSinceEpoch ~/ 1000;
    final milliseconds = DateTime.utc(2031, 1, 1).millisecondsSinceEpoch;
    expect(
      DaddyLiveStream.fromJson(<String, dynamic>{
        'url': 'https://media.example/iso.m3u8',
        'expiresAt': iso.toIso8601String(),
      }).expiresAt,
      iso,
    );
    expect(
      DaddyLiveStream.fromJson(<String, dynamic>{
        'url': 'https://media.example/live.m3u8',
        'expiresAt': seconds,
      }).expiresAt,
      DateTime.utc(2030, 1, 1),
    );
    expect(
      LiveStreamVariant.fromJson(<String, dynamic>{
        'url': 'https://media.example/backup.m3u8',
        'expiresAt': milliseconds.toString(),
      }).expiresAt,
      DateTime.utc(2031, 1, 1),
    );
  });

  test(
    'validates stream expiry, headers, media type and ClearKey metadata',
    () async {
      await manager.initialize();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));
      final keyId = List<String>.filled(32, 'A').join();
      final key = List<String>.filled(32, 'B').join();
      ethio.stream = DaddyLiveStream(
        url: 'https://media.example/live.mpd',
        headers: <String, String>{
          'Referer': 'https://sports.example/',
          'Authorization': 'must-not-reach-player',
          'X-Unapproved': 'must-not-reach-player',
        },
        embedUrl: 'https://embed.example/event',
        expiresAt: expiresAt,
        mediaType: 'application/dash+xml; codecs=avc1',
        clearKey: '$keyId:$key',
        variants: <LiveStreamVariant>[
          const LiveStreamVariant(
            url: 'javascript:alert(1)',
            headers: <String, String>{},
            mediaType: 'hls',
          ),
          LiveStreamVariant(
            url: 'https://media.example/backup.mpd',
            headers: const <String, String>{'Origin': 'https://sports.example'},
            mediaType: 'application/vnd.mpeg.dash.mpd',
            clearKey: 'invalid-key',
          ),
          LiveStreamVariant(
            url: 'https://media.example/expired-backup.mpd',
            headers: const <String, String>{},
            mediaType: 'dash',
            expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
          ),
        ],
      );

      await manager.selectProvider('ethiosports');
      final stream = await manager.getStream('ethio:event-1');

      expect(stream.url, 'https://media.example/live.mpd');
      expect(stream.expiresAt, expiresAt);
      expect(stream.mediaType, 'dash');
      expect(stream.headers, <String, String>{
        'Referer': 'https://sports.example/',
      });
      expect(stream.clearKey, '${keyId.toLowerCase()}:${key.toLowerCase()}');
      expect(stream.variants, hasLength(1));
      expect(stream.variants.single.url, 'https://media.example/backup.mpd');
      expect(stream.variants.single.mediaType, 'dash');
      expect(stream.variants.single.clearKey, isNull);
    },
  );

  test('rejects streams whose declared expiry has already passed', () async {
    await manager.initialize();
    daddy.stream = DaddyLiveStream(
      url: 'https://media.example/expired.m3u8',
      headers: const <String, String>{},
      embedUrl: '',
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );

    await expectLater(
      manager.getStream('daddy-channel'),
      throwsA(
        isA<DaddyLiveException>().having(
          (error) => error.statusCode,
          'statusCode',
          410,
        ),
      ),
    );
    expect(manager.selectedHealth.state, LiveTvProviderState.unavailable);
  });

  test(
    'rejects duplicate data namespaces to prevent cross-provider storage',
    () {
      expect(
        () => LiveTvServiceManager(
          preferences: preferences,
          providers: <LiveTvProviderDefinition>[
            LiveTvProviderDefinition(
              id: 'one',
              label: 'One',
              databaseNamespace: 'shared',
              createService: () => _FakeLiveTvService(catalog: _catalog('one')),
            ),
            LiveTvProviderDefinition(
              id: 'two',
              label: 'Two',
              databaseNamespace: 'shared',
              createService: () => _FakeLiveTvService(catalog: _catalog('two')),
            ),
          ],
          defaultProviderId: 'one',
        ),
        throwsArgumentError,
      );
    },
  );

  test('manager closes every instantiated provider exactly once', () async {
    await manager.initialize();
    await manager.getCatalog();
    await manager.selectProvider('ethiosports');
    await manager.getCatalog();

    manager.close();
    manager.close();

    expect(daddy.closeCount, 1);
    expect(ethio.closeCount, 1);
  });
}

LiveTvServiceManager _manager({
  required SharedPreferences preferences,
  required LiveTvService Function() createDaddy,
  required LiveTvService Function() createEthio,
}) {
  return LiveTvServiceManager(
    preferences: preferences,
    providers: <LiveTvProviderDefinition>[
      LiveTvProviderDefinition(
        id: LiveTvServiceManager.daddyLiveProviderId,
        label: 'DaddyLive',
        databaseNamespace: 'daddylive',
        supportsEpg: true,
        createService: createDaddy,
      ),
      LiveTvProviderDefinition(
        id: LiveTvServiceManager.ethioSportsProviderId,
        label: 'Ethio Sports',
        databaseNamespace: 'ethiosports',
        supportsEpg: true,
        createService: createEthio,
      ),
    ],
  );
}

DaddyLiveCatalog _catalog(String prefix, {List<Channel>? channels}) {
  final resolvedChannels =
      channels ??
      <Channel>[
        Channel(
          id: '$prefix-channel',
          name: '$prefix Channel',
          categories: const <String>['Sports'],
        ),
      ];
  return DaddyLiveCatalog(
    channels: resolvedChannels,
    epg: const DaddyLiveEpg(timezone: 'UTC', days: <DaddyLiveEpgDay>[]),
    categories: resolvedChannels.isEmpty
        ? const <String>[]
        : const <String>['Sports'],
  );
}

class _FakeLiveTvService implements LiveTvService {
  _FakeLiveTvService({required this.catalog});

  DaddyLiveCatalog catalog;
  Object? catalogError;
  DaddyLiveStream? stream;
  final List<bool> refreshFlags = <bool>[];
  final List<String> streamRequests = <String>[];
  int closeCount = 0;

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    refreshFlags.add(refresh);
    final error = catalogError;
    if (error != null) throw error;
    return catalog;
  }

  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    streamRequests.add(channelId);
    return stream ??
        const DaddyLiveStream(
          url: 'https://stream.example/live.m3u8',
          headers: <String, String>{'Referer': 'https://example.com/'},
          embedUrl: '',
        );
  }

  @override
  void close() => closeCount++;
}
