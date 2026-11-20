import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/screens/common/source_health_probe_service.dart';
import 'package:raven23/video_providers/unified/quickjs/quickjs_provider_runtime.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

class _FakeQuickJsProviderRuntime extends QuickJsProviderRuntime {
  final searchedCategories = <String>[];
  final requestedStreamUrls = <String>[];

  @override
  Future<dynamic> call(
    SourceManifest source,
    String method,
    List<Object?> arguments, {
    Duration timeout = const Duration(seconds: 65),
    CancelToken? cancelToken,
  }) async {
    switch (method) {
      case 'getInfo':
        return <String, Object?>{'name': source.name};
      case 'search':
        final options = arguments[2] as Map<String, dynamic>;
        searchedCategories.add(options['category'] as String);
        return <Map<String, Object?>>[
          <String, Object?>{
            'id': 'sample-${options['category']}',
            'url': 'https://listing.example.test/${options['category']}',
            'title': 'Sample title',
          },
        ];
      case 'getDetail':
        return <String, Object?>{
          'episodes': <Map<String, Object?>>[
            <String, Object?>{'url': 'https://listing.example.test/episode-1'},
          ],
        };
      case 'getVideoSources':
        requestedStreamUrls.add(arguments[0] as String);
        return <Map<String, Object?>>[
          <String, Object?>{
            'url': 'https://media.example.test/sample-720.m3u8',
            'quality': '720p',
            'container': 'm3u8',
            'kind': 'sub',
            'subtitles': <Map<String, Object?>>[
              <String, Object?>{
                'url': 'https://media.example.test/sample-en.vtt',
                'language': 'en',
              },
            ],
          },
          <String, Object?>{
            'url': 'https://media.example.test/sample-1080.mp4',
            'quality': '1080p',
            'container': 'mp4',
            'kind': 'dub',
          },
        ];
      default:
        throw UnsupportedError('Unexpected fake provider method: $method');
    }
  }

  @override
  void dispose() {}
}

void main() {
  test('runs three source probes concurrently and returns input order', () async {
    final gates = <String, Completer<SourceHealthCheckResult>>{
      for (final id in <String>['first', 'second', 'third', 'fourth'])
        id: Completer<SourceHealthCheckResult>(),
    };
    final started = <String>[];
    final service = _OrderedSourceHealthProbeService(
      gates: gates,
      started: started,
    );
    final sources = <SourceManifest>[
      for (final id in gates.keys)
        SourceManifest(
          id: id,
          name: id,
          repositoryUrl: 'https://example.com/index.json',
          engine: const SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
            endpoint: 'https://example.com/provider.js',
          ),
        ),
    ];

    final pending = service.checkVideoSources(sources);
    await Future<void>.delayed(Duration.zero);
    expect(started, <String>['first', 'second', 'third']);

    // Complete the third and second calls before the first. This must not
    // reorder the returned list or change the next pending input.
    gates['third']!.complete(_healthyResult(sources[2]));
    gates['second']!.complete(_healthyResult(sources[1]));
    await Future<void>.delayed(Duration.zero);
    expect(started, <String>['first', 'second', 'third', 'fourth']);
    gates['fourth']!.complete(_healthyResult(sources[3]));
    gates['first']!.complete(_healthyResult(sources[0]));

    final results = await pending;
    expect(results.map((result) => result.id), <String>[
      'first',
      'second',
      'third',
      'fourth',
    ]);
    service.dispose();
  });

  test(
    'probes both movie and sub categories and captures stream diversity',
    () async {
      final runtime = _FakeQuickJsProviderRuntime();
      final service = SourceHealthProbeService(quickJsRuntime: runtime);
      const source = SourceManifest(
        id: 'mixed-provider',
        name: 'Mixed Provider',
        repositoryUrl: 'https://example.com/index.json',
        tags: <String>['movies', 'series'],
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
          endpoint: 'https://example.com/provider.js',
        ),
      );

      try {
        final result = await service.checkVideoSource(source);

        expect(runtime.searchedCategories, <String>['movie', 'sub']);
        expect(result.status, SourceHealthStatus.healthy);
        expect(result.reason, SourceHealthReason.streamsExtracted);
        expect(result.extractedStreamCount, 4);
        expect(result.qualityLabels, <String>['1080p', '720p']);
        expect(result.containerLabels, <String>['hls', 'mp4']);
        expect(result.audioKinds, <String>['dub', 'sub']);
        expect(result.subtitleTrackCount, 2);
        expect(result.categoryEvidence.keys, <String>['movies', 'series']);
        expect(result.categoryEvidence['movies']?.streamCount, 2);
        expect(result.categoryEvidence['series']?.streamCount, 2);
        expect(
          runtime.requestedStreamUrls,
          contains('https://listing.example.test/episode-1'),
        );

        final restored = SourceHealthCheckResult.fromJson(result.toJson());
        expect(restored.extractedStreamCount, result.extractedStreamCount);
        expect(restored.categoryEvidence['movies']?.qualityLabels, <String>[
          '1080p',
          '720p',
        ]);
      } finally {
        service.dispose();
      }
    },
  );

  test(
    'marks search-only matches for review when stream extraction fails',
    () async {
      const source = SourceManifest(
        id: 'series-provider',
        name: 'Series Provider',
        repositoryUrl: 'https://example.com/index.json',
        tags: <String>['series'],
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
          endpoint: 'https://example.com/provider.js',
        ),
      );

      final failingRuntime = _SearchOnlyQuickJsProviderRuntime();
      final failingService = SourceHealthProbeService(
        quickJsRuntime: failingRuntime,
      );
      final result = await failingService.checkVideoSource(source);
      expect(result.status, SourceHealthStatus.attention);
      expect(result.reason, SourceHealthReason.streamExtractionFailed);
      expect(result.extractedStreamCount, 0);
      failingService.dispose();
    },
  );
}


class _OrderedSourceHealthProbeService extends SourceHealthProbeService {
  _OrderedSourceHealthProbeService({
    required this.gates,
    required this.started,
  });

  final Map<String, Completer<SourceHealthCheckResult>> gates;
  final List<String> started;

  @override
  Future<SourceHealthCheckResult> checkVideoSource(SourceManifest source) {
    started.add(source.id);
    return gates[source.id]!.future;
  }

  @override
  void dispose() {}
}

SourceHealthCheckResult _healthyResult(SourceManifest source) =>
    SourceHealthCheckResult(
      id: source.stableKey,
      name: source.name,
      engineLabel: 'javascript',
      status: SourceHealthStatus.healthy,
      reason: SourceHealthReason.streamsExtracted,
      elapsed: Duration(milliseconds: 5),
      extractedStreamCount: 1,
      videoSource: source,
    );

class _SearchOnlyQuickJsProviderRuntime extends QuickJsProviderRuntime {
  @override
  Future<dynamic> call(
    SourceManifest source,
    String method,
    List<Object?> arguments, {
    Duration timeout = const Duration(seconds: 65),
    CancelToken? cancelToken,
  }) async {
    switch (method) {
      case 'getInfo':
        return <String, Object?>{'name': source.name};
      case 'search':
        return <Map<String, Object?>>[
          <String, Object?>{
            'id': 'sample-series',
            'url': 'https://listing.example.test/series',
          },
        ];
      case 'getDetail':
        throw StateError('No detail contract in this test provider.');
      case 'getEpisodes':
        throw StateError('No episode contract in this test provider.');
      case 'getVideoSources':
        return <Object?>[];
      default:
        throw UnsupportedError('Unexpected fake provider method: $method');
    }
  }

  @override
  void dispose() {}
}
