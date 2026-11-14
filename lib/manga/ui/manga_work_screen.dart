import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../anilist/anilist_manga_service.dart';
import '../mihon/mihon_runtime.dart';
import 'manga_chapter_download_store.dart';
import 'manga_reading_store.dart';
import 'manga_notification_service.dart';
import 'manga_reader_screen.dart';
import 'manga_source_matcher.dart';

/// A single work-centred Manga/Manhwa/Manhua experience.
///
/// The AniList id is the catalogue identity. The screen may bind it to a real
/// Mihon result after a strict automatic title match, or after the user corrects
/// the result manually. Chapter and page requests always use that source's
/// native URL and source id (never a guessed or pseudo-source id).
class MangaWorkScreen extends StatefulWidget {
  const MangaWorkScreen({
    required this.title,
    required this.service,
    super.key,
  });

  final MangaTitle title;
  final AniListMangaService service;

  @override
  State<MangaWorkScreen> createState() => _MangaWorkScreenState();
}

class _MangaWorkScreenState extends State<MangaWorkScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MihonRuntimeService _runtime = MihonRuntimeService.instance;
  final MangaReadingStore _store = MangaReadingStore.instance;
  late final TabController _tabs;
  late final TextEditingController _sourceFilterController;
  final ScrollController _outerScrollController = ScrollController();
  final GlobalKey _tabBarKey = GlobalKey();
  final GlobalKey _detailsSynopsisKey = GlobalKey();
  int _lastPinnedTabIndex = 0;
  bool _tabBarRevealPending = false;
  bool _tabBarPinQueued = false;

  late MangaTitle _title = widget.title;
  MangaSourceBinding? _binding;
  MihonSourceInfo? _boundSource;
  List<Map<String, dynamic>> _chapters = const <Map<String, dynamic>>[];
  Map<String, MangaChapterProgress> _progress =
      const <String, MangaChapterProgress>{};
  Set<String> _downloadedChapters = const <String>{};
  List<MihonSourceInfo> _sources = const <MihonSourceInfo>[];
  List<_MangaSourceMatch> _matches = const <_MangaSourceMatch>[];

  bool _sourcesLoaded = false;
  bool _sourceManagerOpen = false;
  bool _loadingTitle = false;
  bool _loadingBoundWork = false;
  bool _loadingSources = false;
  bool _searchingAll = false;
  bool _autoResolving = false;
  bool _gridView = false;
  bool _ascendingInList = true;
  bool _notifyNewChapters = false;
  bool _workPreferencesLoaded = false;
  final Map<int, Future<bool>> _sourceSettingsAvailability =
      <int, Future<bool>>{};
  String? _autoResolveSourceName;
  int _autoResolveIndex = 0;
  int _autoResolveTotal = 0;
  bool _isSaved = false;
  String _readingStatus = 'PLANNING';
  String? _boundError;
  String? _sourceError;
  String? _scanlator;
  int _sourceRequest = 0;
  int _boundLoadRequest = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(_handleTabChanged);
    _sourceFilterController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Flush the latest visible per-work controls when the detail route is
    // popped. The store serializes this with any pending chapter refresh save.
    if (_workPreferencesLoaded) unawaited(_persistWorkPreferences());
    _sourceRequest++;
    _boundLoadRequest++;
    _tabs.removeListener(_handleTabChanged);
    _tabs.dispose();
    _outerScrollController.dispose();
    _sourceFilterController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    // TabController notifies repeatedly while a swipe is in progress. Reveal
    // only after the selected index has settled, so the tab strip does not
    // chase every animation frame.
    if (_tabs.indexIsChanging || _tabs.index == _lastPinnedTabIndex) return;
    _lastPinnedTabIndex = _tabs.index;
    _scheduleTabBarPin();
  }

  void _scheduleTabBarPin() {
    if (_tabBarRevealPending) {
      _tabBarPinQueued = true;
      return;
    }
    _tabBarRevealPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _tabBarRevealPending = false;
        _tabBarPinQueued = false;
        return;
      }
      final tabContext = _tabBarKey.currentContext;
      if (tabContext == null) {
        _tabBarRevealPending = false;
        _tabBarPinQueued = false;
        return;
      }
      // Scroll to the tab strip itself rather than guessing the outer header's
      // max extent. This keeps the exact same visible top edge on every page,
      // including short/empty tabs and horizontal TabBarView swipes.
      unawaited(
        Scrollable.ensureVisible(
          tabContext,
          // Leave the collapsed app bar visible above the pinned tabs, as in
          // Zangetsu (the strip sits immediately below its toolbar).
          alignment: 0.10,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ).whenComplete(() {
          _tabBarRevealPending = false;
          if (_tabBarPinQueued && mounted) {
            _tabBarPinQueued = false;
            _scheduleTabBarPin();
          }
        }),
      );
    });
  }

  Future<void> _revealSynopsis() async {
    // Switch to Details first, then pin the tab strip before revealing the
    // synopsis section itself. This mirrors Zangetsu's _revealTab(3) flow but
    // continues to the exact synopsis anchor requested by the user.
    _lastPinnedTabIndex = 3;
    _tabs.animateTo(
      3,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final tabContext = _tabBarKey.currentContext;
    if (tabContext != null) {
      await Scrollable.ensureVisible(
        tabContext,
        alignment: 0.10,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    final synopsisContext = _detailsSynopsisKey.currentContext;
    if (synopsisContext != null) {
      await Scrollable.ensureVisible(
        synopsisContext,
        alignment: 0.08,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _persistWorkPreferences() async {
    if (!_workPreferencesLoaded) return;
    final titleId = _title.id;
    final gridView = _gridView;
    final ascendingInList = _ascendingInList;
    final scanlator = _scanlator;
    final notifyNewChapters = _notifyNewChapters;
    await _store.updateWorkPreferences(
      titleId,
      (current) => current.copyWith(
        gridView: gridView,
        ascendingInList: ascendingInList,
        scanlator: scanlator,
        clearScanlator: scanlator == null,
        selectedTab: 0,
        notifyNewChapters: notifyNewChapters,
      ),
    );
  }

  void _setScanlator(String? value) {
    setState(() => _scanlator = value);
    unawaited(_persistWorkPreferences());
  }

  Future<void> _toggleChapterNotifications() async {
    if (_notifyNewChapters) {
      setState(() => _notifyNewChapters = false);
      await _store.updateWorkPreferences(
        _title.id,
        (current) => current.copyWith(notifyNewChapters: false),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('manga_notifications_disabled'))),
      );
      return;
    }

    if (_binding == null || _boundSource == null || _chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('manga_notify_requires_source'))),
      );
      await _openSourcePicker();
      return;
    }

    final granted = await MangaNotificationService.instance.requestPermission();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('manga_notifications_permission_needed'))),
      );
      return;
    }

    setState(() => _notifyNewChapters = true);
    await _store.updateWorkPreferences(
      _title.id,
      (current) => current.copyWith(
        notifyNewChapters: true,
        lastKnownChapterCount: _chapters.length,
        notificationSourceId: _boundSource!.id,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('manga_notifications_enabled'))));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_notifyNewChapters ||
        !_workPreferencesLoaded) {
      return;
    }
    final binding = _binding;
    if (binding != null) {
      unawaited(_loadBoundWork(binding, refresh: true));
    }
  }

  Future<void> _initialize() async {
    try {
      // The refreshed AniList record carries native titles and synonyms. Resolve
      // only after it has completed so source search has the full alias set.
      await _refreshTitle();
      if (!mounted) return;
      final results = await Future.wait<Object?>(<Future<Object?>>[
        _store.bindingFor(_title.id),
        _store.isSaved(_title.id),
        _store.readingStatusFor(_title.id),
        _store.lastGoodMangaSourceId(),
        _store.workPreferencesFor(_title.id),
      ]);
      final binding = results[0] as MangaSourceBinding?;
      final lastGoodSourceId = results[3] as int?;
      final workPreferences = results[4] as MangaWorkPreferences;
      if (!mounted) return;
      setState(() {
        _binding = binding;
        _isSaved = results[1] as bool;
        _readingStatus = results[2] as String;
        _gridView = workPreferences.gridView;
        _ascendingInList = workPreferences.ascendingInList;
        _scanlator = workPreferences.scanlator;
        _notifyNewChapters = workPreferences.notifyNewChapters;
        _tabs.index = 0;
        _workPreferencesLoaded = true;
      });
      if (binding != null) {
        // A per-title binding is a firm choice, just like Zangetsu's title pin.
        // Never overwrite it with an automatic match when reopening this work.
        await _loadInstalledSources(reload: true);
        if (mounted) await _loadBoundWork(binding);
      } else {
        await _autoResolveInstalledSource(lastGoodSourceId: lastGoodSourceId);
      }
    } catch (error) {
      if (mounted) setState(() => _boundError = error.toString());
    }
  }

  Future<void> _refreshTitle() async {
    setState(() => _loadingTitle = true);
    try {
      final detail = await widget.service.detail(widget.title.id);
      if (!mounted) return;
      setState(() {
        _title = detail;
        _loadingTitle = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTitle = false);
    }
  }

  Future<void> _shareWork() async {
    final url = 'https://anilist.co/manga/${_title.id}';
    await Share.share('${_title.title}\n$url');
  }

  Future<void> _chooseReadingStatus() async {
    const statuses = <String>[
      'PLANNING',
      'READING',
      'COMPLETED',
      'PAUSED',
      'DROPPED',
      'REPEATING',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppPalette.of(context).page,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Text(
                tr('manga_reading_status'),
                style: AppType.sectionHeader.copyWith(
                  color: AppPalette.of(sheetContext).foreground,
                ),
              ),
            ),
            for (final status in statuses)
              ListTile(
                leading: Icon(
                  _readingStatus == status
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                title: Text(tr('manga_status_${status.toLowerCase()}')),
                onTap: () => Navigator.pop(sheetContext, status),
              ),
            if (_isSaved) ...<Widget>[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: Text(tr('manga_remove_from_list')),
                onTap: () => Navigator.pop(sheetContext, '__remove__'),
              ),
            ],
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (selected == '__remove__') {
      if (!_isSaved) return;
      final saved = await _store.toggleSaved(_title.id);
      if (mounted) setState(() => _isSaved = saved);
      return;
    }
    if (selected == _readingStatus && _isSaved) return;
    await _store.saveReadingStatus(_title.id, selected);
    var saved = _isSaved;
    if (!saved) saved = await _store.toggleSaved(_title.id);
    if (mounted) {
      setState(() {
        _readingStatus = selected;
        _isSaved = saved;
      });
    }
  }

  Future<void> _loadInstalledSources({bool reload = false}) async {
    setState(() {
      _loadingSources = true;
      _sourceError = null;
    });
    try {
      final sources = await _runtime.listSources(reload: reload);
      if (!mounted) return;
      MihonSourceInfo? resolved;
      final binding = _binding;
      if (binding != null) {
        for (final candidate in sources) {
          if (candidate.id == binding.sourceId) {
            resolved = candidate;
            break;
          }
        }
      }
      setState(() {
        _sources = sources;
        _sourcesLoaded = true;
        _loadingSources = false;
        if (binding != null) {
          _boundSource = resolved;
          if (resolved == null) {
            _boundError = tr('manga_bound_source_missing');
          } else if (_boundError == tr('manga_bound_source_missing')) {
            _boundError = null;
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sourceError = error.toString();
        _loadingSources = false;
      });
    }
  }

  Future<void> _loadBoundWork(
    MangaSourceBinding binding, {
    bool refresh = false,
  }) async {
    final request = ++_boundLoadRequest;
    setState(() {
      _loadingBoundWork = true;
      _boundError = null;
    });
    try {
      // Mihon caches catalogue/detail/chapter JSON in its shared OkHttp cache.
      // A visible Refresh action must evict that cache before asking for chapters.
      if (refresh) await _runtime.clearCache();
      if (!mounted || request != _boundLoadRequest) return;
      var source = _boundSource;
      if (source == null || source.id != binding.sourceId) {
        final sources = _sourcesLoaded
            ? _sources
            : await _runtime.listSources();
        source = sources.cast<MihonSourceInfo?>().firstWhere(
          (item) => item?.id == binding.sourceId,
          orElse: () => null,
        );
      }
      if (source == null) {
        throw StateError(tr('manga_bound_source_missing'));
      }
      final resolvedSource = source;
      final rawChapters = await _runtime.chapters(
        resolvedSource.id,
        binding.mangaUrl,
      );
      final chapters = _sortChapters(rawChapters);
      final progress = await _store.progressForWork(
        _title.id,
        resolvedSource.id,
      );
      final downloaded = await MangaChapterDownloadStore.instance
          .downloadedChapterUrls(
            anilistId: _title.id,
            sourceId: resolvedSource.id,
          );
      if (!mounted || request != _boundLoadRequest) return;

      final workPreferences = await _store.workPreferencesFor(_title.id);
      final sameNotificationSource =
          workPreferences.notificationSourceId == resolvedSource.id;
      final previousChapterCount = sameNotificationSource
          ? workPreferences.lastKnownChapterCount
          : chapters.length;
      if (workPreferences.notifyNewChapters &&
          sameNotificationSource &&
          previousChapterCount > 0 &&
          chapters.length > previousChapterCount) {
        final added = chapters.length - previousChapterCount;
        await MangaNotificationService.instance.showNewChapters(
          anilistId: _title.id,
          title: _title.title,
          body: tr(
            'manga_new_chapters_notification_body',
            namedArgs: <String, String>{'count': '$added'},
          ),
        );
      }
      await _store.updateWorkPreferences(
        _title.id,
        (current) => current.copyWith(
          lastKnownChapterCount: chapters.length,
          notificationSourceId: resolvedSource.id,
        ),
      );
      if (!mounted || request != _boundLoadRequest) return;
      await _store.rememberLastGoodMangaSourceId(resolvedSource.id);
      if (!mounted || request != _boundLoadRequest) return;
      final availableScanlators = <String>{
        for (final chapter in chapters)
          if ('${chapter['scanlator'] ?? ''}'.trim().isNotEmpty)
            '${chapter['scanlator']}'.trim(),
      };
      setState(() {
        _boundSource = resolvedSource;
        _chapters = chapters;
        _progress = progress;
        _downloadedChapters = downloaded;
        _loadingBoundWork = false;
        if (_scanlator != null && !availableScanlators.contains(_scanlator)) {
          _scanlator = null;
        }
      });
      unawaited(_persistWorkPreferences());
    } catch (error) {
      if (!mounted || request != _boundLoadRequest) return;
      setState(() {
        _boundError = error.toString();
        _loadingBoundWork = false;
      });
    }
  }

  List<Map<String, dynamic>> _sortChapters(List<Map<String, dynamic>> input) {
    final values = <Map<String, dynamic>>[
      for (var index = 0; index < input.length; index++)
        <String, dynamic>{...input[index], '_sourceOrder': index},
    ];
    values.sort((left, right) {
      final a = parseMangaChapterNumber(
        left['chapter_number'] ?? left['chapterNumber'] ?? left['number'],
        _chapterSortTitle(left),
      );
      final b = parseMangaChapterNumber(
        right['chapter_number'] ?? right['chapterNumber'] ?? right['number'],
        _chapterSortTitle(right),
      );
      if (a != null && b != null) return a.compareTo(b);
      if (a != null) return -1;
      if (b != null) return 1;
      final byTitle = _naturalChapterTitleCompare(
        _chapterSortTitle(left),
        _chapterSortTitle(right),
      );
      if (byTitle != 0) return byTitle;
      return ((left['_sourceOrder'] as int?) ?? 0).compareTo(
        (right['_sourceOrder'] as int?) ?? 0,
      );
    });
    return values;
  }

  String _chapterSortTitle(Map<String, dynamic> chapter) {
    final name = '${chapter['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return '${chapter['title'] ?? ''}'.trim();
  }

  int _naturalChapterTitleCompare(String left, String right) {
    final pattern = RegExp(r'\d+(?:[.,]\d+)?|[^\d]+');
    final a = pattern
        .allMatches(left.toLowerCase())
        .map((match) => match.group(0)!)
        .toList(growable: false);
    final b = pattern
        .allMatches(right.toLowerCase())
        .map((match) => match.group(0)!)
        .toList(growable: false);
    final count = a.length < b.length ? a.length : b.length;
    for (var index = 0; index < count; index++) {
      final leftPart = a[index];
      final rightPart = b[index];
      final leftNumber = double.tryParse(leftPart.replaceAll(',', '.'));
      final rightNumber = double.tryParse(rightPart.replaceAll(',', '.'));
      final compared = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : leftPart.compareTo(rightPart);
      if (compared != 0) return compared;
    }
    return a.length.compareTo(b.length);
  }

  List<String> get _titleQueries => buildMangaTitleQueries(
    romaji: _title.title,
    english: _title.englishTitle,
    native: _title.nativeTitle,
    synonyms: _title.synonyms,
  );

  Future<void> _autoResolveInstalledSource({
    int? lastGoodSourceId,
    bool forceSweep = false,
  }) async {
    final request = ++_sourceRequest;
    if (!mounted) return;
    setState(() {
      _autoResolving = true;
      _autoResolveSourceName = null;
      _autoResolveIndex = 0;
      _autoResolveTotal = 0;
      _sourceError = null;
      _matches = const <_MangaSourceMatch>[];
    });

    try {
      if (forceSweep) {
        await _store.clearLastGoodMangaSourceId();
        lastGoodSourceId = null;
      } else {
        lastGoodSourceId ??= await _store.lastGoodMangaSourceId();
      }
      if (!mounted || request != _sourceRequest) return;
      if (!_sourcesLoaded || _sources.isEmpty) {
        await _loadInstalledSources(reload: true);
      }
      if (!mounted || request != _sourceRequest) return;
      final installed = List<MihonSourceInfo>.of(_sources);
      if (installed.isEmpty) {
        setState(() {
          _autoResolving = false;
          _sourceError = _sourceError ?? tr('manga_no_installed_sources');
        });
        return;
      }

      // Prefer the last successful provider first, but never let that global
      // preference block an unbound work from being found elsewhere. Search
      // every installed source until an exact match for one of AniList's title
      // aliases is found. A per-work binding remains authoritative and bypasses
      // this sweep entirely in _initialize.
      MihonSourceInfo? remembered;
      if (lastGoodSourceId != null) {
        for (final source in installed) {
          if (source.id == lastGoodSourceId) {
            remembered = source;
            break;
          }
        }
      }
      final candidates = <MihonSourceInfo>[
        if (remembered != null) remembered,
        ...installed.where((source) => source.id != remembered?.id),
      ];
      final suggestions = <_MangaSourceMatch>[];
      if (mounted && request == _sourceRequest) {
        setState(() => _autoResolveTotal = candidates.length);
      }

      for (var index = 0; index < candidates.length; index++) {
        if (!mounted || request != _sourceRequest) return;
        final source = candidates[index];
        setState(() {
          _autoResolveSourceName = source.name;
          _autoResolveIndex = index + 1;
        });

        final sourceMatches = await _searchOneSource(source);
        if (!mounted || request != _sourceRequest) return;
        suggestions.addAll(sourceMatches);
        _MangaSourceMatch? exact;
        for (final match in sourceMatches) {
          if (mangaTitleMatches(_titleQueries, match.title)) {
            exact = match;
            break;
          }
        }
        if (exact != null) {
          await _bindSourceMatch(exact, sourceRequest: request);
          return;
        }
      }

      suggestions.sort((a, b) => b.score.compareTo(a.score));
      if (!mounted || request != _sourceRequest) return;
      setState(() {
        _matches = List<_MangaSourceMatch>.unmodifiable(suggestions.take(8));
        _autoResolving = false;
        _autoResolveSourceName = null;
        if (suggestions.isEmpty) {
          _sourceError = tr('manga_no_exact_source_match');
        }
      });
    } catch (error) {
      if (!mounted || request != _sourceRequest) return;
      setState(() {
        _autoResolving = false;
        _autoResolveSourceName = null;
        _sourceError = error.toString();
      });
    }
  }

  Future<void> _findAcrossSources() async {
    final request = ++_sourceRequest;
    setState(() {
      _searchingAll = true;
      _matches = const <_MangaSourceMatch>[];
      _sourceError = null;
    });
    try {
      if (_sources.isEmpty) await _loadInstalledSources(reload: true);
      if (!mounted) return;
      final sources = _sources;
      if (sources.isEmpty) {
        setState(() {
          _searchingAll = false;
          _sourceError = tr('manga_no_installed_sources');
        });
        return;
      }
      final results = <_MangaSourceMatch>[];
      const batchSize = 3;
      for (var offset = 0; offset < sources.length; offset += batchSize) {
        if (!mounted || request != _sourceRequest) return;
        final batch = sources.skip(offset).take(batchSize).toList();
        final settled = await Future.wait<List<_MangaSourceMatch>>(
          batch.map(_searchOneSource),
        );
        for (final group in settled) {
          results.addAll(group);
        }
        if (mounted && request == _sourceRequest) {
          results.sort((a, b) => b.score.compareTo(a.score));
          setState(
            () => _matches = List<_MangaSourceMatch>.unmodifiable(results),
          );
        }
      }
      if (!mounted || request != _sourceRequest) return;
      results.sort((a, b) => b.score.compareTo(a.score));
      setState(() {
        _matches = List<_MangaSourceMatch>.unmodifiable(results);
        _searchingAll = false;
      });
    } catch (error) {
      if (!mounted || request != _sourceRequest) return;
      setState(() {
        _sourceError = error.toString();
        _searchingAll = false;
      });
    }
  }

  Future<List<_MangaSourceMatch>> _searchOneSource(
    MihonSourceInfo source,
  ) async {
    final found = <String, _MangaSourceMatch>{};
    for (final query in _titleQueries) {
      try {
        final items = await _runtime.search(source.id, query, page: 1);
        for (final item in items) {
          final title = '${item['title'] ?? ''}'.trim();
          final url = '${item['url'] ?? ''}'.trim();
          if (title.isEmpty || url.isEmpty) continue;
          final score = mangaTitleMatchScore(_titleQueries, title);
          final match = _MangaSourceMatch(
            source: source,
            item: item,
            score: score,
          );
          final previous = found[url];
          if (previous == null || score > previous.score) found[url] = match;
        }
      } catch (_) {
        // A single extension can be offline or require Cloudflare. Keep
        // searching the other installed sources instead of aborting the scan.
      }
    }
    final matches = found.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return matches.take(4).toList(growable: false);
  }

  Future<void> _openSourceSearch(MihonSourceInfo source) async {
    final selected = await showModalBottomSheet<_MangaSourceMatch>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppPalette.of(context).page,
      builder: (_) => _MangaSourceSearchSheet(
        source: source,
        sources: _sources.isEmpty ? <MihonSourceInfo>[source] : _sources,
        queries: _titleQueries,
        scoreFor: (value) => mangaTitleMatchScore(_titleQueries, value),
      ),
    );
    if (selected != null) await _bindSourceMatch(selected);
  }

  Widget _buildMihonSourceIcon(MihonSourceInfo source, {required double size}) {
    final encoded = source.iconBase64?.trim();
    if (encoded != null && encoded.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.memory(
            base64Decode(encoded),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackMihonSourceIcon(size),
          ),
        );
      } on FormatException {
        // Older or third-party extension builds may not expose a package icon.
      }
    }
    return _fallbackMihonSourceIcon(size);
  }

  Widget _fallbackMihonSourceIcon(double size) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppPalette.of(context).raisedSurface,
      borderRadius: BorderRadius.circular(9),
    ),
    child: const Icon(Icons.extension_rounded),
  );

  Future<bool> _settingsAvailable(MihonSourceInfo source) =>
      _sourceSettingsAvailability.putIfAbsent(
        source.id,
        () => _runtime.hasSettings(source.id).catchError((_) => false),
      );

  Future<void> _openSourcePicker() async {
    if (!mounted) return;
    if (!_sourcesLoaded || _sources.isEmpty) {
      await _loadInstalledSources(reload: true);
    }
    if (!mounted) return;
    if (_sources.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('manga_no_installed_sources'))));
      return;
    }

    // Manual source selection interrupts an in-progress automatic sweep.
    _sourceRequest++;
    if (_autoResolving) {
      setState(() {
        _autoResolving = false;
        _autoResolveSourceName = null;
      });
    }

    final palette = AppPalette.of(context);
    final pinnedOrder = await _store.pinnedMihonSourceOrder();
    final pinned = pinnedOrder.toSet();
    if (!mounted) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final initialExtent = (330 / screenHeight).clamp(.40, .48).toDouble();
    final selected = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: palette.page,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DefaultTabController(
        length: 2,
        child: DraggableScrollableSheet(
          initialChildSize: initialExtent,
          minChildSize: .26,
          maxChildSize: .92,
          expand: false,
          builder: (sheetContext, dragController) => StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final sourcesById = <int, MihonSourceInfo>{
                for (final source in _sources) source.id: source,
              };
              final orderedSources = <MihonSourceInfo>[
                for (final id in pinnedOrder)
                  if (sourcesById[id] != null) sourcesById[id]!,
                ..._sources.where((source) => !pinned.contains(source.id)),
              ];

              return Column(
                children: <Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.mutedText.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Theme.of(sheetContext).colorScheme.primary,
                    unselectedLabelColor: palette.mutedText,
                    indicatorColor: Theme.of(sheetContext).colorScheme.primary,
                    dividerColor: palette.hairline,
                    tabs: <Widget>[
                      Tab(text: tr('all')),
                      Tab(text: tr('manga')),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      controller: dragController,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(sheetContext).bottom + 22,
                      ),
                      children: <Widget>[
                        ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -2),
                          minVerticalPadding: 6,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                sheetContext,
                              ).colorScheme.primary.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Theme.of(sheetContext).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            tr('manga_auto_resolve_source'),
                            style: AppType.cardTitle.copyWith(
                              color: palette.foreground,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: Text(
                            tr('manga_auto_resolve_hint'),
                            style: AppType.metadata.copyWith(
                              color: palette.mutedText,
                            ),
                          ),
                          onTap: () => Navigator.pop(sheetContext, 'auto'),
                        ),
                        Divider(height: 1, color: palette.hairline),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
                          child: Text(
                            tr('manga_source_group_manga').toUpperCase(),
                            style: AppType.kicker.copyWith(
                              color: palette.mutedText,
                            ),
                          ),
                        ),
                        for (final source in orderedSources)
                          Builder(
                            builder: (_) {
                              final current = source.id == _boundSource?.id;
                              final isPinned = pinned.contains(source.id);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: current
                                        ? Theme.of(sheetContext)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: .13)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: current
                                        ? Border(
                                            left: BorderSide(
                                              color: Theme.of(
                                                sheetContext,
                                              ).colorScheme.primary,
                                              width: 3,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    visualDensity: const VisualDensity(
                                      vertical: -2,
                                    ),
                                    minVerticalPadding: 6,
                                    leading: _buildMihonSourceIcon(
                                      source,
                                      size: 42,
                                    ),
                                    title: Text(
                                      'Mihon · ${source.name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.cardTitle.copyWith(
                                        color: palette.foreground,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Mihon · ${source.lang.toLowerCase()}'
                                      '${source.isNsfw ? ' · ${tr('explicit_content')}' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.metadata.copyWith(
                                        color: palette.mutedText,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        if (isPinned)
                                          Icon(
                                            Icons.push_pin_rounded,
                                            size: 17,
                                            color: palette.mutedText,
                                          ),
                                        if (current)
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Theme.of(
                                              sheetContext,
                                            ).colorScheme.primary,
                                          ),
                                        FutureBuilder<bool>(
                                          future: _settingsAvailable(source),
                                          builder: (context, snapshot) =>
                                              PopupMenuButton<String>(
                                                tooltip: tr('more'),
                                                icon: Icon(
                                                  Icons.more_vert_rounded,
                                                  color: palette.mutedText,
                                                ),
                                                onSelected: (action) =>
                                                    unawaited(
                                                      _handleSourceAction(
                                                        source,
                                                        action,
                                                      ),
                                                    ),
                                                itemBuilder: (context) =>
                                                    <PopupMenuEntry<String>>[
                                                      if (source
                                                          .baseUrl
                                                          .isNotEmpty)
                                                        PopupMenuItem<String>(
                                                          value: 'solve',
                                                          child: Text(
                                                            tr(
                                                              'manga_source_solve_cloudflare',
                                                            ),
                                                          ),
                                                        ),
                                                      if (source
                                                          .baseUrl
                                                          .isNotEmpty)
                                                        PopupMenuItem<String>(
                                                          value: 'signin',
                                                          child: Text(
                                                            tr(
                                                              'manga_source_sign_in',
                                                            ),
                                                          ),
                                                        ),
                                                      if (snapshot.data == true)
                                                        PopupMenuItem<String>(
                                                          value: 'settings',
                                                          child: Text(
                                                            tr(
                                                              'manga_source_settings',
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                              ),
                                        ),
                                      ],
                                    ),
                                    onTap: () =>
                                        Navigator.pop(sheetContext, source),
                                    onLongPress: () async {
                                      final nowPinned = await _store
                                          .togglePinnedMihonSource(source.id);
                                      if (!sheetContext.mounted) return;
                                      setSheetState(() {
                                        if (nowPinned) {
                                          pinned.add(source.id);
                                          pinnedOrder.remove(source.id);
                                          pinnedOrder.insert(0, source.id);
                                        } else {
                                          pinned.remove(source.id);
                                          pinnedOrder.remove(source.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.push_pin_outlined,
                                size: 16,
                                color: palette.mutedText,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  tr('manga_source_pin_hint'),
                                  textAlign: TextAlign.center,
                                  style: AppType.metadata.copyWith(
                                    color: palette.mutedText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == 'auto') {
      await _resetToAutoResolve();
    } else if (selected is MihonSourceInfo) {
      await _selectSource(selected);
    }
  }

  Future<void> _resetToAutoResolve() async {
    final request = ++_sourceRequest;
    ++_boundLoadRequest;
    await _store.removeBinding(_title.id);
    if (!mounted || request != _sourceRequest) return;
    setState(() {
      _binding = null;
      _boundSource = null;
      _chapters = const <Map<String, dynamic>>[];
      _progress = const <String, MangaChapterProgress>{};
      _downloadedChapters = const <String>{};
      _boundError = null;
      _loadingBoundWork = false;
      _sourceError = null;
      _autoResolving = false;
      _autoResolveSourceName = null;
      _matches = const <_MangaSourceMatch>[];
      _scanlator = null;
    });
    await _autoResolveInstalledSource(forceSweep: true);
  }

  Future<void> _selectSource(MihonSourceInfo source) async {
    final request = ++_sourceRequest;
    setState(() {
      _autoResolving = true;
      _autoResolveSourceName = source.name;
      _autoResolveIndex = 1;
      _autoResolveTotal = 1;
      _sourceError = null;
    });
    final results = await _searchOneSource(source);
    if (!mounted || request != _sourceRequest) return;

    _MangaSourceMatch? exact;
    for (final match in results) {
      if (mangaTitleMatches(_titleQueries, match.title)) {
        exact = match;
        break;
      }
    }
    if (exact != null) {
      await _bindSourceMatch(exact, sourceRequest: request);
      return;
    }

    setState(() {
      _autoResolving = false;
      _autoResolveSourceName = null;
      _matches = List<_MangaSourceMatch>.unmodifiable(results);
      _sourceError = results.isEmpty
          ? tr('manga_source_no_results')
          : tr('manga_source_choose_matching_result');
    });
    // No unverified title is bound automatically. Let the user type the
    // preferred alias or select the exact catalogue entry from this provider.
    if (mounted && request == _sourceRequest) {
      await _openSourceSearch(source);
    }
  }

  Widget _buildSourceSwitcher(BuildContext context) {
    final palette = AppPalette.of(context);
    final sourceName = _boundSource?.name ?? _binding?.sourceName;
    final label = _boundSource != null || sourceName != null
        ? 'Mihon · ${sourceName ?? ''}'
        : _autoResolving
        ? tr('manga_source_auto_resolving')
        : tr('manga_choose_source');
    final subtitle = _autoResolving && _autoResolveSourceName != null
        ? '${_autoResolveSourceName!} · $_autoResolveIndex/$_autoResolveTotal'
        : _sourceError;
    final source = _boundSource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .48),
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Row(
            children: <Widget>[
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 14),
                child: Icon(Icons.dns_rounded, color: Colors.white70, size: 20),
              ),
              Expanded(
                child: InkWell(
                  onTap: _openSourcePicker,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.cardTitle.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        if (subtitle != null &&
                            subtitle.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.metadata.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('manga_change_source'),
                onPressed: _openSourcePicker,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              if (source != null)
                FutureBuilder<bool>(
                  future: _settingsAvailable(source),
                  builder: (context, snapshot) => PopupMenuButton<String>(
                    tooltip: tr('more'),
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                    ),
                    onSelected: (action) =>
                        unawaited(_handleSourceAction(source, action)),
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      if (source.baseUrl.isNotEmpty)
                        PopupMenuItem<String>(
                          value: 'solve',
                          child: Text(tr('manga_source_solve_cloudflare')),
                        ),
                      if (source.baseUrl.isNotEmpty)
                        PopupMenuItem<String>(
                          value: 'signin',
                          child: Text(tr('manga_source_sign_in')),
                        ),
                      if (snapshot.data == true)
                        PopupMenuItem<String>(
                          value: 'settings',
                          child: Text(tr('manga_source_settings')),
                        ),
                    ],
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
        if (_binding != null) ...<Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _binding!.mangaTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.metadata.copyWith(
                      color: palette.mutedText,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (source != null)
                  TextButton(
                    onPressed: () => _openSourceSearch(source),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: Text(tr('manga_source_wrong_title')),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _bindSourceMatch(
    _MangaSourceMatch match, {
    int? sourceRequest,
  }) async {
    if (!mounted ||
        (sourceRequest != null && sourceRequest != _sourceRequest)) {
      return;
    }
    final url = '${match.item['url'] ?? ''}'.trim();
    final title = '${match.item['title'] ?? ''}'.trim();
    if (url.isEmpty || title.isEmpty) return;
    final binding = MangaSourceBinding(
      anilistId: _title.id,
      sourceId: match.source.id,
      sourceName: match.source.name,
      mangaUrl: url,
      mangaTitle: title,
      thumbnailUrl: '${match.item['thumbnail_url'] ?? ''}'.trim().isEmpty
          ? null
          : '${match.item['thumbnail_url']}',
    );
    await _store.saveBinding(binding);
    if (!mounted || (sourceRequest != null && sourceRequest != _sourceRequest))
      return;
    await _store.rememberLastGoodMangaSourceId(match.source.id);
    if (!mounted || (sourceRequest != null && sourceRequest != _sourceRequest))
      return;
    setState(() {
      _binding = binding;
      _boundSource = match.source;
      _chapters = const <Map<String, dynamic>>[];
      _progress = const <String, MangaChapterProgress>{};
      _downloadedChapters = const <String>{};
      _boundError = null;
      _autoResolving = false;
      _autoResolveSourceName = null;
      _sourceError = null;
      _tabs.animateTo(0);
    });
    if (_sourceManagerOpen && mounted) {
      Navigator.of(context).pop();
    }
    await _loadBoundWork(binding);
  }

  Future<void> _removeBinding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('manga_remove_source_title')),
        content: Text(tr('manga_remove_source_message')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.removeBinding(_title.id);
    if (!mounted) return;
    setState(() {
      _binding = null;
      _boundSource = null;
      _chapters = const <Map<String, dynamic>>[];
      _progress = const <String, MangaChapterProgress>{};
      _downloadedChapters = const <String>{};
      _boundError = null;
      _matches = const <_MangaSourceMatch>[];
    });
  }

  Future<void> _handleSourceAction(
    MihonSourceInfo source,
    String action,
  ) async {
    try {
      if (action == 'settings') {
        final available = await _runtime.hasSettings(source.id);
        if (!mounted) return;
        if (!available) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('manga_source_settings_unavailable'))),
          );
          return;
        }
        await _runtime.openSettings(source.id);
        return;
      }
      if ((action == 'web' || action == 'signin') &&
          source.baseUrl.isNotEmpty) {
        await _runtime.openSourceWebView(source.baseUrl, title: source.name);
        return;
      }
      if (action == 'solve' && source.baseUrl.isNotEmpty) {
        final solved = await _runtime.solveCloudflare(source.baseUrl);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              solved
                  ? tr('manga_source_cloudflare_solved')
                  : tr('manga_source_cloudflare_not_solved'),
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openReader(int index) async {
    final binding = _binding;
    final source = _boundSource;
    if (binding == null || source == null || _chapters.isEmpty) {
      await _openSourcePicker();
      return;
    }
    final safeIndex = index.clamp(0, _chapters.length - 1).toInt();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MangaReaderScreen(
          anilistId: _title.id,
          workTitle: _title.title,
          source: source,
          mangaUrl: binding.mangaUrl,
          chapters: _chapters,
          startIndex: safeIndex,
        ),
      ),
    );
    if (mounted) {
      await _reloadProgress();
    }
  }

  Future<void> _reloadProgress() async {
    final source = _boundSource;
    if (source == null) return;
    final progress = await _store.progressForWork(_title.id, source.id);
    if (mounted) setState(() => _progress = progress);
  }

  int _resumeIndex() {
    if (_chapters.isEmpty) return 0;
    for (var i = 0; i < _chapters.length; i++) {
      final url = '${_chapters[i]['url'] ?? ''}';
      final mark = _progress[url];
      if (mark != null && !mark.isRead && mark.totalPages > 0) return i;
    }
    for (var i = 0; i < _chapters.length; i++) {
      final url = '${_chapters[i]['url'] ?? ''}';
      if (_progress[url]?.isRead != true) return i;
    }
    return _chapters.length - 1;
  }

  Future<void> _setChapterRead(
    Map<String, dynamic> chapter, {
    required bool read,
  }) async {
    final binding = _binding;
    final source = _boundSource;
    final url = '${chapter['url'] ?? ''}';
    if (binding == null || source == null || url.isEmpty) return;
    await _store.setRead(
      anilistId: _title.id,
      sourceId: source.id,
      chapterUrl: url,
      isRead: read,
    );
    await _reloadProgress();
  }

  Future<void> _setChaptersReadThrough(
    Map<String, dynamic> chapter, {
    required bool read,
  }) async {
    final binding = _binding;
    final source = _boundSource;
    if (binding == null || source == null) return;
    final visible = _displayChapters;
    final target = visible.indexWhere((item) => item['url'] == chapter['url']);
    if (target < 0) return;

    for (var index = 0; index <= target; index++) {
      final url = '${visible[index]['url'] ?? ''}';
      if (url.isEmpty) continue;
      await _store.setRead(
        anilistId: _title.id,
        sourceId: source.id,
        chapterUrl: url,
        isRead: read,
      );
    }
    await _reloadProgress();
  }

  Future<void> _showChapterActions(Map<String, dynamic> chapter) async {
    final url = '${chapter['url'] ?? ''}';
    final isRead = _progress[url]?.isRead == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppPalette.of(context).surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.of(
                      sheetContext,
                    ).mutedText.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                '${chapter['name'] ?? tr('chapter')}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.sectionHeader.copyWith(
                  color: AppPalette.of(sheetContext).foreground,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isRead
                      ? Icons.mark_chat_unread_outlined
                      : Icons.check_circle_outline_rounded,
                ),
                title: Text(
                  isRead ? tr('manga_mark_unread') : tr('manga_mark_read'),
                ),
                onTap: () => Navigator.pop(sheetContext, 'single'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.done_all_rounded),
                title: Text(
                  isRead
                      ? tr('manga_mark_this_and_above_unread')
                      : tr('manga_mark_this_and_above_read'),
                ),
                onTap: () => Navigator.pop(sheetContext, 'through'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'single') {
      await _setChapterRead(chapter, read: !isRead);
    } else if (action == 'through') {
      await _setChaptersReadThrough(chapter, read: !isRead);
    }
  }

  Future<void> _downloadChapter(Map<String, dynamic> chapter) async {
    final source = _boundSource;
    final binding = _binding;
    if (source == null || binding == null) return;
    final downloaded = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MangaChapterDownloadDialog(
        anilistId: _title.id,
        workTitle: _title.title,
        source: source,
        chapter: chapter,
      ),
    );
    if (downloaded == true && mounted) {
      final url = '${chapter['url'] ?? ''}';
      setState(
        () => _downloadedChapters = <String>{..._downloadedChapters, url},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('manga_download_complete'))));
    }
  }

  Future<void> _showChapterDownloadOptions() async {
    final visible = _displayChapters;
    final pending = visible
        .where(
          (chapter) => !_downloadedChapters.contains('${chapter['url'] ?? ''}'),
        )
        .toList(growable: false);
    if (pending.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('manga_no_pending_downloads'))));
      return;
    }

    final palette = AppPalette.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.surface,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.md,
            AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.mutedText.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      tr('manga_download_chapters_title'),
                      style: AppType.sectionHeader.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                  ),
                  Text(
                    '${pending.length} ${tr('manga_not_downloaded')}',
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              ListTile(
                leading: Icon(
                  Icons.tune_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(tr('manga_download_custom')),
                onTap: () => Navigator.pop(sheetContext, 'custom'),
              ),
              ListTile(
                leading: Icon(
                  Icons.download_for_offline_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text('${tr('all')} ${pending.length}'),
                onTap: () => Navigator.pop(sheetContext, 'all'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'all') {
      await _downloadSelectedChapters(visible);
    } else if (choice == 'custom') {
      await _showCustomChapterRange(visible);
    }
  }

  Future<void> _showCustomChapterRange(
    List<Map<String, dynamic>> visible,
  ) async {
    if (visible.isEmpty) return;
    var startIndex = 0;
    var endIndex = visible.length - 1;
    final palette = AppPalette.of(context);
    final selectedRange = await showModalBottomSheet<(int, int)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: palette.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.md,
              AppSpace.md,
              MediaQuery.viewInsetsOf(context).bottom + AppSpace.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.mutedText.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  tr('manga_download_custom'),
                  style: AppType.sectionHeader.copyWith(
                    color: palette.foreground,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<int>(
                  key: ValueKey<String>('manga-download-start-$startIndex'),
                  initialValue: startIndex,
                  isExpanded: true,
                  menuMaxHeight: 360,
                  decoration: InputDecoration(
                    labelText: tr('manga_start_chapter'),
                    border: const OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<int>>[
                    for (var index = 0; index < visible.length; index++)
                      DropdownMenuItem<int>(
                        value: index,
                        child: Text(
                          '${visible[index]['name'] ?? '${tr('chapter')} ${index + 1}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setSheetState(() {
                      startIndex = value;
                      if (endIndex < startIndex) endIndex = startIndex;
                    });
                  },
                ),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<int>(
                  key: ValueKey<String>('manga-download-end-$endIndex'),
                  initialValue: endIndex,
                  isExpanded: true,
                  menuMaxHeight: 360,
                  decoration: InputDecoration(
                    labelText: tr('manga_end_chapter'),
                    border: const OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<int>>[
                    for (var index = 0; index < visible.length; index++)
                      DropdownMenuItem<int>(
                        value: index,
                        child: Text(
                          '${visible[index]['name'] ?? '${tr('chapter')} ${index + 1}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setSheetState(() {
                      endIndex = value;
                      if (startIndex > endIndex) startIndex = endIndex;
                    });
                  },
                ),
                const SizedBox(height: AppSpace.lg),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(sheetContext, (startIndex, endIndex)),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(tr('download')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selectedRange == null || !mounted) return;
    final from = selectedRange.$1 < selectedRange.$2
        ? selectedRange.$1
        : selectedRange.$2;
    final to = selectedRange.$1 > selectedRange.$2
        ? selectedRange.$1
        : selectedRange.$2;
    await _downloadSelectedChapters(visible.sublist(from, to + 1));
  }

  Future<void> _downloadSelectedChapters(
    List<Map<String, dynamic>> selection,
  ) async {
    final source = _boundSource;
    if (source == null || selection.isEmpty) return;
    final pending = selection
        .where(
          (chapter) => !_downloadedChapters.contains('${chapter['url'] ?? ''}'),
        )
        .toList(growable: false);
    if (pending.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('manga_no_pending_downloads'))));
      return;
    }

    if (pending.length > 50) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('manga_download_remaining')),
          content: Text(
            tr(
              'manga_confirm_download_remaining',
              args: <String>['${pending.length}'],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('download')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MangaBatchChapterDownloadDialog(
        anilistId: _title.id,
        workTitle: _title.title,
        source: source,
        chapters: pending,
      ),
    );
    if (!mounted) return;
    final downloaded = await MangaChapterDownloadStore.instance
        .downloadedChapterUrls(anilistId: _title.id, sourceId: source.id);
    if (!mounted) return;
    setState(() => _downloadedChapters = downloaded);
    if (completed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('manga_batch_download_complete'))),
      );
    }
  }

  Future<void> _removeOfflineChapter(Map<String, dynamic> chapter) async {
    final source = _boundSource;
    if (source == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('manga_remove_offline_copy')),
        content: Text(tr('manga_remove_offline_confirm')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final url = '${chapter['url'] ?? ''}';
    await MangaChapterDownloadStore.instance.removeChapter(
      anilistId: _title.id,
      sourceId: source.id,
      chapterUrl: url,
    );
    if (mounted)
      setState(
        () =>
            _downloadedChapters = <String>{..._downloadedChapters}..remove(url),
      );
  }

  List<String> get _scanlators {
    final values = <String>{};
    for (final chapter in _chapters) {
      final value = '${chapter['scanlator'] ?? ''}'.trim();
      if (value.isNotEmpty) values.add(value);
    }
    return values.toList(growable: false);
  }

  List<Map<String, dynamic>> get _displayChapters {
    final filtered = _scanlator == null
        ? _chapters
        : _chapters
              .where(
                (chapter) =>
                    '${chapter['scanlator'] ?? ''}'.trim() == _scanlator,
              )
              .toList(growable: false);
    return _ascendingInList
        ? filtered
        : filtered.reversed.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final banner = _title.bannerUrl ?? _title.coverUrl;
    final canRead =
        _binding != null && _boundSource != null && _chapters.isNotEmpty;
    final hasPartialProgress = _progress.values.any(
      (item) => item.pageIndex > 0 && !item.isRead,
    );
    final heroHeight = (MediaQuery.sizeOf(context).height * .48)
        .clamp(360.0, 440.0)
        .toDouble();
    final readLabel = _autoResolving
        ? tr('manga_source_auto_resolving')
        : _chapters.isEmpty
        ? tr('manga_find_source')
        : hasPartialProgress
        ? tr('manga_continue_reading')
        : tr('manga_read_action');

    return Scaffold(
      backgroundColor: palette.page,
      body: NestedScrollView(
        key: PageStorageKey<String>('manga-${_title.id}-nested-detail'),
        controller: _outerScrollController,
        floatHeaderSlivers: false,
        headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
          SliverAppBar(
            expandedHeight: heroHeight,
            pinned: true,
            floating: false,
            backgroundColor: palette.page,
            foregroundColor: palette.foreground,
            title: Text(
              _title.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _buildHeroBackdrop(context, banner, heroHeight),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildWorkHeader(
              context,
              readLabel: readLabel,
              canRead: canRead,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            floating: false,
            delegate: _MangaTabBarDelegate(
              child: Material(
                color: palette.page,
                child: SizedBox(
                  key: _tabBarKey,
                  height: 49,
                  child: TabBar(
                    controller: _tabs,
                    onTap: (_) => _scheduleTabBarPin(),
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 20,
                    ),
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: palette.mutedText,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    dividerColor: Colors.transparent,
                    tabs: <Widget>[
                      Tab(text: tr('chapters')),
                      Tab(text: tr('characters')),
                      Tab(text: tr('manga_related_titles')),
                      Tab(text: tr('details')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: <Widget>[
            _buildChaptersTab(context),
            _buildCharactersTab(context),
            _buildRelationsTab(context),
            _buildDetailsTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBackdrop(
    BuildContext context,
    String? banner,
    double heroHeight,
  ) {
    final palette = AppPalette.of(context);
    final cover = _title.coverUrl;
    final title = _title.title.trim();
    final english = _title.englishTitle?.trim();
    final posterHeight = (heroHeight * .47).clamp(180.0, 205.0).toDouble();
    final posterWidth = posterHeight * .68;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (banner != null && banner.isNotEmpty)
          CachedNetworkImage(
            imageUrl: banner,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                ColoredBox(color: palette.raisedSurface),
          )
        else
          ColoredBox(color: palette.raisedSurface),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x4A000000),
                  Color(0x78000000),
                  Color(0xE8000000),
                ],
                stops: <double>[0, .48, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSpace.gutter(context),
          right: AppSpace.gutter(context),
          bottom: 16,
          child: SizedBox(
            height: posterHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: posterWidth,
                    height: posterHeight,
                    color: palette.raisedSurface,
                    child: cover != null && cover.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white70,
                              size: 34,
                            ),
                          )
                        : const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white70,
                            size: 34,
                          ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.heroTitle.copyWith(
                            color: Colors.white,
                            fontSize: 21,
                            height: 1.18,
                          ),
                        ),
                        if (english != null &&
                            english.isNotEmpty &&
                            english != title) ...<Widget>[
                          const SizedBox(height: 5),
                          Text(
                            english,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body.copyWith(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: <Widget>[
                            _HeroTag(_title.format ?? tr('manga')),
                            if (_title.countryOfOrigin != null)
                              _HeroTag(_countryLabel(_title.countryOfOrigin!)),
                            if (_title.averageScore != null)
                              _HeroTag(
                                '★ ${(_title.averageScore! / 10).toStringAsFixed(1)}/10',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkHeader(
    BuildContext context, {
    required String readLabel,
    required bool canRead,
  }) {
    final palette = AppPalette.of(context);
    final synopsis = (_title.description ?? '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final binding = _binding;
    final source = _boundSource;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter(context),
        16,
        AppSpace.gutter(context),
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 4),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: _loadingBoundWork || _autoResolving
                  ? null
                  : canRead
                  ? () => _openReader(_resumeIndex())
                  : binding == null
                  ? _openSourcePicker
                  : () => _loadBoundWork(binding, refresh: true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white70,
                disabledForegroundColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                canRead ? Icons.menu_book_rounded : Icons.search_rounded,
                size: 23,
              ),
              label: Text(
                _loadingBoundWork ? tr('loading') : readLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.cardTitle.copyWith(
                  color: _loadingBoundWork ? Colors.black54 : Colors.black,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          if (_sourcesLoaded ||
              _loadingSources ||
              binding != null ||
              _autoResolving) ...<Widget>[
            const SizedBox(height: 12),
            _buildSourceSwitcher(context),
          ],
          if (synopsis.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              synopsis,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppType.body.copyWith(
                color: palette.secondaryText,
                height: 1.4,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _revealSynopsis,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                ),
                child: Text(tr('read_more')),
              ),
            ),
          ],
          if (_title.characters.isNotEmpty)
            _heroMetadataLine(
              tr('starring'),
              _title.characters
                  .take(3)
                  .map((person) => person.name)
                  .join(' · '),
            ),
          if (_title.staff.isNotEmpty)
            _heroMetadataLine(
              tr('creators'),
              _title.staff.take(3).map((person) => person.name).join(' · '),
            ),
          if (_title.genres.isNotEmpty)
            _heroMetadataLine(tr('genres'), _title.genres.take(4).join(' · ')),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _heroAction(
                icon: _isSaved ? Icons.check_rounded : Icons.add_rounded,
                label: tr('my_list'),
                onTap: _chooseReadingStatus,
                active: _isSaved,
              ),
              _heroAction(
                icon: _notifyNewChapters
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                label: tr('manga_notify'),
                onTap: _toggleChapterNotifications,
                active: _notifyNewChapters,
              ),
              _heroAction(
                icon: Icons.ios_share_rounded,
                label: tr('share'),
                onTap: _shareWork,
              ),
              _heroAction(
                icon: Icons.public_rounded,
                label: tr('web'),
                onTap: source != null && source.baseUrl.isNotEmpty
                    ? () => _handleSourceAction(source, 'web')
                    : _openSourcePicker,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetadataLine(String label, String value) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.metadata.copyWith(
          color: palette.mutedText,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _heroAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final palette = AppPalette.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : palette.foreground,
                size: 23,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.metadata.copyWith(
                  color: palette.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _countryLabel(String country) => switch (country.toUpperCase()) {
    'JP' => 'Japan',
    'KR' => 'South Korea',
    'CN' => 'China',
    'TW' => 'Taiwan',
    'US' => 'United States',
    _ => country.toUpperCase(),
  };

  Widget _buildChaptersTab(BuildContext context) {
    final palette = AppPalette.of(context);
    final chapters = _displayChapters;
    final binding = _binding;

    if (binding == null || _boundSource == null) {
      if (_autoResolving || _loadingSources) {
        final progressText = _autoResolveSourceName == null
            ? tr('manga_source_auto_resolving')
            : '${_autoResolveSourceName!} · '
                  '$_autoResolveIndex/$_autoResolveTotal';
        return _MangaTabLoading(
          message: progressText,
          foreground: palette.mutedText,
        );
      }
      return _MangaTabEmpty(
        icon: Icons.menu_book_outlined,
        title: tr('manga_no_source_bound'),
        message: _sourceError ?? tr('manga_bind_source_hint'),
        actionLabel: tr('manga_choose_source'),
        onAction: _openSourcePicker,
        secondaryLabel: tr('mihon_sources'),
        onSecondary: _openSourceManager,
      );
    }
    if (_loadingBoundWork && _chapters.isEmpty) {
      return const _MangaTabLoading();
    }
    if (_boundError != null && _chapters.isEmpty) {
      return _MangaTabEmpty(
        icon: Icons.cloud_off_outlined,
        title: tr('manga_chapters_unavailable'),
        message: _boundError!,
        actionLabel: tr('retry'),
        onAction: () => _loadBoundWork(binding, refresh: true),
        secondaryLabel: tr('manga_change_source'),
        onSecondary: _openSourcePicker,
      );
    }
    if (_chapters.isEmpty) {
      return _MangaTabEmpty(
        icon: Icons.menu_book_outlined,
        title: tr('manga_no_chapters'),
        message: tr('manga_source_has_no_chapters'),
        actionLabel: tr('manga_change_source'),
        onAction: _openSourcePicker,
      );
    }

    final pendingCount = chapters
        .where(
          (chapter) => !_downloadedChapters.contains('${chapter['url'] ?? ''}'),
        )
        .length;
    return RefreshIndicator(
      onRefresh: () => _loadBoundWork(binding, refresh: true),
      child: CustomScrollView(
        key: PageStorageKey<String>('manga-${_title.id}-chapters'),
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter(context),
                AppSpace.md,
                AppSpace.gutter(context),
                AppSpace.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          binding.mangaTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.cardTitle.copyWith(
                            color: palette.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_boundSource!.name} · ${chapters.length} '
                          '${tr('chapters').toLowerCase()}',
                          style: AppType.metadata.copyWith(
                            color: palette.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('manga_download_chapters_title'),
                    onPressed: pendingCount == 0 || _loadingBoundWork
                        ? null
                        : _showChapterDownloadOptions,
                    icon: const Icon(Icons.download_rounded),
                  ),
                  IconButton(
                    tooltip: _gridView
                        ? tr('manga_list_view')
                        : tr('manga_grid_view'),
                    onPressed: () {
                      setState(() => _gridView = !_gridView);
                      unawaited(_persistWorkPreferences());
                    },
                    icon: Icon(
                      _gridView
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: tr('more'),
                    onSelected: (action) {
                      if (action == 'refresh') {
                        unawaited(_loadBoundWork(binding, refresh: true));
                      } else if (action == 'reverse') {
                        setState(() => _ascendingInList = !_ascendingInList);
                        unawaited(_persistWorkPreferences());
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'refresh',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.refresh_rounded),
                          title: Text(tr('manga_refresh_chapters')),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'reverse',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.swap_vert_rounded),
                          title: Text(
                            _ascendingInList
                                ? tr('manga_reverse_chapters')
                                : tr('manga_sort_ascending'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_scanlators.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpace.gutter(context),
                  ),
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(tr('all')),
                        selected: _scanlator == null,
                        onSelected: (_) => _setScanlator(null),
                      ),
                    ),
                    for (final group in _scanlators)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(group),
                          selected: _scanlator == group,
                          onSelected: (_) => _setScanlator(group),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.gutter(context),
              AppSpace.sm,
              AppSpace.gutter(context),
              MediaQuery.paddingOf(context).bottom + 28,
            ),
            sliver: _gridView
                ? SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 9,
                          mainAxisSpacing: 9,
                          childAspectRatio: 1.08,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildChapterGridTile(
                        context,
                        chapters[index],
                        index,
                      ),
                      childCount: chapters.length,
                    ),
                  )
                : SliverList.separated(
                    itemCount: chapters.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: palette.hairline),
                    itemBuilder: (context, index) =>
                        _buildChapterListRow(context, chapters[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterListRow(
    BuildContext context,
    Map<String, dynamic> chapter,
  ) {
    final palette = AppPalette.of(context);
    final url = '${chapter['url'] ?? ''}';
    final mark = _progress[url];
    final isRead = mark?.isRead == true;
    final isDownloaded = _downloadedChapters.contains(url);
    final name = '${chapter['name'] ?? tr('chapter')}';
    final number = _chapterNumber(chapter['chapter_number']);
    final scanlator = '${chapter['scanlator'] ?? ''}'.trim();
    final date = _chapterDate(chapter['date_upload']);
    final thumbnail = _chapterThumbnailUrl(chapter);

    return InkWell(
      onTap: () => _openChapterFromList(chapter),
      onLongPress: () => _showChapterActions(chapter),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: SizedBox(
                width: 48,
                height: 64,
                child: thumbnail.isEmpty
                    ? ColoredBox(
                        color: palette.surface,
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: palette.mutedText,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: thumbnail,
                        fit: BoxFit.cover,
                        memCacheWidth: 144,
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: palette.surface,
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: palette.mutedText,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle.copyWith(
                      color: isRead ? palette.mutedText : palette.foreground,
                      decoration: isRead ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    <String>[
                      if (number != null) '${tr('chapter')} $number',
                      if (scanlator.isNotEmpty) scanlator,
                      if (date != null) date,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                  if (mark != null &&
                      !isRead &&
                      mark.totalPages > 0) ...<Widget>[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: mark.fraction,
                        minHeight: 3,
                        backgroundColor: palette.hairline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            if (isDownloaded)
              IconButton(
                tooltip: tr('manga_remove_offline_copy'),
                onPressed: () => _removeOfflineChapter(chapter),
                icon: const Icon(
                  Icons.offline_pin_rounded,
                  color: Colors.green,
                  size: 22,
                ),
              )
            else
              IconButton(
                tooltip: tr('manga_download_chapter'),
                onPressed: () => _downloadChapter(chapter),
                icon: const Icon(Icons.file_download_outlined),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterGridTile(
    BuildContext context,
    Map<String, dynamic> chapter,
    int displayIndex,
  ) {
    final palette = AppPalette.of(context);
    final url = '${chapter['url'] ?? ''}';
    final mark = _progress[url];
    final isRead = mark?.isRead == true;
    final isDownloaded = _downloadedChapters.contains(url);
    final number =
        _chapterNumber(chapter['chapter_number']) ?? '${displayIndex + 1}';
    final name = '${chapter['name'] ?? tr('chapter')}';

    return Tooltip(
      message: name,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: () => _openChapterFromList(chapter),
        onLongPress: () => _showChapterActions(chapter),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isRead
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .12)
                : palette.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: palette.hairline),
          ),
          child: Stack(
            children: <Widget>[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle.copyWith(
                      color: isRead ? palette.mutedText : palette.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (isDownloaded || isRead)
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: Icon(
                    isDownloaded
                        ? Icons.offline_pin_rounded
                        : Icons.check_circle_rounded,
                    color: isDownloaded
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                    size: 15,
                  ),
                ),
              if (mark != null && !isRead && mark.totalPages > 0)
                PositionedDirectional(
                  bottom: 0,
                  start: 0,
                  end: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppRadii.card),
                    ),
                    child: LinearProgressIndicator(
                      value: mark.fraction,
                      minHeight: 3,
                      backgroundColor: palette.hairline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _chapterThumbnailUrl(Map<String, dynamic> chapter) {
    for (final value in <Object?>[
      chapter['thumbnail_url'],
      chapter['thumbnail'],
      _binding?.thumbnailUrl,
      _title.coverUrl,
    ]) {
      final url = '${value ?? ''}'.trim();
      if (url.startsWith('https://') || url.startsWith('http://')) {
        return url;
      }
    }
    return '';
  }

  Future<void> _openChapterFromList(Map<String, dynamic> chapter) async {
    final index = _chapters.indexWhere((item) => item['url'] == chapter['url']);
    if (index >= 0) await _openReader(index);
  }

  String? _chapterNumber(Object? value) {
    if (value is! num || value < 0) return null;
    final number = value.toDouble();
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString();
  }

  String? _chapterDate(Object? value) {
    if (value is! num || value <= 0) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final difference = DateTime.now().difference(date);
    if (difference.isNegative) {
      return DateFormat.yMMMd(context.locale.toString()).format(date);
    }
    if (difference.inMinutes < 1) return tr('just_now');
    if (difference.inHours < 1) {
      return tr(
        'n_minutes_ago',
        namedArgs: <String, String>{'n': '${difference.inMinutes}'},
      );
    }
    if (difference.inDays < 1) {
      return tr(
        'n_hours_ago',
        namedArgs: <String, String>{'n': '${difference.inHours}'},
      );
    }
    if (difference.inDays < 30) {
      return tr(
        'n_days_ago',
        namedArgs: <String, String>{'n': '${difference.inDays}'},
      );
    }
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor().clamp(1, 11);
      return tr('n_months_ago', namedArgs: <String, String>{'n': '$months'});
    }
    final years = (difference.inDays / 365).floor();
    return tr('n_years_ago', namedArgs: <String, String>{'n': '$years'});
  }

  Future<void> _openSourceManager() async {
    if (_sourceManagerOpen || !mounted) return;
    _sourceManagerOpen = true;
    if (!_sourcesLoaded && !_loadingSources) {
      unawaited(_loadInstalledSources());
    }
    final palette = AppPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: palette.page,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .92,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.sm,
                AppSpace.sm,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      tr('manga_choose_source'),
                      style: AppType.sectionHeader.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('close'),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildSourcesTab(sheetContext)),
          ],
        ),
      ),
    );
    _sourceManagerOpen = false;
  }

  Widget _buildSourcesTab(BuildContext context) {
    final palette = AppPalette.of(context);
    final filtered = _sources
        .where((source) {
          final query = _sourceFilterController.text.trim().toLowerCase();
          if (query.isEmpty) return true;
          return source.name.toLowerCase().contains(query) ||
              source.lang.toLowerCase().contains(query) ||
              source.packageName.toLowerCase().contains(query);
        })
        .toList(growable: false);
    return ListView(
      key: PageStorageKey<String>('manga-${_title.id}-sources'),
      primary: true,
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter(context),
        AppSpace.md,
        AppSpace.gutter(context),
        MediaQuery.paddingOf(context).bottom + 28,
      ),
      children: <Widget>[
        if (_binding != null) ...<Widget>[
          _SectionHeading(title: tr('manga_current_source')),
          Card(
            color: palette.surface,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.verified_rounded, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _binding!.sourceName,
                          style: AppType.cardTitle.copyWith(
                            color: palette.foreground,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('manga_remove_source'),
                        onPressed: _removeBinding,
                        icon: const Icon(Icons.link_off_rounded),
                      ),
                      if (_boundSource != null)
                        PopupMenuButton<String>(
                          onSelected: (action) =>
                              _handleSourceAction(_boundSource!, action),
                          itemBuilder: (context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'settings',
                              child: Text(tr('manga_source_settings')),
                            ),
                            PopupMenuItem<String>(
                              value: 'web',
                              child: Text(tr('manga_open_source_website')),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Text(
                    _binding!.mangaTitle,
                    style: AppType.body.copyWith(color: palette.secondaryText),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _boundSource == null
                              ? () => _loadInstalledSources(reload: true)
                              : _openSourcePicker,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: Text(tr('manga_change_source')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loadingBoundWork
                              ? null
                              : () => _loadBoundWork(_binding!, refresh: true),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(tr('refresh')),
                        ),
                      ),
                    ],
                  ),
                  if (_boundError != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _boundError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
        ],
        _SectionHeading(title: tr('manga_auto_match_sources')),
        Text(
          tr('manga_auto_match_hint'),
          style: AppType.body.copyWith(color: palette.mutedText),
        ),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _searchingAll ? null : _findAcrossSources,
            icon: _searchingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore_rounded),
            label: Text(
              _searchingAll
                  ? tr('manga_searching_sources')
                  : tr('manga_search_all_sources'),
            ),
          ),
        ),
        if (_matches.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.md),
          _SectionHeading(title: tr('manga_matching_results')),
          for (final match in _matches)
            Card(
              color: palette.surface,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: palette.raisedSurface,
                  child: const Icon(Icons.menu_book_rounded),
                ),
                title: Text(
                  match.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${match.source.name} · ${match.source.lang.toUpperCase()}',
                ),
                trailing: FilledButton(
                  onPressed: () => _bindSourceMatch(match),
                  child: Text(tr('use')),
                ),
              ),
            ),
        ],
        if (_sourceError != null) ...<Widget>[
          const SizedBox(height: AppSpace.sm),
          Text(
            _sourceError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpace.xl),
        Row(
          children: <Widget>[
            Expanded(
              child: _SectionHeading(title: tr('manga_installed_sources')),
            ),
            IconButton(
              onPressed: _loadingSources
                  ? null
                  : () => _loadInstalledSources(reload: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        TextField(
          controller: _sourceFilterController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: tr('manga_filter_sources'),
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        if (_loadingSources && _sources.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpace.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Text(
              tr('manga_no_installed_sources'),
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: palette.mutedText),
            ),
          )
        else
          for (final source in filtered)
            Card(
              color: palette.surface,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: palette.raisedSurface,
                  child: const Icon(Icons.extension_rounded),
                ),
                title: Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${source.lang.toUpperCase()}${source.isNsfw ? ' · ${tr('explicit_content')}' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.search_rounded),
                    PopupMenuButton<String>(
                      onSelected: (action) =>
                          _handleSourceAction(source, action),
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'settings',
                          child: Text(tr('manga_source_settings')),
                        ),
                        PopupMenuItem<String>(
                          value: 'web',
                          child: Text(tr('manga_open_source_website')),
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () => _openSourceSearch(source),
              ),
            ),
      ],
    );
  }

  Widget _buildCharactersTab(BuildContext context) {
    final characters = _title.characters;
    final staff = _title.staff;
    final palette = AppPalette.of(context);
    if (_loadingTitle && characters.isEmpty && staff.isEmpty) {
      return const _MangaTabLoading();
    }
    if (characters.isEmpty && staff.isEmpty) {
      return _MangaTabEmpty(
        icon: Icons.people_outline_rounded,
        title: tr('manga_no_characters'),
        message: tr('manga_no_characters_hint'),
      );
    }
    return ListView(
      key: PageStorageKey<String>('manga-${_title.id}-characters'),
      primary: true,
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter(context),
        AppSpace.lg,
        AppSpace.gutter(context),
        MediaQuery.paddingOf(context).bottom + 28,
      ),
      children: <Widget>[
        if (characters.isNotEmpty) ...<Widget>[
          _SectionHeading(title: tr('characters')),
          const SizedBox(height: AppSpace.sm),
          _MangaPeopleGrid(people: characters),
        ],
        if (staff.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.lg),
          _SectionHeading(title: tr('creators')),
          const SizedBox(height: AppSpace.sm),
          _MangaPeopleGrid(people: staff),
        ],
        if (characters.isEmpty && staff.isNotEmpty)
          Text(
            tr('manga_no_characters_hint'),
            style: AppType.metadata.copyWith(color: palette.mutedText),
          ),
      ],
    );
  }

  Widget _buildRelationsTab(BuildContext context) {
    final relations = _title.relations;
    if (_loadingTitle && relations.isEmpty) {
      return const _MangaTabLoading();
    }
    if (relations.isEmpty) {
      return _MangaTabEmpty(
        icon: Icons.account_tree_outlined,
        title: tr('manga_no_relations'),
        message: tr('manga_no_relations_hint'),
      );
    }
    return ListView(
      key: PageStorageKey<String>('manga-${_title.id}-related'),
      primary: true,
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter(context),
        AppSpace.lg,
        AppSpace.gutter(context),
        MediaQuery.paddingOf(context).bottom + 28,
      ),
      children: <Widget>[
        _SectionHeading(title: tr('manga_related_works')),
        const SizedBox(height: AppSpace.sm),
        _buildRelatedMangaGrid(relations),
      ],
    );
  }

  Widget _buildRelatedMangaGrid(List<MangaRelatedWork> works) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700 ? 5 : 3;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: works.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpace.md,
          crossAxisSpacing: AppSpace.md,
          childAspectRatio: .58,
        ),
        itemBuilder: (context, index) {
          final relation = works[index];
          return _MangaRelationCard(
            relation: relation,
            onTap: () => _openRelatedWork(relation),
          );
        },
      );
    },
  );

  void _openRelatedWork(MangaRelatedWork relation) {
    final relatedTitle = MangaTitle(
      id: relation.id,
      title: relation.title,
      englishTitle: relation.englishTitle,
      nativeTitle: relation.nativeTitle,
      coverUrl: relation.coverUrl,
      format: relation.format,
      countryOfOrigin: relation.countryOfOrigin,
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            MangaWorkScreen(title: relatedTitle, service: widget.service),
      ),
    );
  }

  Widget _buildDetailsTab(BuildContext context) {
    final palette = AppPalette.of(context);
    final synopsis = (_title.description ?? '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .trim();
    final dateRange = _dateRange(
      _title.startDate,
      _title.endDate,
      ongoing: _title.status == 'RELEASING',
    );
    final year = _title.startDate != null && _title.startDate!.length >= 4
        ? _title.startDate!.substring(0, 4)
        : null;
    final chapterCount = _binding != null && _boundSource != null
        ? _chapters.length
        : _title.chapters;
    return ListView(
      key: PageStorageKey<String>('manga-${_title.id}-details'),
      primary: true,
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter(context),
        AppSpace.lg,
        AppSpace.gutter(context),
        MediaQuery.paddingOf(context).bottom + 32,
      ),
      children: <Widget>[
        if (_binding != null && _binding!.sourceName.trim().isNotEmpty)
          _InfoLine(
            label: tr('manga_info_source'),
            value: _binding!.sourceName,
          ),
        if ((_title.status ?? '').isNotEmpty)
          _InfoLine(label: tr('status'), value: _displayCode(_title.status!)),
        if (year != null) _InfoLine(label: tr('year'), value: year),
        if (chapterCount != null)
          _InfoLine(label: tr('chapters'), value: chapterCount.toString()),
        if ((_title.format ?? '').isNotEmpty)
          _InfoLine(label: tr('format'), value: _displayCode(_title.format!)),
        if (_title.averageScore != null)
          _InfoLine(
            label: tr('score'),
            value: '${(_title.averageScore! / 10).toStringAsFixed(1)} / 10',
          ),
        if (_title.popularity != null)
          _InfoLine(
            label: tr('popularity'),
            value: _formatCount(_title.popularity!),
          ),
        if (_title.favourites != null)
          _InfoLine(
            label: tr('manga_favourites'),
            value: _formatCount(_title.favourites!),
          ),
        if ((_title.sourceMaterial ?? '').isNotEmpty)
          _InfoLine(
            label: tr('manga_source_material'),
            value: _displayCode(_title.sourceMaterial!),
          ),
        if ((_title.countryOfOrigin ?? '').isNotEmpty)
          _InfoLine(
            label: tr('manga_country'),
            value: _countryLabel(_title.countryOfOrigin!),
          ),
        if (dateRange != null)
          _InfoLine(label: tr('manga_aired'), value: dateRange),
        if ((_title.nativeTitle ?? '').isNotEmpty)
          _InfoLine(
            label: tr('manga_native_title'),
            value: _title.nativeTitle!,
          ),
        if (_title.synonyms.isNotEmpty)
          _InfoLine(
            label: tr('manga_also_known_as'),
            value: _title.synonyms.take(5).join(' · '),
          ),
        if (_title.genres.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.lg),
          _SectionHeading(title: tr('genres')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final genre in _title.genres)
                Chip(
                  label: Text(genre),
                  backgroundColor: palette.surface,
                  side: BorderSide(color: palette.hairline),
                ),
            ],
          ),
        ],
        if (_title.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.lg),
          _SectionHeading(title: tr('manga_tags')),
          const SizedBox(height: 8),
          _MangaTags(tags: _title.tags),
        ],
        if (synopsis.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.lg),
          KeyedSubtree(
            key: _detailsSynopsisKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SectionHeading(title: tr('manga_synopsis')),
                const SizedBox(height: 8),
                Text(
                  synopsis,
                  style: AppType.body.copyWith(
                    color: palette.secondaryText,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String? _dateRange(String? start, String? end, {bool ongoing = false}) {
    if (start == null || start.isEmpty) return null;
    String display(String value) {
      final parts = value.split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
      if (parts.length == 2) return '${parts[1]}/${parts[0]}';
      return value;
    }

    if (end != null && end.isNotEmpty)
      return '${display(start)} — ${display(end)}';
    return ongoing ? '${display(start)} —' : display(start);
  }

  String _displayCode(String value) => value
      .toLowerCase()
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  String _formatCount(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(',');
      buffer.write(raw[index]);
    }
    return buffer.toString();
  }
}

class _MangaTags extends StatefulWidget {
  const _MangaTags({required this.tags});
  final List<MangaTag> tags;

  @override
  State<_MangaTags> createState() => _MangaTagsState();
}

class _MangaTagsState extends State<_MangaTags> {
  bool _showSpoilers = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final safe = widget.tags
        .where((tag) => !tag.isSpoiler)
        .toList(growable: false);
    final spoilers = widget.tags
        .where((tag) => tag.isSpoiler)
        .toList(growable: false);
    final visible = _showSpoilers ? widget.tags : safe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final tag in visible)
              Chip(
                label: Text(
                  tag.rank == null ? tag.name : '${tag.name} ${tag.rank}%',
                ),
                backgroundColor: tag.isSpoiler
                    ? Theme.of(context).colorScheme.errorContainer
                    : palette.surface,
                side: BorderSide(color: palette.hairline),
              ),
          ],
        ),
        if (spoilers.isNotEmpty && !_showSpoilers)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _showSpoilers = true),
              child: Text(
                tr('manga_show_spoilers', args: ['${spoilers.length}']),
              ),
            ),
          ),
      ],
    );
  }
}

class _MangaPeopleGrid extends StatelessWidget {
  const _MangaPeopleGrid({required this.people});
  final List<MangaPersonCredit> people;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700 ? 5 : 3;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: people.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: AppSpace.md,
          crossAxisSpacing: AppSpace.md,
          childAspectRatio: .7,
        ),
        itemBuilder: (context, index) {
          final person = people[index];
          final palette = AppPalette.of(context);
          return Column(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: SizedBox(
                    width: double.infinity,
                    child: person.imageUrl == null
                        ? ColoredBox(
                            color: palette.raisedSurface,
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 34,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: person.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: palette.raisedSurface,
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 34,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                person.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppType.metadata.copyWith(fontWeight: FontWeight.w600),
              ),
              if (person.role.isNotEmpty)
                Text(
                  person.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppType.metadata.copyWith(
                    color: palette.mutedText,
                    fontSize: 10,
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

class _MangaRelationCard extends StatelessWidget {
  const _MangaRelationCard({required this.relation, required this.onTap});
  final MangaRelatedWork relation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: SizedBox(
                width: double.infinity,
                child: relation.coverUrl == null
                    ? ColoredBox(
                        color: palette.raisedSurface,
                        child: const Icon(Icons.menu_book_rounded),
                      )
                    : CachedNetworkImage(
                        imageUrl: relation.coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: palette.raisedSurface,
                          child: const Icon(Icons.menu_book_rounded),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            relation.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.metadata.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            relation.relationType.replaceAll('_', ' ').toLowerCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.metadata.copyWith(
              color: palette.mutedText,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _MangaBatchChapterDownloadDialog extends StatefulWidget {
  const _MangaBatchChapterDownloadDialog({
    required this.anilistId,
    required this.workTitle,
    required this.source,
    required this.chapters,
  });

  final int anilistId;
  final String workTitle;
  final MihonSourceInfo source;
  final List<Map<String, dynamic>> chapters;

  @override
  State<_MangaBatchChapterDownloadDialog> createState() =>
      _MangaBatchChapterDownloadDialogState();
}

class _MangaBatchChapterDownloadDialogState
    extends State<_MangaBatchChapterDownloadDialog> {
  int _completed = 0;
  int _page = 0;
  int _pageTotal = 0;
  bool _running = false;
  bool _cancelRequested = false;
  String? _activeTitle;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _cancelRequested = false;
      _error = null;
    });
    try {
      while (_completed < widget.chapters.length && !_cancelRequested) {
        final chapter = widget.chapters[_completed];
        setState(() {
          _activeTitle = '${chapter['name'] ?? tr('chapter')}';
          _page = 0;
          _pageTotal = 0;
        });
        await MangaChapterDownloadStore.instance.downloadChapter(
          anilistId: widget.anilistId,
          workTitle: widget.workTitle,
          source: widget.source,
          chapterUrl: '${chapter['url'] ?? ''}',
          chapterTitle: '${chapter['name'] ?? tr('chapter')}',
          runtime: MihonRuntimeService.instance,
          onProgress: (completed, total) {
            if (!mounted) return;
            setState(() {
              _page = completed;
              _pageTotal = total;
            });
          },
        );
        _completed++;
        if (mounted) setState(() {});
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        !_cancelRequested && _completed == widget.chapters.length,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _running = false;
      });
    }
  }

  void _cancel() {
    if (_running) {
      setState(() => _cancelRequested = true);
    } else {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.chapters.length;
    final chapterFraction = total == 0 ? 0.0 : _completed / total;
    return AlertDialog(
      title: Text(tr('manga_download_remaining')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _activeTitle ?? tr('manga_preparing_download'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _error == null ? chapterFraction : null,
          ),
          const SizedBox(height: 8),
          Text('${_completed} / $total ${tr('chapters').toLowerCase()}'),
          if (_pageTotal > 0) ...<Widget>[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _page / _pageTotal),
            const SizedBox(height: 4),
            Text('$_page / $_pageTotal', style: AppType.metadata),
          ],
          if (_cancelRequested && _running) ...<Widget>[
            const SizedBox(height: 8),
            Text(tr('manga_cancel_after_current'), style: AppType.metadata),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        if (_error != null)
          TextButton(onPressed: _run, child: Text(tr('retry'))),
        TextButton(
          onPressed: _running ? (_cancelRequested ? null : _cancel) : _cancel,
          child: Text(_running ? tr('cancel') : tr('close')),
        ),
      ],
    );
  }
}

class _MangaChapterDownloadDialog extends StatefulWidget {
  const _MangaChapterDownloadDialog({
    required this.anilistId,
    required this.workTitle,
    required this.source,
    required this.chapter,
  });

  final int anilistId;
  final String workTitle;
  final MihonSourceInfo source;
  final Map<String, dynamic> chapter;

  @override
  State<_MangaChapterDownloadDialog> createState() =>
      _MangaChapterDownloadDialogState();
}

class _MangaChapterDownloadDialogState
    extends State<_MangaChapterDownloadDialog> {
  int _completed = 0;
  int _total = 0;
  bool _running = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
      _completed = 0;
      _total = 0;
    });
    try {
      await MangaChapterDownloadStore.instance.downloadChapter(
        anilistId: widget.anilistId,
        workTitle: widget.workTitle,
        source: widget.source,
        chapterUrl: '${widget.chapter['url'] ?? ''}',
        chapterTitle: '${widget.chapter['name'] ?? tr('chapter')}',
        runtime: MihonRuntimeService.instance,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _completed = completed;
            _total = total;
          });
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('manga_download_chapter')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${widget.chapter['name'] ?? tr('chapter')}'),
        const SizedBox(height: 12),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else ...<Widget>[
          LinearProgressIndicator(
            value: _total > 0 ? _completed / _total : null,
          ),
          const SizedBox(height: 8),
          Text(
            _total > 0
                ? '$_completed / $_total'
                : tr('manga_preparing_download'),
          ),
        ],
      ],
    ),
    actions: <Widget>[
      if (_error != null)
        TextButton(onPressed: _start, child: Text(tr('retry'))),
      if (!_running || _error != null)
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('cancel')),
        ),
    ],
  );
}

class _MangaSourceMatch {
  const _MangaSourceMatch({
    required this.source,
    required this.item,
    required this.score,
  });

  final MihonSourceInfo source;
  final Map<String, dynamic> item;
  final double score;

  String get title => '${item['title'] ?? ''}';
}

class _MangaSourceSearchSheet extends StatefulWidget {
  const _MangaSourceSearchSheet({
    required this.source,
    required this.sources,
    required this.queries,
    required this.scoreFor,
  });

  final MihonSourceInfo source;
  final List<MihonSourceInfo> sources;
  final List<String> queries;
  final double Function(String) scoreFor;

  @override
  State<_MangaSourceSearchSheet> createState() =>
      _MangaSourceSearchSheetState();
}

class _MangaSourceSearchSheetState extends State<_MangaSourceSearchSheet> {
  final MihonRuntimeService _runtime = MihonRuntimeService.instance;
  late final TextEditingController _controller = TextEditingController(
    text: widget.queries.isEmpty ? '' : widget.queries.first,
  );
  late MihonSourceInfo _source = widget.source;
  List<_MangaSourceMatch> _results = const <_MangaSourceMatch>[];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 0;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore)) return;
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final request = reset ? ++_request : _request;
    final page = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _results = const <_MangaSourceMatch>[];
        _page = 0;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final values = await _runtime.search(_source.id, query, page: page);
      if (!mounted || request != _request) return;
      final matches = values
          .where((item) => '${item['url'] ?? ''}'.trim().isNotEmpty)
          .map(
            (item) => _MangaSourceMatch(
              source: _source,
              item: item,
              score: widget.scoreFor('${item['title'] ?? ''}'),
            ),
          )
          .toList(growable: false);
      final combined = reset
          ? matches
          : <_MangaSourceMatch>[
              ..._results,
              ...matches.where(
                (item) =>
                    !_results.any((old) => old.item['url'] == item.item['url']),
              ),
            ];
      setState(() {
        _results = combined;
        _page = page;
        _hasMore = values.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _switchSource(int sourceId) async {
    MihonSourceInfo? next;
    for (final source in widget.sources) {
      if (source.id == sourceId) {
        next = source;
        break;
      }
    }
    if (next == null || next.id == _source.id) return;
    setState(() {
      _source = next!;
      _results = const <_MangaSourceMatch>[];
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _load(reset: true);
  }

  Widget _sourcePicker(AppPalette palette) => PopupMenuButton<int>(
    tooltip: tr('manga_change_source'),
    onSelected: _switchSource,
    itemBuilder: (context) => <PopupMenuEntry<int>>[
      for (final source in widget.sources)
        PopupMenuItem<int>(
          value: source.id,
          child: Row(
            children: <Widget>[
              _SourceMenuIcon(source: source),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (source.id == _source.id) ...<Widget>[
                const SizedBox(width: 8),
                const Icon(Icons.check_rounded, size: 18),
              ],
            ],
          ),
        ),
    ],
    child: Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              '${tr('manga_source_searching')} ${_source.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.metadata.copyWith(color: palette.secondaryText),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: palette.mutedText,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 18),
                      child: Text(
                        tr('manga_source_search_prompt'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sectionHeader.copyWith(
                          color: palette.foreground,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 14),
                    child: _sourcePicker(palette),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpace.gutter(context),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 16),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _load(reset: true);
                        },
                        child: Icon(
                          Icons.search_rounded,
                          color: palette.mutedText,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _load(reset: true),
                          style: AppType.body.copyWith(
                            color: palette.foreground,
                          ),
                          decoration: InputDecoration(
                            hintText: tr('manga_search_source'),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) => value.text.isEmpty
                            ? const SizedBox(width: 12)
                            : IconButton(
                                tooltip: tr('clear'),
                                onPressed: _controller.clear,
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: palette.mutedText,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter(context),
                  7,
                  AppSpace.gutter(context),
                  7,
                ),
                child: Text(
                  _loading
                      ? '${tr('manga_source_searching')} ${_source.name}'
                      : '${_results.length} ${tr('results').toLowerCase()}',
                  style: AppType.metadata.copyWith(color: palette.mutedText),
                ),
              ),
              Expanded(
                child: _loading && _results.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      )
                    : _results.isEmpty
                    ? Center(child: Text(tr('no_results_found')))
                    : GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          AppSpace.gutter(context),
                          4,
                          AppSpace.gutter(context),
                          20,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: .64,
                            ),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          final thumbnail =
                              '${result.item['thumbnail_url'] ?? ''}'.trim();
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context, result),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox.expand(
                                      child: thumbnail.isEmpty
                                          ? ColoredBox(
                                              color: palette.surface,
                                              child: Icon(
                                                Icons.menu_book_rounded,
                                                color: palette.mutedText,
                                                size: 38,
                                              ),
                                            )
                                          : CachedNetworkImage(
                                              imageUrl: thumbnail,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  ColoredBox(
                                                    color: palette.surface,
                                                    child: Icon(
                                                      Icons.menu_book_rounded,
                                                      color: palette.mutedText,
                                                      size: 38,
                                                    ),
                                                  ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  result.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.cardTitle.copyWith(
                                    color: palette.foreground,
                                  ),
                                ),
                                Text(
                                  '${(result.score * 100).round()}% ${tr('manga_title_match')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.metadata.copyWith(
                                    color: palette.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_hasMore && _results.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.gutter(context),
                    0,
                    AppSpace.gutter(context),
                    AppSpace.md,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : () => _load(),
                    icon: _loadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(_loadingMore ? tr('loading') : tr('load_more')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceMenuIcon extends StatelessWidget {
  const _SourceMenuIcon({required this.source});
  final MihonSourceInfo source;

  @override
  Widget build(BuildContext context) {
    final encoded = source.iconBase64?.trim();
    if (encoded == null || encoded.isEmpty) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Icon(Icons.extension_rounded, size: 20),
      );
    }
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          base64Decode(encoded),
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.extension_rounded, size: 20),
        ),
      );
    } on FormatException {
      return const Icon(Icons.extension_rounded, size: 20);
    }
  }
}

class _MangaTabLoading extends StatelessWidget {
  const _MangaTabLoading({this.message, this.foreground});

  final String? message;
  final Color? foreground;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      primary: true,
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(),
                if (message != null) ...<Widget>[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(
                      color: foreground ?? AppPalette.of(context).mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _MangaTabEmpty extends StatelessWidget {
  const _MangaTabEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.gutter(context) * 1.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 42, color: palette.mutedText),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: AppType.sectionHeader.copyWith(
                      color: palette.foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: AppType.body.copyWith(color: palette.mutedText),
                    textAlign: TextAlign.center,
                  ),
                  if (actionLabel != null && onAction != null) ...<Widget>[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                  if (secondaryLabel != null && onSecondary != null)
                    TextButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MangaTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _MangaTabBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 49;

  @override
  double get maxExtent => 49;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _MangaTabBarDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: AppType.sectionHeader.copyWith(color: palette.foreground),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: AppType.metadata.copyWith(color: palette.mutedText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppType.body.copyWith(color: palette.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .56),
      borderRadius: BorderRadius.circular(AppRadii.chip),
      border: Border.all(color: Colors.white24),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        label,
        style: AppType.metadata.copyWith(color: Colors.white, fontSize: 10),
      ),
    ),
  );
}
