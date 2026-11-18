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
  test('keeps the first twelve Movies/Series PRIMARY entries fixed', () {
    final prefix = List<String>.generate(12, (index) => 'fixed-$index');
    final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
      category: SourcePriorityCategory.movies,
      currentPrimaryKeys: <String>[...prefix, 'old-tail'],
      backupKeys: const <String>[],
      results: <SourceHealthCheckResult>[
        _result(
          'quality-rich',
          category: 'movies',
          qualities: const <String>['720p', '1080p'],
        ),
        _result(
          'quick',
          category: 'movies',
          qualities: const <String>['720p'],
          elapsedMs: 20,
        ),
        _result(
          'no-stream',
          category: 'movies',
          qualities: const <String>[],
          streamCount: 0,
        ),
      ],
    );

    expect(ranked.take(12), prefix);
    expect(ranked.skip(12), <String>[_key('quality-rich'), _key('quick')]);
    expect(ranked, isNot(contains(_key('no-stream'))));
  });

  test('keeps the first fourteen Anime PRIMARY entries fixed', () {
    final prefix = List<String>.generate(14, (index) => 'anime-fixed-$index');
    final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
      category: SourcePriorityCategory.anime,
      currentPrimaryKeys: <String>[...prefix, 'old-anime-tail'],
      backupKeys: const <String>[],
      results: <SourceHealthCheckResult>[
        _result(
          'anime-fast',
          category: 'anime',
          qualities: const <String>['720p'],
          elapsedMs: 10,
        ),
      ],
    );

    expect(ranked.take(14), prefix);
    expect(ranked.skip(14), <String>[_key('anime-fast')]);
  });

  test('ranks quality diversity first and latency as a later tie-breaker', () {
    final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
      category: SourcePriorityCategory.series,
      currentPrimaryKeys: const <String>[],
      backupKeys: const <String>[],
      results: <SourceHealthCheckResult>[
        _result(
          'slow-rich',
          category: 'series',
          qualities: const <String>['480p', '720p', '1080p'],
          elapsedMs: 800,
        ),
        _result(
          'fast-rich',
          category: 'series',
          qualities: const <String>['480p', '720p', '1080p'],
          elapsedMs: 60,
        ),
        _result(
          'fast-limited',
          category: 'series',
          qualities: const <String>['720p'],
          elapsedMs: 5,
        ),
      ],
    );

    expect(ranked, <String>[
      _key('fast-rich'),
      _key('slow-rich'),
      _key('fast-limited'),
    ]);
  });

  test('does not rank manually selected BACKUP providers', () {
    final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
      category: SourcePriorityCategory.series,
      currentPrimaryKeys: const <String>['fixed'],
      backupKeys: <String>[_key('backup-provider')],
      results: <SourceHealthCheckResult>[
        _result(
          'backup-provider',
          category: 'series',
          qualities: const <String>['720p', '1080p'],
        ),
        _result(
          'primary-candidate',
          category: 'series',
          qualities: const <String>['720p'],
        ),
      ],
    );

    expect(ranked, <String>['fixed', _key('primary-candidate')]);
  });

  test(
    'does not erase an existing safe tail when no stream evidence exists',
    () {
      final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
        category: SourcePriorityCategory.movies,
        currentPrimaryKeys: const <String>['first', 'safe-tail', 'hentai-old'],
        backupKeys: const <String>[],
        results: const <SourceHealthCheckResult>[],
      );

      expect(ranked, <String>['first', 'safe-tail']);
    },
  );
}
