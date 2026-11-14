import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../mihon/mihon_runtime.dart';
import '../translation/manga_page_translation_service.dart';
import '../translation/manga_translation_models.dart';
import '../translation/manga_translation_overlay.dart';
import 'manga_chapter_download_store.dart';
import 'manga_reading_store.dart';
import 'manga_reader_crop.dart';

const MethodChannel _mangaReaderComfortChannel = MethodChannel(
  'raven23/reader_comfort',
);
const MethodChannel _mangaReaderVolumeChannel = MethodChannel(
  'raven23/reader_volume_keys',
);

/// Native Mihon chapter reader. The source extension owns HTTP, cookies,
/// Cloudflare state and image delivery; this screen owns reader presentation,
/// progress, page navigation and chapter navigation.
class MangaReaderScreen extends StatefulWidget {
  const MangaReaderScreen({
    required this.anilistId,
    required this.workTitle,
    required this.source,
    required this.mangaUrl,
    required this.chapters,
    required this.startIndex,
    super.key,
  });

  final int anilistId;
  final String workTitle;
  final MihonSourceInfo source;
  final String mangaUrl;
  final List<Map<String, dynamic>> chapters;
  final int startIndex;

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen>
    with WidgetsBindingObserver {
  final MihonRuntimeService _runtime = MihonRuntimeService.instance;
  final MangaReadingStore _store = MangaReadingStore.instance;
  final PageController _pageController = PageController();
  final ScrollController _stripController = ScrollController();
  final GlobalKey _menuButtonKey = GlobalKey();
  final MangaPageTranslationService _translationService =
      MangaPageTranslationService();
  final Map<int, Uint8List> _loadedPageBytes = <int, Uint8List>{};
  final Map<int, String> _translationPageFiles = <int, String>{};
  final Map<String, MangaPageTranslation> _translatedPages =
      <String, MangaPageTranslation>{};

  List<Map<String, dynamic>> _pages = const <Map<String, dynamic>>[];
  int _chapterIndex = 0;
  int _pageIndex = 0;
  bool _loading = true;
  bool _showChrome = false;
  bool _vertical = true;
  bool _rightToLeft = true;
  bool _autoWebtoon = true;
  bool _doublePageLandscape = false;
  bool _cropBorders = false;
  bool _tapZonesEnabled = true;
  bool _pullToChangeChapter = true;
  bool _volumeKeyPaging = false;
  bool _invertVolumeKeys = false;
  String _readerOrientation = 'system';
  double _chapterPullDistance = 0;
  bool _chapterPullTriggered = false;
  int? _webtoonDetectionChapter;
  bool? _lastDoublePageLayout;
  bool get _doublePageActive =>
      _doublePageLandscape &&
      !_vertical &&
      MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
  bool _fitHeight = false;
  String _fitMode = 'width';
  String _background = 'black';
  String _colorFilter = 'none';
  bool _keepScreenOn = true;
  double _readerBrightness = -1.0;
  bool _autoScrollActive = false;
  bool _autoScrollPaused = false;
  double _autoScrollSpeed = 1.5;
  Timer? _autoScrollTimer;
  bool _autoScrollPageAnimating = false;
  Timer? _pagePillTimer;
  bool _pagePillVisible = false;
  bool _fullScreen = false;
  bool _isChapterRead = false;
  String _translationSource = 'ja';
  String _translationTarget = 'ar';
  MangaTranslationEngine _translationEngine = MangaTranslationEngine.online;
  bool _translationRunning = false;
  bool _translationStopRequested = false;
  bool _showTranslations = true;
  int _translationCompleted = 0;
  int _translationTotal = 0;
  String? _error;
  int _loadGeneration = 0;
  int _saveGeneration = 0;

  Map<String, dynamic> get _chapter => widget.chapters[_chapterIndex];
  String get _chapterUrl => '${_chapter['url'] ?? ''}';
  String get _chapterTitle => '${_chapter['name'] ?? tr('chapter')}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chapterIndex = widget.startIndex
        .clamp(0, widget.chapters.length - 1)
        .toInt();
    unawaited(_initializeReader());
  }

  Future<void> _initializeReader() async {
    await _restoreSettings();
    if (!mounted) return;
    await _loadChapter(_chapterIndex, savePrevious: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLayout = _doublePageActive;
    final previousLayout = _lastDoublePageLayout;
    _lastDoublePageLayout = currentLayout;
    if (previousLayout != null && previousLayout != currentLayout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreViewport(_pageIndex, _pages.length);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_syncVolumeKeys(false));
    _mangaReaderVolumeChannel.setMethodCallHandler(null);
    unawaited(_saveProgress());
    _translationService.cancelPending();
    _autoScrollTimer?.cancel();
    _pagePillTimer?.cancel();
    unawaited(_resetReaderBrightness());
    unawaited(WakelockPlus.disable());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    _pageController.dispose();
    _stripController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_volumeKeyPaging) unawaited(_syncVolumeKeys(true));
    } else {
      unawaited(_syncVolumeKeys(false));
    }
  }

  Future<void> _syncVolumeKeys([bool enabled = true]) async {
    final shouldEnable = enabled && _volumeKeyPaging;
    try {
      await _mangaReaderVolumeChannel.invokeMethod<void>(
        'setEnabled',
        <String, bool>{'enabled': shouldEnable},
      );
      if (shouldEnable) {
        _mangaReaderVolumeChannel.setMethodCallHandler((call) async {
          if (call.method == 'volumeKey') {
            final up = call.arguments == 'up';
            final forward = _invertVolumeKeys ? up : !up;
            if (_vertical) {
              _scrollStripByViewport(forward ? 1 : -1);
            } else {
              final step = _doublePageActive ? 2 : 1;
              await _jumpToPage(_pageIndex + (forward ? step : -step));
            }
          }
          return null;
        });
      }
    } on PlatformException {
      // Keep normal system volume behaviour when the native bridge is absent.
    } on MissingPluginException {
      // Non-Android builds do not provide the native volume-key bridge.
    }
  }

  Future<void> _restoreSettings() async {
    final settings = await _store.readerSettings();
    if (!mounted) return;
    setState(() {
      _vertical = settings['vertical'] != false;
      _rightToLeft = settings['rightToLeft'] != false;
      _autoWebtoon = settings['autoWebtoon'] != false;
      _doublePageLandscape = settings['doublePageLandscape'] == true;
      _cropBorders = settings['cropBorders'] == true;
      _tapZonesEnabled = settings['tapZonesEnabled'] != false;
      _pullToChangeChapter = settings['pullToChangeChapter'] != false;
      _volumeKeyPaging = settings['volumeKeyPaging'] == true;
      _invertVolumeKeys = settings['invertVolumeKeys'] == true;
      _readerOrientation = settings['readerOrientation'] is String
          ? settings['readerOrientation'] as String
          : 'system';
      _fitMode = settings['fitMode'] is String
          ? settings['fitMode'] as String
          : settings['fitHeight'] == true
          ? 'height'
          : 'width';
      _fitHeight = _fitMode == 'height';
      _background = settings['background'] is String
          ? settings['background'] as String
          : 'black';
      _colorFilter = settings['colorFilter'] is String
          ? settings['colorFilter'] as String
          : 'none';
      _keepScreenOn = settings['keepScreenOn'] != false;
      _readerBrightness = (settings['brightness'] as num?)?.toDouble() ?? -1.0;
      _autoScrollSpeed =
          ((settings['autoScrollSpeed'] as num?)?.toDouble() ?? 1.5)
              .clamp(0.5, 5.0)
              .toDouble();
      _fullScreen = settings['fullScreen'] == true;
      _translationSource = settings['translationSource'] is String
          ? settings['translationSource'] as String
          : 'ja';
      _translationTarget = settings['translationTarget'] is String
          ? settings['translationTarget'] as String
          : 'ar';
      _translationEngine = settings['translationEngine'] == 'offline'
          ? MangaTranslationEngine.offline
          : MangaTranslationEngine.online;
    });
    await _applyComfortSettings();
    await _applyReaderBrightness();
    if (_volumeKeyPaging) await _syncVolumeKeys(true);
  }

  Future<void> _persistSettings() =>
      _store.saveReaderSettings(<String, dynamic>{
        'vertical': _vertical,
        'rightToLeft': _rightToLeft,
        'autoWebtoon': _autoWebtoon,
        'doublePageLandscape': _doublePageLandscape,
        'cropBorders': _cropBorders,
        'tapZonesEnabled': _tapZonesEnabled,
        'pullToChangeChapter': _pullToChangeChapter,
        'volumeKeyPaging': _volumeKeyPaging,
        'invertVolumeKeys': _invertVolumeKeys,
        'readerOrientation': _readerOrientation,
        'fitHeight': _fitHeight,
        'fitMode': _fitMode,
        'background': _background,
        'colorFilter': _colorFilter,
        'keepScreenOn': _keepScreenOn,
        'brightness': _readerBrightness,
        'autoScrollSpeed': _autoScrollSpeed,
        'fullScreen': _fullScreen,
        'translationSource': _translationSource,
        'translationTarget': _translationTarget,
        'translationEngine': _translationEngine.name,
      });

  Future<void> _applyComfortSettings() async {
    if (_keepScreenOn) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
    await SystemChrome.setEnabledSystemUIMode(
      _fullScreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    final orientations = switch (_readerOrientation) {
      'portrait' => <DeviceOrientation>[DeviceOrientation.portraitUp],
      'landscape' => <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      _ => DeviceOrientation.values,
    };
    try {
      await SystemChrome.setPreferredOrientations(orientations);
    } on PlatformException {
      // Orientation locks are optional on platforms that do not support them.
    } on MissingPluginException {
      // Keep the reader usable if the platform channel is unavailable.
    }
  }

  Future<void> _applyReaderBrightness() async {
    try {
      await _mangaReaderComfortChannel.invokeMethod<void>(
        'setBrightness',
        <String, double>{'value': _readerBrightness},
      );
    } on PlatformException {
      // Reader brightness is a comfort enhancement; a platform failure must
      // not interrupt loading or reading the chapter.
    } on MissingPluginException {
      // The native bridge is not available on non-Android targets.
    }
  }

  Future<void> _resetReaderBrightness() async {
    try {
      await _mangaReaderComfortChannel.invokeMethod<void>(
        'setBrightness',
        const <String, double>{'value': -1.0},
      );
    } on PlatformException {
      // Ignore a reset failure while the reader is being disposed.
    } on MissingPluginException {
      // The native bridge is not available on non-Android targets.
    }
  }

  void _setAutoScroll(bool enabled) {
    _autoScrollTimer?.cancel();
    _autoScrollPageAnimating = false;
    if (!enabled) {
      if (mounted) {
        setState(() {
          _autoScrollActive = false;
          _autoScrollPaused = false;
        });
      } else {
        _autoScrollActive = false;
        _autoScrollPaused = false;
      }
      unawaited(_persistSettings());
      return;
    }

    setState(() {
      _autoScrollActive = true;
      _autoScrollPaused = false;
    });

    if (_vertical) {
      // Smooth continuous movement for Webtoon/vertical reading.
      _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        if (!mounted ||
            !_autoScrollActive ||
            _autoScrollPaused ||
            !_stripController.hasClients) {
          return;
        }
        final position = _stripController.position;
        if (position.pixels >= position.maxScrollExtent - 1) {
          _setAutoScroll(false);
          return;
        }
        _stripController.jumpTo(
          (position.pixels + _autoScrollSpeed)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble(),
        );
      });
    } else {
      // Paged manga advances one page/spread per interval. Higher speed means
      // a shorter pause between turns, matching the Zangetsu reader behavior.
      final intervalMilliseconds = (3200 / _autoScrollSpeed)
          .clamp(500, 8000)
          .round();
      _autoScrollTimer = Timer.periodic(
        Duration(milliseconds: intervalMilliseconds),
        (_) async {
          if (!mounted ||
              !_autoScrollActive ||
              _autoScrollPaused ||
              _autoScrollPageAnimating ||
              !_pageController.hasClients ||
              _pages.isEmpty) {
            return;
          }
          final currentSpread =
              _pageController.page?.round() ??
              (_doublePageActive ? _pageIndex ~/ 2 : _pageIndex);
          final lastSpread = _doublePageActive
              ? (_pages.length - 1) ~/ 2
              : _pages.length - 1;
          if (currentSpread >= lastSpread) {
            _setAutoScroll(false);
            return;
          }
          _autoScrollPageAnimating = true;
          try {
            await _pageController.nextPage(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
            );
          } catch (_) {
            // A chapter/layout change can detach the PageController mid-turn.
          } finally {
            _autoScrollPageAnimating = false;
          }
        },
      );
    }
    unawaited(_persistSettings());
  }

  void _toggleAutoScrollPause() {
    if (!_autoScrollActive) return;
    setState(() => _autoScrollPaused = !_autoScrollPaused);
  }

  Color _readerBackground(BuildContext context) => switch (_background) {
    'white' => Colors.white,
    'gray' => const Color(0xFF777777),
    'system' => AppPalette.of(context).page,
    _ => Colors.black,
  };

  Uri? get _chapterUri {
    final raw = _chapterUrl.trim();
    if (raw.isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;
    final base = Uri.tryParse(widget.source.baseUrl);
    return base?.resolveUri(parsed);
  }

  Future<void> _loadChapter(int index, {bool savePrevious = true}) async {
    if (index < 0 || index >= widget.chapters.length) return;
    // Invalidate async work immediately, before the progress write can yield.
    final generation = ++_loadGeneration;
    _translationService.cancelPending();
    _autoScrollTimer?.cancel();
    _autoScrollActive = false;
    _autoScrollPaused = false;
    _autoScrollPageAnimating = false;
    _chapterPullDistance = 0;
    _chapterPullTriggered = false;
    _webtoonDetectionChapter = null;
    _pagePillTimer?.cancel();
    _pagePillVisible = false;
    if (savePrevious && _pages.isNotEmpty) await _saveProgress();
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _chapterIndex = index;
      _loading = true;
      _error = null;
      _pages = const <Map<String, dynamic>>[];
      _pageIndex = 0;
      _showChrome = false;
      _isChapterRead = false;
      _loadedPageBytes.clear();
      _translationPageFiles.clear();
      _translatedPages.clear();
      _translationRunning = false;
      _translationStopRequested = false;
      _translationCompleted = 0;
      _translationTotal = 0;
    });
    try {
      var pages =
          await MangaChapterDownloadStore.instance.cachedPages(
            anilistId: widget.anilistId,
            sourceId: widget.source.id,
            chapterUrl: '${widget.chapters[index]['url'] ?? ''}',
          ) ??
          const <Map<String, dynamic>>[];
      if (pages.isEmpty) {
        Object? lastError;
        for (var attempt = 0; attempt < 2; attempt++) {
          try {
            pages = await _runtime.pages(
              widget.source.id,
              '${widget.chapters[index]['url'] ?? ''}',
            );
            lastError = null;
            if (pages.isNotEmpty) break;
          } catch (error) {
            lastError = error;
          }
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 350));
          }
        }
        if (lastError != null && pages.isEmpty) throw lastError;
      }
      pages = pages
          .where((page) => '${page['imageUrl'] ?? ''}'.trim().isNotEmpty)
          .toList(growable: false);
      if (pages.isEmpty) throw StateError(tr('mihon_pages_empty'));
      final saved = await _store.progressForChapter(
        widget.anilistId,
        widget.source.id,
        '${widget.chapters[index]['url'] ?? ''}',
      );
      final start = saved == null || saved.isRead
          ? 0
          : saved.pageIndex.clamp(0, pages.length - 1).toInt();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _pages = pages;
        _pageIndex = start;
        _isChapterRead = saved?.isRead == true;
        _loading = false;
      });
      _restoreViewport(start, pages.length);
      await _saveProgress();
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _restoreViewport(int page, int total) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || total == 0) return;
      if (_vertical && _stripController.hasClients) {
        final max = _stripController.position.maxScrollExtent;
        if (max > 0) {
          _stripController.jumpTo(max * (page / (total > 1 ? total - 1 : 1)));
        }
      } else if (!_vertical && _pageController.hasClients) {
        _pageController.jumpToPage(_doublePageActive ? page ~/ 2 : page);
      }
    });
  }

  Future<void> _saveProgress() async {
    if (_pages.isEmpty || _chapterUrl.isEmpty) return;
    final generation = ++_saveGeneration;
    await _store.saveProgress(
      anilistId: widget.anilistId,
      sourceId: widget.source.id,
      chapterUrl: _chapterUrl,
      pageIndex: _pageIndex,
      totalPages: _pages.length,
      isRead: _isChapterRead || _pageIndex >= _pages.length - 1,
    );
    if (generation != _saveGeneration) return;
  }

  void _setPage(int index) {
    if (_pages.isEmpty) return;
    final safe = index.clamp(0, _pages.length - 1).toInt();
    if (safe == _pageIndex) return;
    setState(() {
      _pageIndex = safe;
      _isChapterRead = safe >= _pages.length - 1;
      _pagePillVisible = true;
    });
    _pagePillTimer?.cancel();
    _pagePillTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _pagePillVisible) {
        setState(() => _pagePillVisible = false);
      }
    });
    unawaited(_saveProgress());
  }

  void _onPageChanged(int index) =>
      _setPage(_doublePageActive ? index * 2 : index);

  void _onStripPageVisible(int index, VisibilityInfo info) {
    if (!_vertical || index == _pageIndex) return;
    final midpoint = MediaQuery.sizeOf(context).height * .52;
    final bounds = info.visibleBounds;
    if (bounds.top <= midpoint && bounds.bottom >= midpoint) {
      _setPage(index);
    }
  }

  bool _onReaderScrollNotification(ScrollNotification notification) {
    if (!_vertical || !_pullToChangeChapter || _chapterPullTriggered) {
      if (notification is ScrollEndNotification) _chapterPullDistance = 0;
      return false;
    }
    if (notification is OverscrollNotification) {
      final atStart =
          notification.metrics.pixels <=
          notification.metrics.minScrollExtent + 1;
      final atEnd =
          notification.metrics.pixels >=
          notification.metrics.maxScrollExtent - 1;
      final towardPrevious = atStart && notification.overscroll < 0;
      final towardNext = atEnd && notification.overscroll > 0;
      if (towardPrevious || towardNext) {
        _chapterPullDistance += notification.overscroll.abs();
        if (_chapterPullDistance >= 96) {
          _chapterPullTriggered = true;
          _chapterPullDistance = 0;
          if (towardPrevious && _chapterIndex > 0) {
            unawaited(_previousChapter());
          } else if (towardNext && _chapterIndex < widget.chapters.length - 1) {
            unawaited(_nextChapter());
          } else {
            _chapterPullTriggered = false;
          }
        }
      } else {
        _chapterPullDistance = 0;
      }
    } else if (notification is ScrollEndNotification) {
      _chapterPullDistance = 0;
      _chapterPullTriggered = false;
    }
    return false;
  }

  Future<void> _detectWebtoonIfNeeded(int index, Uint8List bytes) async {
    if (!_autoWebtoon ||
        index != 0 ||
        _webtoonDetectionChapter == _chapterIndex) {
      return;
    }
    final chapter = _chapterIndex;
    _webtoonDetectionChapter = chapter;
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes, targetWidth: 96);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final ratio = image.height / image.width;
      if (ratio >= 2.5 && mounted && chapter == _chapterIndex && !_vertical) {
        setState(() {
          _vertical = true;
          _autoScrollActive = false;
          _autoScrollPaused = false;
        });
        _autoScrollTimer?.cancel();
        unawaited(_persistSettings());
      }
    } catch (_) {
      // Detection is advisory: unreadable dimensions must never block pages.
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  Future<void> _previousChapter() async {
    if (_chapterIndex <= 0) return;
    await _loadChapter(_chapterIndex - 1);
  }

  Future<void> _nextChapter() async {
    if (_chapterIndex >= widget.chapters.length - 1) return;
    await _loadChapter(_chapterIndex + 1);
  }

  Future<void> _jumpToPage(int index) async {
    if (_pages.isEmpty) return;
    final bounded = index.clamp(0, _pages.length - 1).toInt();
    final safe = _doublePageActive ? (bounded ~/ 2) * 2 : bounded;
    if (_vertical && _stripController.hasClients) {
      final max = _stripController.position.maxScrollExtent;
      _stripController.jumpTo(
        max * (safe / (_pages.length > 1 ? _pages.length - 1 : 1)),
      );
      _setPage(safe);
    } else if (_pageController.hasClients) {
      await _pageController.animateToPage(
        _doublePageActive ? safe ~/ 2 : safe,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      if (_doublePageActive) _setPage(safe);
    }
  }

  Future<void> _openChapterPicker() async {
    final chapterScrollController = ScrollController(
      initialScrollOffset: (_chapterIndex > 2 ? _chapterIndex - 2 : 0) * 72.0,
    );
    int? selected;
    try {
      selected = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppPalette.of(context).page,
        builder: (sheetContext) {
          final palette = AppPalette.of(sheetContext);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .72,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: Text(
                      tr('manga_chapter_list'),
                      style: AppType.sectionHeader.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: chapterScrollController,
                      itemExtent: 72,
                      itemCount: widget.chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = widget.chapters[index];
                        final active = index == _chapterIndex;
                        return ListTile(
                          selected: active,
                          title: Text('${chapter['name'] ?? tr('chapter')}'),
                          subtitle: Text('${chapter['scanlator'] ?? ''}'),
                          trailing: active
                              ? const Icon(Icons.play_arrow_rounded)
                              : null,
                          onTap: () => Navigator.pop(sheetContext, index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      chapterScrollController.dispose();
    }
    if (selected != null) await _loadChapter(selected);
  }

  Future<void> _openSettings() async {
    final palette = AppPalette.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void update(VoidCallback change, {bool persist = true}) {
            setState(change);
            setSheetState(() {});
            if (persist) unawaited(_persistSettings());
          }

          Widget section(String title, Widget child) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpace.xs,
                    bottom: AppSpace.sm,
                  ),
                  child: Text(
                    title,
                    style: AppType.sectionHeader.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppRadii.sheet),
                    border: Border.all(color: palette.hairline),
                  ),
                  child: child,
                ),
              ],
            ),
          );

          Widget choices(
            List<(String, String)> values,
            String selected,
            ValueChanged<String> onSelected,
          ) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final item in values)
                ChoiceChip(
                  label: Text(item.$2),
                  selected: selected == item.$1,
                  onSelected: (_) => onSelected(item.$1),
                ),
            ],
          );

          Widget settingsRow({
            required IconData icon,
            required String title,
            String? subtitle,
            required Widget trailing,
            VoidCallback? onTap,
          }) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: palette.mutedText),
            title: Text(
              title,
              style: AppType.body.copyWith(color: palette.foreground),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle,
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
            trailing: trailing,
            onTap: onTap,
          );

          final direction = _vertical
              ? 'vertical'
              : _rightToLeft
              ? 'rtl'
              : 'ltr';
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .88,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  AppSpace.lg,
                  AppSpace.lg,
                  AppSpace.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr('manga_reader_settings'),
                      style: AppType.sectionHeader.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    section(
                      tr('manga_reader_section_translation'),
                      settingsRow(
                        icon: Icons.translate_rounded,
                        title: tr('manga_translate_chapter'),
                        subtitle:
                            '${mangaOcrLanguages[_translationSource] ?? _translationSource} → ${mangaTranslationLanguages[_translationTarget] ?? _translationTarget}',
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_openTranslationSettings());
                        },
                      ),
                    ),
                    section(
                      tr('manga_reader_section_reading'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          choices(
                            <(String, String)>[
                              ('vertical', tr('manga_reader_vertical')),
                              ('ltr', tr('manga_reader_ltr')),
                              ('rtl', tr('manga_reader_rtl')),
                            ],
                            direction,
                            (value) {
                              _autoScrollTimer?.cancel();
                              _autoScrollPageAnimating = false;
                              update(() {
                                _vertical = value == 'vertical';
                                _rightToLeft = value == 'rtl';
                                _autoScrollActive = false;
                                _autoScrollPaused = false;
                              });
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr('manga_reader_auto_webtoon')),
                            subtitle: Text(
                              tr('manga_reader_auto_webtoon_hint'),
                            ),
                            value: _autoWebtoon,
                            onChanged: (value) =>
                                update(() => _autoWebtoon = value),
                          ),
                        ],
                      ),
                    ),
                    section(
                      tr('manga_reader_section_display'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tr('manga_reader_fit'),
                            style: AppType.body.copyWith(
                              color: palette.foreground,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          choices(
                            <(String, String)>[
                              ('width', tr('manga_reader_fit_width')),
                              ('height', tr('manga_reader_fit_height')),
                              ('contain', tr('manga_reader_fit_contain')),
                              ('original', tr('manga_reader_fit_original')),
                              ('smart', tr('manga_reader_fit_smart')),
                            ],
                            _fitMode,
                            (value) => update(() {
                              _fitMode = value;
                              _fitHeight = value == 'height';
                            }),
                          ),
                          const SizedBox(height: AppSpace.md),
                          Text(
                            tr('manga_reader_background'),
                            style: AppType.body.copyWith(
                              color: palette.foreground,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          choices(
                            <(String, String)>[
                              ('black', tr('manga_reader_bg_black')),
                              ('white', tr('manga_reader_bg_white')),
                              ('gray', tr('manga_reader_bg_gray')),
                              ('system', tr('manga_reader_bg_system')),
                            ],
                            _background,
                            (value) => update(() => _background = value),
                          ),
                          const SizedBox(height: AppSpace.md),
                          Text(
                            tr('manga_reader_filter'),
                            style: AppType.body.copyWith(
                              color: palette.foreground,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          choices(
                            <(String, String)>[
                              ('none', tr('manga_reader_filter_none')),
                              (
                                'grayscale',
                                tr('manga_reader_filter_grayscale'),
                              ),
                              ('invert', tr('manga_reader_filter_invert')),
                              ('sepia', tr('manga_reader_filter_sepia')),
                            ],
                            _colorFilter,
                            (value) => update(() => _colorFilter = value),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr('manga_reader_double_page')),
                            subtitle: Text(tr('manga_reader_double_page_hint')),
                            value: _doublePageLandscape,
                            onChanged: (value) {
                              update(() => _doublePageLandscape = value);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted)
                                  _restoreViewport(_pageIndex, _pages.length);
                              });
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr('manga_reader_crop_borders')),
                            subtitle: Text(
                              tr('manga_reader_crop_borders_hint'),
                            ),
                            value: _cropBorders,
                            onChanged: (value) =>
                                update(() => _cropBorders = value),
                          ),
                        ],
                      ),
                    ),
                    section(
                      tr('manga_reader_section_navigation'),
                      Column(
                        children: <Widget>[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr('manga_reader_auto_scroll')),
                            subtitle: Text(tr('manga_reader_auto_scroll_hint')),
                            value: _autoScrollActive,
                            onChanged: (value) {
                              _setAutoScroll(value);
                              setSheetState(() {});
                            },
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                tr('manga_reader_auto_scroll_speed'),
                                style: AppType.body.copyWith(
                                  color: palette.foreground,
                                ),
                              ),
                              Slider(
                                min: .5,
                                max: 5,
                                divisions: 18,
                                value: _autoScrollSpeed.clamp(.5, 5).toDouble(),
                                onChanged: (value) {
                                  update(() => _autoScrollSpeed = value);
                                  if (_autoScrollActive && !_vertical) {
                                    _setAutoScroll(true);
                                  }
                                },
                              ),
                            ],
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr('manga_reader_tap_zones')),
                            subtitle: Text(tr('manga_reader_tap_zones_hint')),
                            value: _tapZonesEnabled,
                            onChanged: (value) =>
                                update(() => _tapZonesEnabled = value),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              tr('manga_reader_pull_to_change_chapter'),
                            ),
                            value: _pullToChangeChapter,
                            onChanged: (value) =>
                                update(() => _pullToChangeChapter = value),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr('manga_reader_volume_key_paging')),
                            subtitle: Text(
                              tr('manga_reader_volume_key_paging_hint'),
                            ),
                            value: _volumeKeyPaging,
                            onChanged: (value) {
                              update(() => _volumeKeyPaging = value);
                              unawaited(_syncVolumeKeys(value));
                            },
                          ),
                          if (_volumeKeyPaging)
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                tr('manga_reader_invert_volume_keys'),
                              ),
                              value: _invertVolumeKeys,
                              onChanged: (value) =>
                                  update(() => _invertVolumeKeys = value),
                            ),
                        ],
                      ),
                    ),
                    section(
                      tr('manga_reader_section_comfort'),
                      Column(
                        children: <Widget>[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr('manga_reader_keep_screen_on')),
                            value: _keepScreenOn,
                            onChanged: (value) {
                              update(() => _keepScreenOn = value);
                              unawaited(_applyComfortSettings());
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tr('manga_reader_fullscreen')),
                            value: _fullScreen,
                            onChanged: (value) {
                              update(() => _fullScreen = value);
                              unawaited(_applyComfortSettings());
                            },
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              tr('manga_reader_orientation'),
                              style: AppType.body.copyWith(
                                color: palette.foreground,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          choices(
                            <(String, String)>[
                              ('system', tr('manga_reader_orientation_system')),
                              (
                                'portrait',
                                tr('manga_reader_orientation_portrait'),
                              ),
                              (
                                'landscape',
                                tr('manga_reader_orientation_landscape'),
                              ),
                            ],
                            _readerOrientation,
                            (value) {
                              update(() => _readerOrientation = value);
                              unawaited(_applyComfortSettings());
                            },
                          ),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  tr('manga_reader_brightness'),
                                  style: AppType.body.copyWith(
                                    color: palette.foreground,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  update(() => _readerBrightness = -1.0);
                                  unawaited(_applyReaderBrightness());
                                },
                                child: Text(
                                  tr('manga_reader_brightness_system'),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            min: .1,
                            max: 1,
                            divisions: 18,
                            value:
                                (_readerBrightness < 0 ? .6 : _readerBrightness)
                                    .clamp(.1, 1)
                                    .toDouble(),
                            onChanged: (value) {
                              update(() => _readerBrightness = value);
                              unawaited(_applyReaderBrightness());
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _rememberPageBytes(int index, Uint8List bytes) {
    _loadedPageBytes.putIfAbsent(index, () => bytes);
    if (index == 0 && _autoWebtoon) {
      unawaited(_detectWebtoonIfNeeded(index, bytes));
    }
  }

  Future<void> _openPageActions(int index) async {
    if (index < 0 || index >= _pages.length) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppPalette.of(context).surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.save_alt_rounded),
              title: Text(tr('manga_reader_save_gallery')),
              onTap: () => Navigator.pop(sheetContext, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(tr('manga_reader_share_page')),
              onTap: () => Navigator.pop(sheetContext, 'share'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    try {
      final bytes = await _pageBytesForAction(index);
      if (selected == 'save') {
        await _mangaReaderComfortChannel.invokeMethod<String>(
          'saveImageToGallery',
          <String, Object>{
            'bytes': bytes,
            'name':
                'RAVEN23_${widget.anilistId}_${_chapterIndex + 1}_${index + 1}',
            'mimeType': _imageMime(bytes),
          },
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('manga_reader_page_saved'))));
      } else {
        final temporary = await getTemporaryDirectory();
        final extension = _imageExtension(bytes);
        final file = File(
          p.join(
            temporary.path,
            'raven23_page_${widget.anilistId}_${_chapterIndex + 1}_${index + 1}.$extension',
          ),
        );
        await file.writeAsBytes(bytes, flush: true);
        await Share.shareXFiles(<XFile>[
          XFile(file.path, mimeType: _imageMime(bytes)),
        ], text: '${widget.workTitle} · $_chapterTitle');
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? tr('manga_reader_page_save_failed')),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('manga_reader_page_save_failed'))),
      );
    }
  }

  Future<Uint8List> _pageBytesForAction(int index) async {
    final cached = _loadedPageBytes[index];
    if (cached != null && cached.isNotEmpty) return cached;
    final page = _pages[index];
    final localPath = '${page['localPath'] ?? ''}'.trim();
    if (localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }
    }
    final rawHeaders = page['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const <String, String>{};
    final bytes = await _runtime.image(
      widget.source.id,
      '${page['imageUrl'] ?? ''}',
      headers: headers,
    );
    if (bytes.isEmpty) throw StateError('Empty manga page');
    _loadedPageBytes[index] = bytes;
    return bytes;
  }

  String _imageMime(Uint8List bytes) {
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50)
      return 'image/png';
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP')
      return 'image/webp';
    if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8)
      return 'image/jpeg';
    if (bytes.length >= 6 && String.fromCharCodes(bytes.sublist(0, 3)) == 'GIF')
      return 'image/gif';
    return 'image/jpeg';
  }

  String _imageExtension(Uint8List bytes) => switch (_imageMime(bytes)) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    _ => 'jpg',
  };

  Future<File> _translationFileForPage(int index) async {
    final existingPath = _translationPageFiles[index];
    if (existingPath != null) {
      final existing = File(existingPath);
      if (await existing.exists() && await existing.length() > 0)
        return existing;
      _translationPageFiles.remove(index);
    }

    final page = _pages[index];
    final localPath = '${page['localPath'] ?? ''}'.trim();
    if (localPath.isNotEmpty) {
      final localFile = File(localPath);
      if (await localFile.exists() && await localFile.length() > 0) {
        _translationPageFiles[index] = localFile.path;
        return localFile;
      }
    }

    final imageUrl = '${page['imageUrl'] ?? ''}'.trim();
    if (imageUrl.isEmpty)
      throw StateError('The manga page has no image address.');
    var bytes = _loadedPageBytes[index];
    if (bytes == null || bytes.isEmpty) {
      final rawHeaders = page['headers'];
      final headers = rawHeaders is Map
          ? rawHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{};
      bytes = await _runtime.image(
        widget.source.id,
        imageUrl,
        headers: headers,
      );
      if (bytes.isEmpty) throw StateError('The manga page image is empty.');
      _loadedPageBytes[index] = bytes;
    }

    final temporary = await getTemporaryDirectory();
    final cacheDirectory = Directory(
      p.join(temporary.path, 'raven23_manga_ocr'),
    );
    await cacheDirectory.create(recursive: true);
    final name = sha256.convert(utf8.encode(imageUrl)).toString();
    final file = File(p.join(cacheDirectory.path, '$name.page'));
    await file.writeAsBytes(bytes, flush: true);
    _translationPageFiles[index] = file.path;
    return file;
  }

  Future<void> _openTranslationSettings() async {
    if (_pages.isEmpty || _translationRunning) return;
    final chapterGeneration = _loadGeneration;
    try {
      final installedOcr = await _translationService.supportedOcrLanguages();
      final supportedOffline = await _translationService
          .supportedOfflineLanguages();
      if (!mounted || chapterGeneration != _loadGeneration) return;
      final sourceOptions = mangaOcrLanguages.keys
          .where(installedOcr.contains)
          .toList(growable: false);
      if (sourceOptions.isEmpty) {
        throw StateError(
          'No supported on-device OCR language packs are available.',
        );
      }

      var engine = _translationEngine;
      var source = sourceOptions.contains(_translationSource)
          ? _translationSource
          : sourceOptions.first;
      List<String> availableSources() =>
          engine == MangaTranslationEngine.offline
          ? sourceOptions
                .where(supportedOffline.contains)
                .toList(growable: false)
          : sourceOptions;
      List<String> availableTargets() => mangaTranslationLanguages.keys
          .where(
            (code) =>
                code != source &&
                (engine == MangaTranslationEngine.online ||
                    supportedOffline.contains(code)),
          )
          .toList(growable: false);
      if (engine == MangaTranslationEngine.offline &&
          (!supportedOffline.contains(source) ||
              !mangaTranslationLanguages.keys.any(
                (code) => code != source && supportedOffline.contains(code),
              ))) {
        engine = MangaTranslationEngine.online;
      }
      var targets = availableTargets();
      var target = targets.contains(_translationTarget)
          ? _translationTarget
          : targets.contains('ar')
          ? 'ar'
          : targets.first;

      final selected =
          await showModalBottomSheet<(String, String, MangaTranslationEngine)>(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppPalette.of(context).surface,
            builder: (sheetContext) => StatefulBuilder(
              builder: (sheetContext, setSheetState) {
                final currentSources = availableSources();
                targets = availableTargets();
                if (currentSources.isNotEmpty &&
                    !currentSources.contains(source))
                  source = currentSources.first;
                if (targets.isNotEmpty && !targets.contains(target))
                  target = targets.first;
                final palette = AppPalette.of(sheetContext);
                Widget fieldLabel(String value) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    value,
                    style: AppType.body.copyWith(color: palette.mutedText),
                  ),
                );
                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpace.lg,
                      AppSpace.lg,
                      AppSpace.lg,
                      MediaQuery.viewInsetsOf(sheetContext).bottom +
                          AppSpace.lg,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            tr('manga_translate_chapter'),
                            style: AppType.sectionHeader.copyWith(
                              color: palette.foreground,
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),
                          fieldLabel(tr('manga_translation_engine')),
                          Wrap(
                            spacing: 8,
                            children: <Widget>[
                              ChoiceChip(
                                label: Text(tr('manga_translation_online')),
                                selected:
                                    engine == MangaTranslationEngine.online,
                                onSelected: (_) => setSheetState(() {
                                  engine = MangaTranslationEngine.online;
                                  final nextSources = availableSources();
                                  if (!nextSources.contains(source) &&
                                      nextSources.isNotEmpty)
                                    source = nextSources.first;
                                  final nextTargets = availableTargets();
                                  if (!nextTargets.contains(target) &&
                                      nextTargets.isNotEmpty)
                                    target = nextTargets.first;
                                }),
                              ),
                              ChoiceChip(
                                label: Text(tr('manga_translation_offline')),
                                selected:
                                    engine == MangaTranslationEngine.offline,
                                onSelected: supportedOffline.isEmpty
                                    ? null
                                    : (_) => setSheetState(() {
                                        engine = MangaTranslationEngine.offline;
                                        final nextSources = availableSources();
                                        if (!nextSources.contains(source) &&
                                            nextSources.isNotEmpty)
                                          source = nextSources.first;
                                        final nextTargets = availableTargets();
                                        if (!nextTargets.contains(target) &&
                                            nextTargets.isNotEmpty)
                                          target = nextTargets.first;
                                      }),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.md),
                          fieldLabel(tr('manga_translation_source_language')),
                          DropdownButtonFormField<String>(
                            initialValue: currentSources.contains(source)
                                ? source
                                : currentSources.isNotEmpty
                                ? currentSources.first
                                : null,
                            isExpanded: true,
                            items: <DropdownMenuItem<String>>[
                              for (final code in currentSources)
                                DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(mangaOcrLanguages[code] ?? code),
                                ),
                            ],
                            onChanged: currentSources.isEmpty
                                ? null
                                : (value) => setSheetState(() {
                                    if (value == null) return;
                                    source = value;
                                    targets = availableTargets();
                                    if (!targets.contains(target) &&
                                        targets.isNotEmpty)
                                      target = targets.first;
                                  }),
                          ),
                          const SizedBox(height: AppSpace.md),
                          fieldLabel(tr('manga_translation_target_language')),
                          DropdownButtonFormField<String>(
                            initialValue: targets.contains(target)
                                ? target
                                : targets.isNotEmpty
                                ? targets.first
                                : null,
                            isExpanded: true,
                            items: <DropdownMenuItem<String>>[
                              for (final code in targets)
                                DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(
                                    mangaTranslationLanguages[code] ?? code,
                                  ),
                                ),
                            ],
                            onChanged: targets.isEmpty
                                ? null
                                : (value) => setSheetState(() {
                                    if (value != null) target = value;
                                  }),
                          ),
                          const SizedBox(height: AppSpace.md),
                          Text(
                            engine == MangaTranslationEngine.online
                                ? tr('manga_translation_online_privacy_note')
                                : tr('manga_translation_offline_note'),
                            style: AppType.metadata.copyWith(
                              color: palette.mutedText,
                            ),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  currentSources.isEmpty || targets.isEmpty
                                  ? null
                                  : () => Navigator.of(
                                      sheetContext,
                                    ).pop((source, target, engine)),
                              icon: const Icon(Icons.translate_rounded),
                              label: Text(tr('manga_translation_start')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
      if (!mounted || chapterGeneration != _loadGeneration || selected == null)
        return;
      final translationConfigChanged =
          _translationSource != selected.$1 ||
          _translationTarget != selected.$2 ||
          _translationEngine != selected.$3;
      if (translationConfigChanged) {
        _translationService.cancelPending();
      }
      setState(() {
        _translationSource = selected.$1;
        _translationTarget = selected.$2;
        _translationEngine = selected.$3;
        if (translationConfigChanged) _translatedPages.clear();
        _showTranslations = true;
      });
      await _persistSettings();
      if (!mounted || chapterGeneration != _loadGeneration) return;
      await _startChapterTranslation(
        sourceLanguage: selected.$1,
        targetLanguage: selected.$2,
        engine: selected.$3,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _startChapterTranslation({
    required String sourceLanguage,
    required String targetLanguage,
    required MangaTranslationEngine engine,
  }) async {
    if (_translationRunning || _pages.isEmpty) return;
    final chapterGeneration = _loadGeneration;
    final status = await _translationService.modelStatus(
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      engine: engine,
    );
    if (!mounted || chapterGeneration != _loadGeneration) return;
    if (!status.readyFor(engine)) {
      final message = engine == MangaTranslationEngine.offline
          ? tr('manga_translation_download_offline_models')
          : tr('manga_translation_download_ocr_model');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('manga_translation_prepare_models')),
          content: Text(message),
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
      if (!mounted || chapterGeneration != _loadGeneration || confirmed != true)
        return;
      await _translationService.downloadModels(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        engine: engine,
      );
      if (!mounted || chapterGeneration != _loadGeneration) return;
    }

    setState(() {
      _translationRunning = true;
      _translationStopRequested = false;
      _showTranslations = true;
      _translationCompleted = 0;
      _translationTotal = _pages.length;
    });

    var failedPages = 0;
    try {
      for (var index = 0; index < _pages.length; index++) {
        if (!mounted ||
            chapterGeneration != _loadGeneration ||
            _translationStopRequested)
          break;
        final pageUrl = '${_pages[index]['imageUrl'] ?? ''}';
        try {
          final file = await _translationFileForPage(index);
          if (!mounted ||
              chapterGeneration != _loadGeneration ||
              _translationStopRequested)
            break;
          final translated = await _translationService.translatePage(
            pageUrl: pageUrl,
            filePath: file.path,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            engine: engine,
          );
          if (!mounted || chapterGeneration != _loadGeneration) break;
          setState(() {
            _translatedPages[pageUrl] = translated;
            _translationCompleted++;
          });
        } catch (error) {
          if (!mounted || chapterGeneration != _loadGeneration) break;
          failedPages++;
          setState(() {
            _translationCompleted++;
          });
        }
      }
    } finally {
      if (mounted && chapterGeneration == _loadGeneration) {
        setState(() {
          _translationRunning = false;
          _translationStopRequested = false;
        });
        final message = failedPages == 0
            ? tr(
                'manga_translation_completed',
                args: ['${_translatedPages.length}'],
              )
            : tr(
                'manga_translation_completed_with_errors',
                args: ['$failedPages'],
              );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _stopChapterTranslation() {
    if (!_translationRunning) return;
    setState(() => _translationStopRequested = true);
  }

  void _toggleTranslationVisibility() {
    setState(() => _showTranslations = !_showTranslations);
  }

  Future<void> _openReaderMenu() async {
    final button =
        _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + button.size.height + 4,
      overlay.size.width - origin.dx - button.size.width,
      0,
    );
    final uri = _chapterUri;
    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: AppPalette.of(context).surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: <PopupMenuEntry<String>>[
        if (uri != null) ...<PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'webview',
            child: _menuRow(
              Icons.public_rounded,
              tr('manga_reader_open_webview'),
            ),
          ),
          PopupMenuItem<String>(
            value: 'browser',
            child: _menuRow(
              Icons.open_in_new_rounded,
              tr('manga_reader_open_browser'),
            ),
          ),
        ],
        PopupMenuItem<String>(
          value: 'translate',
          child: _menuRow(
            Icons.translate_rounded,
            tr('manga_translate_chapter'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'read',
          child: _menuRow(
            _isChapterRead
                ? Icons.remove_done_rounded
                : Icons.check_circle_outline_rounded,
            tr(
              _isChapterRead
                  ? 'manga_reader_mark_unread'
                  : 'manga_reader_mark_read',
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: _menuRow(Icons.tune_rounded, tr('manga_reader_settings')),
        ),
      ],
    );
    if (!mounted || selected == null) return;
    try {
      switch (selected) {
        case 'webview':
          if (uri != null) {
            await _runtime.openSourceWebView(
              uri.toString(),
              title: _chapterTitle,
            );
          }
          break;
        case 'browser':
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          break;
        case 'read':
          final next = !_isChapterRead;
          await _store.setRead(
            anilistId: widget.anilistId,
            sourceId: widget.source.id,
            chapterUrl: _chapterUrl,
            isRead: next,
          );
          if (!mounted) return;
          setState(() {
            _isChapterRead = next;
            if (!next) _pageIndex = 0;
          });
          if (!next) await _jumpToPage(0);
          break;
        case 'settings':
          await _openSettings();
          break;
        case 'translate':
          await _openTranslationSettings();
          break;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _menuRow(IconData icon, String label) => Row(
    children: <Widget>[
      Icon(icon, size: 20, color: Colors.white70),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Widget _floatingIconButton({
    Key? key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool enabled = true,
  }) => Material(
    key: key,
    color: const Color(0xE6222222),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Tooltip(
          message: tooltip,
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white30,
            size: 21,
          ),
        ),
      ),
    ),
  );

  void _scrollStripByViewport(int direction) {
    if (!_stripController.hasClients) return;
    final position = _stripController.position;
    final distance = position.viewportDimension * .82 * direction;
    unawaited(
      _stripController.animateTo(
        (position.pixels + distance).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ),
    );
  }

  void _handleReaderTap(TapUpDetails details) {
    if (_showChrome) {
      setState(() => _showChrome = false);
      return;
    }
    if (_tapZonesEnabled && _pages.isNotEmpty) {
      final size = MediaQuery.sizeOf(context);
      final x = details.localPosition.dx;
      final y = details.localPosition.dy;
      if (_vertical) {
        if (y <= size.height * .33) {
          _scrollStripByViewport(-1);
          return;
        }
        if (y >= size.height * .67) {
          _scrollStripByViewport(1);
          return;
        }
      } else {
        if (x <= size.width * .34) {
          final step = _doublePageActive ? 2 : 1;
          unawaited(_jumpToPage(_pageIndex + (_rightToLeft ? step : -step)));
          return;
        }
        if (x >= size.width * .66) {
          final step = _doublePageActive ? 2 : 1;
          unawaited(_jumpToPage(_pageIndex + (_rightToLeft ? -step : step)));
          return;
        }
      }
    }
    setState(() => _showChrome = true);
  }

  Future<void> _solveCloudflare() async {
    final url = widget.source.baseUrl;
    if (url.isNotEmpty) {
      try {
        await _runtime.solveCloudflare(url);
      } catch (_) {}
    }
    await _loadChapter(_chapterIndex, savePrevious: false);
  }

  @override
  Widget build(BuildContext context) {
    final canPrevious = _chapterIndex > 0;
    final canNext = _chapterIndex < widget.chapters.length - 1;
    final background = _readerBackground(context);
    final subtitle = _pages.isEmpty
        ? '${tr('chapter')} ${_chapterIndex + 1}/${widget.chapters.length}'
        : '${tr('chapter')} ${_chapterIndex + 1}/${widget.chapters.length} · ${_pageIndex + 1}/${_pages.length}';
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _handleReaderTap,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _error != null
                  ? _ReaderError(
                      message: _error!,
                      onRetry: () =>
                          _loadChapter(_chapterIndex, savePrevious: false),
                      onCloudflare: _solveCloudflare,
                    )
                  : _pages.isEmpty
                  ? Center(
                      child: Text(
                        tr('mihon_pages_empty'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : _vertical
                  ? _buildVerticalReader(background)
                  : _buildPagedReader(background),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_showChrome,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showChrome ? 1 : 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
                    child: Row(
                      children: <Widget>[
                        _floatingIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: tr('back'),
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Material(
                            color: const Color(0xE6222222),
                            borderRadius: BorderRadius.circular(24),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: _openChapterPicker,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 9,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      widget.workTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _chapterTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        _floatingIconButton(
                          key: _menuButtonKey,
                          icon: Icons.more_vert_rounded,
                          tooltip: tr('more'),
                          onTap: _openReaderMenu,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!_loading && _error == null && _pages.isNotEmpty)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 18,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _pagePillVisible && !_showChrome ? 1 : 0,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xD9202020),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 6,
                        ),
                        child: Text(
                          '${(_pageIndex + 1).toString().padLeft(2, "0")} / ${_pages.length.toString().padLeft(2, "0")}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!_loading && _error == null && _pages.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_showChrome,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showChrome ? 1 : 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                      child: Material(
                        color: const Color(0xE6222222),
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          child: Row(
                            children: <Widget>[
                              IconButton(
                                tooltip: tr('manga_previous_chapter'),
                                onPressed: canPrevious
                                    ? _previousChapter
                                    : null,
                                color: Colors.white,
                                disabledColor: Colors.white30,
                                icon: const Icon(Icons.skip_previous_rounded),
                              ),
                              Expanded(
                                child: _pages.length > 1
                                    ? SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          inactiveTrackColor: Colors.white30,
                                          thumbColor: Colors.white,
                                          trackHeight: 2,
                                          overlayShape:
                                              SliderComponentShape.noOverlay,
                                        ),
                                        child: Slider(
                                          min: 0,
                                          max: (_pages.length - 1).toDouble(),
                                          value: _pageIndex
                                              .toDouble()
                                              .clamp(
                                                0.0,
                                                (_pages.length - 1).toDouble(),
                                              )
                                              .toDouble(),
                                          onChanged: (value) =>
                                              _jumpToPage(value.round()),
                                        ),
                                      )
                                    : const SizedBox(height: 40),
                              ),
                              IconButton(
                                tooltip: tr('manga_next_chapter'),
                                onPressed: canNext ? _nextChapter : null,
                                color: Colors.white,
                                disabledColor: Colors.white30,
                                icon: const Icon(Icons.skip_next_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_autoScrollActive)
            Positioned(
              left: 12,
              bottom: 88,
              child: Material(
                color: const Color(0xE6222222),
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: tr(
                        _autoScrollPaused
                            ? 'manga_reader_auto_scroll_resume'
                            : 'manga_reader_auto_scroll_pause',
                      ),
                      onPressed: _toggleAutoScrollPause,
                      color: Colors.white,
                      icon: Icon(
                        _autoScrollPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                    ),
                    IconButton(
                      tooltip: tr('manga_reader_auto_scroll_stop'),
                      onPressed: () => _setAutoScroll(false),
                      color: Colors.white,
                      icon: const Icon(Icons.stop_rounded),
                    ),
                  ],
                ),
              ),
            ),
          if (_translationRunning || _translatedPages.isNotEmpty)
            Positioned(
              right: 12,
              bottom: 82,
              child: Material(
                color: const Color(0xE6222222),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: tr(
                          _showTranslations
                              ? 'manga_translation_show_original'
                              : 'manga_translation_show_translated',
                        ),
                        onPressed: _toggleTranslationVisibility,
                        color: Colors.white,
                        icon: Icon(
                          _showTranslations
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                      if (_translationRunning) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Text(
                            '$_translationCompleted/$_translationTotal',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: tr('manga_translation_stop'),
                          onPressed: _translationStopRequested
                              ? null
                              : _stopChapterTranslation,
                          color: Colors.white,
                          icon: const Icon(Icons.stop_rounded),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerticalReader(Color background) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onReaderScrollNotification,
        child: ListView.builder(
          controller: _stripController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          key: ValueKey<String>('vertical-${_chapterIndex}'),
          cacheExtent: 1400,
          itemCount: _pages.length,
          itemBuilder: (context, index) => VisibilityDetector(
            key: Key('manga-page-${widget.source.id}-${_chapterIndex}-$index'),
            onVisibilityChanged: (info) => _onStripPageVisible(index, info),
            child: _MangaReaderPage(
              runtime: _runtime,
              source: widget.source,
              page: _pages[index],
              index: index,
              fitMode: _fitMode,
              colorFilter: _colorFilter,
              cropBorders: _cropBorders,
              backgroundColor: background,
              translation:
                  _translatedPages['${_pages[index]['imageUrl'] ?? ''}'],
              showTranslation: _showTranslations,
              targetLanguage: _translationTarget,
              onBytesReady: _rememberPageBytes,
              onLongPress: _openPageActions,
            ),
          ),
        ),
      );

  Widget _pageWidget(int index, Color background) => Center(
    child: _MangaReaderPage(
      runtime: _runtime,
      source: widget.source,
      page: _pages[index],
      index: index,
      fitMode: _fitMode,
      colorFilter: _colorFilter,
      cropBorders: _cropBorders,
      backgroundColor: background,
      translation: _translatedPages['${_pages[index]['imageUrl'] ?? ''}'],
      showTranslation: _showTranslations,
      targetLanguage: _translationTarget,
      onBytesReady: _rememberPageBytes,
      onLongPress: _openPageActions,
    ),
  );

  Widget _buildPagedReader(Color background) => PageView.builder(
    key: ValueKey<String>(
      'paged-${_chapterIndex}-${_rightToLeft}-${_doublePageActive}',
    ),
    controller: _pageController,
    scrollDirection: Axis.horizontal,
    reverse: _rightToLeft,
    allowImplicitScrolling: true,
    itemCount: _doublePageActive ? (_pages.length / 2).ceil() : _pages.length,
    onPageChanged: _onPageChanged,
    itemBuilder: (context, page) {
      if (!_doublePageActive) return _pageWidget(page, background);
      final first = page * 2;
      final second = first + 1;
      return Row(
        children: <Widget>[
          if (_rightToLeft && second < _pages.length)
            Expanded(child: _pageWidget(second, background)),
          Expanded(child: _pageWidget(first, background)),
          if (!_rightToLeft && second < _pages.length)
            Expanded(child: _pageWidget(second, background)),
        ],
      );
    },
  );
}

class _MangaReaderPage extends StatefulWidget {
  const _MangaReaderPage({
    required this.runtime,
    required this.source,
    required this.page,
    required this.index,
    required this.fitMode,
    required this.colorFilter,
    required this.cropBorders,
    required this.backgroundColor,
    required this.translation,
    required this.showTranslation,
    required this.targetLanguage,
    required this.onBytesReady,
    required this.onLongPress,
  });

  final MihonRuntimeService runtime;
  final MihonSourceInfo source;
  final Map<String, dynamic> page;
  final int index;
  final String fitMode;
  final String colorFilter;
  final bool cropBorders;
  final Color backgroundColor;
  final MangaPageTranslation? translation;
  final bool showTranslation;
  final String targetLanguage;
  final void Function(int index, Uint8List bytes) onBytesReady;
  final Future<void> Function(int index) onLongPress;

  @override
  State<_MangaReaderPage> createState() => _MangaReaderPageState();
}

class _MangaReaderPageState extends State<_MangaReaderPage> {
  late Future<Uint8List> _image;
  final TransformationController _transformationController =
      TransformationController();
  Offset? _doubleTapPosition;
  bool _cropChecking = false;
  bool _cropChecked = false;
  Rect? _cropRect;

  @override
  void initState() {
    super.initState();
    _image = _fetch();
  }

  @override
  void didUpdateWidget(_MangaReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.cropBorders && widget.cropBorders) {
      _cropChecked = false;
      _cropRect = null;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleDoubleTapZoom() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    final focal = _doubleTapPosition ?? Offset.zero;
    const scale = 2.2;
    _transformationController.value = Matrix4.identity()
      ..translate(-focal.dx * (scale - 1), -focal.dy * (scale - 1))
      ..scale(scale);
  }

  Future<Uint8List> _fetch() async {
    final raw = widget.page['headers'];
    final headers = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value.toString()))
        : const <String, String>{};
    final localPath = '${widget.page['localPath'] ?? ''}'.trim();
    if (localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }
    }
    return widget.runtime.image(
      widget.source.id,
      '${widget.page['imageUrl'] ?? ''}',
      headers: headers,
    );
  }

  Widget _buildFilteredImage(Uint8List bytes, double width, double height) {
    final isSmart = widget.fitMode == 'smart';
    final original = widget.fitMode == 'original';
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final smartFit = landscape ? BoxFit.fitWidth : BoxFit.fitHeight;
    Widget image = Image.memory(
      bytes,
      width: original || widget.fitMode == 'height' ? null : width,
      height: original || widget.fitMode == 'width' ? null : height,
      fit: original
          ? BoxFit.none
          : widget.fitMode == 'contain'
          ? BoxFit.contain
          : isSmart
          ? smartFit
          : widget.fitMode == 'height'
          ? BoxFit.fitHeight
          : BoxFit.fitWidth,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
    final filter = switch (widget.colorFilter) {
      'grayscale' => const ColorFilter.matrix(<double>[
        .2126,
        .7152,
        .0722,
        0,
        0,
        .2126,
        .7152,
        .0722,
        0,
        0,
        .2126,
        .7152,
        .0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      'invert' => const ColorFilter.matrix(<double>[
        -1,
        0,
        0,
        0,
        255,
        0,
        -1,
        0,
        0,
        255,
        0,
        0,
        -1,
        0,
        255,
        0,
        0,
        0,
        1,
        0,
      ]),
      'sepia' => const ColorFilter.matrix(<double>[
        .393,
        .769,
        .189,
        0,
        0,
        .349,
        .686,
        .168,
        0,
        0,
        .272,
        .534,
        .131,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      _ => null,
    };
    return filter == null
        ? image
        : ColorFiltered(colorFilter: filter, child: image);
  }

  Future<void> _ensureCrop(Uint8List bytes) async {
    if (!widget.cropBorders || _cropChecking || _cropChecked) return;
    _cropChecking = true;
    try {
      final detected = await detectMangaContentBounds(bytes);
      if (mounted && widget.cropBorders) {
        setState(() => _cropRect = detected);
      }
    } catch (_) {
      // A failed optional crop must leave the original scan untouched.
    } finally {
      _cropChecking = false;
      _cropChecked = true;
    }
  }

  Widget _cropped(Widget child) {
    final rect = _cropRect;
    if (!widget.cropBorders || rect == null) return child;
    final width = rect.width.clamp(.01, 1.0).toDouble();
    final height = rect.height.clamp(.01, 1.0).toDouble();
    final alignmentX = width >= 1
        ? 0.0
        : ((rect.left / (1 - width)) * 2 - 1).clamp(-1.0, 1.0).toDouble();
    final alignmentY = height >= 1
        ? 0.0
        : ((rect.top / (1 - height)) * 2 - 1).clamp(-1.0, 1.0).toDouble();
    return ClipRect(
      child: Align(
        alignment: Alignment(alignmentX, alignmentY),
        widthFactor: width,
        heightFactor: height,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _image,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 220),
          color: widget.backgroundColor,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                tr('mihon_page_failed', args: ['${widget.index + 1}']),
                style: const TextStyle(color: Colors.white70),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _image = _fetch()),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr('retry')),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return Container(
          width: double.infinity,
          height: 260,
          color: widget.backgroundColor,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(
            color: Colors.white70,
            strokeWidth: 2,
          ),
        );
      }
      widget.onBytesReady(widget.index, snapshot.data!);
      if (widget.cropBorders) unawaited(_ensureCrop(snapshot.data!));
      return GestureDetector(
        onLongPress: () => unawaited(widget.onLongPress(widget.index)),
        onDoubleTapDown: (details) =>
            _doubleTapPosition = details.localPosition,
        onDoubleTap: _toggleDoubleTapZoom,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final availableHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            return InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1,
              maxScale: 4,
              panEnabled: true,
              child: Stack(
                fit: StackFit.passthrough,
                children: <Widget>[
                  _cropped(
                    _buildFilteredImage(
                      snapshot.data!,
                      availableWidth,
                      availableHeight,
                    ),
                  ),
                  if (widget.showTranslation && widget.translation != null)
                    Positioned.fill(
                      child: MangaTranslationOverlay(
                        translation: widget.translation!,
                        targetLanguage: widget.targetLanguage,
                        fitMode: widget.fitMode,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({
    required this.message,
    required this.onRetry,
    required this.onCloudflare,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCloudflare;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(tr('retry')),
          ),
          TextButton(
            onPressed: onCloudflare,
            child: Text(tr('manga_solve_cloudflare')),
          ),
        ],
      ),
    ),
  );
}
