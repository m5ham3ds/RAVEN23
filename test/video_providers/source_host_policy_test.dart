import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/openstream_anime_engine.dart';
import 'package:raven23/video_providers/unified/source_host_policy.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

void main() {
  test('accepts a public IP literal when DNS lookup is disabled', () async {
    final policy = SourceHostPolicy(resolveDns: false);
    expect(
      (await policy.validate('https://93.184.216.34/provider.js')).host,
      '93.184.216.34',
    );
  });

  test('rejects loopback, private and local destinations', () async {
    final policy = SourceHostPolicy(resolveDns: false);
    for (final url in <String>[
      'http://127.0.0.1/index.json',
      'http://2130706433/index.json',
      'http://0x7f.1/index.json',
      'http://10.0.0.4/index.json',
      'http://192.168.1.2/index.json',
      'http://localhost/index.json',
      'http://localhost./index.json',
      'http://router.local/index.json',
      'http://service.internal/index.json',
      'http://[::ffff:127.0.0.1]/index.json',
      'http://[64:ff9b::7f00:1]/index.json',
      'http://[2001:1::1]/index.json',
      'http://[2001:10::1]/index.json',
      'http://[2001:db8::1]/index.json',
      'http://[2002:7f00:1::]/index.json',
    ]) {
      await expectLater(policy.validate(url), throwsFormatException);
    }
  });

  test('rejects credentials embedded in a URL', () async {
    final policy = SourceHostPolicy(resolveDns: false);
    await expectLater(
      policy.validate('https://user:secret@example.com/provider.js'),
      throwsFormatException,
    );
  });

  test(
    'rejects a public hostname that resolves to a private address',
    () async {
      final policy = SourceHostPolicy(
        lookup: (_) async => <InternetAddress>[InternetAddress('192.168.1.20')],
      );
      await expectLater(
        policy.validate('https://provider.example/provider.js'),
        throwsFormatException,
      );
    },
  );

  test(
    'OpenStream Anime rejects a private DNS destination before Dio sends',
    () async {
      var requestCount = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount++;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
      final engine = OpenStreamAnimeSourceEngine(
        dio: dio,
        hostPolicy: SourceHostPolicy(
          lookup: (_) async => <InternetAddress>[InternetAddress('10.0.0.7')],
        ),
      );
      const source = SourceManifest(
        id: 'anime-policy',
        name: 'Anime Policy',
        engine: SourceEngineDescriptor(
          rawType: 'reanime',
          kind: SourceEngineKind.animeSite,
        ),
      );
      const media = MediaIdentity(
        type: UnifiedMediaType.movie,
        title: 'Anime movie',
        externalIds: <String, String>{'anilist': '1234'},
      );

      final result = await engine.resolve(source: source, media: media);

      expect(result.streams, isEmpty);
      expect(result.errorMessage, contains('private or reserved'));
      expect(requestCount, 0);
      dio.close(force: true);
    },
  );

  test('permits a public DNS result', () async {
    final policy = SourceHostPolicy(
      lookup: (_) async => <InternetAddress>[InternetAddress('93.184.216.34')],
    );
    expect(
      (await policy.validate('https://provider.example/provider.js')).host,
      'provider.example',
    );
  });
  test(
    'Re:Anime maps exact season/episode and anime movie independently',
    () async {
      final requestedPaths = <Uri>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final uri = options.uri;
            requestedPaths.add(uri);
            dynamic data;
            if (uri.host == 'api.ani.zip' &&
                uri.queryParameters.containsKey('themoviedb_id')) {
              final isMovie = uri.queryParameters['themoviedb_id'] == '420202';
              data = <String, dynamic>{
                'mappings': <String, dynamic>{
                  'type': isMovie ? 'MOVIE' : 'TV',
                  'anilist_id': isMovie ? 20202 : 20201,
                },
              };
            } else if (uri.host == 'graphql.anilist.co') {
              final requestBody = options.data;
              final variables = requestBody is Map
                  ? requestBody['variables']
                  : null;
              final id = variables is Map ? variables['id'] : null;
              data = <String, dynamic>{
                'data': <String, dynamic>{
                  'Media': <String, dynamic>{
                    'id': id,
                    'idMal': 12345,
                    'episodes': 12,
                    'format': id == 20202 ? 'MOVIE' : 'TV',
                    'title': <String, dynamic>{'romaji': 'Phase 43 Anime'},
                    'relations': <String, dynamic>{'edges': <dynamic>[]},
                  },
                },
              };
            } else if (uri.host == 'api.ani.zip' &&
                uri.queryParameters.containsKey('anilist_id')) {
              data = <String, dynamic>{
                'episodes': <String, dynamic>{
                  '8': <String, dynamic>{'seasonNumber': 2, 'episodeNumber': 4},
                },
              };
            } else {
              // Re:Anime mirror HTML intentionally contains no player id. The
              // request contract is exercised without pretending it returned media.
              data = '<html>fixture: no embedded player</html>';
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: data,
              ),
            );
          },
        ),
      );
      final engine = OpenStreamAnimeSourceEngine(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      );
      const source = SourceManifest(
        id: 'reanime',
        name: 'Re:Anime',
        status: 3,
        tags: <String>['anime', 'sub', 'dub'],
        engine: SourceEngineDescriptor(
          rawType: 'reanime',
          kind: SourceEngineKind.animeSite,
          endpoint: 'https://reanime.to',
        ),
      );

      final seriesResult = await engine.resolve(
        source: source,
        media: const MediaIdentity(
          type: UnifiedMediaType.series,
          title: 'Phase 43 Anime',
          tmdbId: 420201,
          seasonNumber: 2,
          episodeNumber: 4,
        ),
      );
      final movieResult = await engine.resolve(
        source: source,
        media: const MediaIdentity(
          type: UnifiedMediaType.movie,
          title: 'Phase 43 Anime Film',
          tmdbId: 420202,
        ),
      );

      expect(seriesResult.errorMessage, isNull);
      expect(movieResult.errorMessage, isNull);
      expect(
        requestedPaths.any((uri) => uri.path == '/stream/ani/20201/8/sub'),
        isTrue,
        reason: 'TMDB S2E4 must map to the ani.zip/AniList episode 8.',
      );
      expect(
        requestedPaths.any((uri) => uri.path == '/stream/ani/20202/1/sub'),
        isTrue,
        reason: 'An anime film is routed as its own first episode slot.',
      );
      expect(seriesResult.streams, isEmpty);
      expect(movieResult.streams, isEmpty);
      dio.close(force: true);
    },
  );
}
