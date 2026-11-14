import 'dart:async';

import 'package:flutter/foundation.dart';

import '../functions/video_utils.dart';

import 'common.dart';
import 'names.dart';
import 'scraper_api.dart';
import 'unified/legacy_provider_adapter.dart';
import 'unified/media_identity.dart';
import 'unified/source_manifest.dart';
import 'unified/source_execution_policy.dart';
import 'unified/source_engine.dart';
import 'unified/unified_source_service.dart';
import 'vixsrc.dart';
import '../preferences/setting_preferences.dart';
import '../services/playback_stream_cache.dart';

typedef ProviderLoaderResult = ProviderLoadResult;
typedef ProviderResultCallback =
    void Function(int index, VideoProvider provider, ProviderLoadResult result);
typedef ProviderStartCallback =
    void Function(int index, VideoProvider provider);

class ProviderSelection {
  const ProviderSelection({
    required this.index,
    required this.provider,
    required this.result,
    this.scanSession,
    this.cachedProviderResults = const <String, ProviderLoadResult>{},
    this.selectedUrl,
    this.restoredFromCache = false,
  });

  final int index;
  final VideoProvider provider;
  final ProviderLoadResult result;
  final ProviderScanSession? scanSession;
  final Map<String, ProviderLoadResult> cachedProviderResults;
  final String? selectedUrl;
  final bool restoredFromCache;
}

class ProviderScanUpdate {
  const ProviderScanUpdate.started({
    required this.index,
    required this.provider,
  }) : result = null,
       isStarted = true;

  const ProviderScanUpdate.completed({
    required this.index,
    required this.provider,
    required this.result,
  }) : isStarted = false;

  final int index;
  final VideoProvider provider;
  final ProviderLoadResult? result;
  final bool isStarted;
}

class _ClaimedProvider {
  const _ClaimedProvider({
    required this.provider,
    required this.engineKind,
    required this.isPrimary,
  });

  final VideoProvider provider;
  final SourceEngineKind engineKind;
  final bool isPrimary;
}

/// One playback scan whose first successful source can start the player while
/// bounded workers continue looking for alternative providers/qualities.
class ProviderScanSession {
  ProviderScanSession({
    required this.providers,
    required this.load,
    this.onResult,
    this.onStart,
    this.unifiedMediaIdentity,
    this.initialResults = const <String, ProviderLoadResult>{},
    this.maxConcurrency = 3,
    this.stopAfterStandardQualities = true,
    this.continueAfterFirstPlayable = true,
    this.fallbackHeadStart = const Duration(seconds: 8),
  }) {
    // Restored results count toward the quality target before any new request
    // is scheduled. A cache hit can therefore resume playback immediately and
    // scan only providers that have not yet produced a reusable result.
    _resolvedResults.addAll(initialResults);
    _completedProviderCount = initialResults.length;
    for (final result in initialResults.values) {
      _recordQualities(result);
    }
    _qualityTargetReached =
        stopAfterStandardQualities &&
        standardQualityHeights.every(_availableHeights.contains);
  }

  static const Set<int> standardQualityHeights = <int>{480, 720, 1080};

  final List<VideoProvider> providers;
  final Future<ProviderLoadResult> Function(VideoProvider provider) load;
  final ProviderResultCallback? onResult;
  final ProviderStartCallback? onStart;
  final MediaIdentity? unifiedMediaIdentity;
  final Map<String, ProviderLoadResult> initialResults;
  final Map<String, ProviderLoadResult> _resolvedResults =
      <String, ProviderLoadResult>{};
  final int maxConcurrency;
  final bool stopAfterStandardQualities;
  final bool continueAfterFirstPlayable;

  /// OpenStream's default search gives direct sources an 8-second head start
  /// before deferred Web Embed fallbacks join the scan. A non-positive value
  /// releases fallbacks immediately.
  final Duration fallbackHeadStart;

  final StreamController<ProviderScanUpdate> _updates =
      StreamController<ProviderScanUpdate>();
  final Completer<ProviderSelection?> _firstPlayable =
      Completer<ProviderSelection?>();
  final Completer<ProviderSelection?> _firstDirectPlayable =
      Completer<ProviderSelection?>();
  ProviderSelection? _firstEmbeddedSelection;
  final Completer<void> _completed = Completer<void>();
  final Set<int> _availableHeights = <int>{};
  late final List<VideoProvider> _primaryProviders = providers
      .where((provider) => !provider.isFallback)
      .toList(growable: false);
  late final List<VideoProvider> _fallbackProviders = providers
      .where((provider) => provider.isFallback)
      .toList(growable: false);
  late final List<VideoProvider> _pendingPrimaryProviders =
      List<VideoProvider>.of(_primaryProviders);
  late final List<VideoProvider> _pendingFallbackProviders =
      List<VideoProvider>.of(_fallbackProviders);
  final Completer<void> _fallbackGate = Completer<void>();
  static const SourceExecutionPolicy _engineExecutionPolicy =
      SourceExecutionPolicy();
  final Map<SourceEngineKind, int> _activeEngineCounts =
      <SourceEngineKind, int>{};
  final Set<Completer<void>> _engineCapacityWaiters = <Completer<void>>{};
  int _activePrimaryCount = 0;
  int _scheduledProviderCount = 0;
  int _completedProviderCount = 0;
  bool _fallbacksReleased = false;
  bool _cancelled = false;
  bool _qualityTargetReached = false;
  bool _stopAfterFirstPlayable = false;
  bool _started = false;

  Stream<ProviderScanUpdate> get updates => _updates.stream;
  Future<ProviderSelection?> get firstPlayable => _firstPlayable.future;

  /// Completes as soon as a direct media URL is found, or with null after all
  /// eligible providers finish. Embedded pages are deliberately excluded.
  Future<ProviderSelection?> get firstDirectPlayable =>
      _firstDirectPlayable.future;
  Future<void> get completed => _completed.future;
  bool get isCompleted => _completed.isCompleted;
  bool get qualityTargetReached => _qualityTargetReached;
  int get scheduledProviderCount => _scheduledProviderCount;
  int get completedProviderCount => _completedProviderCount;
  int get inFlightProviderCount {
    final newlyCompleted = (_completedProviderCount - initialResults.length)
        .clamp(0, _scheduledProviderCount)
        .toInt();
    return (_scheduledProviderCount - newlyCompleted)
        .clamp(0, _scheduledProviderCount)
        .toInt();
  }

  int get totalEligibleProviderCount {
    final queuedCodes = providers
        .where(_isVODEligible)
        .map((provider) => provider.codeName)
        .toSet();
    final alreadyResolvedOutsideQueue = _resolvedResults.keys
        .where((code) => !queuedCodes.contains(code))
        .length;
    return queuedCodes.length + alreadyResolvedOutsideQueue;
  }

  /// Snapshot of every cached or newly resolved provider result. The player
  /// reads this after subscribing so results emitted before its first frame
  /// are not lost when a fast provider completes during route construction.
  Map<String, ProviderLoadResult> get resolvedResults =>
      Map<String, ProviderLoadResult>.unmodifiable(_resolvedResults);

  Set<int> get availableQualityHeights =>
      Set<int>.unmodifiable(_availableHeights);

  /// Adds heights discovered by inspecting an adaptive manifest. This uses
  /// the same stop target as provider responses, but never removes any stream
  /// result already returned by an in-flight provider.
  void reportAdaptiveQualityHeights(Iterable<int> heights) {
    _availableHeights.addAll(heights.where((height) => height > 0));
    if (!stopAfterStandardQualities) return;
    if (standardQualityHeights.every(_availableHeights.contains)) {
      _qualityTargetReached = true;
      if (!_completed.isCompleted) _releaseFallbacks();
    }
  }

  // The selected media type determines which list/query is executed;
  // repository content labels never suppress an installed VOD source.
  // Live TV adapters remain on their dedicated execution pipeline.
  bool _isVODEligible(VideoProvider provider) =>
      unifiedMediaIdentity == null ||
      provider.supportsMedia(unifiedMediaIdentity!);

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_run());
  }

  /// Stops scheduling providers that have not started. In-flight requests are
  /// allowed to finish so a late valid result is not discarded.
  void cancel() {
    _cancelled = true;
    _releaseFallbacks();
    _notifyEngineCapacityWaiters();
  }

  void _releaseFallbacks() {
    if (!_fallbacksReleased) {
      _fallbacksReleased = true;
      if (!_fallbackGate.isCompleted) _fallbackGate.complete();
    }
    _notifyEngineCapacityWaiters();
  }

  Future<_ClaimedProvider?> _takeNextProvider({
    required bool fallbackOnly,
  }) async {
    while (!_cancelled &&
        !_stopAfterFirstPlayable &&
        !(_qualityTargetReached && stopAfterStandardQualities)) {
      if (fallbackOnly && !_fallbacksReleased) {
        await _fallbackGate.future;
        continue;
      }

      final queues = fallbackOnly
          ? <List<VideoProvider>>[_pendingFallbackProviders]
          : <List<VideoProvider>>[
              _pendingPrimaryProviders,
              if (_fallbacksReleased) _pendingFallbackProviders,
            ];

      for (final queue in queues) {
        var index = 0;
        while (index < queue.length) {
          final provider = queue[index];
          if (!_isVODEligible(provider)) {
            queue.removeAt(index);
            continue;
          }

          final isPrimary = identical(queue, _pendingPrimaryProviders);
          final engineKind = _engineKindFor(provider);
          final active = _activeEngineCounts[engineKind] ?? 0;
          final limit = _engineExecutionPolicy.concurrencyFor(engineKind);
          if (active < limit) {
            queue.removeAt(index);
            _activeEngineCounts[engineKind] = active + 1;
            if (isPrimary) _activePrimaryCount++;
            return _ClaimedProvider(
              provider: provider,
              engineKind: engineKind,
              isPrimary: isPrimary,
            );
          }
          index++;
        }
      }

      if (!fallbackOnly &&
          _pendingPrimaryProviders.isEmpty &&
          _activePrimaryCount == 0 &&
          !_fallbacksReleased) {
        _releaseFallbacks();
        continue;
      }
      if (!_fallbacksReleased &&
          _pendingPrimaryProviders.isEmpty &&
          _activePrimaryCount > 0) {
        await _fallbackGate.future;
        continue;
      }

      final hasPending = fallbackOnly
          ? _pendingFallbackProviders.isNotEmpty
          : _pendingPrimaryProviders.isNotEmpty ||
                (_fallbacksReleased && _pendingFallbackProviders.isNotEmpty);
      if (!hasPending) return null;

      final waiter = Completer<void>();
      _engineCapacityWaiters.add(waiter);
      await waiter.future;
    }
    return null;
  }

  SourceEngineKind _engineKindFor(VideoProvider provider) {
    final sourceKind = provider.sourceManifest?.engine.kind;
    if (sourceKind != null) return sourceKind;
    return switch (provider.type) {
      VideoProviderType.directVixSrc => SourceEngineKind.native,
      VideoProviderType.scraperApi => SourceEngineKind.legacyScraperApi,
      VideoProviderType.unifiedSources ||
      VideoProviderType.unifiedSource => SourceEngineKind.native,
    };
  }

  void _releaseEngineSlot(SourceEngineKind kind) {
    final active = _activeEngineCounts[kind] ?? 0;
    if (active <= 1) {
      _activeEngineCounts.remove(kind);
    } else {
      _activeEngineCounts[kind] = active - 1;
    }
    _notifyEngineCapacityWaiters();
  }

  void _notifyEngineCapacityWaiters() {
    if (_engineCapacityWaiters.isEmpty) return;
    final waiters = _engineCapacityWaiters.toList(growable: false);
    _engineCapacityWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  Future<void> _run() async {
    if (_primaryProviders.isEmpty ||
        (_fallbackProviders.isNotEmpty && fallbackHeadStart <= Duration.zero)) {
      _releaseFallbacks();
    }
    final workers = maxConcurrency
        .clamp(1, providers.isEmpty ? 1 : providers.length)
        .toInt();
    final reserveFallbackWorker = _fallbackProviders.isNotEmpty && workers > 1;
    final primaryWorkers = reserveFallbackWorker ? workers - 1 : workers;
    final fallbackTimer =
        fallbackHeadStart <= Duration.zero || _fallbackProviders.isEmpty
        ? null
        : Timer(fallbackHeadStart, _releaseFallbacks);
    final tasks = <Future<void>>[
      for (var index = 0; index < primaryWorkers; index++) _worker(),
      // Reserve one worker inside the configured concurrency budget for
      // deferred fallbacks. With a one-worker scan, the normal worker handles
      // fallbacks after the direct queue completes or the gate opens.
      if (reserveFallbackWorker) _worker(fallbackOnly: true),
    ];
    await Future.wait(tasks);
    // Do not leave a delayed fallback gate alive after the scan has finished.
    fallbackTimer?.cancel();
    _releaseFallbacks();
    if (!_firstDirectPlayable.isCompleted) {
      _firstDirectPlayable.complete(null);
    }
    if (!_firstPlayable.isCompleted) {
      _firstPlayable.complete(_firstEmbeddedSelection);
    }
    final missingHeights =
        standardQualityHeights.difference(_availableHeights).toList()..sort();
    final finishReason = _cancelled
        ? 'cancelled'
        : _qualityTargetReached
        ? 'standard_quality_target_reached'
        : 'all_eligible_providers_exhausted';
    debugPrint(
      '[PlaybackScan][FINISHED] reason=$finishReason '
      'scheduled=$_scheduledProviderCount completed=$_completedProviderCount '
      'totalEligible=$totalEligibleProviderCount '
      'heights=${(_availableHeights.toList()..sort()).join(',')} '
      'missing=${missingHeights.join(',')}',
    );
    // Closing a single-subscription stream can remain pending until a
    // listener subscribes and drains the buffered events. The player may
    // attach after `firstPlayable`, and tests/callers may never listen at
    // all; neither case should hold the scan-completion future open after
    // every provider worker has finished. Keep the close operation in flight
    // so a late single listener can still receive the buffered updates.
    if (!_updates.isClosed) unawaited(_updates.close());
    if (!_completed.isCompleted) _completed.complete();
  }

  Future<void> _worker({bool fallbackOnly = false}) async {
    while (!_cancelled &&
        !_stopAfterFirstPlayable &&
        !(_qualityTargetReached && stopAfterStandardQualities)) {
      final claim = await _takeNextProvider(fallbackOnly: fallbackOnly);
      if (claim == null) return;
      final provider = claim.provider;
      final isPrimary = claim.isPrimary;
      final providerIndex = providers.indexOf(provider);
      _scheduledProviderCount++;
      _emit(
        ProviderScanUpdate.started(index: providerIndex, provider: provider),
      );
      try {
        onStart?.call(providerIndex, provider);
      } catch (_) {
        // UI progress callbacks must not interrupt a source scan.
      }

      try {
        ProviderLoadResult result;
        try {
          result = await load(provider);
        } catch (error) {
          result = ProviderLoadResult(errorMessage: error.toString());
        }

        _completedProviderCount++;
        _resolvedResults[provider.codeName] = result;
        _emit(
          ProviderScanUpdate.completed(
            index: providerIndex,
            provider: provider,
            result: result,
          ),
        );
        try {
          onResult?.call(providerIndex, provider, result);
        } catch (_) {
          // A screen callback must not abort subsequent provider attempts.
        }

        final links = result.videoLinks ?? const <RegularVideoLinks>[];
        final directLinks = links
            .where((link) => !link.isEmbeddedPlayer)
            .toList(growable: false);
        if (result.success && directLinks.isNotEmpty) {
          final directSelection = ProviderSelection(
            index: providerIndex,
            provider: provider,
            result: result,
            scanSession: this,
          );
          if (!_firstDirectPlayable.isCompleted) {
            _firstDirectPlayable.complete(directSelection);
          }
          if (!_firstPlayable.isCompleted) {
            _firstPlayable.complete(directSelection);
          }
          if (!continueAfterFirstPlayable) {
            _stopAfterFirstPlayable = true;
            _releaseFallbacks();
          }
        } else if (result.success &&
            directLinks.isEmpty &&
            links.any((link) => link.isEmbeddedPlayer) &&
            _firstEmbeddedSelection == null) {
          _firstEmbeddedSelection = ProviderSelection(
            index: providerIndex,
            provider: provider,
            result: result,
            scanSession: this,
          );
        }

        _recordQualities(result);
        if (standardQualityHeights.every(_availableHeights.contains)) {
          _qualityTargetReached = true;
          _releaseFallbacks();
        }
      } finally {
        _releaseEngineSlot(claim.engineKind);
        if (isPrimary) {
          _activePrimaryCount--;
          if (_pendingPrimaryProviders.isEmpty && _activePrimaryCount == 0) {
            _releaseFallbacks();
          }
        }
      }
    }
  }

  void _recordQualities(ProviderLoadResult result) {
    if (!result.success) return;
    // Never reduce a provider response to only the three stopping heights.
    // Every link remains in the ProviderLoadResult and is forwarded intact;
    // this set is used exclusively to decide when to stop scheduling more
    // providers, not to filter or discard quality variants.
    for (final link in result.videoLinks ?? const <RegularVideoLinks>[]) {
      if (link.isEmbeddedPlayer) continue;
      final directHeight = _qualityHeight(link.quality ?? '');
      if (directHeight != null) _availableHeights.add(directHeight);
      _availableHeights.addAll(
        link.availableHeights.where((height) => height > 0),
      );
    }
  }

  void _emit(ProviderScanUpdate update) {
    if (!_updates.isClosed) _updates.add(update);
  }

  static int? _qualityHeight(String value) =>
      VideoUtils.videoQualityHeight(value);
}

/// Single loading boundary for direct and API-backed stream providers.
abstract final class ProviderLoader {
  static final UnifiedSourceService _unifiedSourceService =
      UnifiedSourceService();

  /// Installed sources with a registered engine, exposed as individual
  /// providers so progress, picking and recovery use real source identities.
  static Future<List<VideoProvider>> installedSourceProviders({
    MediaIdentity? mediaIdentity,
  }) async {
    final ordered = mediaIdentity == null
        ? null
        : await _unifiedSourceService.orderedInstalledSourcesFor(mediaIdentity);
    final sources = ordered?.sources ??
        await _unifiedSourceService.installedPlayableSources();
    final providers = sources
        .map(
          (source) => VideoProvider.unifiedSource(
            source,
            forcePrimary: ordered?.userSelectedKeys.contains(source.stableKey) ??
                false,
          ),
        )
        .toList(growable: false);
    debugPrint(
      '[PlaybackSources][DISCOVERY] installedRunnable=${providers.length} '
      'media=${mediaIdentity?.normalizedType.name ?? 'unspecified'} '
      'userOrdered=${ordered?.userSelectedKeys.length ?? 0} '
      'providers=${providers.map((provider) => provider.displayName).join(',')}',
    );
    return providers;
  }

  /// Starts a bounded background scan. The first direct stream is returned
  /// immediately; if no direct source appears, the earliest embedded page is
  /// returned only after eligible providers are exhausted. The session then
  /// continues until sources are exhausted or the common quality target is met.
  static ProviderScanSession startScan({
    required List<VideoProvider> providers,
    required Future<ProviderLoadResult> Function(VideoProvider provider) load,
    ProviderResultCallback? onResult,
    ProviderStartCallback? onStart,
    MediaIdentity? unifiedMediaIdentity,
    Map<String, ProviderLoadResult> initialResults =
        const <String, ProviderLoadResult>{},
    int maxConcurrency = 3,
    bool continueAfterFirstPlayable = true,
    Duration fallbackHeadStart = const Duration(seconds: 8),
  }) {
    final session = ProviderScanSession(
      providers: List<VideoProvider>.unmodifiable(providers),
      load: load,
      onResult: onResult,
      onStart: onStart,
      unifiedMediaIdentity: unifiedMediaIdentity,
      initialResults: initialResults,
      maxConcurrency: maxConcurrency,
      continueAfterFirstPlayable: continueAfterFirstPlayable,
      fallbackHeadStart: fallbackHeadStart,
    );
    session.start();
    return session;
  }

  /// Restores previously resolved links without starting a new source search.
  /// The last successful provider/link is preferred, but only if that provider
  /// is still installed and its cached URL has not passed its expiry timestamp.
  static Future<ProviderSelection?> restoreCachedSelection({
    required MediaIdentity identity,
    required List<VideoProvider> providers,
    PlaybackStreamCacheStore? cache,
  }) async {
    final entry = await (cache ?? PlaybackStreamCacheStore()).read(identity);
    if (entry == null) return null;

    VideoProvider? selectedProvider;
    CachedProviderStreams? selectedCached;
    var selectedUrl = entry.lastUrl;
    final preferred = providers.where(
      (provider) => provider.codeName == entry.lastProviderCode,
    );
    if (preferred.isNotEmpty) {
      final candidate = preferred.first;
      final cached = entry.providers[candidate.codeName];
      if (cached != null && candidate.supportsMedia(identity)) {
        selectedProvider = candidate;
        selectedCached = cached;
      }
    }

    if (selectedProvider == null) {
      for (final provider in providers) {
        final cached = entry.providers[provider.codeName];
        if (cached == null || !provider.supportsMedia(identity)) continue;
        selectedProvider = provider;
        selectedCached = cached;
        selectedUrl = cached.videoLinks.first.url ?? '';
        break;
      }
    }
    if (selectedProvider == null || selectedCached == null) return null;
    if (!selectedCached.videoLinks.any((link) => link.url == selectedUrl)) {
      selectedUrl = selectedCached.videoLinks.first.url ?? '';
    }
    if (selectedUrl.isEmpty) return null;

    final cachedResults = <String, ProviderLoadResult>{
      for (final provider in providers)
        if (entry.providers.containsKey(provider.codeName) &&
            provider.supportsMedia(identity))
          provider.codeName: entry.providers[provider.codeName]!.toLoadResult(),
    };
    final selectedIndex = providers.indexOf(selectedProvider);
    return ProviderSelection(
      index: selectedIndex < 0 ? 0 : selectedIndex,
      provider: selectedProvider,
      result: selectedCached.toLoadResult(),
      cachedProviderResults: Map<String, ProviderLoadResult>.unmodifiable(
        cachedResults,
      ),
      selectedUrl: selectedUrl,
      restoredFromCache: true,
    );
  }

  /// Resolves providers in a strict, deterministic queue. Exactly one
  /// provider is started at a time; direct providers, VixSrc and deferred
  /// Web Embed fallbacks all follow the order supplied by the caller.
  /// Repository media labels do not filter providers: every installed VOD
  /// source is attempted in the supplied order. The first result with a
  /// direct media link wins. An embedded HTML page is retained as a fallback
  /// while later providers are checked for a direct stream, then returned if
  /// none exists.
  static Future<ProviderSelection?> loadFirstSuccessful({
    required List<VideoProvider> providers,
    required Future<ProviderLoadResult> Function(VideoProvider provider) load,
    ProviderResultCallback? onResult,
    ProviderStartCallback? onStart,
    MediaIdentity? unifiedMediaIdentity,
  }) async {
    ProviderSelection? firstEmbedded;
    for (var index = 0; index < providers.length; index++) {
      final provider = providers[index];
      if (unifiedMediaIdentity != null &&
          !provider.supportsMedia(unifiedMediaIdentity)) {
        debugPrint(
          '[PlaybackSources][SKIPPED] provider=${provider.displayName} '
          'reason=dedicated-live-tv-adapter',
        );
        continue;
      }
      try {
        onStart?.call(index, provider);
      } catch (_) {
        // UI progress must not interrupt the source queue.
      }

      ProviderLoadResult providerResult;
      try {
        providerResult = await load(provider);
      } catch (error) {
        providerResult = ProviderLoadResult(errorMessage: error.toString());
      }

      try {
        onResult?.call(index, provider, providerResult);
      } catch (_) {
        // One screen callback must not abort subsequent provider attempts.
      }

      final links = providerResult.videoLinks ?? const <RegularVideoLinks>[];
      final directLinks = links
          .where((link) => !link.isEmbeddedPlayer)
          .toList(growable: false);
      if (providerResult.success && directLinks.isNotEmpty) {
        debugPrint(
          '[PlaybackSources][SELECTED] provider=${provider.displayName} '
          'index=$index directLinks=${directLinks.length}',
        );
        return ProviderSelection(
          index: index,
          provider: provider,
          result: providerResult,
        );
      }
      if (providerResult.success &&
          links.any((link) => link.isEmbeddedPlayer) &&
          firstEmbedded == null) {
        firstEmbedded = ProviderSelection(
          index: index,
          provider: provider,
          result: providerResult,
        );
      }
    }
    if (firstEmbedded != null) {
      debugPrint(
        '[PlaybackSources][EMBED_FALLBACK] provider=${firstEmbedded.provider.displayName} '
        'index=${firstEmbedded.index}',
      );
    }
    return firstEmbedded;
  }

  static Future<ProviderLoaderResult> loadMovieFromProvider({
    required VideoProvider provider,
    required int movieId,
    required String scraperApiUrl,
    bool full = false,
    MediaIdentity? mediaIdentity,
  }) {
    switch (provider.type) {
      case VideoProviderType.unifiedSources:
        if (mediaIdentity == null) {
          return Future.value(
            const ProviderLoadResult(
              errorMessage: 'Unified source identity is missing.',
            ),
          );
        }
        return _loadUnified(mediaIdentity);
      case VideoProviderType.unifiedSource:
        final source = provider.sourceManifest;
        if (mediaIdentity == null || source == null) {
          return Future.value(
            const ProviderLoadResult(
              errorMessage: 'Installed source metadata is missing.',
            ),
          );
        }
        return _loadUnified(mediaIdentity, onlySource: source);
      case VideoProviderType.directVixSrc:
        return VixSrc.loadMovie(movieId);
      case VideoProviderType.scraperApi:
        final providerId = provider.apiId;
        if (providerId == null || providerId.isEmpty) {
          return Future.value(
            const ProviderLoadResult(errorMessage: 'Provider ID is missing'),
          );
        }
        return ScraperApi(
          scraperApiUrl,
        ).loadMovie(providerId: providerId, movieId: movieId, full: full);
    }
  }

  static Future<ProviderLoaderResult> loadTVFromProvider({
    required VideoProvider provider,
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
    required String scraperApiUrl,
    bool full = false,
    MediaIdentity? mediaIdentity,
  }) {
    switch (provider.type) {
      case VideoProviderType.unifiedSources:
        if (mediaIdentity == null) {
          return Future.value(
            const ProviderLoadResult(
              errorMessage: 'Unified source identity is missing.',
            ),
          );
        }
        return _loadUnified(mediaIdentity);
      case VideoProviderType.unifiedSource:
        final source = provider.sourceManifest;
        if (mediaIdentity == null || source == null) {
          return Future.value(
            const ProviderLoadResult(
              errorMessage: 'Installed source metadata is missing.',
            ),
          );
        }
        return _loadUnified(mediaIdentity, onlySource: source);
      case VideoProviderType.directVixSrc:
        return VixSrc.loadEpisode(
          tvId: tvId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
        );
      case VideoProviderType.scraperApi:
        final providerId = provider.apiId;
        if (providerId == null || providerId.isEmpty) {
          return Future.value(
            const ProviderLoadResult(errorMessage: 'Provider ID is missing'),
          );
        }
        return ScraperApi(scraperApiUrl).loadTVEpisode(
          providerId: providerId,
          tvId: tvId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
          full: full,
        );
    }
  }

  static Future<ProviderLoadResult> _loadUnified(
    MediaIdentity identity, {
    SourceManifest? onlySource,
  }) async {
    try {
      final preferredAudioLanguage = await SettingsPreferences()
          .getPreferredVidkingAudioLanguage();
      final result = await _unifiedSourceService.search(
        media: identity,
        onlySource: onlySource,
        preferredAudioLanguage: preferredAudioLanguage.isEmpty
            ? null
            : preferredAudioLanguage,
      );
      final converted = result.toProviderLoadResult();
      debugPrint(
        '[UnifiedSources][SEARCH] source=${onlySource?.name ?? 'all'} '
        'media=${identity.normalizedType.name} '
        'tmdbId=${identity.tmdbId} repositories=${result.repositorySnapshot.repositories.length} '
        'catalog=${result.repositorySnapshot.catalog.length} '
        'installedEnabled=${result.repositorySnapshot.sources.length} '
        'repositoryErrors=${result.repositorySnapshot.errors.length} '
        'attempts=${result.attempts.length} '
        'successfulSources=${result.successfulSourceCount} '
        'playableStreams=${result.streams.where((stream) => stream.isPlayable && !stream.isExpired).length} '
        'playerLinks=${converted.videoLinks?.length ?? 0} '
        'subtitles=${converted.subtitleLinks?.length ?? 0} '
        'success=${converted.success}',
      );
      for (final attempt in result.attempts) {
        debugPrint(
          '[UnifiedSources][ATTEMPT] source=${attempt.source.name} '
          'engine=${attempt.source.engine.kind.name} '
          'success=${attempt.result.success} '
          'streams=${attempt.result.streams.length} '
          'elapsedMs=${attempt.result.elapsed?.inMilliseconds ?? -1} '
          'error=${sanitizeDiagnosticError(attempt.result.errorMessage)}',
        );
      }
      return converted;
    } catch (error) {
      debugPrint(
        '[UnifiedSources][SEARCH_FAILED] ${error.runtimeType}: ${sanitizeDiagnosticError(error.toString())}',
      );
      return ProviderLoadResult(errorMessage: error.toString());
    }
  }

  /// Legacy diagnostic helper retained for older logs/tests. It is no longer
  /// used to skip a provider: declared media labels do not restrict attempts.
  static bool isAnimeOnlyMismatch(String? error) {
    final value = error?.toLowerCase() ?? '';
    return value.contains('declares type "anime"') ||
        value.contains('declares type "anime-only"') ||
        value.contains('declares type "anime_only"') ||
        value.contains('declares type "donghua"');
  }

  static String sanitizeDiagnosticError(String? message) {
    if (message == null || message.trim().isEmpty) return 'none';
    // Keep the actionable status/message while avoiding large response bodies
    // or accidentally printing seed/token query parameters into CI logs.
    final safe = message
        .replaceAll(RegExp(r'https?://[^\s]+'), '[url]')
        .replaceAll(
          RegExp(
            r'(seed|token|key|api[_-]?key)=([^&\s]+)',
            caseSensitive: false,
          ),
          r'$1=[redacted]',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return safe.length > 220 ? '${safe.substring(0, 220)}…' : safe;
  }

  /// Transitional movie adapter: callers can adopt the normalized source
  /// contract without changing the existing BetterPlayer screens yet.
  static Future<UnifiedSourceResult> loadMovieUnified({
    required VideoProvider provider,
    required int movieId,
    required String scraperApiUrl,
    required String providerName,
    bool full = false,
  }) async {
    final legacy = await loadMovieFromProvider(
      provider: provider,
      movieId: movieId,
      scraperApiUrl: scraperApiUrl,
      full: full,
    );
    return legacy.toUnifiedSourceResult(
      providerId: provider.codeName,
      providerName: providerName,
    );
  }

  /// Transitional episode adapter matching [loadMovieUnified].
  static Future<UnifiedSourceResult> loadTVUnified({
    required VideoProvider provider,
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
    required String scraperApiUrl,
    required String providerName,
    bool full = false,
  }) async {
    final legacy = await loadTVFromProvider(
      provider: provider,
      tvId: tvId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      scraperApiUrl: scraperApiUrl,
      full: full,
    );
    return legacy.toUnifiedSourceResult(
      providerId: provider.codeName,
      providerName: providerName,
    );
  }

  /// Builds the source identity used by the new engine from the IDs currently
  /// available in the movie and TV flows. External IDs can be added later by
  /// enriching the catalogue detail model without changing source contracts.
  static MediaIdentity movieIdentity({
    required int tmdbId,
    required String title,
    int? year,
    String? originalTitle,
    Map<String, String> externalIds = const <String, String>{},
    bool isAnime = false,
    MediaContentClassification classification =
        MediaContentClassification.general,
  }) => MediaIdentity(
    type: UnifiedMediaType.movie,
    tmdbId: tmdbId,
    title: title,
    originalTitle: originalTitle,
    year: year,
    externalIds: externalIds,
    isAnimeContent: isAnime,
    contentClassification:
        isAnime && classification == MediaContentClassification.general
        ? MediaContentClassification.anime
        : classification,
  );

  static MediaIdentity episodeIdentity({
    required int tmdbId,
    required String title,
    required int seasonNumber,
    required int episodeNumber,
    int? year,
    String? originalTitle,
    int? episodeTmdbId,
    String? episodeAirDate,
    Map<String, String> externalIds = const <String, String>{},
    bool isAnime = false,
    MediaContentClassification classification =
        MediaContentClassification.general,
  }) => MediaIdentity(
    // Anime and Donghua are classifications of episodic TV content; they
    // must use the existing series/season/episode execution path.
    type: UnifiedMediaType.series,
    tmdbId: tmdbId,
    title: title,
    originalTitle: originalTitle,
    year: year,
    seasonNumber: seasonNumber,
    episodeNumber: episodeNumber,
    episodeTmdbId: episodeTmdbId,
    episodeAirDate: episodeAirDate,
    externalIds: externalIds,
    isAnimeContent: isAnime,
    contentClassification:
        isAnime && classification == MediaContentClassification.general
        ? MediaContentClassification.anime
        : classification,
  );
}
