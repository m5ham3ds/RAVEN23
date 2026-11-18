import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/controllers/live_tv_database_controller.dart';
import 'package:raven23/models/live_tv.dart';
import 'package:raven23/services/daddylive_service.dart';
import 'package:raven23/services/iptv/live_tv_category_mapper.dart';
import 'package:raven23/services/iptv/spyhell_live_tv_service.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/quickjs_source_catalog_profile.dart';
import 'package:raven23/video_providers/unified/source_repository_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing cached Spyhell channel returns a controlled error', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final service = SpyhellLiveTvService(
      database: LiveTVDatabaseController(
        namespace: SpyhellLiveTvService.databaseNamespace,
      ),
    );
    await expectLater(
      service.getStream('spyhell:0123456789abcdef:0123456789abcdef01234567'),
      throwsA(
        isA<DaddyLiveException>().having(
          (error) => error.message,
          'message',
          contains('no longer cached'),
        ),
      ),
    );
  });

  for (final locator in <String?>[null, '']) {
    final locatorKind = locator == null ? 'null' : 'empty';
    test(
      'cached Spyhell channel with $locatorKind locator returns a controlled error',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final database = LiveTVDatabaseController(
          namespace: SpyhellLiveTvService.databaseNamespace,
        );
        await database.cacheChannels(<Channel>[
          Channel(
            id: 'spyhell:0123456789abcdef:0123456789abcdef01234567',
            name: 'Channel without locator',
            watchUrl: locator,
          ),
        ]);
        final service = SpyhellLiveTvService(database: database);
        addTearDown(service.close);

        await expectLater(
          service.getStream(
            'spyhell:0123456789abcdef:0123456789abcdef01234567',
          ),
          throwsA(
            isA<DaddyLiveException>().having(
              (error) => error.message,
              'message',
              contains('no playable locator'),
            ),
          ),
        );
      },
    );
  }

  test('curated Spyhell live adapters are explicit and bounded', () {
    expect(SpyhellLiveTvService.supportedSourceIds, hasLength(15));
    expect(
      SpyhellLiveTvService.supportedSourceIds,
      containsAll(<String>{
        'worldlivetv',
        'livetvindia',
        'sportslivetv',
        'movieslivetv',
        'newslivetv',
        'documentarylivetv',
        'entertainmentlivetv',
        'serieslivetv',
        'animationlivetv',
        'musictv',
        'kidstv',
        'comedytv',
        'travellivetv',
        'cookinglivetv',
        'educationlivetv',
      }),
    );
  });

  test('Spyhell live source identities remain blocked from VOD searches', () {
    const repositoryUrl =
        'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json';
    const parser = SourceRepositoryParser();
    final live = parser
        .parseRepository(
          '''{"name":"Spyhell","sources":[{"id":"worldlivetv","name":"World Live TV","type":"movie","file":"providers/worldlivetv.js"}]}''',
          sourceUrl: repositoryUrl,
        )
        .extensions
        .single;
    const movie = MediaIdentity(type: UnifiedMediaType.movie, title: 'Sample');
    final profile = QuickJsSourceCatalogProfile.classify(
      repositoryUrl: repositoryUrl,
      sourceId: 'worldlivetv',
    );

    expect(live.requiresLiveTvAdapter, isTrue);
    expect(live.supportsMedia(movie), isFalse);
    expect(profile.catalogRole, 'live-channel-adapter');
  });

  test('group mapping keeps known linear content groups distinct', () {
    expect(mapLiveTvGroup('Movies Live TV'), 'Movies');
    expect(mapLiveTvGroup('Series Live TV'), 'Series');
    expect(mapLiveTvGroup('Animation Live TV'), 'Animation');
    expect(mapLiveTvGroup('World Live TV'), 'World');
    expect(
      mapLiveTvGroup('Custom regional channel group'),
      'Custom regional channel group',
    );
  });
}
