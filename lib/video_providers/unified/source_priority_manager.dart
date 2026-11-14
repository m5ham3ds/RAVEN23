import 'package:shared_preferences/shared_preferences.dart';

/// The three independent search lanes used by the unified VOD resolver.
enum SourcePriorityCategory { movies, series, anime }

/// A source can be placed in exactly one of the two editable lists for a media
/// category. The same source may intentionally be selected in another media
/// category (for example, both Movies and Series).
enum SourcePriorityLane { primary, backup }

/// Persists stable source identities, not list indexes or repository names.
/// Primary and backup lists are user-owned ordered lanes; removing a source
/// from either lane never uninstalls it from the repository catalogue.
class SourcePriorityManager {
  SourcePriorityManager({SharedPreferences? preferences})
    : _preferences = preferences;

  static const int maxPrimarySources = 20;
  static const int maxBackupSources = 30;
  static const int maxTotalSources = maxPrimarySources + maxBackupSources;

  /// Backwards-compatible alias for older call sites/tests.
  static const int maxPrioritySources = maxPrimarySources;

  static const String _configuredKey =
      'raven23.source_priorities.initialized.v1';

  // Keep the v1 primary key so existing users retain their priority order.
  static const String _primaryPrefix = 'raven23.source_priorities.v1.';
  static const String _backupPrefix = 'raven23.source_backups.v1.';

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

  int _limit(SourcePriorityLane lane) =>
      lane == SourcePriorityLane.primary ? maxPrimarySources : maxBackupSources;

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
    final normalized = _normalize(raw, _limit(lane));
    if (lane == SourcePriorityLane.backup) {
      final primary = (prefs.getStringList(
            _key(category, SourcePriorityLane.primary),
          ) ??
          const <String>[]).toSet();
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
  ) => setKeys(category, SourcePriorityLane.backup, keys);

  /// One-time upgrade path: convert the old implicit automatic-backup pool
  /// into an editable backup list without overwriting a user's saved list.
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
    final normalized = _normalize(keys, _limit(lane));
    final otherLane = lane == SourcePriorityLane.primary
        ? SourcePriorityLane.backup
        : SourcePriorityLane.primary;
    final otherKeys = (prefs.getStringList(_key(category, otherLane)) ??
            const <String>[])
        .toSet();
    final unique = normalized.where((key) => !otherKeys.contains(key)).toList();
    await prefs.setStringList(_key(category, lane), unique);
  }

  Future<bool> canAddPriorityKey(SourcePriorityCategory category) =>
      canAddKey(category, SourcePriorityLane.primary);

  Future<bool> canAddKey(
    SourcePriorityCategory category,
    SourcePriorityLane lane,
  ) async => (await getKeys(category, lane)).length < _limit(lane);

  Future<bool> addPriorityKey(
    SourcePriorityCategory category,
    String key,
  ) => addKey(category, SourcePriorityLane.primary, key);

  Future<bool> addKey(
    SourcePriorityCategory category,
    SourcePriorityLane lane,
    String key,
  ) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return false;
    final current = await getKeys(category, lane);
    if (current.contains(normalizedKey)) return true;
    final otherLane = lane == SourcePriorityLane.primary
        ? SourcePriorityLane.backup
        : SourcePriorityLane.primary;
    if ((await getKeys(category, otherLane)).contains(normalizedKey)) {
      return false;
    }
    if (current.length >= _limit(lane)) return false;
    current.add(normalizedKey);
    await setKeys(category, lane, current);
    return true;
  }

  Future<void> removePriorityKey(
    SourcePriorityCategory category,
    String key,
  ) => removeKey(category, SourcePriorityLane.primary, key);

  Future<void> removeBackupKey(
    SourcePriorityCategory category,
    String key,
  ) => removeKey(category, SourcePriorityLane.backup, key);

  Future<void> removeKey(
    SourcePriorityCategory category,
    SourcePriorityLane lane,
    String key,
  ) async {
    final current = await getKeys(category, lane);
    current.remove(key);
    await setKeys(category, lane, current);
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
      _normalize(primary, maxPrimarySources),
    );
    await prefs.setStringList(
      _key(category, SourcePriorityLane.backup),
      _normalize(backup, maxBackupSources),
    );
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
  }

  static List<String> _normalize(Iterable<String> values, int limit) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final key = value.trim();
      if (key.isEmpty || !seen.add(key)) continue;
      result.add(key);
      if (result.length == limit) break;
    }
    return result;
  }
}
