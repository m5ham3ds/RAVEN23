import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../common.dart';

/// Ranks host labels returned inside stream links. This is intentionally
/// separate from [SourcePriorityManager], which ranks installed repository
/// extensions by stable manifest identity.
class StreamHostPriorityManager {
  StreamHostPriorityManager._();

  static final StreamHostPriorityManager instance =
      StreamHostPriorityManager._();

  static const String _storageKey = 'raven23.stream_host_priority.v1';
  static const String _performanceKey = 'raven23.stream_host_performance.v1';
  static const List<String> defaultOrder = <String>[
    'VixSrc',
    'Jett',
    'YaStream',
    'VidFast',
    'VidSpark',
    'HdHub',
    'Sova',
    'Sage',
    'Phoenix',
    'CineStream',
    'VidZee',
    'VegaMovies',
  ];

  List<String> _order = defaultOrder;
  final Map<String, Map<String, Object?>> _performance = {};
  bool _initialized = false;

  List<String> get currentOrder => List<String>.unmodifiable(_order);

  Future<void> initialize({SharedPreferences? preferences}) async {
    if (_initialized) return;
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey);
    final storedPerformance = prefs.getString(_performanceKey);
    if (storedPerformance != null && storedPerformance.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedPerformance);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is Map) {
              _performance['${entry.key}'.toLowerCase()] =
                  Map<String, Object?>.from(entry.value as Map);
            }
          }
        }
      } catch (_) {
        // A corrupt metrics snapshot is non-critical; reset only that cache.
        _performance.clear();
      }
    }
    if (stored == null || stored.isEmpty) {
      _order = defaultOrder;
      await prefs.setStringList(_storageKey, _order);
    } else {
      _order = _normalize(stored);
      // Append newly added defaults without disturbing a user's saved order.
      for (final name in defaultOrder) {
        if (!_contains(_order, name)) _order = <String>[..._order, name];
      }
      await prefs.setStringList(_storageKey, _order);
    }
    _initialized = true;
  }

  Future<List<String>> getOrder() async {
    await initialize();
    return currentOrder;
  }

  Future<void> setOrder(
    Iterable<String> names, {
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final next = _normalize(names);
    for (final name in defaultOrder) {
      if (!_contains(next, name)) next.add(name);
    }
    _order = next;
    _initialized = true;
    await prefs.setStringList(_storageKey, _order);
  }

  static List<String> _normalize(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      if (seen.add(key)) result.add(value);
    }
    return result;
  }

  static bool _contains(Iterable<String> values, String name) =>
      values.any((value) => value.toLowerCase() == name.toLowerCase());

  /// Stores a real successful first-play event. The latency starts when the
  /// selected source is handed to the player and ends at the first play event.
  /// Hosts outside the explicitly pinned first twelve are ranked by these
  /// device-observed values, not by their names or repository metadata.
  Future<void> recordPlaybackSuccess({
    required String server,
    required int startupMs,
  }) async {
    final key = _normalizeHost(server);
    if (key.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = _performance[key] ?? <String, Object?>{};
    final successes = (current['successes'] as num?)?.toInt() ?? 0;
    final failures = (current['failures'] as num?)?.toInt() ?? 0;
    final previousAverage = (current['averageStartupMs'] as num?)?.toDouble();
    final bounded = startupMs.clamp(0, 120000).toInt();
    final average = previousAverage == null
        ? bounded.toDouble()
        : ((previousAverage * successes) + bounded) / (successes + 1);
    _performance[key] = <String, Object?>{
      'displayName': server.trim(),
      'successes': successes + 1,
      'failures': failures,
      'averageStartupMs': average,
      'lastStartupMs': bounded,
      'lastSuccessAt': DateTime.now().toUtc().toIso8601String(),
    };
    await prefs.setString(_performanceKey, jsonEncode(_performance));
  }

  Future<void> recordPlaybackFailure({required String server}) async {
    final key = _normalizeHost(server);
    if (key.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = _performance[key] ?? <String, Object?>{};
    _performance[key] = <String, Object?>{
      ...current,
      'displayName': server.trim(),
      'successes': (current['successes'] as num?)?.toInt() ?? 0,
      'failures': ((current['failures'] as num?)?.toInt() ?? 0) + 1,
      'lastFailureAt': DateTime.now().toUtc().toIso8601String(),
    };
    await prefs.setString(_performanceKey, jsonEncode(_performance));
  }

  int _compareObservedHosts(
    MapEntry<String, Map<String, Object?>> left,
    MapEntry<String, Map<String, Object?>> right,
  ) {
    final leftPinned = _order.indexWhere(
      (name) => _normalizeHost(name) == left.key,
    );
    final rightPinned = _order.indexWhere(
      (name) => _normalizeHost(name) == right.key,
    );
    if (leftPinned >= 0 || rightPinned >= 0) {
      if (leftPinned < 0) return 1;
      if (rightPinned < 0) return -1;
      return leftPinned.compareTo(rightPinned);
    }

    int successes(MapEntry<String, Map<String, Object?>> entry) =>
        (entry.value['successes'] as num?)?.toInt() ?? 0;
    int failures(MapEntry<String, Map<String, Object?>> entry) =>
        (entry.value['failures'] as num?)?.toInt() ?? 0;
    double failureRatio(MapEntry<String, Map<String, Object?>> entry) {
      final successCount = successes(entry);
      final failureCount = failures(entry);
      final total = successCount + failureCount;
      return total == 0 ? 1 : failureCount / total;
    }

    double averageStart(MapEntry<String, Map<String, Object?>> entry) =>
        (entry.value['averageStartupMs'] as num?)?.toDouble() ?? 120000;

    final leftHasSuccess = successes(left) > 0;
    final rightHasSuccess = successes(right) > 0;
    if (leftHasSuccess != rightHasSuccess) return leftHasSuccess ? -1 : 1;
    final reliability = failureRatio(left).compareTo(failureRatio(right));
    if (reliability != 0) return reliability;
    final latency = averageStart(left).compareTo(averageStart(right));
    if (latency != 0) return latency;
    final volume = successes(right).compareTo(successes(left));
    if (volume != 0) return volume;
    return left.key.compareTo(right.key);
  }

  Map<String, Map<String, Object?>> get performanceSnapshot =>
      Map<String, Map<String, Object?>>.unmodifiable({
        for (final entry in _performance.entries)
          entry.key: Map<String, Object?>.unmodifiable(entry.value),
      });

  /// Additional hosts are eligible for the active order only after at least
  /// one successful real playback on this device. Failure-only observations
  /// remain available through [performanceSnapshot] for diagnostics, but do
  /// not promote a host into the active list.
  List<String> get observedHostOrder {
    final entries = _performance.entries.where((entry) {
      final successes = (entry.value['successes'] as num?)?.toInt() ?? 0;
      return successes > 0;
    }).toList()..sort(_compareObservedHosts);
    return List<String>.unmodifiable(
      entries.map(
        (entry) =>
            (entry.value['displayName'] as String?)?.trim().isNotEmpty == true
            ? (entry.value['displayName'] as String).trim()
            : entry.key,
      ),
    );
  }

  Map<String, Object?>? metricsFor(String server) {
    final metrics = _performance[_normalizeHost(server)];
    return metrics == null ? null : Map<String, Object?>.unmodifiable(metrics);
  }

  /// Returns the configured rank for a returned `server` label. Unknown
  /// hosts with at least one successful playback are sorted by failure ratio
  /// then average first-play latency. Hosts with failures but no successful
  /// playback rank behind unobserved hosts; their metrics remain diagnostic.
  int rankOf(String? server) {
    final normalized = _normalizeHost(server);
    if (normalized.isEmpty) return 1 << 30;
    for (var i = 0; i < _order.length; i++) {
      final candidate = _normalizeHost(_order[i]);
      if (normalized == candidate ||
          normalized.startsWith('$candidate ') ||
          normalized.startsWith('$candidate-') ||
          normalized.startsWith('${candidate}_') ||
          normalized.startsWith('$candidate/')) {
        return i;
      }
    }
    final metrics = _performance[normalized];
    if (metrics == null) return 1 << 30;
    final successes = (metrics['successes'] as num?)?.toInt() ?? 0;
    final failures = (metrics['failures'] as num?)?.toInt() ?? 0;
    if (successes == 0) return (1 << 30) + 1 + failures;
    final average = (metrics['averageStartupMs'] as num?)?.toDouble() ?? 120000;
    final failureRatio = failures / (successes + failures);
    // Failure ratio dominates latency; latency breaks ties among similarly
    // reliable unpinned hosts. Unobserved hosts remain behind known-good ones.
    return _order.length +
        (failureRatio * 1000000000).round() +
        average.clamp(0, 120000).round();
  }

  /// Applies the user's pinned first-twelve order to the actual links returned
  /// by a provider. An additional host moves ahead of unknown hosts only after
  /// a successful real playback on this device; failure-only hosts rank after
  /// unobserved hosts, while unobserved ties preserve source-returned order.
  List<RegularVideoLinks> orderLinks(Iterable<RegularVideoLinks> links) {
    final indexed = links.indexed.toList(growable: true);
    indexed.sort((left, right) {
      final rank = rankOf(left.$2.server).compareTo(rankOf(right.$2.server));
      return rank != 0 ? rank : left.$1.compareTo(right.$1);
    });
    return List<RegularVideoLinks>.unmodifiable(
      indexed.map((entry) => entry.$2),
    );
  }

  static String _normalizeHost(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
