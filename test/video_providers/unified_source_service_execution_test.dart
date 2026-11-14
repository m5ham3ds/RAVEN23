import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/source_engine.dart';
import 'package:raven23/video_providers/unified/source_execution_policy.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_priority_manager.dart';
import 'package:raven23/video_providers/unified/source_repository_manager.dart';
import 'package:raven23/video_providers/unified/stream_option.dart';
import 'package:raven23/video_providers/unified/unified_source_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const media = MediaIdentity(
    type: UnifiedMediaType.movie,
    title: 'Unified Source Execution Fixture',
    tmdbId: 9004501,
  );

  test(
    'first playable callback fires before the slower source completes',
    () async {
      final slowGate = Completer<UnifiedSourceResult>();
      final firstPlayable = Completer<UnifiedSourceAttempt>();
      var searchCompleted = false;
      final engine = _FakeEngine((source, _, __, ___) {
        if (source.id == 'slow') return slowGate.future;
        return Future<UnifiedSourceResult>.value(_playable(source.id));
      });
      final service = _service(
        engine,
        policy: const SourceExecutionPolicy(
          maxConcurrentSources: 2,
          fallbackHeadStart: Duration.zero,
        ),
      );

      final search = service
          .search(
            media: media,
            repositorySnapshot: _snapshot(<SourceManifest>[
              _source('slow', priority: 1),
              _source('fast', priority: 2),
            ]),
            onFirstPlayable: firstPlayable.complete,
          )
          .then((value) {
            searchCompleted = true;
            return value;
          });

      final first = await firstPlayable.future.timeout(
        const Duration(seconds: 2),
      );
      expect(first.source.id, 'fast');
      expect(searchCompleted, isFalse);

      slowGate.complete(_empty());
      final completed = await search;
      expect(completed.streams, hasLength(1));
      expect(completed.attempts.map((attempt) => attempt.source.id), <String>[
        'slow',
        'fast',
      ]);
    },
  );

  test(
    'a saturated QuickJS queue does not block another engine worker',
    () async {
      final quickJsGate = Completer<UnifiedSourceResult>();
      final stremioStarted = Completer<void>();
      var activeQuickJs = 0;
      final quickJsEngine = _FakeEngine((source, _, __, ___) async {
        activeQuickJs++;
        try {
          return await quickJsGate.future;
        } finally {
          activeQuickJs--;
        }
      }, engineKind: SourceEngineKind.javascript);
      final stremioEngine = _FakeEngine((source, _, __, ___) async {
        if (!stremioStarted.isCompleted) stremioStarted.complete();
        return _empty();
      });
      final service = UnifiedSourceService(
        engines: SourceEngineRegistry(
          engines: <SourceEngine>[quickJsEngine, stremioEngine],
        ),
        executionPolicy: const SourceExecutionPolicy(maxConcurrentSources: 3),
      );

      final search = service.search(
        media: media,
        repositorySnapshot: _snapshot(<SourceManifest>[
          _source('quickjs-a', kind: SourceEngineKind.javascript),
          _source('quickjs-b', kind: SourceEngineKind.javascript),
          _source('quickjs-c', kind: SourceEngineKind.javascript),
          _source('stremio-ready'),
        ]),
      );

      await stremioStarted.future.timeout(const Duration(seconds: 2));
      expect(activeQuickJs, 1);
      quickJsGate.complete(_empty());
      await search.timeout(const Duration(seconds: 2));
    },
  );

  test(
    'returned attempts remain priority ordered despite completion order',
    () async {
      final slowGate = Completer<UnifiedSourceResult>();
      final engine = _FakeEngine((source, _, __, ___) {
        if (source.id == 'priority-first') return slowGate.future;
        return Future<UnifiedSourceResult>.value(_empty());
      });
      final service = _service(
        engine,
        policy: const SourceExecutionPolicy(maxConcurrentSources: 2),
      );
      final search = service.search(
        media: media,
        repositorySnapshot: _snapshot(<SourceManifest>[
          _source('priority-first', priority: 1),
          _source('priority-second', priority: 2),
        ]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      slowGate.complete(_empty());
      final result = await search;
      expect(result.attempts.map((attempt) => attempt.source.id), <String>[
        'priority-first',
        'priority-second',
      ]);
    },
  );

  test(
    'manual primary and backup lists override declared media tags and order',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final priorityManager = SourcePriorityManager(preferences: preferences);
      await priorityManager.setPriorityKeys(
        SourcePriorityCategory.movies,
        <String>['https://repo.example/index.json::anime-first'],
      );
      await priorityManager.setBackupKeys(
        SourcePriorityCategory.movies,
        <String>['https://repo.example/index.json::movie-backup'],
      );
      await priorityManager.markInitialized();

      final attempted = <String>[];
      final engine = _FakeEngine((source, _, __, ___) async {
        attempted.add(source.id);
        return source.id == 'remaining' ? _playable(source.id) : _empty();
      });
      final service = UnifiedSourceService(
        engines: SourceEngineRegistry(engines: <SourceEngine>[engine]),
        priorityManager: priorityManager,
        executionPolicy: const SourceExecutionPolicy(
          maxConcurrentSources: 1,
          fallbackHeadStart: Duration.zero,
        ),
      );
      final animeTagged = SourceManifest(
        id: 'anime-first',
        name: 'Anime first',
        repositoryUrl: 'https://repo.example/index.json',
        language: 'Japanese',
        tags: const <String>['anime-only'],
        engine: const SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          config: <String, dynamic>{'idPrefixes': <String>[]},
        ),
      );
      final movieTagged = SourceManifest(
        id: 'movie-backup',
        name: 'Movie backup',
        repositoryUrl: 'https://repo.example/index.json',
        tags: const <String>['movie-only'],
        engine: const SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          config: <String, dynamic>{'idPrefixes': <String>[]},
        ),
      );
      final remaining = SourceManifest(
        id: 'remaining',
        name: 'Remaining',
        repositoryUrl: 'https://repo.example/index.json',
        engine: const SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
          config: <String, dynamic>{'idPrefixes': <String>[]},
        ),
      );

      final result = await service.search(
        media: media,
        repositorySnapshot: _snapshot(<SourceManifest>[
          remaining,
          movieTagged,
          animeTagged,
        ]),
      );

      expect(attempted, <String>['anime-first', 'movie-backup', 'remaining']);
      expect(result.streams, hasLength(1));
    },
  );

  test(
    'only streams with explicit future expiry enter the result cache',
    () async {
      var calls = 0;
      final engine = _FakeEngine((source, _, __, ___) {
        calls++;
        return Future<UnifiedSourceResult>.value(
          UnifiedSourceResult(
            streams: <UnifiedStreamOption>[
              _stream(
                source.id,
                expiresAt: DateTime.now().add(const Duration(minutes: 5)),
              ),
            ],
          ),
        );
      });
      final service = _service(engine);
      final snapshot = _snapshot(<SourceManifest>[_source('cacheable')]);

      await service.search(media: media, repositorySnapshot: snapshot);
      final second = await service.search(
        media: media,
        repositorySnapshot: snapshot,
      );

      expect(calls, 1);
      expect(
        second.attempts.single.result.streams.single.url,
        contains('cacheable'),
      );
      expect(
        service.recentExecutionMetrics.any((metric) => metric.cacheHit),
        isTrue,
      );
    },
  );

  test('cached streams are isolated by preferred audio language', () async {
    final requestedLanguages = <String?>[];
    final engine = _FakeEngine((source, _, language, ___) async {
      requestedLanguages.add(language);
      return UnifiedSourceResult(
        streams: <UnifiedStreamOption>[
          _stream(
            '${source.id}-${language ?? 'auto'}',
            expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
        ],
      );
    });
    final service = _service(engine);
    final snapshot = _snapshot(<SourceManifest>[_source('language-cache')]);

    await service.search(
      media: media,
      repositorySnapshot: snapshot,
      preferredAudioLanguage: 'English',
    );
    await service.search(
      media: media,
      repositorySnapshot: snapshot,
      preferredAudioLanguage: 'Hindi',
    );

    expect(requestedLanguages, <String?>['English', 'Hindi']);
  });

  test(
    'cache is invalidated when the same repository source is revised',
    () async {
      var calls = 0;
      final engine = _FakeEngine((source, _, __, ___) async {
        calls++;
        return UnifiedSourceResult(
          streams: <UnifiedStreamOption>[
            _stream(
              source.engine.endpoint,
              expiresAt: DateTime.now().add(const Duration(minutes: 5)),
            ),
          ],
        );
      });
      final service = _service(engine);
      final oldSource = SourceManifest(
        id: 'revision-cache',
        name: 'Revision Cache',
        repositoryUrl: 'https://repo.example/index.json',
        language: 'English',
        engine: const SourceEngineDescriptor(
          rawType: 'native',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://provider.example/v1',
          config: <String, dynamic>{
            'revision': 1,
            'languageDeclared': true,
            'statusDeclared': true,
          },
        ),
      );
      final newSource = SourceManifest(
        id: 'revision-cache',
        name: 'Revision Cache',
        repositoryUrl: 'https://repo.example/index.json',
        version: '2.0.0',
        language: 'English',
        engine: const SourceEngineDescriptor(
          rawType: 'native',
          kind: SourceEngineKind.stremio,
          endpoint: 'https://provider.example/v2',
          config: <String, dynamic>{
            'revision': 2,
            'languageDeclared': true,
            'statusDeclared': true,
          },
        ),
      );

      await service.search(
        media: media,
        repositorySnapshot: _snapshot(<SourceManifest>[oldSource]),
      );
      await service.search(
        media: media,
        repositorySnapshot: _snapshot(<SourceManifest>[newSource]),
      );

      expect(calls, 2);
    },
  );

  test('results without source-declared expiry are never cached', () async {
    var calls = 0;
    final engine = _FakeEngine((source, _, __, ___) {
      calls++;
      return Future<UnifiedSourceResult>.value(_playable(source.id));
    });
    final service = _service(engine);
    final snapshot = _snapshot(<SourceManifest>[_source('no-expiry')]);

    await service.search(media: media, repositorySnapshot: snapshot);
    await service.search(media: media, repositorySnapshot: snapshot);

    expect(calls, 2);
  });

  test(
    'circuit breaker cools a provider after repeated retryable failures',
    () async {
      var now = DateTime.utc(2026, 11, 7);
      var calls = 0;
      final engine = _FakeEngine((source, _, __, ___) {
        calls++;
        return Future<UnifiedSourceResult>.value(
          const UnifiedSourceResult(
            errorMessage: 'network unavailable',
            failureKind: SourceFailureKind.network,
          ),
        );
      });
      final service = UnifiedSourceService(
        engines: SourceEngineRegistry(engines: <SourceEngine>[engine]),
        executionPolicy: const SourceExecutionPolicy(
          maxConcurrentSources: 1,
          circuitFailureThreshold: 2,
          circuitCooldown: Duration(minutes: 2),
        ),
        clock: () => now,
      );
      final snapshot = _snapshot(<SourceManifest>[_source('unstable')]);

      await service.search(media: media, repositorySnapshot: snapshot);
      await service.search(media: media, repositorySnapshot: snapshot);
      final blocked = await service.search(
        media: media,
        repositorySnapshot: snapshot,
      );
      expect(
        blocked.attempts.single.result.failureKind,
        SourceFailureKind.circuitOpen,
      );
      expect(calls, 2);

      now = now.add(const Duration(minutes: 3));
      await service.search(media: media, repositorySnapshot: snapshot);
      expect(calls, 3);
    },
  );

  test('per-engine semaphore enforces the configured request limit', () async {
    var active = 0;
    var maximumActive = 0;
    final engine = _FakeEngine((source, _, __, ___) async {
      active++;
      if (active > maximumActive) maximumActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      active--;
      return _empty();
    });
    final service = _service(
      engine,
      policy: const SourceExecutionPolicy(maxConcurrentSources: 4),
    );
    await service.search(
      media: media,
      repositorySnapshot: _snapshot(<SourceManifest>[
        _source('semaphore-a', priority: 1),
        _source('semaphore-b', priority: 2),
        _source('semaphore-c', priority: 3),
        _source('semaphore-d', priority: 4),
      ]),
    );

    expect(maximumActive, 2);
  });

  test('metrics retain only coarse HTTP status class', () async {
    final engine = _FakeEngine(
      (source, _, __, ___) async => const UnifiedSourceResult(
        errorMessage: 'Request returned an error.',
        failureKind: SourceFailureKind.invalidResponse,
        httpStatusCodeClass: '4xx',
      ),
    );
    final service = _service(engine);
    await service.search(
      media: media,
      repositorySnapshot: _snapshot(<SourceManifest>[_source('status-class')]),
    );

    expect(service.recentExecutionMetrics.single.httpStatusClass, '4xx');
    expect(
      service.recentExecutionMetrics.single.toString(),
      isNot(contains('https://')),
    );
  });

  test(
    'cancellation suppresses callbacks and discards late source results',
    () async {
      final response = Completer<UnifiedSourceResult>();
      final cancelToken = CancelToken();
      var callbackCount = 0;
      final engine = _FakeEngine((source, _, __, ___) => response.future);
      final service = _service(engine);
      final search = service.search(
        media: media,
        cancelToken: cancelToken,
        repositorySnapshot: _snapshot(<SourceManifest>[_source('late')]),
        onAttempt: (_) => callbackCount++,
        onFirstPlayable: (_) => callbackCount++,
      );

      await Future<void>.delayed(Duration.zero);
      cancelToken.cancel('test cancellation');
      response.complete(_playable('late'));
      final result = await search;

      expect(result.attempts, isEmpty);
      expect(callbackCount, 0);
    },
  );
}

UnifiedSourceService _service(
  _FakeEngine engine, {
  SourceExecutionPolicy policy = const SourceExecutionPolicy(
    maxConcurrentSources: 3,
    fallbackHeadStart: Duration.zero,
  ),
}) => UnifiedSourceService(
  engines: SourceEngineRegistry(engines: <SourceEngine>[engine]),
  executionPolicy: policy,
);

SourceManifest _source(
  String id, {
  int priority = 50,
  int status = 1,
  bool statusDeclared = true,
  bool fallback = false,
  SourceEngineKind kind = SourceEngineKind.stremio,
}) => SourceManifest(
  id: id,
  name: id,
  repositoryUrl: 'https://repo.example/index.json',
  isFallback: fallback,
  status: status,
  engine: SourceEngineDescriptor(
    rawType: kind.name,
    kind: kind,
    priority: priority,
    config: <String, dynamic>{
      'idPrefixes': <String>[],
      'languageDeclared': true,
      'statusDeclared': statusDeclared,
    },
  ),
);

SourceRepositorySyncResult _snapshot(List<SourceManifest> sources) =>
    SourceRepositorySyncResult(
      repositories: const <SourceRepositoryManifest>[],
      sources: sources,
      errors: const <String, String>{},
    );

UnifiedSourceResult _playable(String id) =>
    UnifiedSourceResult(streams: <UnifiedStreamOption>[_stream(id)]);

UnifiedSourceResult _empty() => const UnifiedSourceResult();

UnifiedStreamOption _stream(String id, {DateTime? expiresAt}) =>
    UnifiedStreamOption(
      id: 'stream-$id',
      providerId: id,
      providerName: id,
      url: 'https://media.example/$id.m3u8',
      container: StreamContainer.hls,
      expiresAt: expiresAt,
    );

class _FakeEngine extends SourceEngine {
  _FakeEngine(this.handler, {this.engineKind = SourceEngineKind.stremio});

  final SourceEngineKind engineKind;
  final Future<UnifiedSourceResult> Function(
    SourceManifest source,
    MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  )
  handler;

  @override
  SourceEngineKind get kind => engineKind;

  @override
  Future<UnifiedSourceResult> resolve({
    required SourceManifest source,
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  }) => handler(source, media, preferredAudioLanguage, cancelToken);
}
