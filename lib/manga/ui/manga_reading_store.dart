import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent source-to-catalogue binding for one AniList work.
///
/// A Mihon source result is not the catalogue identity: the AniList id remains
/// the stable work id, while sourceId + mangaUrl identify the concrete chapter
/// provider selected by the reader.
class MangaSourceBinding {
  const MangaSourceBinding({
    required this.anilistId,
    required this.sourceId,
    required this.sourceName,
    required this.mangaUrl,
    required this.mangaTitle,
    this.thumbnailUrl,
    this.updatedAt,
  });

  final int anilistId;
  final int sourceId;
  final String sourceName;
  final String mangaUrl;
  final String mangaTitle;
  final String? thumbnailUrl;
  final int? updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'anilistId': anilistId,
    'sourceId': sourceId,
    'sourceName': sourceName,
    'mangaUrl': mangaUrl,
    'mangaTitle': mangaTitle,
    'thumbnailUrl': thumbnailUrl,
    'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
  };

  factory MangaSourceBinding.fromJson(Map<String, dynamic> json) =>
      MangaSourceBinding(
        anilistId: (json['anilistId'] as num?)?.toInt() ?? 0,
        sourceId: (json['sourceId'] as num?)?.toInt() ?? 0,
        sourceName: '${json['sourceName'] ?? ''}',
        mangaUrl: '${json['mangaUrl'] ?? ''}',
        mangaTitle: '${json['mangaTitle'] ?? ''}',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
      );
}

class MangaChapterProgress {
  const MangaChapterProgress({
    required this.pageIndex,
    required this.totalPages,
    required this.isRead,
    this.updatedAt,
  });

  final int pageIndex;
  final int totalPages;
  final bool isRead;
  final int? updatedAt;

  double get fraction => totalPages <= 1
      ? (isRead ? 1 : 0)
      : ((pageIndex + 1) / totalPages).clamp(0.0, 1.0).toDouble();

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pageIndex': pageIndex,
    'totalPages': totalPages,
    'isRead': isRead,
    'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
  };

  factory MangaChapterProgress.fromJson(Map<String, dynamic> json) =>
      MangaChapterProgress(
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
        isRead: json['isRead'] == true,
        updatedAt: (json['updatedAt'] as num?)?.toInt(),
      );
}

/// UI and notification preferences scoped to a single AniList work.
/// Keeping these separate from reader settings prevents a reader preset from
/// accidentally resetting the detail page layout when the work is reopened.
class MangaWorkPreferences {
  const MangaWorkPreferences({
    this.gridView = false,
    this.ascendingInList = true,
    this.scanlator,
    this.selectedTab = 0,
    this.notifyNewChapters = false,
    this.lastKnownChapterCount = 0,
    this.notificationSourceId,
  });

  final bool gridView;
  final bool ascendingInList;
  final String? scanlator;
  final int selectedTab;
  final bool notifyNewChapters;
  final int lastKnownChapterCount;
  final int? notificationSourceId;

  MangaWorkPreferences copyWith({
    bool? gridView,
    bool? ascendingInList,
    String? scanlator,
    bool clearScanlator = false,
    int? selectedTab,
    bool? notifyNewChapters,
    int? lastKnownChapterCount,
    int? notificationSourceId,
    bool clearNotificationSourceId = false,
  }) => MangaWorkPreferences(
    gridView: gridView ?? this.gridView,
    ascendingInList: ascendingInList ?? this.ascendingInList,
    scanlator: clearScanlator ? null : (scanlator ?? this.scanlator),
    selectedTab: selectedTab ?? this.selectedTab,
    notifyNewChapters: notifyNewChapters ?? this.notifyNewChapters,
    lastKnownChapterCount: lastKnownChapterCount ?? this.lastKnownChapterCount,
    notificationSourceId: clearNotificationSourceId
        ? null
        : (notificationSourceId ?? this.notificationSourceId),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'gridView': gridView,
    'ascendingInList': ascendingInList,
    'scanlator': scanlator,
    'selectedTab': selectedTab,
    'notifyNewChapters': notifyNewChapters,
    'lastKnownChapterCount': lastKnownChapterCount,
    'notificationSourceId': notificationSourceId,
  };

  factory MangaWorkPreferences.fromJson(Map<String, dynamic> json) =>
      MangaWorkPreferences(
        gridView: json['gridView'] == true,
        ascendingInList: json['ascendingInList'] != false,
        scanlator: json['scanlator'] is String
            ? (json['scanlator'] as String).trim().isEmpty
                  ? null
                  : json['scanlator'] as String
            : null,
        selectedTab: ((json['selectedTab'] as num?)?.toInt() ?? 0)
            .clamp(0, 3)
            .toInt(),
        notifyNewChapters: json['notifyNewChapters'] == true,
        lastKnownChapterCount:
            (json['lastKnownChapterCount'] as num?)?.toInt() ?? 0,
        notificationSourceId: (json['notificationSourceId'] as num?)?.toInt(),
      );
}

/// SharedPreferences-backed state used by the Manga detail page and reader.
/// Progress is scoped to (AniList work, Mihon source, chapter URL) so identical
/// chapter identifiers from unrelated sources cannot collide.
class MangaReadingStore {
  MangaReadingStore._();

  static final MangaReadingStore instance = MangaReadingStore._();
  static const String _bindingsKey = 'raven.manga.source_bindings.v1';
  static const String _progressKey = 'raven.manga.chapter_progress.v1';
  static const String _readerSettingsKey = 'raven.manga.reader_settings.v1';
  static const String _savedWorksKey = 'raven.manga.saved_works.v1';
  static const String _readingStatusesKey = 'raven.manga.reading_statuses.v1';
  static const String _lastGoodMangaSourceKey =
      'raven.manga.last_good_source.v1';
  static const String _workPreferencesKey = 'raven.manga.work_preferences.v1';
  static const String _pinnedMihonSourcesKey = 'raven.manga.pinned_sources.v1';
  Future<void> _writeTail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final next = _writeTail.then<T>((_) => operation());
    _writeTail = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return next;
  }

  Future<Map<String, dynamic>> _readMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeMap(String key, Map<String, dynamic> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(values));
  }

  Future<MangaSourceBinding?> bindingFor(int anilistId) async {
    final values = await _readMap(_bindingsKey);
    final raw = values['$anilistId'];
    if (raw is! Map) return null;
    final binding = MangaSourceBinding.fromJson(Map<String, dynamic>.from(raw));
    if (binding.sourceId <= 0 || binding.mangaUrl.isEmpty) return null;
    return binding;
  }

  Future<void> saveBinding(MangaSourceBinding binding) => _serialized(() async {
    final values = await _readMap(_bindingsKey);
    values['${binding.anilistId}'] = binding.toJson();
    await _writeMap(_bindingsKey, values);
  });

  Future<void> removeBinding(int anilistId) => _serialized(() async {
    final values = await _readMap(_bindingsKey);
    values.remove('$anilistId');
    await _writeMap(_bindingsKey, values);
  });

  /// Last successfully used manga source. New unbound works try it first,
  /// then continue through every other installed source if no exact title
  /// alias match is found. Existing per-work bindings remain authoritative.
  Future<int?> lastGoodMangaSourceId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_lastGoodMangaSourceKey);
    return value != null && value > 0 ? value : null;
  }

  Future<void> rememberLastGoodMangaSourceId(int sourceId) =>
      _serialized(() async {
        if (sourceId <= 0) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastGoodMangaSourceKey, sourceId);
      });

  /// Forget the remembered provider so the next manga work performs a fresh
  /// ordered source sweep. This is the explicit "Auto Resolve" action in the
  /// source picker; ordinary title pins remain independent of this preference.
  Future<void> clearLastGoodMangaSourceId() => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastGoodMangaSourceKey);
  });

  String _progressId(int anilistId, int sourceId, String chapterUrl) =>
      '$anilistId::$sourceId::$chapterUrl';

  Future<Map<String, MangaChapterProgress>> progressForWork(
    int anilistId,
    int sourceId,
  ) async {
    final values = await _readMap(_progressKey);
    final result = <String, MangaChapterProgress>{};
    final prefix = '$anilistId::$sourceId::';
    for (final entry in values.entries) {
      if (!entry.key.startsWith(prefix) || entry.value is! Map) continue;
      result[entry.key.substring(
        prefix.length,
      )] = MangaChapterProgress.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return result;
  }

  Future<MangaChapterProgress?> progressForChapter(
    int anilistId,
    int sourceId,
    String chapterUrl,
  ) async {
    final values = await _readMap(_progressKey);
    final raw = values[_progressId(anilistId, sourceId, chapterUrl)];
    if (raw is! Map) return null;
    return MangaChapterProgress.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> saveProgress({
    required int anilistId,
    required int sourceId,
    required String chapterUrl,
    required int pageIndex,
    required int totalPages,
    bool? isRead,
  }) => _serialized(() async {
    final values = await _readMap(_progressKey);
    final id = _progressId(anilistId, sourceId, chapterUrl);
    final previous = values[id] is Map
        ? MangaChapterProgress.fromJson(
            Map<String, dynamic>.from(values[id] as Map),
          )
        : null;
    values[id] = MangaChapterProgress(
      pageIndex: pageIndex
          .clamp(0, totalPages > 0 ? totalPages - 1 : 0)
          .toInt(),
      totalPages: totalPages,
      isRead: isRead ?? previous?.isRead ?? false,
    ).toJson();
    await _writeMap(_progressKey, values);
  });

  Future<void> setRead({
    required int anilistId,
    required int sourceId,
    required String chapterUrl,
    required bool isRead,
  }) => _serialized(() async {
    final values = await _readMap(_progressKey);
    final id = _progressId(anilistId, sourceId, chapterUrl);
    final previous = values[id] is Map
        ? MangaChapterProgress.fromJson(
            Map<String, dynamic>.from(values[id] as Map),
          )
        : null;
    values[id] = MangaChapterProgress(
      pageIndex: isRead ? (previous?.pageIndex ?? 0) : 0,
      totalPages: previous?.totalPages ?? 0,
      isRead: isRead,
    ).toJson();
    await _writeMap(_progressKey, values);
  });

  Future<bool> isSaved(int anilistId) async {
    final values = await _readMap(_savedWorksKey);
    return values['$anilistId'] == true;
  }

  /// Toggles the local Manga library entry and returns its new saved state.
  Future<bool> toggleSaved(int anilistId) => _serialized(() async {
    final values = await _readMap(_savedWorksKey);
    final key = '$anilistId';
    final saved = values[key] == true;
    if (saved) {
      values.remove(key);
    } else {
      values[key] = true;
    }
    await _writeMap(_savedWorksKey, values);
    return !saved;
  });

  Future<String> readingStatusFor(int anilistId) async {
    final values = await _readMap(_readingStatusesKey);
    final status = values['$anilistId'];
    return status is String && status.isNotEmpty ? status : 'PLANNING';
  }

  Future<void> saveReadingStatus(int anilistId, String status) =>
      _serialized(() async {
        final values = await _readMap(_readingStatusesKey);
        values['$anilistId'] = status;
        await _writeMap(_readingStatusesKey, values);
      });

  Future<MangaWorkPreferences> workPreferencesFor(int anilistId) async {
    // A route may be reopened immediately after dispose queued its final save.
    // Wait for queued writes before restoring preferences to avoid a stale read.
    await _writeTail;
    final values = await _readMap(_workPreferencesKey);
    final raw = values['$anilistId'];
    if (raw is! Map) return const MangaWorkPreferences();
    return MangaWorkPreferences.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Atomically merges a preference change with the latest stored value.
  /// This prevents a chapter refresh (which only changes the notification
  /// baseline) from overwriting a grid/order/tab choice made while it was in
  /// flight, and vice versa.
  Future<MangaWorkPreferences> updateWorkPreferences(
    int anilistId,
    MangaWorkPreferences Function(MangaWorkPreferences current) update,
  ) => _serialized(() async {
    final values = await _readMap(_workPreferencesKey);
    final raw = values['$anilistId'];
    final current = raw is Map
        ? MangaWorkPreferences.fromJson(Map<String, dynamic>.from(raw))
        : const MangaWorkPreferences();
    final next = update(current);
    values['$anilistId'] = next.toJson();
    await _writeMap(_workPreferencesKey, values);
    return next;
  });

  Future<void> saveWorkPreferences(
    int anilistId,
    MangaWorkPreferences preferences,
  ) async {
    await updateWorkPreferences(anilistId, (_) => preferences);
  }

  Future<List<int>> pinnedMihonSourceOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pinnedMihonSourcesKey) ?? const <String>[];
    final result = <int>[];
    final seen = <int>{};
    for (final item in raw) {
      final id = int.tryParse(item);
      if (id != null && id > 0 && seen.add(id)) result.add(id);
    }
    return result;
  }

  Future<Set<int>> pinnedMihonSourceIds() async =>
      (await pinnedMihonSourceOrder()).toSet();

  /// Toggle a source's pinned state; most recently pinned sources stay first.
  /// Returns true when the source is now pinned.
  Future<bool> togglePinnedMihonSource(int sourceId) => _serialized(() async {
    if (sourceId <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pinnedMihonSourcesKey) ?? const <String>[];
    final ids = <int>[];
    final seen = <int>{};
    for (final item in raw) {
      final id = int.tryParse(item);
      if (id != null && id > 0 && seen.add(id)) ids.add(id);
    }
    final pinned = !seen.contains(sourceId);
    if (pinned) {
      ids.insert(0, sourceId);
    } else {
      ids.remove(sourceId);
    }
    await prefs.setStringList(
      _pinnedMihonSourcesKey,
      ids.map((id) => id.toString()).toList(growable: false),
    );
    return pinned;
  });

  Future<Map<String, dynamic>> readerSettings() => _readMap(_readerSettingsKey);

  Future<void> saveReaderSettings(Map<String, dynamic> settings) =>
      _serialized(() => _writeMap(_readerSettingsKey, settings));
}
