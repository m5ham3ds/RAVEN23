import 'dart:async';
import 'dart:io';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../data/sync/library_scope.dart';
import '../../functions/language_names.dart';
import '../../functions/player_subtitle_configuration.dart';
import '../../models/movie_stream_metadata.dart';
import '../../models/offline_download.dart';
import '../../models/tv_stream_metadata.dart';
import '../../models/wellness.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/offline_download_provider.dart';
import '../../provider/settings_provider.dart';
import '../../provider/wellness_provider.dart';
import 'player/player_external_subtitles.dart';
import 'player/player_feedback_ui.dart';
import 'player/player_sheet_ui.dart';
import 'player/player_strings.dart';

/// Offline playback uses BetterPlayer just like online playback. The completed
/// Media3 download is materialized through the existing exporter into a local
/// MP4 first; all player gestures and controls therefore remain identical.
class OfflinePlayerScreen extends StatefulWidget {
  const OfflinePlayerScreen({
    super.key,
    required this.download,
  });

  final OfflineDownload download;

  @override
  State<OfflinePlayerScreen> createState() => _OfflinePlayerScreenState();
}

class _OfflinePlayerScreenState extends State<OfflinePlayerScreen> {
  BetterPlayerController? _controller;
  final GlobalKey _playerKey = GlobalKey();
  final PlayerExternalSubtitles _externalSubtitles = PlayerExternalSubtitles();
  var _initialized = false;
  var _playerReady = false;
  String? _preparationError;
  bool _completed = false;
  StreamSubscription<dynamic>? _nativeEvents;
  bool _nativeViewCreated = false;
  bool _nativeReady = false;
  String? _nativeError;
  int _nativeDurationMs = 0;
  int _nativePositionMs = 0;
  late final WellnessPlaybackTracker _wellnessTracker;
  late final String _wellnessSessionId;

  bool get _isMovie => widget.download.mediaType == 'movie';

  String get _subtitlePlaybackKey {
    final id = widget.download.contentId ?? 0;
    if (_isMovie) return 'movie_$id';
    return 'tv_${id}_s${widget.download.seasonNumber ?? 0}_e${widget.download.episodeNumber ?? 0}';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _wellnessSessionId =
        '${now.microsecondsSinceEpoch}-offline-${widget.download.id}';
    _wellnessTracker = WellnessPlaybackTracker(
      id: _wellnessSessionId,
      createdAt: now,
      libraryGeneration: LibraryScope.generation,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (!Platform.isAndroid) unawaited(_initializePlayer());
  }

  void _onNativePlatformViewCreated(int viewId) {
    _nativeViewCreated = true;
    _nativeEvents = EventChannel(
      'raven23/offline_player_events/$viewId',
    ).receiveBroadcastStream().listen(
      _onNativePlayerEvent,
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _nativeError = error.toString());
      },
    );
  }

  void _onNativePlayerEvent(dynamic raw) {
    if (!mounted || raw is! Map) return;
    final event = Map<Object?, Object?>.from(raw);
    final type = event['event'] as String? ?? '';
    _nativeDurationMs =
        (event['durationMs'] as num?)?.toInt() ?? _nativeDurationMs;
    _nativePositionMs =
        (event['positionMs'] as num?)?.toInt() ?? _nativePositionMs;
    switch (type) {
      case 'snapshot':
      case 'progress':
        // The native view sends a snapshot as soon as EventChannel attaches.
        // It may already be READY before Flutter subscribes to later state changes.
        _nativeReady = true;
        if (event['isPlaying'] == true) {
          _wellnessTracker.play();
        }
      case 'playing':
        _wellnessTracker.play();
      case 'paused':
      case 'buffering':
        _wellnessTracker.pause();
      case 'ready':
        _nativeReady = true;
        _nativeError = null;
        if (event['isPlaying'] == true) {
          _wellnessTracker.play();
        } else {
          _wellnessTracker.pause();
        }
      case 'ended':
        _completed = true;
        _wellnessTracker.pause();
        unawaited(_persistWellnessSession(syncImmediately: true));
      case 'error':
        _nativeError = event['error']?.toString() ?? tr('offline_play_failed_hint');
      default:
        break;
    }
    setState(() {});
  }

  Future<void> _initializePlayer() async {
    try {
      final settings = context.read<SettingsProvider>();
      final accent = Theme.of(context).primaryColor;
      await _externalSubtitles.restoreCachedSubtitles(
        mediaCacheKey: _subtitlePlaybackKey,
        preferredLanguageCode: settings.defaultSubtitleLanguage,
      );
      if (!mounted) return;

      final subtitleSources = <BetterPlayerSubtitlesSource>[
        ..._externalSubtitles.appliedSubtitles,
      ];
      final savedSubtitle = widget.download.offlineSubtitlePath?.trim();
      final savedSubtitleExists = savedSubtitle != null &&
          savedSubtitle.isNotEmpty &&
          await File(savedSubtitle).exists();
      if (!mounted) return;
      if (savedSubtitleExists &&
          !subtitleSources.any((source) => source.urls?.contains(savedSubtitle) == true)) {
        subtitleSources.add(
          BetterPlayerSubtitlesSource(
            type: BetterPlayerSubtitlesSourceType.file,
            urls: <String>[savedSubtitle],
            name: widget.download.offlineSubtitleName ?? tr('subtitle'),
            selectedByDefault: subtitleSources.isEmpty,
          ),
        );
      }

      final controls = BetterPlayerControlsConfiguration(
        gestureConfiguration: BetterPlayerGestureConfiguration(
          enableVolumeSwipe: true,
          enableBrightnessSwipe: true,
          enableSeekSwipe: true,
          enableDoubleTapSeek: true,
          volumeSwipeSensitivity: 0.5,
          brightnessSwipeSensitivity: 0.5,
          seekSwipeSensitivity: 1.0,
        ),
        name: widget.download.title,
        subtitle: widget.download.subtitle,
        strings: playerControlsStrings(),
        languageLabelBuilder: languageDisplayName,
        emphasisFontFamily: 'FigtreeSB',
        enableFullscreen: true,
        enableSubtitles: false,
        showSubtitlesButton: false,
        enableQualities: false,
        showQualitiesButton: false,
        enableDownloadButton: false,
        enableCrop: true,
        cropIcon: PhosphorIcons.crop(),
        enablePip: true,
        enableAudioTracks: true,
        backgroundColor: Colors.black,
        progressBarBackgroundColor: Colors.white24,
        progressBarHandleColor: accent,
        controlBarColor: Colors.black.withValues(alpha: .48),
        muteIcon: PhosphorIcons.speakerSimpleSlash(),
        unMuteIcon: PhosphorIcons.speakerHigh(),
        pauseIcon: PhosphorIcons.pause(PhosphorIconsStyle.fill),
        pipMenuIcon: PhosphorIcons.pictureInpicture(),
        playIcon: PhosphorIcons.play(PhosphorIconsStyle.fill),
        showControlsOnInitialize: false,
        controlsHideTime: const Duration(milliseconds: 300),
        backwardSkipTimeInMilliseconds: Duration(
          seconds: settings.defaultSeekDuration,
        ).inMilliseconds,
        forwardSkipTimeInMilliseconds: Duration(
          seconds: settings.defaultSeekDuration,
        ).inMilliseconds,
        watchingText: tr('watching_text'),
        loadingColor: Colors.white,
        iconsColor: Colors.white,
        progressBarPlayedColor: accent,
        progressBarBufferedColor: Colors.white38,
        skipForwardIcon: PhosphorIcons.arrowClockwise(),
        skipBackIcon: PhosphorIcons.arrowCounterClockwise(),
        fullscreenEnableIcon: PhosphorIcons.cornersOut(),
        fullscreenDisableIcon: PhosphorIcons.cornersIn(),
        overflowMenuIcon: PhosphorIcons.dotsThreeVertical(),
        subtitlesIcon: PhosphorIcons.closedCaptioning(),
        qualitiesIcon: PhosphorIcons.highDefinition(),
        controlBarHeight: 56,
                playerTimeMode: settings.playerTimeDisplay,
        quickActions: [
          if (!_isMovie)
            BetterPlayerOverflowMenuItem(
              PhosphorIcons.cardsThree(),
              playerControlsStrings().episodes,
              _showOfflineEpisodeSelection,
            ),
          BetterPlayerOverflowMenuItem(
            PhosphorIcons.closedCaptioning(),
            playerControlsStrings().audioAndSubtitles,
            _showSubtitleSwitcher,
          ),
        ],
      );

      final controller = BetterPlayerController(
        BetterPlayerConfiguration(
          autoDetectFullscreenDeviceOrientation: true,
          fullScreenByDefault: false,
          autoPlay: true,
          fit: BoxFit.contain,
          autoDispose: true,
          allowedScreenSleep: true,
          controlsConfiguration: controls,
          subtitlesConfiguration: buildPlayerSubtitleConfiguration(
            backgroundColor: settings.subtitleBackgroundColor,
            foregroundColor: settings.subtitleForegroundColor,
            fontSize: settings.subtitleFontSize,
            textStyle: settings.subtitleTextStyle,
          ),
          showPlaceholderUntilPlay: true,
          errorBuilder: (_, __) => _OfflinePlaybackError(
            onClose: () => Navigator.pop(context),
          ),
        ),
      );
      _controller = controller;
      controller.setBetterPlayerGlobalKey(_playerKey);
      controller.addEventsListener(_onPlayerEvent);

      // This uses the same cache-backed exporter already used by Save a copy
      // and Open in external player. The exported MP4 remains reusable.
      final localPath = await context
          .read<OfflineDownloadProvider>()
          .prepareForPlayback(widget.download.id);
      if (!mounted) {
        controller.removeEventsListener(_onPlayerEvent);
        controller.dispose();
        return;
      }
      if (!await File(localPath).exists()) {
        throw StateError('The prepared offline video file is missing.');
      }
      await controller.setupDataSource(
        BetterPlayerDataSource.file(
          localPath,
          subtitles: subtitleSources,
          useAsmsSubtitles: false,
          useAsmsTracks: false,
        ),
      );
      if (!mounted) return;
      setState(() {
        _playerReady = true;
        _preparationError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preparationError = error is PlatformException &&
                error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : error.toString();
      });
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    final controller = _controller;
    if (controller == null) return;
    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.play:
        _wellnessTracker.play();
      case BetterPlayerEventType.pause:
      case BetterPlayerEventType.bufferingStart:
        _wellnessTracker.pause();
      case BetterPlayerEventType.bufferingEnd:
        if (controller.videoPlayerController?.value.isPlaying == true) {
          _wellnessTracker.play();
        }
      case BetterPlayerEventType.finished:
        _completed = true;
        _wellnessTracker.pause();
        unawaited(_persistWellnessSession(syncImmediately: true));
      default:
        break;
    }
  }

  Future<void> _persistWellnessSession({bool syncImmediately = false}) async {
    final value = _controller?.videoPlayerController?.value;
    final contentId = _isMovie
        ? (widget.download.contentId?.toString() ?? widget.download.id)
        : '${widget.download.contentId ?? 'unknown'}:'
            '${widget.download.seasonNumber ?? 0}:'
            '${widget.download.episodeNumber ?? 0}';
    await WellnessProvider.instance.recordPlayback(
      sessionId: _wellnessSessionId,
      tracker: _wellnessTracker,
      mediaType: _isMovie ? WellnessMediaType.movie : WellnessMediaType.episode,
      source: WellnessPlaybackSource.offline,
      contentId: contentId,
      seriesId: _isMovie ? null : widget.download.contentId?.toString(),
      title: widget.download.title,
      subtitle: widget.download.subtitle,
      seasonNumber: widget.download.seasonNumber,
      episodeNumber: widget.download.episodeNumber,
      durationMs: value?.duration?.inMilliseconds ?? _nativeDurationMs,
      progressEndMs: value?.position.inMilliseconds ?? _nativePositionMs,
      completed: _completed,
      posterPath: widget.download.posterUrl,
      provider: 'Downloaded',
      syncImmediately: syncImmediately,
    );
  }

  void _showSubtitleSwitcher() {
    final controller = _controller;
    if (controller == null) return;
    final sources = List<BetterPlayerSubtitlesSource>.of(
      controller.betterPlayerSubtitlesSourceList,
    );
    if (!sources.any((source) => source.type == BetterPlayerSubtitlesSourceType.none)) {
      sources.insert(
        0,
        BetterPlayerSubtitlesSource(type: BetterPlayerSubtitlesSourceType.none),
      );
    }
    showPlayerSheet<void>(
      context: context,
      builder: (sheetContext) => PlayerSheetScaffold(
        title: tr('external_subtitles'),
        subtitle: tr('choose_subtitle_language'),
        actions: [
          IconButton(
            tooltip: tr('search_subtitles'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _showExternalSubtitles();
            },
            icon: Icon(PhosphorIcons.magnifyingGlass()),
          ),
          IconButton(
            onPressed: () => Navigator.pop(sheetContext),
            icon: Icon(PhosphorIcons.x()),
          ),
        ],
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          itemCount: sources.length,
          separatorBuilder: (_, __) => const SizedBox(height: 2),
          itemBuilder: (context, index) {
            final source = sources[index];
            final isOff = source.type == BetterPlayerSubtitlesSourceType.none;
            final label = isOff
                ? tr('player_off')
                : languageDisplayName(source.name).isEmpty
                    ? tr('subtitle')
                    : languageDisplayName(source.name);
            final current = identical(
              source,
              controller.betterPlayerSubtitlesSource,
            );
            return PlayerChoiceCard(
              title: label,
              subtitle: isOff ? '' : (source.name ?? ''),
              selected: current,
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(sheetContext);
                try {
                  await controller.selectSubtitlesSource(source);
                } catch (error) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(tr('subtitle_unavailable_pick_another'))),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _showExternalSubtitles() {
    final id = widget.download.contentId;
    final controller = _controller;
    if (id == null || controller == null) return;
    final apiUrl = context.read<AppDependencyProvider>().raven23APIURL;
    _externalSubtitles.showExternalSubtitlesMenu(
      context: context,
      colors: [Theme.of(context).primaryColor, Theme.of(context).colorScheme.surface],
      scraperApiUrl: apiUrl,
      mediaType: _isMovie ? MediaType.movie : MediaType.tvShow,
      movieMetadata: _isMovie
          ? MovieStreamMetadata(
              backdropPath: null,
              elapsed: 0,
              movieId: id,
              movieName: widget.download.title,
              posterPath: null,
              releaseYear: null,
              isAdult: false,
              releaseDate: null,
            )
          : null,
      tvMetadata: _isMovie
          ? null
          : TVStreamMetadata(
              elapsed: 0,
              episodeId: 0,
              episodeName: widget.download.subtitle,
              episodeNumber: widget.download.episodeNumber ?? 0,
              posterPath: null,
              seasonNumber: widget.download.seasonNumber ?? 0,
              seriesName: widget.download.title,
              tvId: id,
              airDate: null,
            ),
      preferredLanguageCode: context.read<SettingsProvider>().defaultSubtitleLanguage,
      betterPlayerController: controller,
    );
  }

  Future<void> _showOfflineEpisodeSelection() async {
    if (_isMovie || widget.download.contentId == null) return;
    final playerContext = context;
    final downloads = context.read<OfflineDownloadProvider>();
    final future = downloads.refresh().then((_) {
      final items = downloads.downloads.where((item) =>
          item.isComplete &&
          item.mediaType == 'episode' &&
          item.contentId == widget.download.contentId &&
          item.seasonNumber == widget.download.seasonNumber);
      final sorted = items.toList()
        ..sort((a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));
      return sorted;
    });
    await showPlayerSheet<void>(
      context: context,
      builder: (sheetContext) => FutureBuilder<List<OfflineDownload>>(
        future: future,
        builder: (context, snapshot) {
          final episodes = snapshot.data ?? const <OfflineDownload>[];
          return PlayerSheetScaffold(
            title: tr('season_episodes', namedArgs: {
              'season': '${widget.download.seasonNumber ?? 0}',
            }),
            subtitle: tr('offline_downloaded_episodes'),
            actions: [
              IconButton(
                onPressed: () => Navigator.pop(sheetContext),
                icon: Icon(PhosphorIcons.x()),
              ),
            ],
            child: snapshot.connectionState != ConnectionState.done
                ? const Center(child: CircularProgressIndicator())
                : episodes.isEmpty
                    ? Center(child: Text(tr('offline_no_downloaded_episodes')))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: episodes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final episode = episodes[index];
                          final current = episode.id == widget.download.id;
                          final episodeLabel = 'S${(episode.seasonNumber ?? 0).toString().padLeft(2, '0')}'
                              ' • E${(episode.episodeNumber ?? 0).toString().padLeft(2, '0')}';
                          return PlayerChoiceCard(
                            title: episode.subtitle?.trim().isNotEmpty == true
                                ? episode.subtitle!
                                : episode.title,
                            subtitle: '$episodeLabel • ${episode.quality}',
                            selected: current,
                            onTap: current
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                    if (!playerContext.mounted) return;
                                    Navigator.of(playerContext).pushReplacement(
                                      MaterialPageRoute<void>(
                                        builder: (_) => OfflinePlayerScreen(download: episode),
                                      ),
                                    );
                                  },
                          );
                        },
                      ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeEventsListener(_onPlayerEvent);
      controller.dispose();
    }
    _nativeEvents?.cancel();
    if (_initialized && (_controller != null || _nativeViewCreated)) {
      _wellnessTracker.pause();
      unawaited(_persistWellnessSession(syncImmediately: true));
    }
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent = Platform.isAndroid
        ? null
        : context.watch<OfflineDownloadProvider>().exportFor(widget.download.id)?.progress;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (Platform.isAndroid)
              Stack(
                children: [
                  AndroidView(
                    viewType: 'com.m5ham3ds.raven23/offline_player',
                    creationParams: <String, Object?>{'id': widget.download.id},
                    onPlatformViewCreated: _onNativePlatformViewCreated,
                  ),
                  if (_nativeError != null)
                    Positioned.fill(
                      child: _OfflinePlaybackError(
                        message: _nativeError!,
                        onClose: () => Navigator.pop(context),
                      ),
                    )
                  else if (!_nativeReady)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              )
            else if (_playerReady && _controller != null)
              PlayerTheme(
                onVideo: true,
                child: BetterPlayer(controller: _controller!, key: _playerKey),
              )
            else if (_preparationError != null)
              _OfflinePlaybackError(
                message: _preparationError ?? tr('offline_play_failed_hint'),
                onClose: () => Navigator.pop(context),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 30,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr('preparing_offline_video'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (progressPercent != null) ...<Widget>[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 220,
                        child: LinearProgressIndicator(
                          value: progressPercent / 100,
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$progressPercent%',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfflinePlaybackError extends StatelessWidget {
  const _OfflinePlaybackError({required this.onClose, this.message});

  final VoidCallback onClose;
  final String? message;

  @override
  Widget build(BuildContext context) => PlayerErrorView(
        title: tr('offline_play_failed'),
        message: message ?? tr('offline_play_failed_hint'),
        icon: PhosphorIcons.fileX(),
        actions: [
          PlayerActionButton(
            label: tr('go_back'),
            icon: PhosphorIcons.arrowLeft(),
            primary: true,
            onPressed: onClose,
          ),
        ],
      );
}
