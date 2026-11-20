import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The three independent search lanes used by the unified VOD resolver.
enum SourcePriorityCategory { movies, series, anime }

/// A source can be placed in exactly one of the two editable lists for a media
/// category. The same source may intentionally be selected in another media
/// category (for example, both Movies and Series).
enum SourcePriorityLane { primary, backup }

/// Persists stable source identities, not list indexes or repository names.
/// PRIMARY is the user's fixed, authoritative default/manual execution order.
/// BACKUP is a separate automatic recovery lane: sustained, real playback
/// evidence may add a working source and rank automatically-added entries by
/// reliability/latency, but it must never alter PRIMARY or manual BACKUP picks.
/// Health scans and extraction-only success are not playback verification.
class SourcePriorityManager {
  SourcePriorityManager({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _configuredKey =
      'raven23.source_priorities.initialized.v1';

  // Keep the v1 primary key so existing users retain their priority order.
  static const String _primaryPrefix = 'raven23.source_priorities.v1.';
  static const String _backupPrefix = 'raven23.source_backups.v1.';
  static const String _manualBackupPrefix = 'raven23.source_backups.manual.v1.';
  static const String _manualBackupInitializedPrefix =
      'raven23.source_backups.manual_initialized.v1.';
  static const String _playbackMetricsPrefix =
      'raven23.source_playback_metrics.v1.';

  final SharedPreferences? _preferences;
  SharedPreferences? _resolvedPreferences;

  Future<SharedPreferences> get _prefs async {
    if (_preferences != null) return _preferences;
    return _resolvedPreferences ??= await SharedPreferences.getInstance();
  }

  String _key(SourcePriorityCategory category, SourcePriorityLane lane) {
    final prefix = lane == SourcePriorityLane.primary
        ? _primaryPrefix
        : _backupPrefix;
    return '$prefix${category.name}';
  }

  Future<bool> get isInitialized async =>
      (await _prefs).getBool(_configuredKey) ?? false;

  Future<void> markInitialized() async =>
      (await _prefs).setBool(_configuredKey, true);

  /// Legacy accessor: the original priority list is the primary list.
  Future<List<String>> getPriorityKeys(SourcePriorityCategory category) =>
      getKeys(category, SourcePriorityLane.primary);

  Future<List<String>> getBackupKeys(SourcePriorityCategory category) =>
      getKeys(category, SourcePriorityLane.backup);

  Future<List<String>> getKeys(
    SourcePriorityCategory category,
    SourcePriorityLane lane,
  ) async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_key(category, lane)) ?? const <String>[];
    final normalized = _normalize(raw);
    if (lane == SourcePriorityLane.backup) {
      final primary =
          (prefs.getStringList(_key(category, SourcePriorityLane.primary)) ??
                  const <String>[])
              .toSet();
      return normalized.where((key) => !primary.contains(key)).toList();
    }
    return normalized;
  }

  Future<void> setPriorityKeys(
    SourcePriorityCategory category,
    Iterable<String> keys,
  ) => setKeys(category, SourcePriorityLane.primary, keys);

  Future<void> setBackupKeys(
    SourcePriorityCategory category,
    Iterable<String> keys,
  ) async {
    await setKeys(category, SourcePriorityLane.backup, keys);
    await _pinBackupOrder(category, await getBackupKeys(category));
  }

  /// Classifies the existing BACKUP lane once during upgrade. Existing entries
  /// are preserved exactly as found; newly auto-promoted entries are kept in a
  /// separate unpinned portion so measured reliability can rank only that
  /// automatically-managed portion.
  Future<void> preserveExistingBackupOrderIfNeeded(
    SourcePriorityCategory category,
  ) async {
    final prefs = await _prefs;
    final initializedKey = '$_manualBackupInitializedPrefix${category.name}';
    if (prefs.getBool(initializedKey) == true) return;
    await _pinBackupOrder(category, await getBackupKeys(category));
  }

  Future<Set<String>> _manualBackupKeys(
    SourcePriorityCategory category,
  ) async =>
      (await _prefs)
          .getStringList('$_manualBackupPrefix${category.name}')
          ?.toSet() ??
      <String>{};

  Future<void> _pinBackupOrder(
    SourcePriorityCategory category,
    Iterable<String> keys,
  ) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      '$_manualBackupPrefix${category.name}',
      _normalize(keys),
    );
    await prefs.setBool(
      '$_manualBackupInitializedPrefix${category.name}',
      true,
    );
  }

  /// Initializes a missing BACKUP lane without overwriting an existing lane.
  /// Callers may seed the app's established automatic recovery candidates here;
  /// this method never writes to PRIMARY and never reseeds an existing BACKUP.
  Future<bool> seedBackupKeysIfMissing(
    SourcePriorityCategory category,
    Iterable<String> keys,
  ) async {
    final prefs = await _prefs;
    final key = _key(category, SourcePriorityLane.backup);
    if (prefs.containsKey(key)) return false;
    await setKeys(category, SourcePriorityLane.backup, keys);
    return true;
  }

  Future<void> setKeys(
    SourcePriorityCategory category,
    SourcePriorityLane lane,
    Iterable<String> keys,
  ) async {
    final prefs = await _prefs;
    final normalized = _normalize(keys);
    final otherLane = lane == SourcePriorityLane.primary
        ? SourcePriorityLane.backup
        : SourcePriorityLane.primary;
    final otherKeys =
        (prefs.getStringList(_key(category, otherLane)) ?? const <String>[])
            .toSet();
    final unique = normalized.where((key) => !otherKeys.contains(key)).toList();
    await prefs.setStringList(_key(category, lane), unique);
  }

  Future<bool> canAddPriorityKey(SourcePriorityCategory category) =>
      canAddKey(category, SourcePriorityLane.primary);

  Future<bool> canAddKey(
    SourcePriorityCategory category,
    SourcePriorityLane lane,
  ) async => true;

  Future<bool> addPriorityKey(SourcePriorityCategory category, String key) =>
      addKey(category, SourcePriorityLane.primary, key);

  /// Adds a source to the automatic BACKUP recovery lane only after sustained
  /// real playback. [startupMs] is measured until the first play event, never
  /// inferred from a health probe or extracted link. PRIMARY is not touched.
  /// Manual BACKUP entries remain pinned; automatically-added BACKUP entries
  /// can be ranked by observed reliability and startup latency.
  Future<bool> promoteVerifiedPlayback(
    SourcePriorityCategory category,
    String stableSourceKey, {
    int? startupMs,
  }) async {
    final key = stableSourceKey.trim();
    if (key.isEmpty) return false;

    final metrics = await _readPlaybackMetrics(category);
    final previous = metrics[key] ?? <String, Object?>{};
    final successes = (previous['successes'] as num?)?.toInt() ?? 0;
    final failures = (previous['failures'] as num?)?.toInt() ?? 0;
    final previousAverage = (previous['averageStartupMs'] as num?)?.toDouble();
    final boundedStartup = startupMs?.clamp(0, 120000).toInt();
    final averageStartup = boundedStartup == null
        ? previousAverage
        : previousAverage == null
        ? boundedStartup.toDouble()
        : ((previousAverage * successes) + boundedStartup) / (successes + 1);
    metrics[key] = <String, Object?>{
      ...previous,
      'successes': successes + 1,
      'failures': failures,
      if (averageStartup != null) 'averageStartupMs': averageStartup,
      if (boundedStartup != null) 'lastStartupMs': boundedStartup,
      'lastSuccessAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _writePlaybackMetrics(category, metrics);

    if ((await getKeys(category, SourcePriorityLane.primary)).contains(key)) {
      return false;
    }
    final backups = await getKeys(category, SourcePriorityLane.backup);
    final added = !backups.contains(key);
    if (added) backups.add(key);
    if (added) await setKeys(category, SourcePriorityLane.backup, backups);
    await _sortMeasuredBackups(category, metrics);
    return added;
  }

  /// Persists a real player-start failure for later recovery ranking. A
  /// failure alone never inserts a source into BACKUP or changes PRIMARY.
  Future<void> recordPlaybackFailure(
    SourcePriorityCategory category,
    String stableSourceKey,
  ) async {
    final key = stableSourceKey.trim();
    if (key.isEmpty) return;
    final metrics = await _readPlaybackMetrics(category);
    final previous = metrics[key] ?? <String, Object?>{};
    metrics[key] = <String, Object?>{
      ...previous,
      'successes': (previous['successes'] as num?)?.toInt() ?? 0,
      'failures': ((previous['failures'] as num?)?.toInt() ?? 0) + 1,
      'lastFailureAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _writePlaybackMetrics(category, metrics);
    await _sortMeasuredBackups(category, metrics);
  }

  Future<Map<String, Map<String, Object?>>> _readPlaybackMetrics(
    SourcePriorityCategory category,
  ) async {
    final raw = (await _prefs).getString(
      '$_playbackMetricsPrefix${category.name}',
    );
    if (raw == null || raw.isEmpty) return <String, Map<String, Object?>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, Object?>>{};
      return <String, Map<String, Object?>>{
        for (final entry in decoded.entries)
          if (entry.value is Map)
            entry.key.toString(): Map<String, Object?>.from(entry.value as Map),
      };
    } catch (_) {
      return <String, Map<String, Object?>>{};
    }
  }

  Future<void> _writePlaybackMetrics(
    SourcePriorityCategory category,
    Map<String, Map<String, Object?>> metrics,
  ) async {
    await (await _prefs).setString(
      '$_playbackMetricsPrefix${category.name}',
      jsonEncode(metrics),
    );
  }

  Future<void> _sortMeasuredBackups(
    SourcePriorityCategory category,
    Map<String, Map<String, Object?>> metrics,
  ) async {
    final backups = await getKeys(category, SourcePriorityLane.backup);
    final manualKeys = await _manualBackupKeys(category);
    final measuredPositions = <int>[
      for (var index = 0; index < backups.length; index++)
        if (!manualKeys.contains(backups[index]) &&
            metrics.containsKey(backups[index]))
          index,
    ];
    if (measuredPositions.length < 2) return;

    int successes(String key) =>
        (metrics[key]?['successes'] as num?)?.toInt() ?? 0;
    int failures(String key) =>
        (metrics[key]?['failures'] as num?)?.toInt() ?? 0;
    double failureRatio(String key) {
      final total = successes(key) + failures(key);
      return total == 0 ? 1 : failures(key) / total;
    }

    double latency(String key) =>
        (metrics[key]?['averageStartupMs'] as num?)?.toDouble() ?? 120000;

    final ranked =
        measuredPositions.map((index) => backups[index]).toList(growable: false)
          ..sort((left, right) {
            final reliability = failureRatio(
              left,
            ).compareTo(failureRatio(right));
            if (reliability != 0) return reliability;
            final byLatency = latency(left).compareTo(latency(right));
            if (byLatency != 0) return byLatency;
            final byVolume = successes(right).compareTo(successes(left));
            if (byVolume != 0) return byVolume;
            return left.compareTo(right);
          });

    final reordered = List<String>.of(backups);
    for (var index = 0; index < measuredPositions.length; index++) {
      reordered[measuredPositions[index]] = ranked[index];
    }
    await setKeys(category, SourcePriorityLane.backup, reordered);
  }

  Future<bool> addKey(
    SourcePriorityCategory category,
    SourcePriorityLane lane,
    String key,
  ) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return false;
    final current = await getKeys(category, lane);
    if (current.contains(normalizedKey)) {
      if (lane == SourcePriorityLane.backup) {
        final manual = await _manualBackupKeys(category);
        manual.add(normalizedKey);
        await _pinBackupOrder(category, manual);
      }
      return true;
    }
    final otherLane = lane == SourcePriorityLane.primary
        ? SourcePriorityLane.backup
        : SourcePriorityLane.primary;
    if ((await getKeys(category, otherLane)).contains(normalizedKey)) {
      return false;
    }
    current.add(normalizedKey);
    await setKeys(category, lane, current);
    if (lane == SourcePriorityLane.backup) {
      await _pinBackupOrder(category, await getBackupKeys(category));
    }
    return true;
  }

  Future<void> removePriorityKey(SourcePriorityCategory category, String key) =>
      removeKey(category, SourcePriorityLane.primary, key);

  Future<void> removeBackupKey(SourcePriorityCategory category, String key) =>
      removeKey(category, SourcePriorityLane.backup, key);

  Future<void> removeKey(
    SourcePriorityCategory category,
    SourcePriorityLane lane,
    String key,
  ) async {
    final current = await getKeys(category, lane);
    current.remove(key);
    await setKeys(category, lane, current);
    if (lane == SourcePriorityLane.backup) {
      final manual = await _manualBackupKeys(category);
      manual.remove(key);
      await _pinBackupOrder(category, manual);
    }
  }

  /// Swaps two selected items while preserving their positions. The items may
  /// be in the same lane or in different lanes. Cross-lane swaps preserve the
  /// selected item's source slot and never create duplicates.
  Future<bool> swapKeys(
    SourcePriorityCategory category, {
    required String firstKey,
    required String secondKey,
  }) async {
    if (firstKey == secondKey) return false;
    final primary = await getKeys(category, SourcePriorityLane.primary);
    final backup = await getKeys(category, SourcePriorityLane.backup);
    final firstPrimary = primary.indexOf(firstKey);
    final secondPrimary = primary.indexOf(secondKey);
    final firstBackup = backup.indexOf(firstKey);
    final secondBackup = backup.indexOf(secondKey);
    final firstIsPrimary = firstPrimary >= 0;
    final secondIsPrimary = secondPrimary >= 0;
    final firstIndex = firstIsPrimary ? firstPrimary : firstBackup;
    final secondIndex = secondIsPrimary ? secondPrimary : secondBackup;
    if (firstIndex < 0 || secondIndex < 0) return false;

    if (firstIsPrimary && secondIsPrimary) {
      primary[firstPrimary] = secondKey;
      primary[secondPrimary] = firstKey;
    } else if (!firstIsPrimary && !secondIsPrimary) {
      backup[firstBackup] = secondKey;
      backup[secondBackup] = firstKey;
    } else if (firstIsPrimary) {
      primary[firstPrimary] = secondKey;
      backup[secondBackup] = firstKey;
    } else {
      backup[firstBackup] = secondKey;
      primary[secondPrimary] = firstKey;
    }

    final prefs = await _prefs;
    await prefs.setStringList(
      _key(category, SourcePriorityLane.primary),
      _normalize(primary),
    );
    await prefs.setStringList(
      _key(category, SourcePriorityLane.backup),
      _normalize(backup),
    );
    if (firstBackup >= 0 || secondBackup >= 0) {
      await _pinBackupOrder(category, await getBackupKeys(category));
    }
    return true;
  }

  /// Clears orphaned entries when a whole repository is removed.
  /// Source keys are stored as `<repository-url>::<source-id>`.
  Future<void> removeRepositorySources(String repositoryUrl) async {
    final prefix = '$repositoryUrl::';
    for (final category in SourcePriorityCategory.values) {
      for (final lane in SourcePriorityLane.values) {
        final current = await getKeys(category, lane);
        current.removeWhere((key) => key.startsWith(prefix));
        await setKeys(category, lane, current);
      }
      final manual = await _manualBackupKeys(category);
      manual.removeWhere((key) => key.startsWith(prefix));
      await _pinBackupOrder(category, manual);
    }
  }

  Future<void> reorderPriorityKey(
    SourcePriorityCategory category, {
    required int oldIndex,
    required int newIndex,
  }) => reorderKey(
    category,
    SourcePriorityLane.primary,
    oldIndex: oldIndex,
    newIndex: newIndex,
  );

  Future<void> reorderBackupKey(
    SourcePriorityCategory category, {
    required int oldIndex,
    required int newIndex,
  }) => reorderKey(
    category,
    SourcePriorityLane.backup,
    oldIndex: oldIndex,
    newIndex: newIndex,
  );

  Future<void> reorderKey(
    SourcePriorityCategory category,
    SourcePriorityLane lane, {
    required int oldIndex,
    required int newIndex,
  }) async {
    final current = await getKeys(category, lane);
    if (oldIndex < 0 || oldIndex >= current.length) return;
    var target = newIndex;
    if (target > oldIndex) target--;
    target = target.clamp(0, current.length - 1).toInt();
    final item = current.removeAt(oldIndex);
    current.insert(target, item);
    await setKeys(category, lane, current);
    if (lane == SourcePriorityLane.backup) {
      await _pinBackupOrder(category, await getBackupKeys(category));
    }
  }

  static List<String> _normalize(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final key = value.trim();
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(key);
    }
    return result;
  }
}
