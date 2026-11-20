import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/screens/common/source_health_priority_ranker.dart';
import 'package:raven23/screens/common/source_health_probe_service.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_priority_manager.dart';

const _repository = 'https://example.com/index.json';

SourceManifest _source(String id) => SourceManifest(
  id: id,
  name: id,
  repositoryUrl: _repository,
  tags: const <String>['series'],
  engine: const SourceEngineDescriptor(
    rawType: 'javascript',
    kind: SourceEngineKind.javascript,
  ),
);

String _key(String id) => '$_repository::$id';

SourceHealthCheckResult _result(
  String id, {
  required String category,
  required List<String> qualities,
  List<String> containers = const <String>['hls'],
  List<String> audioKinds = const <String>['sub'],
  int streamCount = 1,
  int elapsedMs = 100,
}) {
  final evidence = SourceHealthCategoryEvidence(
    category: category,
    resultCount: 1,
    streamCount: streamCount,
    elapsedMs: elapsedMs,
    qualityLabels: qualities,
    containerLabels: containers,
    audioKinds: audioKinds,
  );
  return SourceHealthCheckResult(
    id: id,
    name: id,
    engineLabel: 'javascript',
    status: SourceHealthStatus.healthy,
    reason: SourceHealthReason.streamsExtracted,
    elapsed: Duration(milliseconds: elapsedMs),
    extractedStreamCount: streamCount,
    qualityLabels: qualities,
    containerLabels: containers,
    audioKinds: audioKinds,
    categoryEvidence: <String, SourceHealthCategoryEvidence>{
      category: evidence,
    },
    videoSource: _source(id),
  );
}

void main() {
  test('keeps every existing Movies PRIMARY entry in its exact order', () {
    final primary = <String>[
      for (var i = 0; i < 12; i++) 'movie-default-$i',
      'custom-source-z',
      'custom-source-a',
      'custom-source-m',
    ];

    final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
      category: SourcePriorityCategory.movies,
      currentPrimaryKeys: primary,
      backupKeys: const <String>['backup-source'],
      results: <SourceHealthCheckResult>[
        _result(
          'new-fastest-source',
          category: 'movies',
          qualities: const <String>['360p', '720p', '1080p', '2160p'],
          elapsedMs: 1,
        ),
        _result(
          'custom-source-a',
          category: 'movies',
          qualities: const <String>['720p'],
        ),
      ],
    );

    expect(ranked, primary);
    expect(ranked, isNot(contains(_key('new-fastest-source'))));
    expect(ranked, isNot(contains('backup-source')));
  });

  test('keeps the complete Anime PRIMARY order including its custom tail', () {
    final primary = <String>[
      for (var i = 0; i < 14; i++) 'anime-default-$i',
      'anime-custom-z',
      'anime-custom-a',
    ];

    final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
      category: SourcePriorityCategory.anime,
      currentPrimaryKeys: primary,
      backupKeys: const <String>[],
      results: <SourceHealthCheckResult>[
        _result(
          'anime-fastest-new-source',
          category: 'anime',
          qualities: const <String>['720p', '1080p'],
          elapsedMs: 1,
        ),
      ],
    );

    expect(ranked, primary);
  });

  test('does not append a successful BACKUP or unknown catalogue source', () {
    final primary = <String>['first', 'custom-tail'];

    final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
      category: SourcePriorityCategory.series,
      currentPrimaryKeys: primary,
      backupKeys: <String>[_key('backup-provider')],
      results: <SourceHealthCheckResult>[
        _result('backup-provider', category: 'series', qualities: const ['720p']),
        _result('new-provider', category: 'series', qualities: const ['1080p']),
      ],
    );

    expect(ranked, primary);
  });

  test('removes only explicitly blocked Hentai identities without sorting', () {
    final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
      category: SourcePriorityCategory.movies,
      currentPrimaryKeys: const <String>[
        'first-custom',
        'hentai-old-provider',
        'second-custom',
        'third-custom',
      ],
      backupKeys: const <String>[],
      results: const <SourceHealthCheckResult>[],
    );

    expect(ranked, <String>[
      'first-custom',
      'second-custom',
      'third-custom',
    ]);
  });

  test('keeps the documented default prefix lengths', () {
    expect(
      SourceHealthPriorityRanker.fixedPrefixLength(SourcePriorityCategory.movies),
      12,
    );
    expect(
      SourceHealthPriorityRanker.fixedPrefixLength(SourcePriorityCategory.series),
      12,
    );
    expect(
      SourceHealthPriorityRanker.fixedPrefixLength(SourcePriorityCategory.anime),
      14,
    );
  });
}
