import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/quickjs/quickjs_provider_runtime.dart';
import 'package:raven23/video_providers/unified/quickjs_source_engine.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

void main() {
  const source = SourceManifest(
    id: 'fixture-provider',
    name: 'Fixture Provider',
    repositoryUrl: 'https://repo.example/index.json',
    engine: SourceEngineDescriptor(
      rawType: 'javascript',
      kind: SourceEngineKind.javascript,
      endpoint: 'https://repo.example/fixture-provider.js',
    ),
  );

  MediaIdentity requestedEpisode() => const MediaIdentity(
    type: UnifiedMediaType.series,
    title: 'Sample Series',
    seasonNumber: 2,
    episodeNumber: 8,
  );

  group('QuickJsSourceEngine episode resolution', () {
    test('uses exact season and episode before extracting streams', () async {
      final runtime = _FakeRuntime(
        detail: <String, dynamic>{
          'episodes': <dynamic>[
            <String, dynamic>{
              'title': 'S01E08',
              'url': 'https://source.example/s1e8',
            },
            <String, dynamic>{
              'title': 'S02E08',
              'url': 'https://source.example/s2e8',
            },
          ],
        },
      );

      final result = await QuickJsSourceEngine(
        runtime: runtime,
      ).resolve(source: source, media: requestedEpisode());

      expect(result.success, isTrue);
      expect(runtime.videoSourceTarget, 'https://source.example/s2e8');
    });

    test(
      'never substitutes the same episode number from another season',
      () async {
        final runtime = _FakeRuntime(
          detail: <String, dynamic>{
            'episodes': <dynamic>[
              <String, dynamic>{
                'title': 'S01E08',
                'url': 'https://source.example/wrong-season-s1e8',
              },
            ],
          },
        );

        final result = await QuickJsSourceEngine(
          runtime: runtime,
        ).resolve(source: source, media: requestedEpisode());

        expect(result.success, isFalse);
        expect(runtime.videoSourceTarget, isNull);
      },
    );

    test(
      'does not extract an episode when provider season is missing',
      () async {
        final runtime = _FakeRuntime(
          detail: <String, dynamic>{
            'episodes': <dynamic>[
              <String, dynamic>{
                'number': 8,
                'title': 'Episode 8',
                'url': 'https://source.example/ambiguous-episode-8',
              },
            ],
          },
        );

        final result = await QuickJsSourceEngine(
          runtime: runtime,
        ).resolve(source: source, media: requestedEpisode());

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('No exact S02E08 match'));
        expect(runtime.videoSourceTarget, isNull);
      },
    );

    test(
      'inherits a season only from an explicitly numbered detail response',
      () async {
        final runtime = _FakeRuntime(
          detail: <String, dynamic>{
            'season_number': 2,
            'episodes': <dynamic>[
              <String, dynamic>{
                'episode_number': 8,
                'title': 'Episode 8',
                'url': 'https://source.example/parent-season-s2e8',
              },
            ],
          },
        );

        final result = await QuickJsSourceEngine(
          runtime: runtime,
        ).resolve(source: source, media: requestedEpisode());

        expect(result.success, isTrue);
        expect(
          runtime.videoSourceTarget,
          'https://source.example/parent-season-s2e8',
        );
      },
    );

    test(
      'does not fall back to an earlier season after a conflicting wrapper',
      () async {
        final runtime = _FakeRuntime(
          detail: <String, dynamic>{
            'season_number': 2,
            'episodes': <dynamic>[],
          },
          episodesResult: <String, dynamic>{
            'season': 1,
            'season_number': 2,
            'episodes': <dynamic>[
              <String, dynamic>{
                'episode_number': 8,
                'url': 'https://source.example/ambiguous-parent-season',
              },
            ],
          },
        );

        final result = await QuickJsSourceEngine(
          runtime: runtime,
        ).resolve(source: source, media: requestedEpisode());

        expect(result.success, isFalse);
        expect(runtime.videoSourceTarget, isNull);
      },
    );

    test(
      'routes anime-only QuickJS sources through the series episode path',
      () async {
        final runtime = _FakeRuntime(
          declaredType: 'anime',
          detail: <String, dynamic>{
            'episodes': <dynamic>[
              <String, dynamic>{
                'title': 'S01E01',
                'url': 'https://source.example/anime/s1e1',
              },
            ],
          },
        );
        final media = MediaIdentity(
          type: UnifiedMediaType.series,
          title: 'Sample Series',
          seasonNumber: 1,
          episodeNumber: 1,
          contentClassification: MediaContentClassification.anime,
        );

        final result = await QuickJsSourceEngine(
          runtime: runtime,
        ).resolve(source: source, media: media);

        expect(result.success, isTrue);
        expect(runtime.videoSourceTarget, 'https://source.example/anime/s1e1');
      },
    );

    test('matches titles across supported writing systems', () async {
      const titles = <String>[
        '葬送のフリーレン',
        '나 혼자만 레벨업',
        '哪吒之魔童降世',
        'الأنمي التجريبي',
        'Sample Series',
      ];

      for (final title in titles) {
        final runtime = _FakeRuntime(
          detail: <String, dynamic>{
            'episodes': <dynamic>[
              <String, dynamic>{
                'title': 'S01E01',
                'url': 'https://source.example/episode-1',
              },
            ],
          },
          searchResults: <dynamic>[
            <String, dynamic>{
              'title': title,
              'url': 'https://source.example/series/multilingual',
            },
          ],
        );
        final media = MediaIdentity(
          type: UnifiedMediaType.series,
          title: title,
          seasonNumber: 1,
          episodeNumber: 1,
        );

        final result = await QuickJsSourceEngine(
          runtime: runtime,
        ).resolve(source: source, media: media);

        expect(result.success, isTrue, reason: title);
      }
    });

    test(
      'rejects a request that is missing its season or episode number',
      () async {
        final runtime = _FakeRuntime(
          detail: <String, dynamic>{
            'season_number': 2,
            'episodes': <dynamic>[
              <String, dynamic>{
                'episode_number': 8,
                'url': 'https://x.example/8',
              },
            ],
          },
        );
        const incomplete = MediaIdentity(
          type: UnifiedMediaType.series,
          title: 'Sample Series',
          episodeNumber: 8,
        );

        final result = await QuickJsSourceEngine(
          runtime: runtime,
        ).resolve(source: source, media: incomplete);

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('exact season and episode'));
        expect(runtime.calls, isEmpty);
        expect(runtime.videoSourceTarget, isNull);
      },
    );
  });
}

class _FakeRuntime extends QuickJsProviderRuntime {
  _FakeRuntime({
    required this.detail,
    this.declaredType = 'all',
    this.episodesResult = const <dynamic>[],
    this.searchResults = const <dynamic>[
      <String, dynamic>{
        'title': 'Sample Series',
        'url': 'https://source.example/series/sample',
      },
    ],
  }) : super(dio: Dio());

  final dynamic detail;
  final String declaredType;
  final dynamic episodesResult;
  final List<dynamic> searchResults;
  String? videoSourceTarget;
  final List<String> calls = <String>[];

  @override
  Future<dynamic> call(
    SourceManifest source,
    String method,
    List<Object?> arguments, {
    Duration timeout = const Duration(seconds: 65),
    CancelToken? cancelToken,
  }) async {
    calls.add(method);
    switch (method) {
      case 'getInfo':
        return <String, dynamic>{'type': declaredType};
      case 'search':
        return searchResults;
      case 'getDetail':
        return detail;
      case 'getEpisodes':
        return episodesResult;
      case 'getVideoSources':
        videoSourceTarget = arguments.first.toString();
        return <dynamic>[
          <String, dynamic>{
            'url': 'https://cdn.example/sample.m3u8',
            'quality': '1080p',
          },
        ];
      default:
        return null;
    }
  }
}
