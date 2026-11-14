import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:raven23/video_providers/unified/source_host_policy.dart';
import 'package:raven23/video_providers/unified/source_repository_client.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects M3U and media manifest URLs as source repositories', () {
    for (final url in <String>[
      'https://example.test/playlist.m3u',
      'https://example.test/index.m3u8?token=public',
      'https://example.test/live/channel.mpd',
    ]) {
      expect(
        () => SourceRepositoryClient.normalizeRepositoryUrl(url),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('media playlist or stream URL'),
          ),
        ),
      );
    }
    expect(
      SourceRepositoryClient.normalizeRepositoryUrl(
        'https://example.test/extensions/index.json',
      ),
      'https://example.test/extensions/index.json',
    );
  });

  test('rejects extensionless endpoints that return an M3U document', () async {
    final dio = Dio();
    dio.httpClientAdapter = _TextAdapter(
      '\uFEFF#EXTM3U\n#EXTINF:-1,Test Channel\nhttps://media.example/live.m3u8',
    );
    final client = SourceRepositoryClient(
      dio: dio,
      hostPolicy: const SourceHostPolicy(resolveDns: false),
    );

    await expectLater(
      client.fetchRepository('https://repo.example/live/channels'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('M3U/HLS media playlist'),
        ),
      ),
    );
    dio.close(force: true);
  });

  test(
    'enriches Stremio entries from OpenStream-style indexes with manifest IDs',
    () async {
      final requested = <String>[];
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requested.add(options.uri.toString());
        if (options.uri.host == 'repo.example') {
          return <String, dynamic>{
            'manifestVersion': 1,
            'name': 'Test Repository',
            'extensions': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'test-addon',
                'name': 'Test Addon',
                'engine': <String, dynamic>{
                  'type': 'stremio',
                  'endpoint':
                      'https://addon.example/config?tenant=profile-a&token=private',
                  'priority': 15,
                },
              },
            ],
          };
        }
        return <String, dynamic>{
          'id': 'org.test.addon',
          'name': 'Test Addon Manifest',
          'version': '1.2.0',
          'resources': <String>['stream'],
          'types': <String>['series'],
          'idPrefixes': <String>['tmdb:'],
          'behaviorHints': <String, dynamic>{
            'configurable': true,
            'configurationRequired': false,
          },
        };
      });

      final repository = await SourceRepositoryClient(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).fetchRepository('https://repo.example/index.json');
      final source = repository.extensions.single;

      expect(requested, <String>[
        'https://repo.example/index.json',
        'https://addon.example/config/manifest.json?tenant=profile-a&token=private',
      ]);
      expect(requested.every((url) => !Uri.parse(url).hasFragment), isTrue);
      expect(source.engine.kind, SourceEngineKind.stremio);
      expect(
        source.engine.endpoint,
        'https://addon.example/config?tenant=profile-a&token=private',
      );
      expect(source.engine.config['types'], <String>['series']);
      expect(source.engine.config['idPrefixes'], <String>['tmdb:']);
      expect(source.engine.config['configurable'], isTrue);
      expect(source.engine.config['configurationRequired'], isFalse);
      final configurationUrl = Uri.parse(
        source.engine.config['configurationUrl'] as String,
      );
      expect(configurationUrl.hasFragment, isFalse);
      expect(
        source.engine.config['configurationUrl'],
        'https://addon.example/config/configure',
      );
      expect(source.engine.priority, 15);
      dio.close(force: true);
    },
  );

  test('pins raw GitHub indexes to a full immutable commit SHA', () {
    const repository =
        'https://raw.githubusercontent.com/example/repo/main/extensions/index.json';
    const commit = '0123456789abcdef0123456789abcdef01234567';
    expect(
      SourceRepositoryClient.pinGitHubRawUrlToCommit(repository, commit),
      'https://raw.githubusercontent.com/example/repo/$commit/extensions/index.json',
    );
    expect(
      SourceRepositoryClient.commitHashFromUrl(
        SourceRepositoryClient.pinGitHubRawUrlToCommit(repository, commit),
      ),
      commit,
    );
    expect(
      () => SourceRepositoryClient.pinGitHubRawUrlToCommit(repository, '1234'),
      throwsFormatException,
    );
  });

  test(
    'pinned fetch preserves the original repository source identity',
    () async {
      const repository =
          'https://raw.githubusercontent.com/example/repo/main/extensions/index.json';
      const commit = '0123456789abcdef0123456789abcdef01234567';
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        expect(options.uri.pathSegments[2], commit);
        return <String, dynamic>{
          'name': 'Pinned Repository',
          'extensions': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'pinned-source',
              'name': 'Pinned Source',
              'engine': <String, dynamic>{
                'type': 'vidking-direct',
                'endpoint': 'cdn/provider',
              },
            },
          ],
        };
      });
      final pinnedUrl = SourceRepositoryClient.pinGitHubRawUrlToCommit(
        repository,
        commit,
      );
      final result = await SourceRepositoryClient(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).fetchRepository(pinnedUrl, repositoryIdentityUrl: repository);
      expect(result.extensions.single.stableKey, '$repository::pinned-source');
      dio.close(force: true);
    },
  );

  test(
    'keeps healthy Stremio add-ons when another manifest lookup fails',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        if (options.uri.host == 'repo.example') {
          return <String, dynamic>{
            'name': 'Mixed Repository',
            'extensions': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'healthy-addon',
                'name': 'Healthy Addon',
                'engine': <String, dynamic>{
                  'type': 'stremio',
                  'endpoint': 'https://healthy.example',
                },
              },
              <String, dynamic>{
                'id': 'offline-addon',
                'name': 'Offline Addon',
                'engine': <String, dynamic>{
                  'type': 'stremio',
                  'endpoint': 'https://offline.example',
                },
              },
            ],
          };
        }
        if (options.uri.host == 'offline.example') {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );
        }
        return <String, dynamic>{
          'id': 'org.healthy.addon',
          'name': 'Healthy Addon Manifest',
          'resources': <String>['stream'],
          'types': <String>['movie'],
          'idPrefixes': <String>['tt'],
        };
      });

      final repository = await SourceRepositoryClient(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).fetchRepository('https://repo.example/index.json');

      expect(repository.extensions, hasLength(2));
      final healthy = repository.extensions.singleWhere(
        (source) => source.id == 'healthy-addon',
      );
      final offline = repository.extensions.singleWhere(
        (source) => source.id == 'offline-addon',
      );
      expect(healthy.engine.config['idPrefixes'], <String>['tt']);
      expect(offline.engine.endpoint, 'https://offline.example');
      dio.close(force: true);
    },
  );
}

class _TextAdapter implements HttpClientAdapter {
  _TextAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/vnd.apple.mpegurl'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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
