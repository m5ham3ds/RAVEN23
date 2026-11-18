import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:raven23/video_providers/unified/source_host_policy.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_contracts.dart';
import 'package:raven23/video_providers/unified/source_repository_client.dart';
import 'package:raven23/video_providers/unified/source_repository_manager.dart';
import 'package:raven23/video_providers/unified/source_repository_revision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Keep these tests isolated from the production first-run OpenStream seed.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'unified_source_default_repository_seeded_v1': true,
      'unified_source_default_repository_seed_version_v2': 2,
    });
  });

  test(
    'lifecycle helper reflects default installation and explicit disablement',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final manager = SourceRepositoryManager(preferences: preferences);
      const source = SourceManifest(
        id: 'default-beta',
        name: 'Default Beta',
        installedByDefault: true,
        status: 3,
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      final initiallyEnabled = await manager.lifecycleOf(source);
      expect(initiallyEnabled.has(SourceLifecycleFlag.discovered), isTrue);
      expect(initiallyEnabled.has(SourceLifecycleFlag.validated), isFalse);
      expect(initiallyEnabled.has(SourceLifecycleFlag.installed), isTrue);
      expect(initiallyEnabled.has(SourceLifecycleFlag.enabled), isTrue);
      expect(initiallyEnabled.has(SourceLifecycleFlag.experimental), isTrue);

      await manager.uninstallSource(source);
      final disabled = await manager.lifecycleOf(source);
      expect(disabled.has(SourceLifecycleFlag.installed), isFalse);
      expect(disabled.has(SourceLifecycleFlag.enabled), isFalse);
      expect(disabled.has(SourceLifecycleFlag.disabled), isTrue);
    },
  );

  test(
    'fresh installs seed all six bundled repositories and parse both index formats',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final dio = _bundledRepositoriesDio();
      final manager = SourceRepositoryManager(
        client: SourceRepositoryClient(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ),
        preferences: preferences,
      );

      final snapshot = await manager.sync(forceRefresh: true);

      const expectedRepositories = <String>[
        'https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json',
        'https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json',
        'https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json',
        'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json',
        'https://raw.githubusercontent.com/Spyou/Zangetsu-spyou-provider/main/index.json',
        'https://raw.githubusercontent.com/Spyhell/spyou-latin-zan/main/index.json',
      ];
      expect(
        SourceRepositoryManager.bundledRepositoryUrls,
        expectedRepositories,
      );
      expect(await manager.repositoryUrls(), expectedRepositories);
      expect(snapshot.repositories, hasLength(6));
      expect(snapshot.catalog, hasLength(6));
      expect(
        snapshot.repositories.map((repo) => repo.name).toSet(),
        hasLength(6),
      );
      // Only OpenStream entries explicitly marked installedByDefault are active.
      expect(snapshot.sources, hasLength(1));
      expect(snapshot.sources.single.id, 'openstream-default');
      expect(
        snapshot.catalog.where(
          (source) => source.engine.kind == SourceEngineKind.javascript,
        ),
        hasLength(5),
      );
      dio.close(force: true);
    },
  );

  test(
    'existing installs receive five repositories additively without losing user data',
    () async {
      const customRepository = 'https://custom.example/index.json';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'unified_source_default_repository_seeded_v1': true,
        'unified_source_repository_urls_v1': <String>[
          SourceRepositoryManager.defaultOpenStreamRepository,
          customRepository,
        ],
        'unified_installed_source_keys_v1': <String>[
          '$customRepository::installed-addon',
        ],
        'unified_disabled_default_source_keys_v1': <String>[
          '$customRepository::disabled-addon',
        ],
      });
      final preferences = await SharedPreferences.getInstance();
      final dio = _bundledRepositoriesDio();
      final manager = SourceRepositoryManager(
        client: SourceRepositoryClient(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ),
        preferences: preferences,
      );

      await manager.sync(forceRefresh: true);
      final urls = await manager.repositoryUrls();

      expect(urls, contains(customRepository));
      expect(
        urls,
        contains(SourceRepositoryManager.defaultOpenStreamRepository),
      );
      expect(urls, hasLength(7));
      for (final url in SourceRepositoryManager.bundledRepositoryUrls) {
        expect(urls.where((item) => item == url), hasLength(1));
      }
      expect(
        await manager.installedSourceKeys(),
        contains('$customRepository::installed-addon'),
      );
      expect(
        await manager.disabledDefaultSourceKeys(),
        contains('$customRepository::disabled-addon'),
      );
      expect(
        preferences.getInt('unified_source_default_repository_seed_version_v2'),
        2,
      );
      dio.close(force: true);
    },
  );

  test(
    'upgrade does not resurrect OpenStream when a user removed it previously',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'unified_source_default_repository_seeded_v1': true,
        'unified_source_repository_urls_v1': <String>[
          'https://custom.example/index.json',
        ],
      });
      final preferences = await SharedPreferences.getInstance();
      final dio = _bundledRepositoriesDio();
      final manager = SourceRepositoryManager(
        client: SourceRepositoryClient(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ),
        preferences: preferences,
      );

      await manager.sync(forceRefresh: true);
      final urls = await manager.repositoryUrls();

      expect(
        urls,
        isNot(contains(SourceRepositoryManager.defaultOpenStreamRepository)),
      );
      expect(
        urls,
        hasLength(6),
      ); // one custom plus the five new bundled indexes.
      dio.close(force: true);
    },
  );

  test(
    'manual bundled repository restore is additive and idempotent',
    () async {
      const customRepository = 'https://custom.example/index.json';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'unified_source_default_repository_seeded_v1': true,
        'unified_source_default_repository_seed_version_v2': 2,
        'unified_source_repository_urls_v1': <String>[customRepository],
      });
      final preferences = await SharedPreferences.getInstance();
      final manager = SourceRepositoryManager(preferences: preferences);

      final added = await manager.addDefaultRepositories();
      final secondAdded = await manager.addDefaultRepositories();

      expect(added, 6);
      expect(secondAdded, 0);
      expect(await manager.repositoryUrls(), hasLength(7));
      expect(await manager.repositoryUrls(), contains(customRepository));
    },
  );

  test(
    'pins GitHub repositories to full commits and exports the pin',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final manager = SourceRepositoryManager(preferences: preferences);
      const repositoryUrl =
          'https://raw.githubusercontent.com/example/providers/main/index.json';
      const commit = '0123456789abcdef0123456789abcdef01234567';

      await manager.addRepository(repositoryUrl);
      await manager.pinRepositoryToCommit(repositoryUrl, commit);

      expect(await manager.pinnedCommit(repositoryUrl), commit);
      final exported = jsonDecode(await manager.exportConfiguration()) as Map;
      expect(exported['schemaVersion'], 3);
      expect(exported['repositoryPins'], isNotEmpty);

      await manager.clearRepositoryPin(repositoryUrl);
      expect(await manager.pinnedCommit(repositoryUrl), isNull);
    },
  );

  test(
    'repository update preview and rollback restore the previous manifest',
    () async {
      var version = 1;
      var repositoryRequests = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        repositoryRequests++;
        return <String, dynamic>{
          'name': 'Versioned Repository',
          'extensions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'versioned-source',
              'name': 'Versioned Source',
              'version': '$version.0.0',
              'engine': <String, dynamic>{
                'type': 'vidking-direct',
                'endpoint': 'cdn/source-$version',
              },
            },
          ],
        };
      });
      final preferences = await SharedPreferences.getInstance();
      final root = await Directory.systemTemp.createTemp(
        'raven23-manager-revisions-',
      );
      final manager = SourceRepositoryManager(
        client: SourceRepositoryClient(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ),
        preferences: preferences,
        artifactStore: SourceRepositoryArtifactStore(rootDirectory: root),
      );
      const repositoryUrl = 'https://repo.example/index.json';
      await manager.addRepository(repositoryUrl);
      final first = await manager.sync(forceRefresh: true);
      expect(first.catalog.single.version, '1.0.0');

      version = 2;
      final preview = await manager.previewRepositoryUpdate(repositoryUrl);
      expect(preview.hasChanges, isTrue);
      expect(preview.changedSourceIds, <String>['versioned-source']);
      expect(preview.candidateManifest.extensions.single.version, '2.0.0');
      final requestsAtPreview = repositoryRequests;

      final applied = await manager.applyPreviewedRepositoryUpdate(preview);
      expect(applied.catalog.single.version, '2.0.0');
      expect(repositoryRequests, requestsAtPreview);
      expect((await manager.repositoryRevisions(repositoryUrl)).length, 2);
      final rollback = await manager.rollbackRepository(repositoryUrl);
      expect(rollback, isNotNull);
      final restored = await manager.sync(forceRefresh: true);
      expect(restored.catalog.single.version, '1.0.0');

      await manager.resumeRepositoryUpdates(repositoryUrl);
      version = 3;
      final latest = await manager.sync(forceRefresh: true);
      expect(latest.catalog.single.version, '3.0.0');
      dio.close(force: true);
      await root.delete(recursive: true);
    },
  );

  test('catalog entries are not resolved until explicitly installed', () async {
    final dio = _repositoryDio();
    final preferences = await SharedPreferences.getInstance();
    final manager = SourceRepositoryManager(
      client: SourceRepositoryClient(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ),
      preferences: preferences,
    );
    await manager.addRepository('https://repo.example/index.json');

    final discovered = await manager.sync();
    expect(discovered.catalog, hasLength(1));
    expect(discovered.sources, isEmpty);

    await manager.installSource(discovered.catalog.single);
    final installed = await manager.sync();
    expect(installed.sources, hasLength(1));
    expect(installed.sources.single.id, 'catalog-addon');

    await manager.uninstallSource(installed.sources.single);
    final uninstalled = await manager.sync();
    expect(uninstalled.catalog, hasLength(1));
    expect(uninstalled.sources, isEmpty);
    dio.close(force: true);
  });

  test(
    'reuses the source catalogue within its cache window and force refreshes',
    () async {
      var repositoryRequests = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        if (options.uri.host == 'repo.example') repositoryRequests++;
        if (options.uri.host == 'repo.example') {
          return <String, dynamic>{
            'name': 'Cached Repository',
            'extensions': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'cached-addon',
                'name': 'Cached Addon',
                'engine': <String, dynamic>{
                  'type': 'stremio',
                  'endpoint': 'https://addon.example',
                },
              },
            ],
          };
        }
        return <String, dynamic>{
          'id': 'org.cached.addon',
          'name': 'Cached Addon',
          'resources': <String>['stream'],
          'types': <String>['movie'],
          'idPrefixes': <String>['tt'],
        };
      });
      final preferences = await SharedPreferences.getInstance();
      final manager = SourceRepositoryManager(
        client: SourceRepositoryClient(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ),
        preferences: preferences,
      );
      await manager.addRepository('https://repo.example/index.json');

      await manager.sync();
      final firstRequestCount = repositoryRequests;
      await manager.sync();
      expect(repositoryRequests, firstRequestCount);

      await manager.sync(forceRefresh: true);
      expect(repositoryRequests, greaterThan(firstRequestCount));
      dio.close(force: true);
    },
  );

  test(
    'removing a repository clears its saved source installation state',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final manager = SourceRepositoryManager(preferences: preferences);
      const source = SourceManifest(
        id: 'installed-addon',
        name: 'Installed Addon',
        repositoryUrl: 'https://repo.example/index.json',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
        ),
      );
      await manager.addRepository('https://repo.example/index.json');
      await manager.installSource(source);
      expect(await manager.installedSourceKeys(), contains(source.stableKey));

      await manager.removeRepository('https://repo.example/index.json');
      expect(await manager.repositoryUrls(), isEmpty);
      expect(await manager.installedSourceKeys(), isEmpty);
    },
  );

  test(
    'directly added Stremio manifest is enabled by default and can be removed',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter(
        (options) async => <String, dynamic>{
          'id': 'direct-addon',
          'name': 'Direct Addon',
          'resources': <String>['stream'],
          'types': <String>['movie'],
        },
      );
      final preferences = await SharedPreferences.getInstance();
      final manager = SourceRepositoryManager(
        client: SourceRepositoryClient(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ),
        preferences: preferences,
      );
      await manager.addRepository('https://addon.example/manifest.json');

      final added = await manager.sync();
      expect(added.catalog.single.installedByDefault, isTrue);
      expect(added.sources, hasLength(1));

      await manager.uninstallSource(added.sources.single);
      expect((await manager.sync()).sources, isEmpty);

      await manager.installSource(added.catalog.single);
      expect((await manager.sync()).sources, hasLength(1));
      dio.close(force: true);
    },
  );
}

Dio _bundledRepositoriesDio() {
  final dio = Dio();
  dio.httpClientAdapter = _JsonAdapter((options) async {
    final path = options.uri.path;
    if (path.contains('/OpenStream/')) {
      return <String, dynamic>{
        'name': 'OpenStream Official',
        'manifestVersion': 1,
        'extensions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'openstream-default',
            'name': 'OpenStream Default',
            'tags': <String>['movies', 'series'],
            'installedByDefault': true,
            'engine': <String, dynamic>{
              'type': 'vidking-direct',
              'endpoint': 'cdn/sources-with-title',
            },
          },
        ],
      };
    }
    final pathSegments = options.uri.pathSegments;
    final repositoryId = pathSegments.length > 1
        ? pathSegments[1].toLowerCase()
        : 'custom-repository';
    return <String, dynamic>{
      'name': 'Repository $repositoryId',
      'description': 'Zangetsu-compatible fixture',
      'sources': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'provider-$repositoryId',
          'name': 'Provider $repositoryId',
          'type': 'anime',
          'lang': 'en',
          'file': 'providers/provider.js',
        },
      ],
    };
  });
  return dio;
}

Dio _repositoryDio() {
  final dio = Dio();
  dio.httpClientAdapter = _JsonAdapter((options) async {
    if (options.uri.host == 'repo.example') {
      return <String, dynamic>{
        'name': 'Test Repository',
        'extensions': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'catalog-addon',
            'name': 'Catalog Addon',
            'engine': <String, dynamic>{
              'type': 'stremio',
              'endpoint': 'https://addon.example',
            },
          },
        ],
      };
    }
    return <String, dynamic>{
      'id': 'org.catalog.addon',
      'name': 'Catalog Addon',
      'resources': <String>['stream'],
      'types': <String>['movie'],
      'idPrefixes': <String>['tt'],
    };
  });
  return dio;
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.handler);

  final Future<Map<String, dynamic>> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
