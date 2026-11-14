import 'dart:async';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

import 'media_identity.dart';
import 'openstream_anime_engine.dart';
import 'openstream_web_embed_engine.dart';
import 'quickjs/quickjs_provider_runtime.dart';
import 'quickjs_source_engine.dart';
import 'source_contracts.dart';
import 'source_host_policy.dart';
import 'source_manifest.dart';
import 'stremio_addon_provider.dart';
import 'stream_option.dart';
import 'embedded_player_option.dart';
import 'vidking_direct_provider.dart';

enum SourceFailureKind {
  disabled,
  repositoryDown,
  unsupportedEngine,
  unsupportedMedia,
  circuitOpen,
  cancelled,
  timeout,
  network,
  invalidResponse,
  emptyResponse,
  unknown,
}

extension SourceFailureKindProperties on SourceFailureKind {
  bool get isRetryable =>
      this == SourceFailureKind.timeout || this == SourceFailureKind.network;
}

enum SourceAttemptStage { preflight, completed, failed, cancelled }

/// Diagnostics are separate from the engine payload so legacy player adapters
/// can continue consuming [UnifiedSourceResult] without depending on telemetry.
class SourceAttemptDiagnostics {
  const SourceAttemptDiagnostics({
    required this.stage,
    required this.startedAt,
    required this.completedAt,
    required this.elapsed,
    this.failureKind,
    this.message,
    this.engineIdentity,
  });

  final SourceAttemptStage stage;
  final DateTime startedAt;
  final DateTime completedAt;
  final Duration elapsed;
  final SourceFailureKind? failureKind;
  final String? message;
  final String? engineIdentity;

  bool get retryable => failureKind?.isRetryable ?? false;
}

String? sourceHttpStatusClass(Object error) {
  final statusCode = error is DioException ? error.response?.statusCode : null;
  return statusCode == null ? null : '${statusCode ~/ 100}xx';
}

SourceFailureKind sourceFailureKindFromException(Object error) {
  if (error is TimeoutException) {
    return SourceFailureKind.timeout;
  }
  if (error is DioException) {
    if (CancelToken.isCancel(error)) {
      return SourceFailureKind.cancelled;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return SourceFailureKind.timeout;
      case DioExceptionType.badResponse:
        return SourceFailureKind.invalidResponse;
      case DioExceptionType.unknown:
        return error.error is SocketException
            ? SourceFailureKind.network
            : SourceFailureKind.unknown;
      case DioExceptionType.cancel:
        return SourceFailureKind.cancelled;
      case DioExceptionType.badCertificate:
        return SourceFailureKind.unknown;
      case DioExceptionType.connectionError:
        return SourceFailureKind.network;
    }
  }
  if (error is SocketException) {
    return SourceFailureKind.network;
  }
  if (error is FormatException) {
    return SourceFailureKind.invalidResponse;
  }
  return SourceFailureKind.unknown;
}

class UnifiedSourceResult {
  const UnifiedSourceResult({
    this.streams = const <UnifiedStreamOption>[],
    this.embeddedPlayer,
    this.errorMessage,
    this.elapsed,
    this.failureKind,
    this.httpStatusCodeClass,
  });

  final List<UnifiedStreamOption> streams;
  final UnifiedEmbeddedPlayerOption? embeddedPlayer;
  final String? errorMessage;
  final Duration? elapsed;
  final SourceFailureKind? failureKind;

  /// Optional coarse HTTP class (for example `4xx` or `5xx`). Never stores a
  /// response body, request URL, headers or query parameters.
  final String? httpStatusCodeClass;

  bool get success => streams.any((stream) => stream.isPlayable);

  /// True when the source produced either a direct media stream or a distinct
  /// browser-page handoff. Embedded pages are never counted as direct streams.
  bool get hasPlaybackCandidate => success || embeddedPlayer != null;
}

abstract class SourceEngine {
  SourceEngineKind get kind;

  bool supports(SourceManifest source) => source.engine.kind == kind;

  /// Implementations must pass [cancelToken] to cancellable I/O operations.
  /// The caller owns the token and cancels it when the request becomes stale.
  Future<UnifiedSourceResult> resolve({
    required SourceManifest source,
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  });
}

class VidkingDirectSourceEngine extends SourceEngine {
  VidkingDirectSourceEngine({
    VidkingDirectProvider? provider,
    Dio? dio,
    SourceHostPolicy? hostPolicy,
  }) : _provider =
           provider ?? VidkingDirectProvider(dio: dio, hostPolicy: hostPolicy);

  final VidkingDirectProvider _provider;

  @override
  SourceEngineKind get kind => SourceEngineKind.vidkingDirect;

  @override
  Future<UnifiedSourceResult> resolve({
    required SourceManifest source,
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final streams = await _provider.resolve(
        source: source,
        media: media,
        preferredAudioLanguage: preferredAudioLanguage,
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      return UnifiedSourceResult(streams: streams, elapsed: stopwatch.elapsed);
    } on DioException catch (error) {
      stopwatch.stop();
      return UnifiedSourceResult(
        errorMessage: error.message ?? 'Vidking request failed.',
        elapsed: stopwatch.elapsed,
        failureKind: sourceFailureKindFromException(error),
        httpStatusCodeClass: sourceHttpStatusClass(error),
      );
    } on FormatException catch (error) {
      stopwatch.stop();
      return UnifiedSourceResult(
        errorMessage: error.message,
        elapsed: stopwatch.elapsed,
        failureKind: SourceFailureKind.invalidResponse,
      );
    } catch (error) {
      stopwatch.stop();
      return UnifiedSourceResult(
        errorMessage: error.toString(),
        elapsed: stopwatch.elapsed,
        failureKind: sourceFailureKindFromException(error),
      );
    }
  }
}

class StremioSourceEngine extends SourceEngine {
  StremioSourceEngine({StremioAddonProvider? provider})
    : _provider = provider ?? StremioAddonProvider();

  final StremioAddonProvider _provider;

  @override
  SourceEngineKind get kind => SourceEngineKind.stremio;

  @override
  Future<UnifiedSourceResult> resolve({
    required SourceManifest source,
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final streams = await _provider.getStreams(
        source: source,
        media: media,
        cancelToken: cancelToken,
      );
      stopwatch.stop();
      return UnifiedSourceResult(streams: streams, elapsed: stopwatch.elapsed);
    } on DioException catch (error) {
      stopwatch.stop();
      // Dio error text may include the full request URI, including private
      // query parameters embedded in a configured Stremio manifest URL.
      return UnifiedSourceResult(
        errorMessage: switch (sourceFailureKindFromException(error)) {
          SourceFailureKind.timeout => 'Stremio add-on request timed out.',
          SourceFailureKind.network => 'Stremio add-on network request failed.',
          SourceFailureKind.invalidResponse =>
            'Stremio add-on returned an invalid response.',
          SourceFailureKind.cancelled =>
            'Stremio add-on request was cancelled.',
          _ => 'Stremio add-on request failed.',
        },
        elapsed: stopwatch.elapsed,
        failureKind: sourceFailureKindFromException(error),
        httpStatusCodeClass: sourceHttpStatusClass(error),
      );
    } on FormatException catch (error) {
      stopwatch.stop();
      return UnifiedSourceResult(
        errorMessage: error.message,
        elapsed: stopwatch.elapsed,
        failureKind: SourceFailureKind.invalidResponse,
      );
    } catch (error) {
      stopwatch.stop();
      return UnifiedSourceResult(
        errorMessage: error.toString(),
        elapsed: stopwatch.elapsed,
        failureKind: sourceFailureKindFromException(error),
      );
    }
  }
}

/// Resolves source manifests through registered engines. Unsupported engine
/// types remain visible in repository metadata but cannot accidentally run.
class UnifiedSourceAttempt {
  const UnifiedSourceAttempt({
    required this.source,
    required this.result,
    this.diagnostics,
  });

  final SourceManifest source;
  final UnifiedSourceResult result;
  final SourceAttemptDiagnostics? diagnostics;
}

typedef SourceAttemptCallback = void Function(UnifiedSourceAttempt attempt);

/// Called when a source actually leaves the queue and begins resolving.
typedef SourceEngineStartCallback = void Function(SourceManifest source);

String? _diagnosticMessageFor(SourceFailureKind? kind) {
  switch (kind) {
    case SourceFailureKind.disabled:
      return 'Source disabled before engine dispatch.';
    case SourceFailureKind.repositoryDown:
      return 'Repository marked source as down.';
    case SourceFailureKind.unsupportedEngine:
      return 'No compatible engine is registered.';
    case SourceFailureKind.unsupportedMedia:
      return 'Source does not declare support for this content type.';
    case SourceFailureKind.circuitOpen:
      return 'Source is temporarily cooling down after repeated network failures.';
    case SourceFailureKind.cancelled:
      return 'Source attempt was cancelled.';
    case SourceFailureKind.timeout:
      return 'Source attempt timed out.';
    case SourceFailureKind.network:
      return 'Source request failed at the network layer.';
    case SourceFailureKind.invalidResponse:
      return 'Source returned an invalid response.';
    case SourceFailureKind.emptyResponse:
      return 'Source returned no playable streams.';
    case SourceFailureKind.unknown:
      return 'Source attempt failed with an unclassified error.';
    case null:
      return null;
  }
}

class SourceEngineRegistry {
  SourceEngineRegistry({Iterable<SourceEngine> engines = const []}) {
    for (final engine in engines) {
      register(engine);
    }
  }

  factory SourceEngineRegistry.standard({
    Dio? dio,
    SourceHostPolicy hostPolicy = const SourceHostPolicy(),
  }) {
    final quickJsRuntime = QuickJsProviderRuntime(
      dio: dio,
      hostPolicy: hostPolicy,
    );
    return SourceEngineRegistry(
      engines: <SourceEngine>[
        VidkingDirectSourceEngine(dio: dio, hostPolicy: hostPolicy),
        StremioSourceEngine(
          provider: StremioAddonProvider(dio: dio, hostPolicy: hostPolicy),
        ),
        OpenStreamWebEmbedSourceEngine(
          engineKind: SourceEngineKind.webEmbed,
          quickJsRuntime: quickJsRuntime,
          dio: dio,
          hostPolicy: hostPolicy,
        ),
        OpenStreamWebEmbedSourceEngine(
          engineKind: SourceEngineKind.vidkingWebView,
          quickJsRuntime: quickJsRuntime,
          dio: dio,
          hostPolicy: hostPolicy,
        ),
        OpenStreamAnimeSourceEngine(
          dio: dio,
          quickJsRuntime: quickJsRuntime,
          hostPolicy: hostPolicy,
        ),
        QuickJsSourceEngine(runtime: quickJsRuntime, dio: dio),
      ],
    );
  }

  final Map<SourceEngineKind, SourceEngine> _engines = {};

  void register(SourceEngine engine) {
    _engines[engine.kind] = engine;
  }

  bool supports(SourceManifest source) =>
      source.isRunnable &&
      (_engines[source.engine.kind]?.supports(source) ?? false);

  /// Resolves enabled sources with bounded concurrency. The default is
  /// sequential: [onSourceStart] fires only when a source actually begins,
  /// and [onAttempt] fires when that source finishes. Results retain manifest
  /// priority order while the UI shows only active work as loading.
  Future<List<UnifiedSourceAttempt>> resolveMany({
    required Iterable<SourceManifest> sources,
    required MediaIdentity media,
    int maxConcurrency = 1,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
    SourceAttemptCallback? onAttempt,
    SourceEngineStartCallback? onSourceStart,
  }) async {
    final ordered = sources.toList(growable: false)
      ..sort((a, b) {
        final byPriority = a.engine.priority.compareTo(b.engine.priority);
        return byPriority != 0
            ? byPriority
            : a.stableKey.compareTo(b.stableKey);
      });
    if (ordered.isEmpty) {
      return const <UnifiedSourceAttempt>[];
    }

    final attempts = List<UnifiedSourceAttempt?>.filled(ordered.length, null);
    var nextIndex = 0;
    final workerCount = maxConcurrency.clamp(1, ordered.length).toInt();

    Future<void> worker() async {
      while (true) {
        if (cancelToken?.isCancelled == true) {
          return;
        }
        final index = nextIndex++;
        if (index >= ordered.length) {
          return;
        }
        final source = ordered[index];
        try {
          onSourceStart?.call(source);
        } catch (_) {
          // Progress reporting must not interrupt the source queue.
        }
        final startedAt = DateTime.now().toUtc();
        final stopwatch = Stopwatch()..start();
        UnifiedSourceResult result;
        try {
          result = await resolve(
            source: source,
            media: media,
            preferredAudioLanguage: preferredAudioLanguage,
            cancelToken: cancelToken,
          );
        } catch (error) {
          result = UnifiedSourceResult(
            errorMessage: error.toString(),
            failureKind: sourceFailureKindFromException(error),
          );
        }
        stopwatch.stop();
        final completedAt = DateTime.now().toUtc();
        final failureKind =
            result.failureKind ??
            (result.hasPlaybackCandidate
                ? null
                : SourceFailureKind.emptyResponse);
        if (result.failureKind == null && failureKind != null) {
          result = UnifiedSourceResult(
            streams: result.streams,
            embeddedPlayer: result.embeddedPlayer,
            errorMessage: result.errorMessage,
            elapsed: result.elapsed,
            failureKind: failureKind,
            httpStatusCodeClass: result.httpStatusCodeClass,
          );
        }
        final isPreflightFailure =
            failureKind == SourceFailureKind.disabled ||
            failureKind == SourceFailureKind.repositoryDown ||
            failureKind == SourceFailureKind.unsupportedEngine;
        final diagnostics = SourceAttemptDiagnostics(
          stage: result.hasPlaybackCandidate
              ? SourceAttemptStage.completed
              : failureKind == SourceFailureKind.cancelled
              ? SourceAttemptStage.cancelled
              : isPreflightFailure
              ? SourceAttemptStage.preflight
              : SourceAttemptStage.failed,
          startedAt: startedAt,
          completedAt: completedAt,
          elapsed: result.elapsed ?? stopwatch.elapsed,
          failureKind: failureKind,
          // Provider exception text may contain signed URLs, headers, or
          // API tokens. Keep diagnostics categorical; the existing result
          // still carries its user-facing error message unchanged.
          message: _diagnosticMessageFor(failureKind),
          engineIdentity: source.engineIdentity.key,
        );
        final attempt = UnifiedSourceAttempt(
          source: source,
          result: result,
          diagnostics: diagnostics,
        );
        attempts[index] = attempt;
        try {
          onAttempt?.call(attempt);
        } catch (_) {
          // A UI callback must not abort remaining provider resolutions.
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return attempts.whereType<UnifiedSourceAttempt>().toList(growable: false);
  }

  Future<UnifiedSourceResult> resolve({
    required SourceManifest source,
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  }) async {
    final engine = _engines[source.engine.kind];
    // Explicit installation from the repository manager is the user's enable
    // action, even when upstream metadata carries an `enabled:false` flag.
    // Repository health labels are advisory; allow the request to prove
    // whether the provider is currently reachable.
    // Provider media tags are advisory only. A source selected by the user
    // must be allowed to attempt resolution for any VOD media identity; its
    // concrete engine response decides whether a playable result exists.
    if (engine == null || !engine.supports(source)) {
      return UnifiedSourceResult(
        errorMessage: 'Unsupported source engine: ${source.engineIdentity.key}',
        failureKind: SourceFailureKind.unsupportedEngine,
      );
    }
    return engine.resolve(
      source: source,
      media: media,
      preferredAudioLanguage: preferredAudioLanguage,
      cancelToken: cancelToken,
    );
  }
}
