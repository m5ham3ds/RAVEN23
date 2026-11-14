import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'media_identity.dart';
import 'media_identity_resolver.dart';
import 'source_contracts.dart';
import 'source_engine.dart';
import 'source_execution_policy.dart';
import 'source_manifest.dart';
import 'source_priority_manager.dart';
import 'source_priority_policy.dart';
import 'source_repository_manager.dart';
import 'source_repository_revision.dart';
import 'stream_option.dart';

class UnifiedSourceSearchResult {
  const UnifiedSourceSearchResult({
    required this.repositorySnapshot,
    required this.attempts,
    required this.streams,
  });

  final SourceRepositorySyncResult repositorySnapshot;
  final List<UnifiedSourceAttempt> attempts;
  final List<UnifiedStreamOption> streams;

  int get successfulSourceCount =>
      attempts.where((attempt) => attempt.result.success).length;
}

/// Installed VOD sources in the actual playback order for one media type.
/// [userSelectedKeys] contains both user-managed lanes; those entries override
/// upstream fallback labels so the player's scan queue preserves their order.
class OrderedInstalledSourceSet {
  OrderedInstalledSourceSet({
    required Iterable<SourceManifest> sources,
    required Iterable<String> userSelectedKeys,
  }) : sources = List<SourceManifest>.unmodifiable(sources),
       userSelectedKeys = Set<String>.unmodifiable(userSelectedKeys);

  final List<SourceManifest> sources;
  final Set<String> userSelectedKeys;
}

/// Called as soon as the first source returns at least one playable stream.
/// The rest of the bounded scan continues unless the caller cancels it.
typedef SourceFirstPlayableCallback =
    void Function(UnifiedSourceAttempt attempt);

/// Application-facing facade for repository management and unified stream
/// lookup. Movie and episode loaders use this service behind the existing
/// player adapter, keeping engine-specific details out of the UI.
class UnifiedSourceService {
  UnifiedSourceService({
    SourceRepositoryManager? repositories,
    SourceEngineRegistry? engines,
    MediaIdentityResolver? identityResolver,
    SourceExecutionPolicy executionPolicy = const SourceExecutionPolicy(),
    SourceExecutionStateStore? executionStateStore,
    SourceCircuitBreaker? circuitBreaker,
    SourcePriorityManager? priorityManager,
    DateTime Function()? clock,
  }) : _repositories = repositories ?? SourceRepositoryManager(),
       _engines = engines ?? SourceEngineRegistry.standard(),
       _identityResolver = identityResolver ?? MediaIdentityResolver(),
       _executionPolicy = executionPolicy,
       _executionStateStore =
           executionStateStore ?? SourceExecutionStateStore(),
       _priorityManager = priorityManager ?? SourcePriorityManager(),
       _clock = clock ?? DateTime.now,
       _circuitBreaker =
           circuitBreaker ??
           SourceCircuitBreaker(
             failureThreshold: executionPolicy.circuitFailureThreshold,
             cooldown: executionPolicy.circuitCooldown,
             clock: clock,
           );

  final SourceRepositoryManager _repositories;
  final SourceEngineRegistry _engines;
  final MediaIdentityResolver _identityResolver;
  final SourceExecutionPolicy _executionPolicy;
  final SourceExecutionStateStore _executionStateStore;
  final SourcePriorityManager _priorityManager;
  final SourceCircuitBreaker _circuitBreaker;
  final DateTime Function() _clock;
  final Map<SourceEngineKind, SourceExecutionSemaphore> _engineSemaphores =
      <SourceEngineKind, SourceExecutionSemaphore>{};
  final Map<String, _CachedSourceResult> _sourceResultCache =
      <String, _CachedSourceResult>{};
  final List<SourceExecutionMetric> _metrics = <SourceExecutionMetric>[];

  /// Bounded, privacy-safe in-memory diagnostics. Stream URLs, headers,
  /// tokens, titles and request query strings are never recorded here.
  List<SourceExecutionMetric> get recentExecutionMetrics =>
      List<SourceExecutionMetric>.unmodifiable(_metrics);

  bool supportsSource(SourceManifest source) => _engines.supports(source);

  /// Returns installed sources with a registered runtime. Unsupported
  /// manifest types stay visible in repository management, but are not
  /// advertised as playable providers.
  Future<List<SourceManifest>> installedPlayableSources() async {
    final snapshot = await _repositories.sync();
    final sources =
        snapshot.sources.where((source) => _engines.supports(source)).toList()
          ..sort(_compareRankedSources);
    return sources;
  }

  /// Orders installed providers by the selected media's editable source lists.
  /// The order is: primary, backup, remaining direct providers, then remaining
  /// embedded/fallback providers. Repository media tags never filter this set.
  Future<OrderedInstalledSourceSet> orderedInstalledSourcesFor(
    MediaIdentity media,
  ) async {
    var snapshot = await _repositories.sync();
    // Also run the lightweight migration when v1 priorities are already
    // initialized: an existing installation may not yet have the new backup
    // keys. `seedBackupKeysIfMissing` never overwrites user-edited lanes.
    final configured = await configureRecommendedSources(snapshot);
    if (configured) {
      snapshot = await _repositories.sync(forceRefresh: false);
    }

    final category = _priorityCategoryFor(media);
    final candidates = snapshot.sources
        .where(
          (source) => SourcePriorityPolicy.isEligible(
            source,
            category,
            supportsRuntime: _engines.supports,
          ),
        )
        .toList(growable: false);
    final byKey = <String, SourceManifest>{
      for (final source in candidates) source.stableKey: source,
    };
    final primaryKeys = await _priorityManager.getKeys(
      category,
      SourcePriorityLane.primary,
    );
    final backupKeys = await _priorityManager.getKeys(
      category,
      SourcePriorityLane.backup,
    );
    final primary = <SourceManifest>[
      for (final key in primaryKeys)
        if (byKey.containsKey(key)) byKey[key]!,
    ];
    final backup = <SourceManifest>[
      for (final key in backupKeys)
        if (byKey.containsKey(key)) byKey[key]!,
    ];
    final selectedKeys = <String>{
      ...primary.map((source) => source.stableKey),
      ...backup.map((source) => source.stableKey),
    };
    final remaining = candidates
        .where((source) => !selectedKeys.contains(source.stableKey))
        .toList();
    final lastWorkingHash = await _executionStateStore
        .readLastWorkingSourceHash(_playbackIdentity(media));
    remaining.sort((left, right) {
      if (left.isFallback != right.isFallback) {
        return left.isFallback ? 1 : -1;
      }
      final byDeclaredStatus = SourcePriorityPolicy.backupStatusRank(
        left,
      ).compareTo(SourcePriorityPolicy.backupStatusRank(right));
      if (byDeclaredStatus != 0) return byDeclaredStatus;
      if (lastWorkingHash != null) {
        final leftWasLastWorking =
            _executionStateStore.sourceDigest(left.stableKey) ==
            lastWorkingHash;
        final rightWasLastWorking =
            _executionStateStore.sourceDigest(right.stableKey) ==
            lastWorkingHash;
        if (leftWasLastWorking != rightWasLastWorking) {
          return leftWasLastWorking ? -1 : 1;
        }
      }
      return _compareRankedSources(left, right);
    });

    return OrderedInstalledSourceSet(
      sources: <SourceManifest>[...primary, ...backup, ...remaining],
      userSelectedKeys: selectedKeys,
    );
  }

  Future<void> addRepository(String url) => _repositories.addRepository(url);

  Future<int> addDefaultRepositories() =>
      _repositories.addDefaultRepositories();

  Future<void> removeRepository(String url) async {
    await _repositories.removeRepository(url);
    await _priorityManager.removeRepositorySources(url);
  }

  Future<List<SourceRepositoryRevision>> repositoryRevisions(String url) =>
      _repositories.repositoryRevisions(url);

  Future<String?> pinnedRepositoryCommit(String url) =>
      _repositories.pinnedCommit(url);

  Future<void> pinRepositoryToCommit(String url, String commitHash) =>
      _repositories.pinRepositoryToCommit(url, commitHash);

  Future<void> clearRepositoryPin(String url) =>
      _repositories.clearRepositoryPin(url);

  Future<RepositoryUpdatePreview> previewRepositoryUpdate(String url) =>
      _repositories.previewRepositoryUpdate(url);

  Future<SourceRepositorySyncResult> applyPreviewedRepositoryUpdate(
    RepositoryUpdatePreview preview,
  ) => _repositories.applyPreviewedRepositoryUpdate(preview);

  Future<SourceRepositoryRevision?> rollbackRepository(String url) =>
      _repositories.rollbackRepository(url);

  Future<void> resumeRepositoryUpdates(String url) =>
      _repositories.resumeRepositoryUpdates(url);

  Future<List<SourceDuplicateCandidate>> findPotentialDuplicates(
    Iterable<SourceManifest> sources,
  ) => _repositories.findPotentialDuplicates(sources);

  Future<SourceProvenance> provenanceOf(SourceManifest source) =>
      _repositories.provenanceOf(source);

  Future<void> installSource(SourceManifest source) =>
      _repositories.installSource(source);

  Future<void> uninstallSource(SourceManifest source) =>
      _repositories.uninstallSource(source);

  Future<List<String>> repositoryUrls() => _repositories.repositoryUrls();

  Future<Set<String>> installedSourceKeys() =>
      _repositories.installedSourceKeys();

  Future<Set<String>> disabledDefaultSourceKeys() =>
      _repositories.disabledDefaultSourceKeys();

  Future<List<String>> priorityKeys(SourcePriorityCategory category) =>
      _priorityManager.getPriorityKeys(category);

  Future<List<String>> backupKeys(SourcePriorityCategory category) =>
      _priorityManager.getBackupKeys(category);

  Future<void> removePrioritySource(
    SourcePriorityCategory category,
    SourceManifest source, {
    SourcePriorityLane lane = SourcePriorityLane.primary,
  }) => _priorityManager.removeKey(category, lane, source.stableKey);

  Future<void> reorderPrioritySource(
    SourcePriorityCategory category, {
    SourcePriorityLane lane = SourcePriorityLane.primary,
    required int oldIndex,
    required int newIndex,
  }) => _priorityManager.reorderKey(
    category,
    lane,
    oldIndex: oldIndex,
    newIndex: newIndex,
  );

  Future<bool> swapPrioritySources(
    SourcePriorityCategory category, {
    required SourceManifest current,
    required SourceManifest replacement,
  }) => _priorityManager.swapKeys(
    category,
    firstKey: current.stableKey,
    secondKey: replacement.stableKey,
  );

  Future<bool> addPrioritySource(
    SourcePriorityCategory category,
    SourceManifest source, {
    SourcePriorityLane lane = SourcePriorityLane.primary,
  }) async {
    // The user may organize any catalog entry in either lane, independent of
    // declared media type or rating. Runtime/safety gates still determine
    // whether the engine can actually execute it during a playback attempt.
    final added = await _priorityManager.addKey(
      category,
      lane,
      source.stableKey,
    );
    if (!added) return false;
    try {
      await _repositories.installSource(source);
      return true;
    } catch (_) {
      await _priorityManager.removeKey(category, lane, source.stableKey);
      rethrow;
    }
  }

  /// Applies the audited first-run selection once. Later refreshes never
  /// overwrite user ordering or manually edited priority lists.
  Future<bool> configureRecommendedSources(
    SourceRepositorySyncResult snapshot,
  ) async {
    if (await _priorityManager.isInitialized) {
      if (snapshot.catalog.isEmpty || snapshot.errors.isNotEmpty) return false;
      var migratedBackupLists = false;
      for (final category in SourcePriorityCategory.values) {
        final primary = await _priorityManager.getPriorityKeys(category);
        final legacyBackups = snapshot.sources
            .where(
              (source) =>
                  !primary.contains(source.stableKey) &&
                  !source.requiresLiveTvAdapter,
            )
            .map((source) => source.stableKey);
        migratedBackupLists =
            await _priorityManager.seedBackupKeysIfMissing(
              category,
              legacyBackups,
            ) ||
            migratedBackupLists;
      }
      return migratedBackupLists;
    }
    // Avoid locking in a partial first-run selection when one or more of the
    // six bundled indexes failed to refresh. A later retry can complete it.
    if (snapshot.catalog.isEmpty || snapshot.errors.isNotEmpty) return false;
    final automatic = SourcePriorityPolicy.autoActivationSet(
      snapshot.catalog,
      supportsRuntime: _engines.supports,
    );
    final installed = await _repositories.installedSourceKeys();
    final disabledDefaults = await _repositories.disabledDefaultSourceKeys();
    for (final source in automatic) {
      if (source.installedByDefault &&
          disabledDefaults.contains(source.stableKey)) {
        continue;
      }
      if (!installed.contains(source.stableKey) && !source.installedByDefault) {
        await _repositories.installSource(source);
      }
    }

    final currentInstalled = await _repositories.installedSourceKeys();
    final activeCatalogSources = snapshot.catalog
        .where((source) {
          return currentInstalled.contains(source.stableKey) ||
              (source.installedByDefault &&
                  !disabledDefaults.contains(source.stableKey));
        })
        .toList(growable: false);
    for (final category in SourcePriorityCategory.values) {
      final preferred =
          SourcePriorityPolicy.recommended(
                category,
                snapshot.catalog,
                supportsRuntime: _engines.supports,
              )
              .where((source) {
                return currentInstalled.contains(source.stableKey) ||
                    (source.installedByDefault &&
                        !disabledDefaults.contains(source.stableKey));
              })
              .map((source) => source.stableKey);
      final preferredKeys = preferred.toList(growable: false);
      await _priorityManager.setPriorityKeys(category, preferredKeys);
      final backupKeys = activeCatalogSources
          .where(
            (source) =>
                !preferredKeys.contains(source.stableKey) &&
                !source.requiresLiveTvAdapter,
          )
          .map((source) => source.stableKey);
      await _priorityManager.seedBackupKeysIfMissing(category, backupKeys);
    }
    await _priorityManager.markInitialized();
    return true;
  }

  Future<bool> hasConfiguredPriorities() => _priorityManager.isInitialized;

  Future<SourceRepositorySyncResult> refreshRepositories({
    bool forceRefresh = true,
  }) => _repositories.sync(forceRefresh: forceRefresh);

  Future<String> exportConfiguration() => _repositories.exportConfiguration();

  Future<void> importConfiguration(String raw) =>
      _repositories.importConfiguration(raw);

  /// Resolves sources through category-specific priority, direct-backup and
  /// embedded tiers when the priority manager is configured. Otherwise the
  /// legacy bounded-concurrency scan is used. Legacy primary sources receive
  /// an eight-second head start; one worker is reserved for deferred fallbacks.
  /// [onFirstPlayable] fires on the first direct media result without waiting
  /// for the remainder of the source scan. Embedded-page handoffs do not stop
  /// the scan. Returned attempts remain in stable
  /// priority order, independent of network completion order.
  Future<UnifiedSourceSearchResult> search({
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
    SourceAttemptCallback? onAttempt,
    SourceEngineStartCallback? onSourceStart,
    SourceFirstPlayableCallback? onFirstPlayable,
    SourceRepositorySyncResult? repositorySnapshot,
    SourceManifest? onlySource,
    Iterable<SourceManifest>? onlySources,
    bool preserveCandidateOrder = false,
  }) async {
    if (onlySource != null && onlySources != null) {
      throw ArgumentError('Use either onlySource or onlySources, not both.');
    }
    final hasExplicitSnapshot = repositorySnapshot != null;
    var snapshot = repositorySnapshot ?? await _repositories.sync();
    if (cancelToken?.isCancelled == true) {
      return UnifiedSourceSearchResult(
        repositorySnapshot: snapshot,
        attempts: const <UnifiedSourceAttempt>[],
        streams: const <UnifiedStreamOption>[],
      );
    }

    if (onlySource == null && onlySources == null) {
      final configured = await configureRecommendedSources(snapshot);
      // A supplied snapshot is an immutable view selected by the caller for
      // this search. First-run configuration may persist defaults, but it
      // must not replace that view with a second sync that can be empty/stale.
      if (configured && !hasExplicitSnapshot) {
        snapshot = await _repositories.sync(forceRefresh: false);
      }
    }

    final orderedOnlySources = onlySources?.toList(growable: false);
    final selectedKeys = orderedOnlySources
        ?.map((source) => source.stableKey)
        .toSet();
    final candidates = snapshot.sources.where((source) {
      if (onlySource != null && source.stableKey != onlySource.stableKey) {
        return false;
      }
      if (selectedKeys != null && !selectedKeys.contains(source.stableKey)) {
        return false;
      }
      final category = _priorityCategoryFor(media);
      if (!SourcePriorityPolicy.isEligible(
        source,
        category,
        supportsRuntime: _engines.supports,
      )) {
        return false;
      }
      return true;
    }).toList();
    if (preserveCandidateOrder && orderedOnlySources != null) {
      final order = <String, int>{
        for (var index = 0; index < orderedOnlySources.length; index++)
          orderedOnlySources[index].stableKey: index,
      };
      candidates.sort(
        (left, right) => (order[left.stableKey] ?? 1 << 30).compareTo(
          order[right.stableKey] ?? 1 << 30,
        ),
      );
    } else {
      candidates.sort(_compareRankedSources);
    }

    if (candidates.isEmpty) {
      return UnifiedSourceSearchResult(
        repositorySnapshot: snapshot,
        attempts: const <UnifiedSourceAttempt>[],
        streams: const <UnifiedStreamOption>[],
      );
    }

    // Run the user's primary list first, then their backup list, then every
    // other eligible source. Engine kind and declared media tags never reorder
    // or exclude a source that the user deliberately selected.
    if (onlySource == null && onlySources == null) {
      final category = _priorityCategoryFor(media);
      final prioritiesConfigured = await _priorityManager.isInitialized;
      if (prioritiesConfigured) {
        final primaryKeys = await _priorityManager.getKeys(
          category,
          SourcePriorityLane.primary,
        );
        final backupKeys = await _priorityManager.getKeys(
          category,
          SourcePriorityLane.backup,
        );
        final byKey = <String, SourceManifest>{
          for (final source in candidates) source.stableKey: source,
        };
        final prioritized = <SourceManifest>[
          for (final key in primaryKeys)
            if (byKey.containsKey(key)) byKey[key]!,
        ];
        final primarySet = prioritized
            .map((source) => source.stableKey)
            .toSet();
        final selectedBackup = <SourceManifest>[
          for (final key in backupKeys)
            if (byKey.containsKey(key)) byKey[key]!,
        ];
        final manualKeys = <String>{
          ...primarySet,
          ...selectedBackup.map((source) => source.stableKey),
        };

        final remaining = candidates
            .where((source) => !manualKeys.contains(source.stableKey))
            .toList();
        final lastWorkingHash = await _executionStateStore
            .readLastWorkingSourceHash(_playbackIdentity(media));
        remaining.sort((left, right) {
          if (left.isFallback != right.isFallback) {
            return left.isFallback ? 1 : -1;
          }
          final byDeclaredStatus = SourcePriorityPolicy.backupStatusRank(
            left,
          ).compareTo(SourcePriorityPolicy.backupStatusRank(right));
          if (byDeclaredStatus != 0) return byDeclaredStatus;
          if (lastWorkingHash != null) {
            final leftWasLastWorking =
                _executionStateStore.sourceDigest(left.stableKey) ==
                lastWorkingHash;
            final rightWasLastWorking =
                _executionStateStore.sourceDigest(right.stableKey) ==
                lastWorkingHash;
            if (leftWasLastWorking != rightWasLastWorking) {
              return leftWasLastWorking ? -1 : 1;
            }
          }
          return _compareRankedSources(left, right);
        });

        return _searchPriorityTiers(
          media: media,
          snapshot: snapshot,
          preferredAudioLanguage: preferredAudioLanguage,
          cancelToken: cancelToken,
          onAttempt: onAttempt,
          onSourceStart: onSourceStart,
          onFirstPlayable: onFirstPlayable,
          prioritized: prioritized,
          backupDirect: selectedBackup,
          embedded: remaining,
        );
      }
    }

    final lastWorkingHash = preserveCandidateOrder
        ? null
        : await _executionStateStore.readLastWorkingSourceHash(
            _playbackIdentity(media),
          );
    if (lastWorkingHash != null) {
      final preferredIndex = candidates.indexWhere(
        (source) =>
            _executionStateStore.sourceDigest(source.stableKey) ==
            lastWorkingHash,
      );
      if (preferredIndex > 0) {
        final preferred = candidates.removeAt(preferredIndex);
        candidates.insert(0, preferred);
      }
    }

    final preserveManualOrder =
        preserveCandidateOrder && orderedOnlySources != null;
    final primary = preserveManualOrder
        ? candidates
        : candidates.where((source) => !source.isFallback).toList();
    final fallback = preserveManualOrder
        ? <SourceManifest>[]
        : candidates.where((source) => source.isFallback).toList();
    final attempts = List<UnifiedSourceAttempt?>.filled(
      candidates.length,
      null,
    );
    final candidateIndexes = <String, int>{
      for (var i = 0; i < candidates.length; i++) candidates[i].stableKey: i,
    };
    final primaryIndexes = <int>[
      for (final source in primary) candidateIndexes[source.stableKey]!,
    ];
    final fallbackIndexes = <int>[
      for (final source in fallback) candidateIndexes[source.stableKey]!,
    ];

    var firstPlayableDelivered = false;
    Future<MediaIdentity>? imdbIdentityFuture;

    Future<MediaIdentity> identityFor(SourceManifest source) {
      if (!_needsImdbId(source, media.stremioType) || media.imdbId != null) {
        return Future<MediaIdentity>.value(media);
      }
      imdbIdentityFuture ??= _identityResolver
          .enrich(media)
          .timeout(const Duration(seconds: 8), onTimeout: () => media)
          .catchError((Object _) => media);
      return imdbIdentityFuture!;
    }

    final pendingPrimaryIndexes = List<int>.of(primaryIndexes);
    final pendingFallbackIndexes = List<int>.of(fallbackIndexes);
    final activeByEngine = <SourceEngineKind, int>{};
    final capacityWaiters = <Completer<void>>{};

    Future<int?> claimNext(List<int> queue) async {
      while (cancelToken?.isCancelled != true) {
        for (var cursor = 0; cursor < queue.length; cursor++) {
          final index = queue[cursor];
          final kind = candidates[index].engine.kind;
          final active = activeByEngine[kind] ?? 0;
          if (active < _executionPolicy.concurrencyFor(kind)) {
            queue.removeAt(cursor);
            activeByEngine[kind] = active + 1;
            return index;
          }
        }
        if (queue.isEmpty) return null;
        final waiter = Completer<void>();
        capacityWaiters.add(waiter);
        await waiter.future;
      }
      return null;
    }

    void releaseEngineSlot(SourceEngineKind kind) {
      final active = activeByEngine[kind] ?? 0;
      if (active <= 1) {
        activeByEngine.remove(kind);
      } else {
        activeByEngine[kind] = active - 1;
      }
      if (capacityWaiters.isEmpty) return;
      final waiters = capacityWaiters.toList(growable: false);
      capacityWaiters.clear();
      for (final waiter in waiters) {
        if (!waiter.isCompleted) waiter.complete();
      }
    }

    Future<void> executeIndex(int index) async {
      final source = candidates[index];
      try {
        if (cancelToken?.isCancelled == true) return;
        try {
          onSourceStart?.call(source);
        } catch (_) {
          // Progress reporting must not interrupt source dispatch.
        }

        final attempt = await _resolveCandidate(
          source: source,
          media: await identityFor(source),
          preferredAudioLanguage: preferredAudioLanguage,
          cancelToken: cancelToken,
        );
        if (cancelToken?.isCancelled == true) return;
        attempts[index] = attempt;

        if (attempt.result.streams.isNotEmpty && !firstPlayableDelivered) {
          firstPlayableDelivered = true;
          try {
            onFirstPlayable?.call(attempt);
          } catch (_) {
            // Playback presentation is independent from ongoing source work.
          }
        }
        try {
          onAttempt?.call(attempt);
        } catch (_) {
          // A UI callback must not abort other source resolutions.
        }
      } finally {
        releaseEngineSlot(source.engine.kind);
      }
    }

    final primaryDone = Completer<void>();
    final concurrency = _executionPolicy.maxConcurrentSources
        .clamp(1, 8)
        .toInt();
    final hasFallbacks = pendingFallbackIndexes.isNotEmpty;
    final primaryWorkerCount = !hasFallbacks
        ? concurrency
        : pendingPrimaryIndexes.isEmpty
        ? 0
        : concurrency > 1
        ? concurrency - 1
        : 1;
    final fallbackWorkerCount = !hasFallbacks
        ? 0
        : pendingPrimaryIndexes.isEmpty
        ? concurrency
        : concurrency > 1
        ? 1
        : 0;

    Future<void> primaryWorker() async {
      while (cancelToken?.isCancelled != true) {
        final index = await claimNext(pendingPrimaryIndexes);
        if (index == null) return;
        await executeIndex(index);
      }
    }

    Future<void> fallbackWorker() async {
      if (pendingPrimaryIndexes.isNotEmpty) {
        await Future.any<void>(<Future<void>>[
          primaryDone.future,
          Future<void>.delayed(_executionPolicy.fallbackHeadStart),
        ]);
      }
      while (cancelToken?.isCancelled != true) {
        final index = await claimNext(pendingFallbackIndexes);
        if (index == null) return;
        await executeIndex(index);
      }
    }

    final primaryTasks = List<Future<void>>.generate(
      primaryWorkerCount == 0
          ? 0
          : primaryWorkerCount.clamp(1, pendingPrimaryIndexes.length).toInt(),
      (_) => primaryWorker(),
    );
    final primaryTask = Future.wait(primaryTasks).then((_) {
      if (!primaryDone.isCompleted) primaryDone.complete();
    });

    final fallbackTasks = <Future<void>>[];
    if (fallbackWorkerCount > 0) {
      fallbackTasks.addAll(
        List<Future<void>>.generate(
          fallbackWorkerCount,
          (_) => fallbackWorker(),
        ),
      );
    } else if (hasFallbacks && concurrency == 1) {
      fallbackTasks.add(
        primaryTask.then((_) async {
          while (cancelToken?.isCancelled != true) {
            final index = await claimNext(pendingFallbackIndexes);
            if (index == null) return;
            await executeIndex(index);
          }
        }),
      );
    }

    await Future.wait(<Future<void>>[primaryTask, ...fallbackTasks]);

    // Convert each completed result in source order. Cancelled, never-started
    // jobs are intentionally absent rather than being misreported as failures.
    final completedAttempts = attempts
        .whereType<UnifiedSourceAttempt>()
        .toList();
    final streams = <UnifiedStreamOption>[];
    final seen = <String>{};
    for (final attempt in completedAttempts) {
      for (final stream in attempt.result.streams) {
        if (_isDistinctStream(stream, seen)) streams.add(stream);
      }
    }

    return UnifiedSourceSearchResult(
      repositorySnapshot: snapshot,
      attempts: List<UnifiedSourceAttempt>.unmodifiable(completedAttempts),
      streams: List<UnifiedStreamOption>.unmodifiable(streams),
    );
  }

  Future<UnifiedSourceSearchResult> _searchPriorityTiers({
    required MediaIdentity media,
    required SourceRepositorySyncResult snapshot,
    required String? preferredAudioLanguage,
    required CancelToken? cancelToken,
    required SourceAttemptCallback? onAttempt,
    required SourceEngineStartCallback? onSourceStart,
    required SourceFirstPlayableCallback? onFirstPlayable,
    required List<SourceManifest> prioritized,
    required List<SourceManifest> backupDirect,
    required List<SourceManifest> embedded,
  }) async {
    final attempts = <UnifiedSourceAttempt>[];
    final streams = <UnifiedStreamOption>[];
    final seenStreams = <String>{};

    Future<void> runTier(
      List<SourceManifest> sources, {
      bool preserveOrder = false,
    }) async {
      if (sources.isEmpty || cancelToken?.isCancelled == true) return;
      final result = await search(
        media: media,
        preferredAudioLanguage: preferredAudioLanguage,
        cancelToken: cancelToken,
        onAttempt: onAttempt,
        onSourceStart: onSourceStart,
        onFirstPlayable: onFirstPlayable,
        repositorySnapshot: snapshot,
        onlySources: sources,
        preserveCandidateOrder: preserveOrder,
      );
      attempts.addAll(result.attempts);
      for (final stream in result.streams) {
        if (_isDistinctStream(stream, seenStreams)) streams.add(stream);
      }
    }

    // Respect the exact user order: primary list, editable backup list, then
    // all other sources not manually assigned to either list.
    await runTier(prioritized, preserveOrder: true);
    if (streams.isEmpty && cancelToken?.isCancelled != true) {
      await runTier(backupDirect, preserveOrder: true);
    }
    if (streams.isEmpty && cancelToken?.isCancelled != true) {
      await runTier(embedded, preserveOrder: true);
    }

    return UnifiedSourceSearchResult(
      repositorySnapshot: snapshot,
      attempts: List<UnifiedSourceAttempt>.unmodifiable(attempts),
      streams: List<UnifiedStreamOption>.unmodifiable(streams),
    );
  }

  SourcePriorityCategory _priorityCategoryFor(MediaIdentity media) {
    if (media.isAnimeContent || media.type == UnifiedMediaType.anime) {
      return SourcePriorityCategory.anime;
    }
    return media.normalizedType == UnifiedMediaType.movie
        ? SourcePriorityCategory.movies
        : SourcePriorityCategory.series;
  }

  Future<UnifiedSourceAttempt> _resolveCandidate({
    required SourceManifest source,
    required MediaIdentity media,
    required String? preferredAudioLanguage,
    required CancelToken? cancelToken,
  }) async {
    final startedAt = _clock().toUtc();
    final stopwatch = Stopwatch()..start();
    final cacheKey = _cacheKey(source, media, preferredAudioLanguage);
    final cached = _readCached(cacheKey);
    if (cached != null) {
      stopwatch.stop();
      final result = UnifiedSourceResult(
        streams: cached.streams,
        elapsed: Duration.zero,
      );
      final attempt = _buildAttempt(
        source: source,
        result: result,
        startedAt: startedAt,
        elapsed: stopwatch.elapsed,
      );
      _recordMetric(source, stopwatch.elapsed, result, cacheHit: true);
      _circuitBreaker.recordSuccess(_sourceCircuitKey(source));
      return attempt;
    }

    final circuitKey = _sourceCircuitKey(source);
    if (!_circuitBreaker.tryAcquire(circuitKey)) {
      stopwatch.stop();
      final result = const UnifiedSourceResult(
        errorMessage:
            'Source is temporarily cooling down after repeated failures.',
        failureKind: SourceFailureKind.circuitOpen,
      );
      final attempt = _buildAttempt(
        source: source,
        result: result,
        startedAt: startedAt,
        elapsed: stopwatch.elapsed,
      );
      _recordMetric(source, stopwatch.elapsed, result, cacheHit: false);
      return attempt;
    }

    if (cancelToken?.isCancelled == true) {
      _circuitBreaker.recordFailure(circuitKey, retryable: false);
      stopwatch.stop();
      final result = const UnifiedSourceResult(
        errorMessage: 'Source attempt was cancelled.',
        failureKind: SourceFailureKind.cancelled,
      );
      return _buildAttempt(
        source: source,
        result: result,
        startedAt: startedAt,
        elapsed: stopwatch.elapsed,
      );
    }

    final semaphore = _engineSemaphores.putIfAbsent(
      source.engine.kind,
      () => SourceExecutionSemaphore(
        _executionPolicy.concurrencyFor(source.engine.kind),
      ),
    );
    UnifiedSourceResult result;
    try {
      result = await semaphore.withPermit(() {
        if (cancelToken?.isCancelled == true) {
          return Future<UnifiedSourceResult>.value(
            const UnifiedSourceResult(
              errorMessage: 'Source attempt was cancelled.',
              failureKind: SourceFailureKind.cancelled,
            ),
          );
        }
        return _engines.resolve(
          source: source,
          media: media,
          preferredAudioLanguage: preferredAudioLanguage,
          cancelToken: cancelToken,
        );
      });
    } catch (error) {
      result = UnifiedSourceResult(
        errorMessage: 'Source attempt failed (${error.runtimeType}).',
        failureKind: sourceFailureKindFromException(error),
        httpStatusCodeClass: sourceHttpStatusClass(error),
      );
    }
    stopwatch.stop();
    final elapsed = result.elapsed ?? stopwatch.elapsed;
    final failure =
        result.failureKind ??
        (result.hasPlaybackCandidate ? null : SourceFailureKind.emptyResponse);
    if (failure != result.failureKind) {
      result = UnifiedSourceResult(
        streams: result.streams,
        embeddedPlayer: result.embeddedPlayer,
        errorMessage: result.errorMessage,
        elapsed: result.elapsed,
        failureKind: failure,
        httpStatusCodeClass: result.httpStatusCodeClass,
      );
    }

    if (result.success) {
      _circuitBreaker.recordSuccess(circuitKey);
      unawaited(
        _executionStateStore.rememberWorkingSource(
          playbackIdentity: _playbackIdentity(media),
          stableSourceKey: source.stableKey,
        ),
      );
      _storeCached(cacheKey, result.streams);
    } else if (result.embeddedPlayer == null && failure != null) {
      _circuitBreaker.recordFailure(circuitKey, retryable: failure.isRetryable);
    }

    final attempt = _buildAttempt(
      source: source,
      result: result,
      startedAt: startedAt,
      elapsed: elapsed,
    );
    _recordMetric(source, elapsed, result, cacheHit: false);
    return attempt;
  }

  UnifiedSourceAttempt _buildAttempt({
    required SourceManifest source,
    required UnifiedSourceResult result,
    required DateTime startedAt,
    required Duration elapsed,
  }) {
    final failure =
        result.failureKind ??
        (result.hasPlaybackCandidate ? null : SourceFailureKind.emptyResponse);
    final isPreflight =
        failure == SourceFailureKind.disabled ||
        failure == SourceFailureKind.repositoryDown ||
        failure == SourceFailureKind.unsupportedEngine ||
        failure == SourceFailureKind.unsupportedMedia ||
        failure == SourceFailureKind.circuitOpen;
    final completedAt = _clock().toUtc();
    return UnifiedSourceAttempt(
      source: source,
      result: result,
      diagnostics: SourceAttemptDiagnostics(
        stage: result.hasPlaybackCandidate
            ? SourceAttemptStage.completed
            : failure == SourceFailureKind.cancelled
            ? SourceAttemptStage.cancelled
            : isPreflight
            ? SourceAttemptStage.preflight
            : SourceAttemptStage.failed,
        startedAt: startedAt,
        completedAt: completedAt,
        elapsed: elapsed,
        failureKind: failure,
        message: _diagnosticMessage(failure),
        engineIdentity: source.engineIdentity.key,
      ),
    );
  }

  String? _diagnosticMessage(SourceFailureKind? kind) {
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

  void _recordMetric(
    SourceManifest source,
    Duration elapsed,
    UnifiedSourceResult result, {
    required bool cacheHit,
  }) {
    if (_executionPolicy.maxMetrics <= 0) return;
    final failure =
        result.failureKind ??
        (result.hasPlaybackCandidate ? null : SourceFailureKind.emptyResponse);
    _metrics.add(
      SourceExecutionMetric(
        sourceId: source.id,
        sourceKeyHash: _executionStateStore.sourceDigest(source.stableKey),
        engine: source.engine.kind.name,
        elapsed: elapsed,
        resultCount: result.streams.length,
        failureCategory: failure?.name ?? 'none',
        httpStatusClass: result.httpStatusCodeClass,
        cacheHit: cacheHit,
        recordedAt: _clock().toUtc(),
      ),
    );
    while (_metrics.length > _executionPolicy.maxMetrics) {
      _metrics.removeAt(0);
    }
  }

  UnifiedSourceResult? _readCached(String key) {
    final entry = _sourceResultCache.remove(key);
    if (entry == null) return null;
    if (!entry.expiresAt.isAfter(_clock())) return null;
    // Reinsert to maintain LRU order.
    _sourceResultCache[key] = entry;
    return UnifiedSourceResult(streams: entry.streams, elapsed: Duration.zero);
  }

  void _storeCached(String key, List<UnifiedStreamOption> streams) {
    final maximum = _executionPolicy.maxCachedSourceResults;
    if (maximum <= 0 || streams.isEmpty) return;
    // Never invent a TTL. Caching is enabled only when every returned stream
    // includes a future expiry supplied by the source itself.
    if (streams.any(
      (stream) =>
          stream.expiresAt == null || !stream.expiresAt!.isAfter(_clock()),
    )) {
      return;
    }
    final expiresAt = streams
        .map((stream) => stream.expiresAt!)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    _sourceResultCache.remove(key);
    _sourceResultCache[key] = _CachedSourceResult(
      streams: List<UnifiedStreamOption>.unmodifiable(streams),
      expiresAt: expiresAt,
    );
    while (_sourceResultCache.length > maximum) {
      _sourceResultCache.remove(_sourceResultCache.keys.first);
    }
  }

  String _cacheKey(
    SourceManifest source,
    MediaIdentity media,
    String? preferredAudioLanguage,
  ) {
    final requestedLanguage = preferredAudioLanguage?.trim().toLowerCase();
    final normalizedLanguage =
        requestedLanguage == null || requestedLanguage.isEmpty
        ? 'auto'
        : requestedLanguage;
    final sourceFingerprint = _sourceConfigurationFingerprint(source);
    final value = <String>[
      _playbackIdentity(media),
      sourceFingerprint,
      normalizedLanguage,
    ].join('\u001f');
    return sha256.convert(utf8.encode(value)).toString();
  }

  String _sourceConfigurationFingerprint(SourceManifest source) {
    final fields = <String>[
      source.stableKey,
      source.version,
      source.versionCode.toString(),
      source.apiVersion.toString(),
      source.language,
      source.engine.rawType,
      source.engine.kind.name,
      source.engine.endpoint,
      source.engine.movieUrl ?? '',
      source.engine.tvUrl ?? '',
      source.engine.audioLanguage ?? '',
      source.engine.qualityFilter ?? '',
    ];
    try {
      fields.add(jsonEncode(source.engine.config));
    } catch (_) {
      // Non-JSON custom configuration falls back to the stable descriptor
      // fields above; cache lifetime is still constrained by explicit expiry.
    }
    return sha256.convert(utf8.encode(fields.join('\u001e'))).toString();
  }

  String _sourceCircuitKey(SourceManifest source) =>
      sha256.convert(utf8.encode(source.stableKey)).toString();

  String _playbackIdentity(MediaIdentity media) {
    final externalIds = media.externalIds.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return <String>[
      media.playbackCacheKey,
      media.year?.toString() ?? '-',
      media.originalTitle?.trim().toLowerCase() ?? '-',
      media.episodeAirDate ?? '-',
      externalIds.map((entry) => '${entry.key}=${entry.value}').join(','),
    ].join(':');
  }

  int _compareRankedSources(SourceManifest a, SourceManifest b) {
    final byPriority = a.engine.priority.compareTo(b.engine.priority);
    if (byPriority != 0) return byPriority;

    final healthA = _healthFor(a);
    final healthB = _healthFor(b);
    if (healthA != null && healthB != null) {
      final reliability = healthA.failureRate.compareTo(healthB.failureRate);
      if (reliability != 0) return reliability;
      final latency = healthA.averageLatency.compareTo(healthB.averageLatency);
      if (latency != 0) return latency;
    }
    return a.stableKey.compareTo(b.stableKey);
  }

  _SourceHealth? _healthFor(SourceManifest source) {
    final digest = _executionStateStore.sourceDigest(source.stableKey);
    final recent = _metrics
        .where(
          (metric) =>
              metric.sourceKeyHash == digest &&
              !metric.cacheHit &&
              metric.failureCategory != 'cancelled' &&
              metric.failureCategory != 'circuitOpen',
        )
        .toList(growable: false);
    // Require repeat observations before measured health can affect ordering.
    if (recent.length < 2) return null;
    final failures = recent
        .where((metric) => metric.failureCategory != 'none')
        .length;
    final elapsed = recent.fold<int>(
      0,
      (total, metric) => total + metric.elapsed.inMilliseconds,
    );
    return _SourceHealth(
      failureRate: failures / recent.length,
      averageLatency: elapsed / recent.length,
    );
  }

  static bool _isDistinctStream(UnifiedStreamOption stream, Set<String> seen) {
    final headerKey =
        stream.headers.entries
            .map((entry) => '${entry.key.toLowerCase()}:${entry.value}')
            .toList()
          ..sort();
    final subtitleKey = stream.subtitles.map((track) {
      final trackHeaders =
          track.headers.entries
              .map((entry) => '${entry.key.toLowerCase()}:${entry.value}')
              .toList()
            ..sort();
      return <String>[
        track.url,
        track.language,
        track.format ?? '',
        track.isDefault.toString(),
        trackHeaders.join('&'),
      ].join(':');
    }).toList()..sort();
    final key = <String>[
      stream.providerId,
      stream.url,
      headerKey.join('&'),
      stream.label ?? '',
      stream.quality ?? '',
      stream.container.name,
      stream.audioKind.name,
      stream.audioLanguage ?? '',
      subtitleKey.join('&'),
      stream.subtitleOffsetSeconds?.toString() ?? '',
      stream.subtitleOffsetAfterSeconds?.toString() ?? '',
      stream.proxyUrl ?? '',
      stream.drmType ?? '',
    ].join('\u001f');
    return seen.add(key);
  }

  bool _needsImdbId(SourceManifest source, String stremioType) {
    if (source.engine.kind != SourceEngineKind.stremio) return false;

    final rawProfiles = source.engine.config['streamResourceProfiles'];
    if (rawProfiles is List && rawProfiles.isNotEmpty) {
      final matching = rawProfiles.whereType<Map>().where((profile) {
        final types = profile['types'];
        return types is List &&
            types.any((value) => value.toString().toLowerCase() == stremioType);
      });
      return matching.any((profile) {
        final mode = profile['prefixMode'];
        if (mode == 'default-imdb') return true;
        if (mode == 'any') return false;
        final prefixes = profile['idPrefixes'];
        return prefixes is List &&
            prefixes.any((value) {
              final prefix = value.toString().trim().toLowerCase();
              return prefix == 'imdb' ||
                  prefix == 'tt' ||
                  prefix.startsWith('tt');
            });
      });
    }

    final rawPrefixes = source.engine.config['idPrefixes'];
    if (rawPrefixes is! List) return true;
    return rawPrefixes.any((value) {
      final prefix = value.toString().trim().toLowerCase();
      return prefix == 'imdb' || prefix == 'tt' || prefix.startsWith('tt');
    });
  }
}

class _SourceHealth {
  const _SourceHealth({
    required this.failureRate,
    required this.averageLatency,
  });

  final double failureRate;
  final double averageLatency;
}

class _CachedSourceResult {
  const _CachedSourceResult({required this.streams, required this.expiresAt});

  final List<UnifiedStreamOption> streams;
  final DateTime expiresAt;
}
