import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/source_engine.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_host_policy.dart';
import 'package:raven23/video_providers/unified/stremio_addon_provider.dart';
import 'package:raven23/video_providers/unified/stream_option.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'resolves direct Stremio streams and preserves headers and subtitles',
    () async {
      Uri? requestedUri;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestedUri = options.uri;
        return <String, dynamic>{
          'streams': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': '1080p · Dual Audio',
              'title': 'BluRay',
              'url': 'https://cdn.example/release-one.m3u8',
              'behaviorHints': <String, dynamic>{
                'proxyHeaders': <String, dynamic>{
                  'request': <String, String>{
                    'Referer': 'https://host.example/',
                    'User-Agent': 'RAVEN23 Test',
                  },
                },
                'filename': 'release-1080p.m3u8',
              },
              'subtitles': <Map<String, dynamic>>[
                <String, dynamic>{
                  'url': 'https://cdn.example/ar.vtt',
                  'lang': 'ar',
                  'format': 'vtt',
                  'default': true,
                },
              ],
            },
            <String, dynamic>{
              'name': '1080p · Dual Audio',
              'url': 'https://cdn-two.example/release-one.mp4',
            },
            <String, dynamic>{
              'name': 'Duplicate mirror',
              'url': 'https://cdn.example/release-one.m3u8',
              'behaviorHints': <String, dynamic>{
                'proxyHeaders': <String, dynamic>{
                  'request': <String, String>{
                    'Referer': 'https://host.example/',
                    'User-Agent': 'RAVEN23 Test',
                  },
                },
              },
            },
            <String, dynamic>{
              'name': '1080p · Dual Audio',
              'title': 'BluRay',
              'url': 'https://cdn.example/release-one.m3u8',
              'behaviorHints': <String, dynamic>{
                'proxyHeaders': <String, dynamic>{
                  'request': <String, String>{
                    'Referer': 'https://host.example/',
                    'User-Agent': 'RAVEN23 Test',
                  },
                },
                'filename': 'release-1080p.m3u8',
              },
              'subtitles': <Map<String, dynamic>>[
                <String, dynamic>{
                  'url': 'https://cdn.example/ar.vtt',
                  'lang': 'ar',
                  'format': 'vtt',
                  'default': true,
                },
              ],
            },
            <String, dynamic>{
              'name': 'Torrent release',
              'infoHash': '0123456789abcdef',
            },
          ],
        };
      });

      const source = SourceManifest(
        id: 'test-addon',
        name: 'Test Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example/configured',
          config: <String, dynamic>{
            'types': <String>['movie'],
            'idPrefixes': <String>['tt'],
          },
        ),
      );
      const media = MediaIdentity(
        type: UnifiedMediaType.movie,
        title: 'Example Movie',
        tmdbId: 7,
        externalIds: <String, String>{'imdb': 'tt1234567'},
      );

      final streams = await StremioAddonProvider(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).getStreams(source: source, media: media);

      expect(requestedUri!.path, '/configured/stream/movie/tt1234567.json');
      // A repeated URL with different stream metadata is retained; the exact
      // duplicate is filtered without collapsing a distinct audio/subtitle option.
      expect(streams, hasLength(3));
      expect(streams.first.container, StreamContainer.hls);
      expect(streams.first.quality, '1080p');
      expect(streams.first.audioKind, StreamAudioKind.dub);
      expect(streams.first.headers['Referer'], 'https://host.example/');
      expect(streams.first.subtitles.single.language, 'ar');
      expect(streams.first.subtitles.single.isDefault, isTrue);
      expect(
        streams.first.subtitles.single.headers['Referer'],
        'https://host.example/',
      );
      expect(streams.first.audioLanguage, isNull);
      dio.close(force: true);
    },
  );

  test(
    'uses advertised anime ecosystem IDs with episode coordinates',
    () async {
      Uri? requestedUri;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestedUri = options.uri;
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      const source = SourceManifest(
        id: 'kitsu-addon',
        name: 'Kitsu Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
          config: <String, dynamic>{
            'types': <String>['series'],
            'idPrefixes': <String>['kitsu:'],
          },
        ),
      );
      const media = MediaIdentity(
        type: UnifiedMediaType.anime,
        title: 'Example Anime',
        seasonNumber: 1,
        episodeNumber: 4,
        externalIds: <String, String>{'kitsu': '12345'},
      );

      await StremioAddonProvider(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).getStreams(source: source, media: media);

      expect(requestedUri!.pathSegments.last, 'kitsu:12345:1:4.json');
      dio.close(force: true);
    },
  );

  test(
    'rejects explicit Stremio episode IDs carrying different coordinates',
    () async {
      var requestCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestCount++;
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      const source = SourceManifest(
        id: 'episode-id-addon',
        name: 'Episode ID Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
          config: <String, dynamic>{
            'idPrefixes': <String>['kitsu:'],
          },
        ),
      );

      await expectLater(
        StremioAddonProvider(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ).getStreams(
          source: source,
          media: const MediaIdentity(
            type: UnifiedMediaType.series,
            title: 'Anime',
            seasonNumber: 2,
            episodeNumber: 4,
            externalIds: <String, String>{'stremio': 'kitsu:12345:1:4'},
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(requestCount, 0);
      dio.close(force: true);
    },
  );

  test(
    'uses TMDB identifiers only when the add-on advertises a TMDB prefix',
    () async {
      Uri? requestedUri;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestedUri = options.uri;
        return <String, dynamic>{'streams': <dynamic>[]};
      });

      const source = SourceManifest(
        id: 'tmdb-addon',
        name: 'TMDB Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
          config: <String, dynamic>{
            'idPrefixes': <String>['tmdb:'],
          },
        ),
      );
      const media = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Example Series',
        tmdbId: 42,
        seasonNumber: 2,
        episodeNumber: 7,
      );

      final streams = await StremioAddonProvider(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).getStreams(source: source, media: media);

      expect(streams, isEmpty);
      expect(requestedUri!.pathSegments.last, 'tmdb:42:2:7.json');
      dio.close(force: true);
    },
  );

  test(
    'uses the stream resource ID-prefix profile for the requested media type',
    () async {
      Uri? movieUri;
      Uri? seriesUri;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        if (options.uri.path.contains('/stream/movie/')) {
          movieUri = options.uri;
        } else {
          seriesUri = options.uri;
        }
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      const source = SourceManifest(
        id: 'resource-profile-addon',
        name: 'Resource Profile Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
          config: <String, dynamic>{
            'streamResourceProfiles': <Map<String, dynamic>>[
              <String, dynamic>{
                'types': <String>['movie'],
                'prefixMode': 'explicit',
                'idPrefixes': <String>['tt'],
              },
              <String, dynamic>{
                'types': <String>['series'],
                'prefixMode': 'explicit',
                'idPrefixes': <String>['kitsu:'],
              },
            ],
          },
        ),
      );

      await StremioAddonProvider(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).getStreams(
        source: source,
        media: const MediaIdentity(
          type: UnifiedMediaType.movie,
          title: 'Movie',
          tmdbId: 42,
          externalIds: <String, String>{'imdb': 'tt1234567', 'kitsu': '12345'},
        ),
      );
      await StremioAddonProvider(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).getStreams(
        source: source,
        media: const MediaIdentity(
          type: UnifiedMediaType.series,
          title: 'Anime series',
          seasonNumber: 1,
          episodeNumber: 4,
          externalIds: <String, String>{'imdb': 'tt1234567', 'kitsu': '12345'},
        ),
      );

      expect(movieUri!.pathSegments.last, 'tt1234567.json');
      expect(seriesUri!.pathSegments.last, 'kitsu:12345:1:4.json');
      dio.close(force: true);
    },
  );

  test(
    'allows supplied IDs when a stream resource omits idPrefixes without synthesizing TMDB IDs',
    () async {
      Uri? requestedUri;
      var requestCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestCount++;
        requestedUri = options.uri;
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      const source = SourceManifest(
        id: 'unrestricted-manifest-addon',
        name: 'Unrestricted Manifest Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
          config: <String, dynamic>{
            'streamResourceProfiles': <Map<String, dynamic>>[
              <String, dynamic>{
                'types': <String>['movie'],
                'prefixMode': 'any',
              },
            ],
          },
        ),
      );

      await StremioAddonProvider(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).getStreams(
        source: source,
        media: const MediaIdentity(
          type: UnifiedMediaType.movie,
          title: 'Movie',
          tmdbId: 42,
          externalIds: <String, String>{'kitsu': '12345'},
        ),
      );

      expect(requestCount, 1);
      expect(requestedUri!.pathSegments.last, 'kitsu:12345.json');
      expect(requestedUri!.pathSegments.last, isNot('tmdb:42.json'));
      dio.close(force: true);
    },
  );

  test(
    'does not send a TMDB-prefixed identifier unless the stream resource advertises it',
    () async {
      var requestCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestCount++;
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      const source = SourceManifest(
        id: 'default-prefix-addon',
        name: 'Default Prefix Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
        ),
      );

      await expectLater(
        StremioAddonProvider(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ).getStreams(
          source: source,
          media: const MediaIdentity(
            type: UnifiedMediaType.movie,
            title: 'Movie',
            tmdbId: 42,
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(requestCount, 0);
      dio.close(force: true);
    },
  );

  test(
    'preserves per-addon manifest query configuration in stream requests',
    () async {
      Uri? requestedUri;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestedUri = options.uri;
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      const source = SourceManifest(
        id: 'configured-addon',
        name: 'Configured Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example/profile-a?tenant=a&token=secret',
          config: <String, dynamic>{
            'idPrefixes': <String>['tt'],
          },
        ),
      );

      await StremioAddonProvider(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).getStreams(
        source: source,
        media: const MediaIdentity(
          type: UnifiedMediaType.movie,
          title: 'Movie',
          externalIds: <String, String>{'imdb': 'tt1234567'},
        ),
      );

      expect(requestedUri!.path, '/profile-a/stream/movie/tt1234567.json');
      expect(requestedUri!.queryParameters['tenant'], 'a');
      expect(requestedUri!.queryParameters['token'], 'secret');
      dio.close(force: true);
    },
  );

  test('configurable optional add-ons still execute stream requests', () async {
    var requestCount = 0;
    final dio = Dio();
    dio.httpClientAdapter = _JsonAdapter((options) async {
      requestCount++;
      return <String, dynamic>{
        'streams': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': '720p',
            'url': 'https://cdn.example/optional.mp4',
          },
        ],
      };
    });
    const source = SourceManifest(
      id: 'optional-config-addon',
      name: 'Optional Config Addon',
      engine: SourceEngineDescriptor(
        rawType: 'stremio',
        kind: SourceEngineKind.stremio,
        endpoint: 'https://addon.example',
        config: <String, dynamic>{
          'configurable': true,
          'configurationRequired': false,
          'needsConfiguration': false,
          'types': <String>['movie'],
          'idPrefixes': <String>['tt'],
        },
      ),
    );

    final streams =
        await StremioAddonProvider(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ).getStreams(
          source: source,
          media: const MediaIdentity(
            type: UnifiedMediaType.movie,
            title: 'Movie',
            externalIds: <String, String>{'imdb': 'tt1234567'},
          ),
        );

    expect(requestCount, 1);
    expect(streams, hasLength(1));
    expect(streams.single.url, 'https://cdn.example/optional.mp4');
    dio.close(force: true);
  });

  test(
    'Stremio engine errors never expose configured manifest query tokens',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _DioFailureAdapter();
      final engine = StremioSourceEngine(
        provider: StremioAddonProvider(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ),
      );
      const source = SourceManifest(
        id: 'private-addon',
        name: 'Private Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example/profile?api_key=secret-token',
          config: <String, dynamic>{
            'idPrefixes': <String>['tt'],
          },
        ),
      );

      final result = await engine.resolve(
        source: source,
        media: const MediaIdentity(
          type: UnifiedMediaType.movie,
          title: 'Movie',
          externalIds: <String, String>{'imdb': 'tt1234567'},
        ),
      );

      expect(result.errorMessage, isNot(contains('secret-token')));
      expect(result.errorMessage, 'Stremio add-on request failed.');
      dio.close(force: true);
    },
  );

  test(
    'blocks execution when the manifest explicitly requires configuration',
    () async {
      var requestCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestCount++;
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      const source = SourceManifest(
        id: 'required-config-addon',
        name: 'Required Config Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
          config: <String, dynamic>{
            'configurable': true,
            'configurationRequired': true,
            'needsConfiguration': true,
          },
        ),
      );

      await expectLater(
        StremioAddonProvider(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ).getStreams(
          source: source,
          media: const MediaIdentity(
            type: UnifiedMediaType.movie,
            title: 'Movie',
            externalIds: <String, String>{'imdb': 'tt1234567'},
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(requestCount, 0);
      dio.close(force: true);
    },
  );

  test(
    'sequential source queue starts only the provider being resolved',
    () async {
      var activeRequests = 0;
      var peakActiveRequests = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        activeRequests++;
        if (activeRequests > peakActiveRequests) {
          peakActiveRequests = activeRequests;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        activeRequests--;
        return <String, dynamic>{
          'streams': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': '720p',
              'url': 'https://cdn.example/${options.uri.host}.mp4',
            },
          ],
        };
      });
      final registry = SourceEngineRegistry.standard(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      );
      final sources = <SourceManifest>[
        const SourceManifest(
          id: 'third',
          name: 'Third',
          engine: SourceEngineDescriptor(
            rawType: 'stremio',
            kind: SourceEngineKind.stremio,
            endpoint: 'https://third.example',
            priority: 30,
          ),
        ),
        const SourceManifest(
          id: 'first',
          name: 'First',
          engine: SourceEngineDescriptor(
            rawType: 'stremio',
            kind: SourceEngineKind.stremio,
            endpoint: 'https://first.example',
            priority: 10,
          ),
        ),
        const SourceManifest(
          id: 'second',
          name: 'Second',
          engine: SourceEngineDescriptor(
            rawType: 'stremio',
            kind: SourceEngineKind.stremio,
            endpoint: 'https://second.example',
            priority: 20,
          ),
        ),
      ];
      const media = MediaIdentity(
        type: UnifiedMediaType.movie,
        title: 'Movie',
        externalIds: <String, String>{'imdb': 'tt1234567'},
      );
      final started = <String>[];
      final attempts = await registry.resolveMany(
        sources: sources,
        media: media,
        maxConcurrency: 1,
        onSourceStart: (source) => started.add(source.id),
      );

      expect(started, <String>['first', 'second', 'third']);
      expect(attempts.map((attempt) => attempt.source.id), <String>[
        'first',
        'second',
        'third',
      ]);
      expect(peakActiveRequests, 1);
      dio.close(force: true);
    },
  );

  test(
    'registry emits source attempts in priority order while resolving concurrently',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter(
        (options) async => <String, dynamic>{
          'streams': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': '720p',
              'url': 'https://cdn.example/${options.uri.host}.mp4',
            },
          ],
        },
      );
      final registry = SourceEngineRegistry.standard(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      );
      final sources = <SourceManifest>[
        const SourceManifest(
          id: 'second',
          name: 'Second',
          engine: SourceEngineDescriptor(
            rawType: 'stremio',
            kind: SourceEngineKind.stremio,
            endpoint: 'https://second.example',
            priority: 20,
          ),
        ),
        const SourceManifest(
          id: 'first',
          name: 'First',
          engine: SourceEngineDescriptor(
            rawType: 'stremio',
            kind: SourceEngineKind.stremio,
            endpoint: 'https://first.example',
            priority: 10,
          ),
        ),
      ];
      const media = MediaIdentity(
        type: UnifiedMediaType.movie,
        title: 'Movie',
        externalIds: <String, String>{'imdb': 'tt1234567'},
      );
      final completed = <String>[];
      final attempts = await registry.resolveMany(
        sources: sources,
        media: media,
        maxConcurrency: 2,
        onAttempt: (attempt) => completed.add(attempt.source.id),
      );

      expect(attempts.map((item) => item.source.id), <String>[
        'first',
        'second',
      ]);
      expect(completed.toSet(), <String>{'first', 'second'});
      expect(attempts.every((item) => item.result.success), isTrue);
      dio.close(force: true);
    },
  );

  test(
    'rejects series requests without exact season and episode metadata',
    () async {
      var requestCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _JsonAdapter((options) async {
        requestCount++;
        return <String, dynamic>{'streams': <dynamic>[]};
      });
      const source = SourceManifest(
        id: 'series-addon',
        name: 'Series Addon',
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://addon.example',
        ),
      );
      const media = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Series without episode coordinates',
        tmdbId: 42,
        episodeNumber: 8,
      );

      await expectLater(
        StremioAddonProvider(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ).getStreams(source: source, media: media),
        throwsA(isA<FormatException>()),
      );
      expect(requestCount, 0);
      dio.close(force: true);
    },
  );
  test('rejects a Stremio redirect into a loopback destination', () async {
    var requestCount = 0;
    final dio = Dio();
    dio.httpClientAdapter = _LoopbackRedirectAdapter(() => requestCount++);
    const source = SourceManifest(
      id: 'redirect-addon',
      name: 'Redirect Addon',
      engine: SourceEngineDescriptor(
        rawType: 'stremio',
        kind: SourceEngineKind.stremio,
        endpoint: 'https://addon.example',
        config: <String, dynamic>{
          'types': <String>['movie'],
          'idPrefixes': <String>['tt'],
        },
      ),
    );
    await expectLater(
      StremioAddonProvider(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      ).getStreams(
        source: source,
        media: const MediaIdentity(
          type: UnifiedMediaType.movie,
          title: 'Movie',
          externalIds: <String, String>{'imdb': 'tt1234567'},
        ),
      ),
      throwsFormatException,
    );
    expect(requestCount, 1);
    dio.close(force: true);
  });
}

class _LoopbackRedirectAdapter implements HttpClientAdapter {
  _LoopbackRedirectAdapter(this.onFetch);

  final VoidCallback onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch();
    return ResponseBody.fromString(
      '',
      302,
      headers: <String, List<String>>{
        'location': <String>['http://127.0.0.1/private'],
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

class _DioFailureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      message: 'Request failed: ${options.uri}',
    );
  }

  @override
  void close({bool force = false}) {}
}
