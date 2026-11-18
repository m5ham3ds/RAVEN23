import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small persistent cache for the AniList home catalogues.
///
/// Catalogue responses are shared between Manga, Manhwa and Manhua screens,
/// survive process restarts, and are retained for offline use after freshness
/// expires. Search and work-detail responses are intentionally not stored here.
class AniListCatalogueCache {
  AniListCatalogueCache({SharedPreferences? preferences})
    : _preferences = preferences;

  static const Duration freshFor = Duration(minutes: 15);
  static const Duration maxStale = Duration(days: 7);
  static const String _prefix = 'raven23.anilist.catalogue.v1.';
  // SharedPreferences is asynchronous. Serialize every mutation across cache
  // instances so a write that races Clear Cache cannot finish after the clear.
  static Future<void> _pendingMutation = Future<void>.value();

  static Future<void> _serialize(Future<void> Function() operation) {
    final next = _pendingMutation.then((_) => operation());
    _pendingMutation = next.catchError((Object _) {});
    return next;
  }

  final SharedPreferences? _preferences;
  Future<SharedPreferences>? _preferencesFuture;

  Future<SharedPreferences> get _prefs async {
    final supplied = _preferences;
    if (supplied != null) return supplied;
    return _preferencesFuture ??= SharedPreferences.getInstance();
  }

  String _storageKey(String key) => '$_prefix$key';

  Future<AniListCatalogueCacheEntry?> read(String key, {DateTime? now}) async {
    try {
      final raw = (await _prefs).getString(_storageKey(key));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final payload = decoded['data'];
      final fetchedAt = decoded['fetchedAt'];
      if (payload is! Map || fetchedAt is! int) return null;
      final entry = AniListCatalogueCacheEntry(
        data: Map<String, dynamic>.from(payload),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetchedAt, isUtc: true),
      );
      final age = (now ?? DateTime.now().toUtc()).difference(entry.fetchedAt);
      if (age.isNegative || age > freshFor + maxStale) {
        await remove(key);
        return null;
      }
      return entry;
    } catch (_) {
      // A malformed entry should not be decoded again on every page open.
      await remove(key);
      return null;
    }
  }

  Future<void> write(
    String key,
    Map<String, dynamic> data, {
    DateTime? fetchedAt,
    bool Function()? shouldWrite,
  }) async {
    try {
      await _serialize(() async {
        if (shouldWrite != null && !shouldWrite()) return;
        final preferences = await _prefs;
        // The generation may change while SharedPreferences is initializing.
        if (shouldWrite != null && !shouldWrite()) return;
        final value = <String, Object>{
          'fetchedAt': (fetchedAt ?? DateTime.now().toUtc())
              .toUtc()
              .millisecondsSinceEpoch,
          'data': data,
        };
        await preferences.setString(_storageKey(key), jsonEncode(value));
      });
    } catch (_) {
      // A catalogue response remains usable even if persistence is unavailable.
    }
  }

  Future<void> remove(String key) async {
    try {
      await _serialize(() async {
        await (await _prefs).remove(_storageKey(key));
      });
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  Future<void> clear() async {
    try {
      await _serialize(() async {
        final preferences = await _prefs;
        final keys = preferences
            .getKeys()
            .where((key) => key.startsWith(_prefix))
            .toList(growable: false);
        for (final key in keys) {
          await preferences.remove(key);
        }
      });
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  static Future<void> clearAll() => AniListCatalogueCache().clear();
}

class AniListCatalogueCacheEntry {
  const AniListCatalogueCacheEntry({
    required this.data,
    required this.fetchedAt,
  });

  final Map<String, dynamic> data;
  final DateTime fetchedAt;

  bool isFresh({DateTime? now}) =>
      (now ?? DateTime.now().toUtc()).difference(fetchedAt) <=
      AniListCatalogueCache.freshFor;
}
