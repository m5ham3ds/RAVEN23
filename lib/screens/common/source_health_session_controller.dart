import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../manga/mihon/mihon_runtime.dart';
import '../../video_providers/unified/source_catalog_safety_policy.dart';
import '../../video_providers/unified/source_manifest.dart';
import '../../video_providers/unified/source_priority_manager.dart';
import '../../video_providers/unified/unified_source_service.dart';
import 'source_health_probe_service.dart';
import 'source_health_priority_ranker.dart';

/// App-wide owner of the installed-source catalogue and health-check session.
/// Screens only subscribe to this controller; leaving a route never cancels
/// the probes, clears their progress, or starts another scan.
class SourceHealthSessionController extends ChangeNotifier {
  SourceHealthSessionController._();

  static final SourceHealthSessionController instance =
      SourceHealthSessionController._();

  static const String _storageKey = 'raven23_source_health_session_v1';
  static const MethodChannel _native = MethodChannel(
    'raven23/source_health_service',
  );

  final UnifiedSourceService _sourceService = UnifiedSourceService();
  final SourceHealthProbeService _probeService = SourceHealthProbeService();
  final SourcePriorityManager _priorityManager = SourcePriorityManager();
  final MihonRuntimeService _mihonRuntime = MihonRuntimeService.instance;

  List<SourceHealthCheckResult> videoResults =
      const <SourceHealthCheckResult>[];
  List<SourceHealthCheckResult> mihonResults =
      const <SourceHealthCheckResult>[];

  bool isRunning = false;
  bool videoPhaseComplete = false;
  bool mihonPhaseComplete = false;
  bool hasRun = false;
  bool isLoadingCatalogue = false;
  bool isLoadingMihonSources = false;
  String? videoError;
  String? mihonError;
  String? repositoryWarning;
  int videoProgress = 0;
  int videoProgressTotal = 0;
  int mihonProgress = 0;
  int mihonProgressTotal = 0;
  int excludedHentaiSourceCount = 0;
  int activatedCatalogSourceCount = 0;
  DateTime? startedAt;
  DateTime? completedAt;

  bool _initialized = false;
  bool _resumeRequired = false;
  Future<void>? _initializing;
  Future<void>? _activeTask;
  Future<void> _persistTail = Future<void>.value();

  bool get hasResults => videoResults.isNotEmpty || mihonResults.isNotEmpty;
  bool get isComplete =>
      hasRun && !isRunning && videoPhaseComplete && mihonPhaseComplete;
  bool get canReviewFailures =>
      !isRunning &&
      <SourceHealthCheckResult>[
        ...videoResults,
        ...mihonResults,
      ].any((result) => result.needsAttention);

  List<SourceHealthCheckResult> get problemResults => <SourceHealthCheckResult>[
    ...videoResults.where((result) => result.needsAttention),
    ...mihonResults.where((result) => result.needsAttention),
  ];

  Future<void> initialize() async {
    if (_initialized) return;
    final pending = _initializing;
    if (pending != null) return pending;
    final task = _restore();
    _initializing = task;
    try {
      await task;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final data = Map<String, dynamic>.from(decoded);
          videoResults = _decodeResults(data['videoResults']);
          mihonResults = _decodeResults(data['mihonResults']);
          videoPhaseComplete = data['videoPhaseComplete'] == true;
          mihonPhaseComplete = data['mihonPhaseComplete'] == true;
          hasRun = data['hasRun'] == true;
          isRunning = data['isRunning'] == true;
          startedAt = DateTime.tryParse('${data['startedAt'] ?? ''}');
          completedAt = DateTime.tryParse('${data['completedAt'] ?? ''}');
          videoProgress = (data['videoProgress'] as num?)?.toInt() ?? 0;
          videoProgressTotal =
              (data['videoProgressTotal'] as num?)?.toInt() ?? 0;
          mihonProgress = (data['mihonProgress'] as num?)?.toInt() ?? 0;
          mihonProgressTotal =
              (data['mihonProgressTotal'] as num?)?.toInt() ?? 0;
          videoError = data['videoError'] as String?;
          mihonError = data['mihonError'] as String?;
          repositoryWarning = data['repositoryWarning'] as String?;
          excludedHentaiSourceCount =
              (data['excludedHentaiSourceCount'] as num?)?.toInt() ?? 0;
          activatedCatalogSourceCount =
              (data['activatedCatalogSourceCount'] as num?)?.toInt() ?? 0;
          _resumeRequired = isRunning;
        }
      } catch (error) {
        debugPrint(
          '[SourceHealth] saved session could not be restored: $error',
        );
      }
    }
    _initialized = true;
    notifyListeners();
  }

  /// Starts the first run, resumes a previously interrupted run, or does
  /// nothing when a completed snapshot already exists.
  Future<void> ensureStarted() async {
    await initialize();
    if (_resumeRequired && _activeTask == null) {
      unawaited(start(resume: true));
      return;
    }
    if (!hasRun && _activeTask == null) {
      unawaited(start());
    }
  }

  /// Manual refresh is the only path that discards a completed result set.
  Future<void> start({bool force = false, bool resume = false}) async {
    await initialize();
    if (_activeTask != null) return _activeTask!;
    if (isRunning && !resume) return;
    if (hasRun && isComplete && !force && !resume) return;

    if (!resume) {
      videoResults = const <SourceHealthCheckResult>[];
      mihonResults = const <SourceHealthCheckResult>[];
      videoPhaseComplete = false;
      mihonPhaseComplete = false;
      videoError = null;
      mihonError = null;
      repositoryWarning = null;
      excludedHentaiSourceCount = 0;
      activatedCatalogSourceCount = 0;
      videoProgress = 0;
      videoProgressTotal = 0;
      mihonProgress = 0;
      mihonProgressTotal = 0;
      startedAt = DateTime.now();
      completedAt = null;
      hasRun = true;
    }

    isRunning = true;
    _resumeRequired = false;
    notifyListeners();
    await _persist();
    await _nativeCall('start');

    final task = _run(resume: resume);
    _activeTask = task;
    try {
      await task;
    } finally {
      _activeTask = null;
    }
  }

  Future<void> _run({required bool resume}) async {
    // Video and Mihon catalogues are independent. Prepare and probe both in
    // parallel so every installed item appears as "Checking" as soon as its
    // own catalogue is ready, rather than waiting for the other phase.
    await Future.wait<void>(<Future<void>>[
      _runVideoPhaseSafely(resume: resume),
      _runMihonPhaseSafely(resume: resume),
    ]);

    isRunning = false;
    _resumeRequired = false;
    completedAt = DateTime.now();
    notifyListeners();
    await _persist();
    await _nativeCall('stop');
  }

  Future<void> _runVideoPhaseSafely({required bool resume}) async {
    try {
      await _runVideoPhase(resume: resume);
    } catch (error, stack) {
      debugPrint('[SourceHealth] video phase failed: $error\n$stack');
      videoError = _friendlyError(error);
      videoResults = videoResults
          .map(_finishInterruptedResult)
          .toList(growable: false);
      videoPhaseComplete = true;
      _notifyAndPersist();
    }
  }

  Future<void> _runMihonPhaseSafely({required bool resume}) async {
    try {
      await _runMihonPhase(resume: resume);
    } catch (error, stack) {
      debugPrint('[SourceHealth] Mihon phase failed: $error\n$stack');
      mihonError = _friendlyError(error);
      mihonResults = mihonResults
          .map(_finishInterruptedResult)
          .toList(growable: false);
      mihonPhaseComplete = true;
      _notifyAndPersist();
    }
  }

  Future<void> _runVideoPhase({required bool resume}) async {
    if (videoPhaseComplete) return;
    List<SourceManifest> pendingSources;
    if (resume && videoResults.isNotEmpty) {
      pendingSources = videoResults
          .where((result) => result.isChecking && result.videoSource != null)
          .map((result) => result.videoSource!)
          .toList(growable: false);
      if (pendingSources.isEmpty) {
        await _applyMeasuredPrimaryOrdering();
        videoPhaseComplete = true;
        _notifyAndPersist();
        return;
      }
    } else {
      isLoadingCatalogue = true;
      notifyListeners();
      // Refresh the complete repository catalogue, not only the currently
      // installed/enabled subset. SOURCE CATALOG is the authoritative test
      // scope for this audit.
      final snapshot = await _sourceService.refreshRepositories(
        forceRefresh: true,
      );
      final catalog = snapshot.catalog.isNotEmpty
          ? snapshot.catalog
          : snapshot.sources;
      final safeCatalog = <SourceManifest>[];
      final excludedCatalog = <SourceManifest>[];
      excludedHentaiSourceCount = 0;
      activatedCatalogSourceCount = 0;

      // Remove stale Hentai identities from every priority lane even if a
      // repository has since removed the corresponding manifest entry.
      for (final category in SourcePriorityCategory.values) {
        final primary = await _priorityManager.getPriorityKeys(category);
        final backup = await _priorityManager.getBackupKeys(category);
        for (final key in <String>{...primary, ...backup}) {
          if (SourceCatalogSafetyPolicy.isExcludedStableKey(key)) {
            await _priorityManager.removeKey(
              category,
              SourcePriorityLane.primary,
              key,
            );
            await _priorityManager.removeKey(
              category,
              SourcePriorityLane.backup,
              key,
            );
          }
        }
      }
      // Also purge stale blocked installation keys from older catalogues,
      // where the original manifest may no longer be present to inspect.
      final staleBlockedKeys = (await _sourceService.installedSourceKeys())
          .where(SourceCatalogSafetyPolicy.isExcludedStableKey)
          .toList(growable: false);
      await _sourceService.uninstallSourceKeys(staleBlockedKeys);

      for (final source in catalog) {
        if (SourceCatalogSafetyPolicy.isExcludedHentai(source)) {
          excludedCatalog.add(source);
          excludedHentaiSourceCount++;
          for (final category in SourcePriorityCategory.values) {
            await _priorityManager.removeKey(
              category,
              SourcePriorityLane.primary,
              source.stableKey,
            );
            await _priorityManager.removeKey(
              category,
              SourcePriorityLane.backup,
              source.stableKey,
            );
          }
          continue;
        }
        safeCatalog.add(source);
      }

      // Explicit installation overrides upstream enabled:false for every safe
      // catalogue entry. Batch writes make this reliable for large indexes.
      await _sourceService.uninstallSources(excludedCatalog);
      await _sourceService.installSources(safeCatalog);
      activatedCatalogSourceCount = safeCatalog.length;

      pendingSources = List<SourceManifest>.unmodifiable(safeCatalog);
      repositoryWarning = snapshot.errors.isEmpty
          ? null
          : '${snapshot.errors.length} repositories could not be refreshed; the cached catalogue was used where available. Results are limited to repositories that returned data.';
      videoResults = safeCatalog
          .map(_checkingVideoResult)
          .toList(growable: false);
      videoProgress = 0;
      videoProgressTotal = safeCatalog.length;
      isLoadingCatalogue = false;
      _notifyAndPersist();
    }

    final completedBeforeRun = videoResults
        .where((result) => !result.isChecking)
        .length;
    videoProgress = completedBeforeRun;
    videoProgressTotal = videoResults.length;
    await _probeService.checkVideoSources(
      pendingSources,
      onProgress: (completed, total) {
        videoProgress = completedBeforeRun + completed;
        videoProgressTotal = completedBeforeRun + total;
        notifyListeners();
      },
      onResult: (source, result) {
        _replaceVideoResult(source, result);
        videoProgress = videoResults.where((item) => !item.isChecking).length;
        videoProgressTotal = videoResults.length;
        _notifyAndPersist();
      },
    );
    await _applyMeasuredPrimaryOrdering();
    videoPhaseComplete = true;
    videoProgress = videoResults.length;
    videoProgressTotal = videoResults.length;
    _notifyAndPersist();
  }

  Future<void> _applyMeasuredPrimaryOrdering() async {
    // Test evidence only fills the tail after the explicit fixed prefix.
    // BACKUP remains reserved for real playback-confirmed providers.
    for (final category in SourcePriorityCategory.values) {
      final currentPrimary = await _priorityManager.getPriorityKeys(category);
      final backup = await _priorityManager.getBackupKeys(category);
      final ranked = SourceHealthPriorityRanker.rankPrimaryKeys(
        category: category,
        currentPrimaryKeys: currentPrimary,
        backupKeys: backup,
        results: videoResults,
      );
      if (ranked.length == currentPrimary.length &&
          _sameOrder(ranked, currentPrimary)) {
        continue;
      }
      await _priorityManager.setPriorityKeys(category, ranked);
    }
  }

  bool _sameOrder(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  Future<void> _runMihonPhase({required bool resume}) async {
    if (mihonPhaseComplete) return;
    List<MihonSourceInfo> pendingSources;
    if (resume && mihonResults.isNotEmpty) {
      pendingSources = mihonResults
          .where((result) => result.isChecking && result.mihonSource != null)
          .map((result) => result.mihonSource!)
          .toList(growable: false);
      if (pendingSources.isEmpty) {
        mihonPhaseComplete = true;
        _notifyAndPersist();
        return;
      }
    } else {
      isLoadingMihonSources = true;
      notifyListeners();
      pendingSources = await _mihonRuntime.listSources();
      mihonResults = pendingSources
          .map(_checkingMihonResult)
          .toList(growable: false);
      mihonProgress = 0;
      mihonProgressTotal = pendingSources.length;
      isLoadingMihonSources = false;
      _notifyAndPersist();
    }

    final completedBeforeRun = mihonResults
        .where((result) => !result.isChecking)
        .length;
    mihonProgress = completedBeforeRun;
    mihonProgressTotal = mihonResults.length;
    await _probeService.checkMihonSources(
      sources: pendingSources,
      onProgress: (completed, total) {
        mihonProgress = completedBeforeRun + completed;
        mihonProgressTotal = completedBeforeRun + total;
        notifyListeners();
      },
      onResult: (source, result) {
        _replaceMihonResult(source, result);
        mihonProgress = mihonResults.where((item) => !item.isChecking).length;
        mihonProgressTotal = mihonResults.length;
        _notifyAndPersist();
      },
    );
    mihonPhaseComplete = true;
    mihonProgress = mihonResults.length;
    mihonProgressTotal = mihonResults.length;
    _notifyAndPersist();
  }

  SourceHealthCheckResult _checkingVideoResult(SourceManifest source) =>
      SourceHealthCheckResult(
        id: source.stableKey,
        name: source.name,
        engineLabel: source.engine.rawType,
        status: SourceHealthStatus.checking,
        reason: SourceHealthReason.unknown,
        elapsed: Duration.zero,
        videoSource: source,
      );

  SourceHealthCheckResult _checkingMihonResult(MihonSourceInfo source) =>
      SourceHealthCheckResult(
        id: source.id.toString(),
        name: source.name,
        engineLabel: 'Mihon · ${source.lang}',
        status: SourceHealthStatus.checking,
        reason: SourceHealthReason.unknown,
        elapsed: Duration.zero,
        mihonSource: source,
      );

  void _replaceVideoResult(
    SourceManifest source,
    SourceHealthCheckResult result,
  ) {
    final index = videoResults.indexWhere(
      (item) => item.videoSource?.stableKey == source.stableKey,
    );
    if (index < 0) {
      videoResults = <SourceHealthCheckResult>[...videoResults, result];
    } else {
      final updated = List<SourceHealthCheckResult>.of(videoResults);
      updated[index] = result;
      videoResults = updated;
    }
  }

  void _replaceMihonResult(
    MihonSourceInfo source,
    SourceHealthCheckResult result,
  ) {
    final index = mihonResults.indexWhere(
      (item) => item.mihonSource?.id == source.id,
    );
    if (index < 0) {
      mihonResults = <SourceHealthCheckResult>[...mihonResults, result];
    } else {
      final updated = List<SourceHealthCheckResult>.of(mihonResults);
      updated[index] = result;
      mihonResults = updated;
    }
  }

  SourceHealthCheckResult _finishInterruptedResult(
    SourceHealthCheckResult result,
  ) {
    if (!result.isChecking) return result;
    return SourceHealthCheckResult(
      id: result.id,
      name: result.name,
      engineLabel: result.engineLabel,
      status: SourceHealthStatus.attention,
      reason: SourceHealthReason.unknown,
      elapsed: result.elapsed,
      resultCount: result.resultCount,
      httpStatusCode: result.httpStatusCode,
      extractedStreamCount: result.extractedStreamCount,
      qualityLabels: result.qualityLabels,
      containerLabels: result.containerLabels,
      audioKinds: result.audioKinds,
      subtitleTrackCount: result.subtitleTrackCount,
      categoryEvidence: result.categoryEvidence,
      videoSource: result.videoSource,
      mihonSource: result.mihonSource,
    );
  }

  void dropResultsFor(Iterable<SourceHealthCheckResult> removed) {
    final keys = removed.map((result) => result.selectionKey).toSet();
    videoResults = videoResults
        .where((result) => !keys.contains(result.selectionKey))
        .toList(growable: false);
    mihonResults = mihonResults
        .where((result) => !keys.contains(result.selectionKey))
        .toList(growable: false);
    _notifyAndPersist();
  }

  Future<void> _nativeCall(
    String method, [
    Map<String, Object?> arguments = const <String, Object?>{},
  ]) async {
    try {
      await _native.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Unit tests and non-Android hosts have no native foreground service.
    } on PlatformException catch (error) {
      debugPrint('[SourceHealth] native notification service failed: $error');
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('unknownhost') || raw.contains('host lookup')) {
      return 'Network/DNS lookup failed while preparing the source list.';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'The source preparation operation timed out.';
    }
    if (raw.contains('missingplugin') || raw.contains('notimplemented')) {
      return 'A required native source runtime is unavailable on this device.';
    }
    return 'The source health session could not complete one phase: $error';
  }

  List<SourceHealthCheckResult> _decodeResults(dynamic raw) {
    if (raw is! List) return const <SourceHealthCheckResult>[];
    return raw
        .whereType<Map>()
        .map(
          (value) => SourceHealthCheckResult.fromJson(
            Map<String, dynamic>.from(value),
          ),
        )
        .toList(growable: false);
  }

  void _notifyAndPersist() {
    notifyListeners();
    unawaited(_persist());
    unawaited(_updateNativeNotification());
  }

  Future<void> _updateNativeNotification() =>
      _nativeCall('update', <String, Object?>{
        'videoDone': videoProgress,
        'videoTotal': videoProgressTotal,
        'mihonDone': mihonProgress,
        'mihonTotal': mihonProgressTotal,
        'isRunning': isRunning,
      });

  Future<void> _persist() {
    final snapshot = jsonEncode(<String, Object?>{
      'version': 1,
      'isRunning': isRunning,
      'hasRun': hasRun,
      'videoPhaseComplete': videoPhaseComplete,
      'mihonPhaseComplete': mihonPhaseComplete,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'videoProgress': videoProgress,
      'videoProgressTotal': videoProgressTotal,
      'mihonProgress': mihonProgress,
      'mihonProgressTotal': mihonProgressTotal,
      'videoError': videoError,
      'mihonError': mihonError,
      'repositoryWarning': repositoryWarning,
      'excludedHentaiSourceCount': excludedHentaiSourceCount,
      'activatedCatalogSourceCount': activatedCatalogSourceCount,
      'videoResults': videoResults
          .map((result) => result.toJson())
          .toList(growable: false),
      'mihonResults': mihonResults
          .map((result) => result.toJson())
          .toList(growable: false),
    });
    _persistTail = _persistTail
        .then((_) async {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(_storageKey, snapshot);
        })
        .catchError((Object error) {
          debugPrint(
            '[SourceHealth] session state could not be persisted: $error',
          );
        });
    return _persistTail;
  }
}
