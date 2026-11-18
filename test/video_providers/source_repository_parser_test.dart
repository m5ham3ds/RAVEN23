import 'dart:io';

import 'package:raven23/video_providers/unified/source_contracts.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_repository_parser.dart';
import 'package:raven23/video_providers/unified/vidking_audio_quality_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = SourceRepositoryParser();

  group('SourceRepositoryParser', () {
    test(
      'parses OpenStream-style extension entries and keeps engine metadata',
      () async {
        // A representative OpenStream-style descriptor fixture.
        const json = '''
      {
        "manifestVersion": 1,
        "name": "Example Repo",
        "extensions": [
          {
            "id": "addon-one",
            "name": "Addon One",
            "version": "1.2.0",
            "versionCode": 2,
            "language": "Multi",
            "tags": ["movies", "series"],
            "engine": {
              "type": "stremio",
              "endpoint": "https://addon.example",
              "priority": 7
            }
          }
        ]
      }
      ''';
        final repository = parser.parseRepository(
          json,
          sourceUrl: 'https://repo.example/index.json',
        );

        expect(repository.name, 'Example Repo');
        expect(repository.extensions, hasLength(1));
        expect(
          repository.extensions.single.engine.kind,
          SourceEngineKind.stremio,
        );
        expect(repository.extensions.single.installedByDefault, isFalse);
        expect(repository.extensions.single.engine.priority, 7);
        expect(
          repository.extensions.single.repositoryUrl,
          'https://repo.example/index.json',
        );
      },
    );

    test('parses VidKing audio language independently from video quality', () {
      const json = '''
      {
        "manifestVersion": 1,
        "name": "VidKing Language and Quality",
        "extensions": [
          {
            "id": "vidking-arabic-1080",
            "name": "VidKing Arabic 1080p",
            "language": "Hindi",
            "engine": {
              "type": "vidking-direct",
              "endpoint": "sources-with-title",
              "audioLanguage": "ar",
              "qualityFilter": "1080p"
            }
          }
        ]
      }
      ''';
      final source = parser
          .parseRepository(json, sourceUrl: 'https://repo.example/index.json')
          .extensions
          .single;

      expect(source.language, 'Hindi');
      expect(source.engine.audioLanguage, 'Arabic');
      expect(source.engine.qualityFilter, '1080p');
      expect(source.engine.config, <String, dynamic>{
        'languageDeclared': true,
        'statusDeclared': false,
      });
      expect(source.engine.config, isNot(contains('audioLanguage')));
      expect(source.engine.config, isNot(contains('qualityFilter')));
    });

    test('parses a Stremio manifest URL as a source entry', () {
      const json = '''
      {
        "id": "org.example.addon",
        "version": "1.0.0",
        "name": "Example Stremio Addon",
        "description": "Test addon",
        "resources": ["catalog", "stream"],
        "types": ["movie", "series"],
        "idPrefixes": ["tt"]
      }
      ''';
      final repository = parser.parseRepository(
        json,
        sourceUrl: 'https://addon.example/config/manifest.json',
      );

      expect(repository.isStremioAddon, isTrue);
      expect(
        repository.extensions.single.engine.kind,
        SourceEngineKind.stremio,
      );
      expect(repository.extensions.single.installedByDefault, isTrue);
      expect(
        repository.extensions.single.engine.endpoint,
        'https://addon.example/config',
      );
      expect(
        Uri.parse(repository.extensions.single.engine.endpoint).hasFragment,
        isFalse,
      );
      expect(
        repository.extensions.single.engine.config['types'],
        containsAll(<String>['movie', 'series']),
      );
    });

    test('reads Stremio stream resource types and idPrefixes', () {
      const json = '''
      {
        "id": "org.example.resource-prefixes",
        "name": "Resource Prefix Addon",
        "resources": [
          {"name": "catalog", "types": ["movie"]},
          {"name": "stream", "types": ["series"], "idPrefixes": ["kitsu:", "anilist:"]}
        ]
      }
      ''';
      final repository = parser.parseRepository(
        json,
        sourceUrl: 'https://addon.example/manifest.json',
      );
      final source = repository.extensions.single;

      expect(source.engine.kind, SourceEngineKind.stremio);
      expect(source.engine.config['types'], contains('series'));
      expect(source.engine.config['types'], isNot(contains('movie')));
      expect(
        source.engine.config['idPrefixes'],
        containsAll(['kitsu:', 'anilist:']),
      );
    });

    test(
      'treats omitted root idPrefixes on a string stream resource as unrestricted',
      () {
        const json = '''
      {
        "id": "org.example.no-prefix",
        "name": "No Prefix Addon",
        "resources": ["stream"],
        "types": ["movie"]
      }
      ''';
        final repository = parser.parseRepository(
          json,
          sourceUrl: 'https://addon.example/manifest.json',
        );

        final source = repository.extensions.single;
        expect(source.engine.config.containsKey('idPrefixes'), isFalse);
        final profile =
            (source.engine.config['streamResourceProfiles'] as List).single
                as Map;
        expect(profile['prefixMode'], 'any');
      },
    );

    test(
      'parses Stremio config schema with supported types and bounded options',
      () {
        const json = '''
      {
        "id": "org.example.config-schema",
        "name": "Config Schema Addon",
        "resources": ["stream"],
        "types": ["movie"],
        "behaviorHints": {"configurable": true},
        "config": [
          {"key":"username","type":"text","title":"Account name","required":true},
          {"key":"quality","type":"select","options":["720p","1080p","4K"]},
          {"key":"enabled","type":"checkbox","default":"checked"},
          {"key":"api_key","type":"password","default":"should-not-be-persisted"},
          {"key":"ignored","type":"unsupported"},
          {"key":"quality","type":"select","options":["duplicate"]}
        ]
      }
      ''';
        final source = parser
            .parseRepository(
              json,
              sourceUrl: 'https://addon.example/manifest.json',
            )
            .extensions
            .single;
        final fields = source.engine.config['configurationSchema'] as List;

        expect(fields, hasLength(4));
        expect(fields[0]['key'], 'username');
        expect(fields[0]['required'], isTrue);
        expect(fields[1]['options'], <String>['720p', '1080p', '4K']);
        expect(fields[2]['default'], 'checked');
        expect(fields[3]['key'], 'api_key');
        expect(fields[3].containsKey('default'), isFalse);
      },
    );

    test('rejects malformed Stremio config and behavior hint containers', () {
      const malformedManifests = <String>[
        '{"id":"bad.config","resources":["stream"],"types":["movie"],"config":{}}',
        '{"id":"bad.hints","resources":["stream"],"types":["movie"],"behaviorHints":[]}',
        '{"id":"bad.boolean","resources":["stream"],"types":["movie"],"behaviorHints":{"configurable":"yes"}}',
      ];
      for (final raw in malformedManifests) {
        expect(
          () => parser.parseRepository(
            raw,
            sourceUrl: 'https://addon.example/manifest.json',
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test(
      'does not require configuration when both behavior hints are false',
      () {
        const json = '''
      {
        "id": "org.example.no-config",
        "name": "No Config Addon",
        "resources": ["stream"],
        "types": ["movie"],
        "behaviorHints": {
          "configurable": false,
          "configurationRequired": false
        }
      }
      ''';
        final source = parser
            .parseRepository(
              json,
              sourceUrl: 'https://addon.example/manifest.json',
            )
            .extensions
            .single;

        expect(source.engine.kind, SourceEngineKind.stremio);
        expect(source.enabled, isTrue);
        expect(source.engine.config['configurable'], isFalse);
        expect(source.engine.config['configurationRequired'], isFalse);
        expect(source.engine.config.containsKey('configurationUrl'), isFalse);
      },
    );

    test(
      'configurationRequired remains authoritative when configurable is false',
      () {
        const json = '''
      {
        "id": "org.example.required-unconfigurable",
        "name": "Required Unconfigurable Addon",
        "resources": ["stream"],
        "types": ["movie"],
        "behaviorHints": {
          "configurable": false,
          "configurationRequired": true
        }
      }
      ''';
        final source = parser
            .parseRepository(
              json,
              sourceUrl: 'https://addon.example/manifest.json',
            )
            .extensions
            .single;

        expect(source.engine.kind, SourceEngineKind.stremio);
        expect(source.enabled, isTrue);
        expect(source.engine.config['configurationRequired'], isTrue);
        expect(source.engine.config['needsConfiguration'], isTrue);
        expect(
          source.engine.config['configurationUrl'],
          'https://addon.example/configure',
        );
      },
    );

    test(
      'configurable but not configuration-required add-ons remain runnable',
      () {
        const json = '''
      {
        "id": "org.example.optional-config",
        "name": "Optional Config Addon",
        "resources": ["stream"],
        "types": ["movie", "series"],
        "behaviorHints": {
          "configurable": true,
          "configurationRequired": false
        }
      }
      ''';
        final source = parser
            .parseRepository(
              json,
              sourceUrl: 'https://addon.example/manifest.json',
            )
            .extensions
            .single;

        expect(source.engine.kind, SourceEngineKind.stremio);
        expect(source.enabled, isTrue);
        expect(source.engine.config['configurable'], isTrue);
        expect(source.engine.config['configurationRequired'], isFalse);
        expect(source.engine.config['needsConfiguration'], isFalse);
        expect(
          source.engine.config['configurationUrl'],
          'https://addon.example/configure',
        );
      },
    );

    test(
      'configurationRequired is distinct from configurable and remains explicit',
      () {
        const json = '''
      {
        "id": "org.example.required-config",
        "name": "Required Config Addon",
        "resources": ["stream"],
        "types": ["movie"],
        "behaviorHints": {
          "configurable": true,
          "configurationRequired": true
        }
      }
      ''';
        final source = parser
            .parseRepository(
              json,
              sourceUrl: 'https://addon.example/manifest.json',
            )
            .extensions
            .single;

        expect(source.engine.kind, SourceEngineKind.stremio);
        expect(source.enabled, isTrue);
        expect(source.engine.config['configurable'], isTrue);
        expect(source.engine.config['configurationRequired'], isTrue);
        expect(source.engine.config['needsConfiguration'], isTrue);
        expect(
          source.engine.config['configurationUrl'],
          'https://addon.example/configure',
        );
      },
    );

    test('preserves stream-resource-specific type and ID-prefix filters', () {
      const json = '''
      {
        "id": "org.example.resource-filters",
        "name": "Resource Filter Addon",
        "resources": [
          {"name": "stream", "types": ["movie"], "idPrefixes": ["tt"]},
          {"name": "stream", "types": ["series"], "idPrefixes": ["kitsu:"]}
        ],
        "types": ["movie", "series"],
        "idPrefixes": ["root:"]
      }
      ''';
      final source = parser
          .parseRepository(
            json,
            sourceUrl: 'https://addon.example/manifest.json',
          )
          .extensions
          .single;
      final profiles = source.engine.config['streamResourceProfiles'] as List;

      expect(profiles, hasLength(2));
      expect(profiles[0]['types'], <String>['movie']);
      expect(profiles[0]['idPrefixes'], <String>['tt']);
      expect(profiles[1]['types'], <String>['series']);
      expect(profiles[1]['idPrefixes'], <String>['kitsu:']);
    });

    test(
      'object stream resources without idPrefixes accept supplied IDs without inheriting root prefixes',
      () {
        const json = '''
      {
        "id": "org.example.unrestricted-resource",
        "name": "Unrestricted Resource Addon",
        "resources": [
          {"name": "stream", "types": ["series"]}
        ],
        "types": ["movie"],
        "idPrefixes": ["tt"]
      }
      ''';
        final source = parser
            .parseRepository(
              json,
              sourceUrl: 'https://addon.example/manifest.json',
            )
            .extensions
            .single;
        final profile =
            (source.engine.config['streamResourceProfiles'] as List).single
                as Map;

        expect(profile['types'], <String>['series']);
        expect(profile['prefixMode'], 'any');
        expect(profile.containsKey('idPrefixes'), isFalse);
      },
    );

    test('validates and retains Stremio catalogs and bounded extra fields', () {
      const json = '''
      {
        "id": "org.example.catalogs",
        "name": "Catalog Addon",
        "resources": ["catalog", "stream"],
        "types": ["movie"],
        "catalogs": [
          {
            "type": "movie",
            "id": "featured",
            "name": "Featured",
            "extra": [
              {"name": "search", "isRequired": true},
              {"name": "skip", "isRequired": false, "options": ["0", "20"]},
              {"name": "genre", "isRequired": false, "options": ["Action", "Sci-Fi"]}
            ]
          },
          {"type": "movie", "id": "featured", "name": "Duplicate"},
          {"type": "series", "id": "broken"},
          "invalid"
        ]
      }
      ''';
      final source = parser
          .parseRepository(
            json,
            sourceUrl: 'https://addon.example/manifest.json',
          )
          .extensions
          .single;
      final catalogs = source.engine.config['catalogs'] as List;

      expect(catalogs, hasLength(1));
      expect(catalogs.single['type'], 'movie');
      expect(catalogs.single['id'], 'featured');
      expect((catalogs.single['extra'] as List), hasLength(3));
      expect((catalogs.single['extra'] as List).first['isRequired'], isTrue);
      expect((catalogs.single['extra'] as List)[2]['options'], <String>[
        'Action',
        'Sci-Fi',
      ]);
    });

    test(
      'preserves configured manifest path and query but omits fragment and config token',
      () {
        const json = '''
      {
        "id": "org.example.path-config",
        "name": "Path Config Addon",
        "resources": ["stream"],
        "types": ["movie"],
        "behaviorHints": {"configurable": true}
      }
      ''';
        final source = parser
            .parseRepository(
              json,
              sourceUrl:
                  'https://addon.example/users/secret/manifest.json?token=abc123#fragment',
            )
            .extensions
            .single;

        final endpoint = Uri.parse(source.engine.endpoint);
        expect(endpoint.path, '/users/secret');
        expect(endpoint.queryParameters['token'], 'abc123');
        expect(endpoint.fragment, isEmpty);
        expect(endpoint.hasFragment, isFalse);
        final configurationUrl = Uri.parse(
          source.engine.config['configurationUrl'] as String,
        );
        expect(configurationUrl.hasFragment, isFalse);
        expect(
          source.engine.config['configurationUrl'],
          'https://addon.example/users/secret/configure',
        );
        expect(
          source.engine.config['configurationUrl'].toString(),
          isNot(contains('abc123')),
        );
      },
    );

    test('removes empty query markers from derived Stremio URLs', () {
      const json = '''
      {
        "id": "org.example.empty-query",
        "name": "Empty Query Addon",
        "resources": ["stream"],
        "types": ["movie"],
        "behaviorHints": {"configurable": true}
      }
      ''';
      final source = parser
          .parseRepository(
            json,
            sourceUrl: 'https://addon.example/manifest.json?#ignored-fragment',
          )
          .extensions
          .single;

      final endpoint = Uri.parse(source.engine.endpoint);
      final configurationUrl = Uri.parse(
        source.engine.config['configurationUrl'] as String,
      );
      expect(source.engine.endpoint, 'https://addon.example');
      expect(endpoint.hasQuery, isFalse);
      expect(endpoint.hasFragment, isFalse);
      expect(
        source.engine.config['configurationUrl'],
        'https://addon.example/configure',
      );
      expect(configurationUrl.hasQuery, isFalse);
      expect(configurationUrl.hasFragment, isFalse);
    });

    test('parses the currently published YaStream manifest fixture', () async {
      final raw = await File(
        'test/fixtures/stremio/yastream_manifest.json',
      ).readAsString();
      final repository = parser.parseRepository(
        raw,
        sourceUrl: 'https://yastream.tamthai.de/manifest.json',
      );
      final source = repository.extensions.single;

      expect(source.id, 'community.yastream');
      expect(source.engine.kind, SourceEngineKind.stremio);
      expect(source.engine.config['types'], containsAll(['movie', 'series']));
      expect(source.engine.config['catalogs'], hasLength(5));
      expect(source.engine.config['configurable'], isTrue);
      expect(source.engine.config['configurationRequired'], isFalse);
      expect(source.enabled, isTrue);
    });

    test('rejects malformed root type, prefix, and catalog containers', () {
      const malformedManifests = <String>[
        '{"id":"bad.types","resources":["stream"],"types":"movie"}',
        '{"id":"bad.prefixes","resources":["stream"],"types":["movie"],"idPrefixes":"tt"}',
        '{"id":"bad.catalogs","resources":["stream"],"types":["movie"],"catalogs":{}}',
      ];
      for (final raw in malformedManifests) {
        expect(
          () => parser.parseRepository(
            raw,
            sourceUrl: 'https://addon.example/manifest.json',
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('rejects a Stremio manifest without a resources array', () {
      expect(
        () => parser.parseRepository(
          '{"id":"org.example.invalid","types":["movie"]}',
          sourceUrl: 'https://addon.example/manifest.json',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('does not mark a Stremio entry runnable without a valid endpoint', () {
      const json = '''
      {
        "name": "Repo",
        "extensions": [
          {"id":"broken-addon","name":"Broken Addon","engine":{"type":"stremio"}}
        ]
      }
      ''';
      final repository = parser.parseRepository(
        json,
        sourceUrl: 'https://repo.example/index.json',
      );

      expect(
        repository.extensions.single.engine.kind,
        SourceEngineKind.unsupported,
      );
      expect(repository.extensions.single.isRunnable, isFalse);
    });

    test(
      'recognizes OpenStream Vidking entries as runnable engine manifests',
      () {
        const json = '''
      {
        "name": "OpenStream Official",
        "extensions": [
          {
            "id": "yoru",
            "name": "Yoru",
            "installedByDefault": true,
            "status": 1,
            "engine": {
              "type": "vidking-direct",
              "endpoint": "cdn/sources-with-title",
              "priority": 0
            }
          }
        ]
      }
      ''';
        final repository = parser.parseRepository(
          json,
          sourceUrl: 'https://repo.example/index.json',
        );
        final source = repository.extensions.single;

        expect(source.id, 'yoru');
        expect(source.installedByDefault, isTrue);
        expect(source.engine.rawType, 'vidking-direct');
        expect(source.engine.kind, SourceEngineKind.vidkingDirect);
        expect(source.isRunnable, isTrue);
      },
    );

    test(
      'parses all engine families in the OpenStream official repository fixture',
      () async {
        final raw = await File(
          'test/fixtures/openstream_official_repo.json',
        ).readAsString();
        final repository = parser.parseRepository(
          raw,
          sourceUrl:
              'https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json',
        );

        expect(repository.extensions, hasLength(30));
        final byType = <String, List<SourceManifest>>{};
        for (final source in repository.extensions) {
          byType
              .putIfAbsent(source.engine.rawType, () => <SourceManifest>[])
              .add(source);
        }
        expect(byType['vidking-direct'], hasLength(9));
        // Keep every upstream VidKing route bound to its source identity.
        // These are contract tests against the checked-in official index;
        // they do not claim that an upstream endpoint is currently playable.
        const vidkingRoutes = <String, String>{
          'yoru': 'cdn/sources-with-title',
          'cypher': 'downloader2/sources-with-title',
          'breach': 'm4uhd/sources-with-title',
          'neon': 'vsrc/sources-with-title',
          'vyse': 'hdmovie/sources-with-title',
          'killjoy': 'meine/sources-with-title',
          'fade': 'hdmovie/sources-with-title',
          'omen': 'lamovie/sources-with-title',
          'raze': 'superflix/sources-with-title',
        };
        for (final source in byType['vidking-direct']!) {
          expect(source.engine.endpoint, vidkingRoutes[source.id]);
          expect(source.status, 1, reason: source.id);
          expect(source.engine.kind, SourceEngineKind.vidkingDirect);
          expect(source.isRunnable, isTrue);
        }
        expect(
          byType['vidking-direct']!
              .where((source) => source.installedByDefault)
              .map((source) => source.id)
              .toSet(),
          <String>{'yoru', 'cypher', 'breach', 'neon', 'vyse'},
          reason: 'Preserve upstream defaults; rollout decisions are separate.',
        );
        expect(byType['stremio'], hasLength(5));
        expect(byType['web-embed'], hasLength(10));
        expect(byType['vidking-webview'], hasLength(1));
        expect(byType['anikoto'], hasLength(1));
        expect(byType['reanime'], hasLength(1));
        expect(byType['animepahe'], hasLength(1));
        expect(byType['fouranimo'], hasLength(1));
        expect(byType['animegg'], hasLength(1));
        expect(
          repository.extensions
              .where(
                (source) =>
                    source.engine.kind == SourceEngineKind.animeSite &&
                    source.installedByDefault,
              )
              .map((source) => source.id)
              .toSet(),
          <String>{'anikoto', 'reanime'},
          reason: 'Preserve only the two anime defaults declared upstream.',
        );

        expect(
          byType['vidking-direct']!.every(
            (source) => source.engine.kind == SourceEngineKind.vidkingDirect,
          ),
          isTrue,
        );
        // Legacy OpenStream values are migrated from qualityFilter to the
        // dedicated audioLanguage field without consulting catalog language.
        final vyse = byType['vidking-direct']!.singleWhere(
          (source) => source.id == 'vyse',
        );
        final fade = byType['vidking-direct']!.singleWhere(
          (source) => source.id == 'fade',
        );
        final killjoy = byType['vidking-direct']!.singleWhere(
          (source) => source.id == 'killjoy',
        );
        expect(vyse.engine.audioLanguage, 'English');
        expect(vyse.engine.qualityFilter, isNull);
        expect(fade.engine.audioLanguage, 'Hindi');
        expect(fade.engine.qualityFilter, isNull);
        expect(killjoy.engine.audioLanguage, isNull);
        expect(killjoy.engine.language, 'german');
        expect(
          VidkingAudioQualityNormalizer.resolveAudioLanguage(
            engine: killjoy.engine,
          ),
          'German',
          reason: 'Legacy engine.language remains a canonical audio default.',
        );
        expect(killjoy.engine.qualityFilter, isNull);
        expect(
          byType['stremio']!.every(
            (source) => source.engine.kind == SourceEngineKind.stremio,
          ),
          isTrue,
        );
        expect(
          byType['web-embed']!.every(
            (source) =>
                source.engine.kind == SourceEngineKind.webEmbed &&
                source.status == 3 &&
                source.isFallback &&
                source.engine.movieUrl?.contains('{tmdbId}') == true &&
                source.engine.tvUrl?.contains('{tmdbId}') == true &&
                source.engine.tvUrl?.contains('{season}') == true &&
                source.engine.tvUrl?.contains('{episode}') == true,
          ),
          isTrue,
          reason:
              'Web Embed entries remain Beta fallbacks with movie/TV routes.',
        );
        // OpenStream Web Embed providers support movies as well as series.
        // Jett is the reference movie route used by the working OpenStream app.
        final jett = byType['web-embed']!.singleWhere(
          (source) => source.id == 'jett',
        );
        expect(jett.engine.movieUrl, 'https://vidlink.pro/movie/{tmdbId}');
        expect(
          jett.engine.tvUrl,
          'https://vidlink.pro/tv/{tmdbId}/{season}/{episode}',
        );
        expect(jett.tags, containsAll(<String>['movies', 'series']));
        expect(jett.isFallback, isTrue);
        expect(jett.status, 3); // Beta is playable; only status 0 means down.
        expect(
          byType['vidking-webview']!.single.engine.kind,
          SourceEngineKind.vidkingWebView,
        );
        expect(
          byType['vidking-direct']!.every((source) => !source.isFallback),
          isTrue,
        );
        expect(
          byType['web-embed']!.every((source) => source.isFallback),
          isTrue,
        );
        expect(byType['vidking-webview']!.single.isFallback, isTrue);
        for (final type in [
          'anikoto',
          'reanime',
          'animepahe',
          'fouranimo',
          'animegg',
        ]) {
          final animeSource = byType[type]!.single;
          expect(animeSource.engine.kind, SourceEngineKind.animeSite);
          expect(animeSource.isRunnable, isTrue);
          expect(animeSource.status, 3, reason: '$type remains upstream Beta');
          expect(
            animeSource.tags,
            containsAll(<String>['anime', 'sub', 'dub']),
          );
          final lifecycle = SourceLifecycleSnapshot.fromManifest(
            animeSource,
            installed: true,
          );
          expect(lifecycle.has(SourceLifecycleFlag.experimental), isTrue);
          expect(lifecycle.has(SourceLifecycleFlag.enabled), isTrue);
        }
        expect(
          repository.extensions.where((source) => source.isRunnable),
          hasLength(30),
        );
      },
    );

    test(
      'parses Zangetsu JavaScript source repositories without running them',
      () {
        const json = '''
      {
        "name": "Zangetsu Sources",
        "description": "Example JS provider repository",
        "sources": [
          {
            "id": "allanime",
            "name": "AllAnime",
            "version": "1.0.0",
            "type": "anime",
            "lang": "en",
            "file": "providers/allanime.js",
            "logo": "icons/allanime.png",
            "nsfw": false
          }
        ]
      }
      ''';
        final repository = parser.parseRepository(
          json,
          sourceUrl: 'https://repo.example/zangetsu/index.json',
        );
        final source = repository.extensions.single;

        expect(source.name, 'AllAnime');
        expect(source.engine.rawType, 'javascript');
        expect(source.engine.kind, SourceEngineKind.javascript);
        expect(
          source.engine.endpoint,
          'https://repo.example/zangetsu/providers/allanime.js',
        );
        expect(
          source.iconUrl,
          'https://repo.example/zangetsu/icons/allanime.png',
        );
        expect(source.engine.config['providerType'], 'anime');
        expect(source.installedByDefault, isFalse);
      },
    );

    test(
      'classifies only explicitly anime-exclusive sources as anime-only',
      () {
        const json = '''
      {
        "name": "Capability fixtures",
        "extensions": [
          {
            "id": "anime-site",
            "name": "Anime Site",
            "tags": ["anime", "sub", "dub"],
            "engine": {"type": "anikoto", "endpoint": "https://anime.example/api"}
          },
          {
            "id": "multi-vidking",
            "name": "Multi Vidking",
            "tags": ["anime", "movies", "series"],
            "engine": {"type": "vidking-direct", "endpoint": "cdn/sources-with-title"}
          },
          {
            "id": "multi-embed",
            "name": "Multi Embed",
            "tags": ["movies", "series", "anime", "fallback"],
            "engine": {
              "type": "web-embed",
              "movieUrl": "https://embed.example/movie/{tmdbId}",
              "tvUrl": "https://embed.example/tv/{tmdbId}/{season}/{episode}"
            }
          },
          {
            "id": "donghua-only",
            "name": "Donghua Only",
            "tags": ["donghua"],
            "engine": {
              "type": "javascript",
              "endpoint": "https://repo.example/providers/donghua.js"
            }
          }
        ]
      }
      ''';
        final parsed = parser
            .parseRepository(
              json,
              sourceUrl: 'https://repo.example/capabilities.json',
            )
            .extensions;
        final byId = {for (final source in parsed) source.id: source};

        expect(byId['anime-site']!.isAnimeOnly, isTrue);
        expect(byId['multi-vidking']!.isAnimeOnly, isFalse);
        expect(byId['multi-embed']!.isAnimeOnly, isFalse);
        expect(byId['donghua-only']!.isAnimeOnly, isTrue);
      },
    );

    test('Zangetsu sources without a declared content type default to all', () {
      const json = '''
      {
        "name": "Generic JavaScript sources",
        "sources": [
          {"id": "generic", "name": "Generic", "file": "providers/generic.js"},
          {"id": "anime", "name": "Anime", "type": "anime", "file": "providers/anime.js"}
        ]
      }
      ''';
      final parsed = parser
          .parseRepository(
            json,
            sourceUrl: 'https://repo.example/zangetsu/index.json',
          )
          .extensions;
      final byId = {for (final source in parsed) source.id: source};

      expect(byId['generic']!.engine.config['providerType'], 'all');
      expect(byId['generic']!.isAnimeOnly, isFalse);
      expect(byId['anime']!.engine.config['providerType'], 'anime');
      expect(byId['anime']!.isAnimeOnly, isTrue);
      final donghua = SourceManifest(
        id: 'donghua-type',
        name: 'Donghua Type',
        engine: const SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
          config: <String, dynamic>{'providerType': 'donghua'},
        ),
      );
      expect(donghua.isAnimeOnly, isTrue);
    });

    test('keeps unknown engine entries visible but marks them unsupported', () {
      const json = '''
      {
        "name": "Repo",
        "extensions": [
          {"id":"future","name":"Future","engine":{"type":"new-engine"}}
        ]
      }
      ''';
      final repository = parser.parseRepository(
        json,
        sourceUrl: 'https://repo.example/index.json',
      );
      expect(
        repository.extensions.single.engine.kind,
        SourceEngineKind.unsupported,
      );
      expect(repository.extensions.single.isRunnable, isFalse);
    });
  });
}
