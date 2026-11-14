import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/source_engine.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_repository_parser.dart';
import 'package:raven23/video_providers/unified/stream_option.dart';
import 'package:raven23/video_providers/unified/source_host_policy.dart';
import 'package:raven23/video_providers/unified/vidking_direct_provider.dart';

void main() {
  test(
    'rejects series requests without exact season and episode metadata',
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
      const source = SourceManifest(
        id: 'vidking-series',
        name: 'VidKing Series',
        engine: SourceEngineDescriptor(
          rawType: 'vidking-direct',
          kind: SourceEngineKind.vidkingDirect,
          endpoint: 'movie',
        ),
      );
      const media = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Series without episode coordinates',
        tmdbId: 42,
        episodeNumber: 8,
      );

      await expectLater(
        VidkingDirectProvider(
          dio: dio,
          hostPolicy: const SourceHostPolicy(resolveDns: false),
        ).resolve(source: source, media: media),
        throwsA(isA<FormatException>()),
      );
      expect(requestCount, 0);
      dio.close(force: true);
    },
  );
  test(
    'source registry applies user audio preference before source defaults',
    () async {
      final dio = Dio();
      final sourceLanguages = <String?>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final uri = options.uri;
            if (uri.path.endsWith('/seed')) {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data: '{"seed":"test-seed","ttlMs":30000}',
                ),
              );
              return;
            }
            sourceLanguages.add(uri.queryParameters['language']);
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
      const source = SourceManifest(
        id: 'vidking-preference',
        name: 'VidKing Preference',
        engine: SourceEngineDescriptor(
          rawType: 'vidking-direct',
          kind: SourceEngineKind.vidkingDirect,
          endpoint: 'sources-with-title',
          audioLanguage: 'Hindi',
        ),
      );
      const legacySource = SourceManifest(
        id: 'vidking-legacy-language',
        name: 'VidKing Legacy Language',
        engine: SourceEngineDescriptor(
          rawType: 'vidking-direct',
          kind: SourceEngineKind.vidkingDirect,
          endpoint: 'sources-with-title',
          language: 'german',
        ),
      );
      const media = MediaIdentity(
        type: UnifiedMediaType.movie,
        title: 'Preference Test',
        tmdbId: 4242,
      );
      final registry = SourceEngineRegistry(
        engines: <SourceEngine>[
          VidkingDirectSourceEngine(
            dio: dio,
            hostPolicy: const SourceHostPolicy(resolveDns: false),
          ),
        ],
      );

      final defaultAttempts = await registry.resolveMany(
        sources: const <SourceManifest>[source],
        media: media,
      );
      final preferredAttempts = await registry.resolveMany(
        sources: const <SourceManifest>[source],
        media: media,
        preferredAudioLanguage: 'English',
      );
      final legacyAttempts = await registry.resolveMany(
        sources: const <SourceManifest>[legacySource],
        media: media,
      );

      expect(defaultAttempts, hasLength(1));
      expect(preferredAttempts, hasLength(1));
      expect(legacyAttempts, hasLength(1));
      expect(sourceLanguages, <String?>['Hindi', 'English', 'german']);
      dio.close(force: true);
    },
  );

  test(
    'all official VidKing routes are dispatched through their declared path',
    () async {
      final raw = await File(
        'test/fixtures/openstream_official_repo.json',
      ).readAsString();
      final repository = const SourceRepositoryParser().parseRepository(
        raw,
        sourceUrl:
            'https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json',
      );
      final sources = repository.extensions
          .where((source) => source.engine.rawType == 'vidking-direct')
          .toList(growable: false);
      final requestedUris = <Uri>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.uri.path == '/seed') {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data: '{"seed":"phase43-contract-seed","ttlMs":30000}',
                ),
              );
              return;
            }
            requestedUris.add(options.uri);
            // A deterministic upstream-unavailable response exercises routing
            // without claiming that an external stream is playable.
            handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: 503,
                data: 'fixture upstream unavailable',
              ),
            );
          },
        ),
      );
      final provider = VidkingDirectProvider(
        dio: dio,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      );
      const movie = MediaIdentity(
        type: UnifiedMediaType.movie,
        title: 'Phase 43 Fixture Movie',
        tmdbId: 420043,
      );

      for (final source in sources) {
        await expectLater(
          provider.resolve(source: source, media: movie),
          throwsA(isA<DioException>()),
        );
      }

      expect(requestedUris, hasLength(9));
      for (final source in sources) {
        expect(
          requestedUris.any((uri) => uri.path == '/${source.engine.endpoint}'),
          isTrue,
          reason: '${source.id} must use ${source.engine.endpoint}',
        );
      }

      final yoru = sources.singleWhere((source) => source.id == 'yoru');
      const episode = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Phase 43 Fixture Series',
        tmdbId: 420044,
        seasonNumber: 3,
        episodeNumber: 7,
      );
      await expectLater(
        provider.resolve(source: yoru, media: episode),
        throwsA(isA<DioException>()),
      );
      final seriesUri = requestedUris.last;
      expect(seriesUri.queryParameters['mediaType'], 'tv');
      expect(seriesUri.queryParameters['seasonId'], '3');
      expect(seriesUri.queryParameters['episodeId'], '7');
      dio.close(force: true);
    },
  );

  test('provider expiry metadata accepts ISO dates and epoch seconds only', () {
    expect(
      parseStreamExpiry('2026-12-01T12:00:00Z'),
      DateTime.utc(2026, 12, 1, 12),
    );
    expect(
      parseStreamExpiry(1796126400),
      DateTime.fromMillisecondsSinceEpoch(1796126400000, isUtc: true),
    );
    expect(parseStreamExpiry('1796126400'), DateTime.utc(2026, 12, 1, 12));
    expect(parseStreamExpiry(3600), isNull);
    expect(parseStreamExpiry('3600'), isNull);
    expect(parseStreamExpiry(null), isNull);
    expect(parseStreamExpiry('not-an-expiry'), isNull);
  });
}
