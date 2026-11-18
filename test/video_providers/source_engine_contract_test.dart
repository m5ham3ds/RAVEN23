import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/source_engine.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/stream_option.dart';

void main() {
  const media = MediaIdentity(
    type: UnifiedMediaType.movie,
    title: 'Contract Test Movie',
  );

  test(
    'registry emits structured diagnostics without changing stream payload',
    () async {
      const source = SourceManifest(
        id: 'test-native',
        name: 'Test Native',
        repositoryUrl: 'https://repo.example/index.json',
        engine: SourceEngineDescriptor(
          rawType: 'native',
          kind: SourceEngineKind.native,
          endpoint: 'https://source.example',
        ),
      );
      final registry = SourceEngineRegistry(
        engines: <SourceEngine>[
          _FakeSourceEngine(
            UnifiedSourceResult(
              streams: const <UnifiedStreamOption>[
                UnifiedStreamOption(
                  id: 'stream-1',
                  providerId: 'test-native',
                  providerName: 'Test Native',
                  url: 'https://media.example/video.m3u8',
                  container: StreamContainer.hls,
                ),
              ],
            ),
          ),
        ],
      );

      final attempts = await registry.resolveMany(
        sources: const <SourceManifest>[source],
        media: media,
      );

      expect(attempts, hasLength(1));
      expect(attempts.single.result.success, isTrue);
      expect(attempts.single.result.streams.single.id, 'stream-1');
      expect(attempts.single.diagnostics, isNotNull);
      expect(attempts.single.diagnostics!.stage, SourceAttemptStage.completed);
      expect(attempts.single.diagnostics!.engineIdentity, 'native::native');
      expect(attempts.single.diagnostics!.elapsed, isNotNull);
      expect(attempts.single.diagnostics!.failureKind, isNull);
    },
  );

  test('unsupported engine messages use a sanitized engine identity', () async {
    const source = SourceManifest(
      id: 'unknown-engine',
      name: 'Unknown Engine',
      engine: SourceEngineDescriptor(
        rawType: 'custom?token=private-value',
        kind: SourceEngineKind.unsupported,
      ),
    );
    final attempts = await SourceEngineRegistry().resolveMany(
      sources: const <SourceManifest>[source],
      media: media,
    );

    expect(
      attempts.single.result.failureKind,
      SourceFailureKind.unsupportedEngine,
    );
    expect(
      attempts.single.result.errorMessage,
      contains('unsupported::custom'),
    );
    expect(
      attempts.single.result.errorMessage,
      isNot(contains('private-value')),
    );
    expect(attempts.single.diagnostics!.stage, SourceAttemptStage.preflight);
  });

  test(
    'registry classifies untyped empty results as empty responses',
    () async {
      const source = SourceManifest(
        id: 'empty-native',
        name: 'Empty Native',
        engine: SourceEngineDescriptor(
          rawType: 'native',
          kind: SourceEngineKind.native,
        ),
      );
      final registry = SourceEngineRegistry(
        engines: <SourceEngine>[_FakeSourceEngine(const UnifiedSourceResult())],
      );

      final attempts = await registry.resolveMany(
        sources: const <SourceManifest>[source],
        media: media,
      );

      expect(
        attempts.single.result.failureKind,
        SourceFailureKind.emptyResponse,
      );
      expect(
        attempts.single.diagnostics!.failureKind,
        SourceFailureKind.emptyResponse,
      );
      expect(attempts.single.diagnostics!.stage, SourceAttemptStage.failed);
    },
  );

  test('registry classifies disabled sources before engine dispatch', () async {
    const source = SourceManifest(
      id: 'disabled-native',
      name: 'Disabled Native',
      enabled: false,
      engine: SourceEngineDescriptor(
        rawType: 'native',
        kind: SourceEngineKind.native,
      ),
    );
    final registry = SourceEngineRegistry(
      engines: <SourceEngine>[_FakeSourceEngine(const UnifiedSourceResult())],
    );

    final attempts = await registry.resolveMany(
      sources: const <SourceManifest>[source],
      media: media,
    );

    expect(attempts, hasLength(1));
    expect(attempts.single.diagnostics!.stage, SourceAttemptStage.preflight);
    expect(
      attempts.single.diagnostics!.failureKind,
      SourceFailureKind.disabled,
    );
    expect(attempts.single.diagnostics!.retryable, isFalse);
  });

  test('diagnostic labels do not copy raw provider error text', () async {
    const source = SourceManifest(
      id: 'secret-error-native',
      name: 'Secret Error Native',
      engine: SourceEngineDescriptor(
        rawType: 'native',
        kind: SourceEngineKind.native,
      ),
    );
    final registry = SourceEngineRegistry(
      engines: <SourceEngine>[
        _FakeSourceEngine(
          const UnifiedSourceResult(
            errorMessage: 'Request failed with api_key=private-value',
            failureKind: SourceFailureKind.network,
          ),
        ),
      ],
    );

    final attempts = await registry.resolveMany(
      sources: const <SourceManifest>[source],
      media: media,
    );

    expect(
      attempts.single.result.errorMessage,
      'Request failed with api_key=private-value',
    );
    expect(
      attempts.single.diagnostics!.message,
      'Source request failed at the network layer.',
    );
    expect(
      attempts.single.diagnostics!.message,
      isNot(contains('private-value')),
    );
  });

  test('Dio and format exceptions map to stable failure categories', () {
    final requestOptions = RequestOptions(path: '/source');

    expect(
      sourceFailureKindFromException(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        ),
      ),
      SourceFailureKind.timeout,
    );
    expect(
      sourceFailureKindFromException(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
        ),
      ),
      SourceFailureKind.network,
    );
    expect(
      sourceFailureKindFromException(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: 404,
          ),
        ),
      ),
      SourceFailureKind.invalidResponse,
    );
    expect(
      sourceFailureKindFromException(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.unknown,
          error: const SocketException('network unavailable'),
        ),
      ),
      SourceFailureKind.network,
    );
    expect(
      sourceFailureKindFromException(TimeoutException('request timeout')),
      SourceFailureKind.timeout,
    );
    expect(
      sourceFailureKindFromException(FormatException('bad json')),
      SourceFailureKind.invalidResponse,
    );
  });

  test(
    'retryable failure metadata is independent from the result message',
    () async {
      const source = SourceManifest(
        id: 'timeout-native',
        name: 'Timeout Native',
        engine: SourceEngineDescriptor(
          rawType: 'native',
          kind: SourceEngineKind.native,
        ),
      );
      final registry = SourceEngineRegistry(
        engines: <SourceEngine>[
          _FakeSourceEngine(
            const UnifiedSourceResult(
              errorMessage: 'The source timed out.',
              failureKind: SourceFailureKind.timeout,
            ),
          ),
        ],
      );

      final attempts = await registry.resolveMany(
        sources: const <SourceManifest>[source],
        media: media,
      );

      final diagnostic = attempts.single.diagnostics!;
      expect(attempts.single.result.errorMessage, 'The source timed out.');
      expect(diagnostic.stage, SourceAttemptStage.failed);
      expect(diagnostic.failureKind, SourceFailureKind.timeout);
      expect(diagnostic.retryable, isTrue);
      expect(diagnostic.message, 'Source attempt timed out.');
    },
  );
}

class _FakeSourceEngine extends SourceEngine {
  _FakeSourceEngine(this.result);

  final UnifiedSourceResult result;

  @override
  SourceEngineKind get kind => SourceEngineKind.native;

  @override
  Future<UnifiedSourceResult> resolve({
    required SourceManifest source,
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  }) async => result;
}
