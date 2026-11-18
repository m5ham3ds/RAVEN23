import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'source_manifest.dart';

/// Per-engine limits prevent a slow/serialized runtime from consuming every
/// worker while still allowing independent HTTP engines to overlap.
class SourceExecutionPolicy {
  const SourceExecutionPolicy({
    this.maxConcurrentSources = 3,
    this.quickJsConcurrency = 1,
    this.animeConcurrency = 2,
    this.stremioConcurrency = 2,
    this.vidkingConcurrency = 2,
    this.webEmbedConcurrency = 1,
    this.fallbackHeadStart = const Duration(seconds: 8),
    this.circuitFailureThreshold = 5,
    this.circuitCooldown = const Duration(minutes: 2),
    this.maxCachedSourceResults = 120,
    this.maxMetrics = 200,
  });

  final int maxConcurrentSources;
  final int quickJsConcurrency;
  final int animeConcurrency;
  final int stremioConcurrency;
  final int vidkingConcurrency;
  final int webEmbedConcurrency;
  final Duration fallbackHeadStart;
  final int circuitFailureThreshold;
  final Duration circuitCooldown;
  final int maxCachedSourceResults;
  final int maxMetrics;

  int concurrencyFor(SourceEngineKind kind) {
    switch (kind) {
      case SourceEngineKind.javascript:
        return quickJsConcurrency;
      case SourceEngineKind.animeSite:
        return animeConcurrency;
      case SourceEngineKind.stremio:
        return stremioConcurrency;
      case SourceEngineKind.vidkingDirect:
        return vidkingConcurrency;
      case SourceEngineKind.webEmbed:
      case SourceEngineKind.vidkingWebView:
        return webEmbedConcurrency;
      case SourceEngineKind.httpJson:
      case SourceEngineKind.legacyScraperApi:
      case SourceEngineKind.native:
      case SourceEngineKind.unsupported:
        return 1;
    }
  }
}

/// Stores only hashes, never source URLs, tokens, headers or media titles.
/// Preferences persistence is best-effort; a process-local fallback keeps the
/// scheduler functional when platform storage is unavailable in tests.
class SourceExecutionStateStore {
  SourceExecutionStateStore();

  static const String _prefix = 'raven23.source_execution.last_working.v1.';
  static final Map<String, String> _memory = <String, String>{};

  String _mediaKey(String playbackIdentity) =>
      '$_prefix${sha256.convert(utf8.encode(playbackIdentity))}';

  String sourceDigest(String stableSourceKey) =>
      sha256.convert(utf8.encode(stableSourceKey)).toString();

  Future<String?> readLastWorkingSourceHash(String playbackIdentity) async {
    final key = _mediaKey(playbackIdentity);
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(key);
      if (value != null && value.isNotEmpty) {
        _memory[key] = value;
        return value;
      }
    } catch (_) {
      // Platform storage is optional; do not block source resolution.
    }
    return _memory[key];
  }

  Future<void> rememberWorkingSource({
    required String playbackIdentity,
    required String stableSourceKey,
  }) async {
    final key = _mediaKey(playbackIdentity);
    final digest = sourceDigest(stableSourceKey);
    _memory[key] = digest;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, digest);
    } catch (_) {
      // The hashed in-memory preference remains available for this process.
    }
  }
}

/// Simple bounded semaphore used for independent per-engine concurrency.
class SourceExecutionSemaphore {
  SourceExecutionSemaphore(int limit) : _limit = limit < 1 ? 1 : limit;

  final int _limit;
  int _active = 0;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  Future<void> _acquire() async {
    if (_active < _limit) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
    // The released permit is transferred directly to this waiter. Do not
    // increment _active here or another caller could steal the slot.
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
      return;
    }
    _active = (_active - 1).clamp(0, _limit).toInt();
  }

  Future<T> withPermit<T>(Future<T> Function() operation) async {
    await _acquire();
    try {
      return await operation();
    } finally {
      _release();
    }
  }
}

class SourceExecutionMetric {
  const SourceExecutionMetric({
    required this.sourceId,
    required this.sourceKeyHash,
    required this.engine,
    required this.elapsed,
    required this.resultCount,
    required this.failureCategory,
    this.httpStatusClass,
    required this.cacheHit,
    required this.recordedAt,
  });

  /// Provider ID only. No URL, headers, query, token or title is retained.
  final String sourceId;
  final String sourceKeyHash;
  final String engine;
  final Duration elapsed;
  final int resultCount;
  final String failureCategory;
  final String? httpStatusClass;
  final bool cacheHit;
  final DateTime recordedAt;
}

class SourceCircuitBreaker {
  SourceCircuitBreaker({
    this.failureThreshold = 5,
    this.cooldown = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int failureThreshold;
  final Duration cooldown;
  final DateTime Function() _clock;
  final Map<String, _CircuitState> _states = <String, _CircuitState>{};

  bool tryAcquire(String stableSourceKey) {
    final state = _states[stableSourceKey];
    if (state == null || state.blockedUntil == null) return true;
    if (_clock().isBefore(state.blockedUntil!)) return false;
    if (state.probeInFlight) return false;
    state.probeInFlight = true;
    return true;
  }

  void recordSuccess(String stableSourceKey) {
    _states.remove(stableSourceKey);
  }

  void recordFailure(String stableSourceKey, {required bool retryable}) {
    final state = _states.putIfAbsent(stableSourceKey, _CircuitState.new);
    state.probeInFlight = false;
    if (!retryable) {
      if (state.blockedUntil != null &&
          !_clock().isBefore(state.blockedUntil!)) {
        _states.remove(stableSourceKey);
      }
      return;
    }
    state.failures++;
    if (state.failures >= failureThreshold) {
      state.blockedUntil = _clock().add(cooldown);
    }
  }

  int consecutiveFailures(String stableSourceKey) =>
      _states[stableSourceKey]?.failures ?? 0;

  DateTime? blockedUntil(String stableSourceKey) =>
      _states[stableSourceKey]?.blockedUntil;
}

class _CircuitState {
  int failures = 0;
  DateTime? blockedUntil;
  bool probeInFlight = false;
}
