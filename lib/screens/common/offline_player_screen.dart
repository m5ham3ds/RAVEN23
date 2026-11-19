import 'dart:async';
import '../../data/sync/library_scope.dart';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../functions/language_names.dart';
import '../../functions/player_subtitle_configuration.dart';
import '../../models/offline_download.dart';
import '../../models/movie_stream_metadata.dart';
import '../../models/tv_stream_metadata.dart';
import '../../models/wellness.dart';
import '../../constants/app_constants.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../provider/wellness_provider.dart';
import 'player/player_feedback_ui.dart';
import 'player/player_strings.dart';
import 'player/player_external_subtitles.dart';

/// The lightweight offline variant of RAVEN23's Better Player. It keeps the
/// same player actions as streaming playback while treating the downloaded
/// quality as a fixed, one-item quality selection.
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
  StreamSubscription<dynamic>? _nativePlayerEvents;
  int _nativeDurationMs = 0;
  int _nativePositionMs = 0;
  String? _nativePlaybackError;

  bool get _usesNativeOfflinePlayer =>
      defaultTargetPlatform == TargetPlatform.android;
  final GlobalKey _playerKey = GlobalKey();
  var _initialized = false;
  late final WellnessPlaybackTracker _wellnessTracker;
  late final String _wellnessSessionId;
  bool _completed = false;
  final PlayerExternalSubtitles _externalSubtitles = PlayerExternalSubtitles();

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
    // Android already has a registered Media3 PlatformView backed by the
    // completed DownloadRequest and the exact read-only download cache.
    // Do not send its synthetic local URI through BetterPlayer's HTTP stack.
    if (_usesNativeOfflinePlayer) return;

    final accent = Theme.of(context).primaryColor;
    final settings = context.read<SettingsProvider>();
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
      enableSubtitles: true,
      showSubtitlesButton: true,
      enableQualities: true,
      showQualitiesButton: true,
      enableDownloadButton: true,
      onDownloadTap: _showAlreadyDownloaded,
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
      // White controls; the accent is the timeline's played part alone.
      loadingColor: Colors.white,
      iconsColor: Colors.white,
      progressBarPlayedColor: accent,
      progressBarBufferedColor: Colors.white38,
      skipForwardIcon: PhosphorIcons.arrowClockwise(),
      skipBackIcon: PhosphorIcons.arrowCounterClockwise(),
      fullscreenEnableIcon: PhosphorIcons.cornersOut(),
      fullscreenDisableIcon: PhosphorIcons.cornersIn(),
      overflowMenuIcon: PhosphorIcons.dotsThreeVertical(),
      overflowMenuCustomItems: [
        BetterPlayerOverflowMenuItem(
          PhosphorIcons.closedCaptioning(),
          tr('external_subtitles'),
          _showExternalSubtitles,
        ),
      ],
      controlBarHeight: 56,
    );
    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoDetectFullscreenDeviceOrientation: true,
        autoDetectFullscreenAspectRatio: true,
        autoPlay: true,
        fit: BoxFit.contain,
        autoDispose: true,
        allowedScreenSleep: false,
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
    _controller.setBetterPlayerGlobalKey(_playerKey);
    _controller.addEventsListener(_onPlayerEvent);
    final savedSubtitle = widget.download.offlineSubtitlePath;
    final quality = widget.download.quality.trim().isEmpty
        ? 'Auto'
        : widget.download.quality.trim();
    final offlineUrl = 'raven23-offline://${widget.download.id}';
    _controller.setupDataSource(
      BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        offlineUrl,
        videoFormat: BetterPlayerVideoFormat.other,
        resolutions: <String, String>{quality: offlineUrl},
        selectedResolution: quality,
        cacheConfiguration: BetterPlayerCacheConfiguration(
          key: 'raven23-offline:${widget.download.id}',
        ),
        subtitles: savedSubtitle?.isNotEmpty == true
            ? [
                BetterPlayerSubtitlesSource(
                  type: BetterPlayerSubtitlesSourceType.file,
                  urls: [savedSubtitle],
                  name: widget.download.offlineSubtitleName ??
                      'Downloaded subtitle',
                  selectedByDefault: true,
                ),
              ]
            : const [],
      ),
    );
  }

  void _onNativePlayerCreated(int viewId) {
    _nativePlayerEvents?.cancel();
    final channel = EventChannel('raven23/offline_player_events/$viewId');
    _nativePlayerEvents = channel.receiveBroadcastStream().listen(
      (event) {
        if (!mounted || event is! Map) return;
        final duration = event['durationMs'];
        final position = event['positionMs'];
        if (duration is num) _nativeDurationMs = duration.toInt();
        if (position is num) _nativePositionMs = position.toInt();

        final name = event['event']?.toString();
        switch (name) {
          case 'playing':
            _nativePlaybackError = null;
            _wellnessTracker.play();
          case 'paused':
          case 'buffering':
            _wellnessTracker.pause();
          case 'ready':
          case 'progress':
          case 'snapshot':
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
            _wellnessTracker.pause();
            setState(() {
              _nativePlaybackError =
                  event['error']?.toString().trim().isNotEmpty == true
                  ? event['error'].toString()
                  : tr('offline_play_failed_hint');
            });
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _nativePlaybackError = tr('offline_play_failed_hint');
        });
      },
    );
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
    final isMovie = widget.download.mediaType == 'movie';
    final contentId = isMovie
        ? (widget.download.contentId?.toString() ?? widget.download.id)
        : '${widget.download.contentId ?? 'unknown'}:'
            '${widget.download.seasonNumber ?? 0}:'
            '${widget.download.episodeNumber ?? 0}';
    await WellnessProvider.instance.recordPlayback(
      sessionId: _wellnessSessionId,
      tracker: _wellnessTracker,
      mediaType: isMovie ? WellnessMediaType.movie : WellnessMediaType.episode,
      source: WellnessPlaybackSource.offline,
      contentId: contentId,
      seriesId: isMovie ? null : widget.download.contentId?.toString(),
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

  void _showAlreadyDownloaded() {
    final quality = widget.download.quality.trim().isEmpty
        ? 'Auto'
        : widget.download.quality.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Already downloaded at $quality.')),
    );
  }

  void _showExternalSubtitles() {
    final id = widget.download.contentId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Subtitle search is unavailable for this older download.')),
      );
      return;
    }
    final isMovie = widget.download.mediaType == 'movie';
    final controller = _controller;
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('offline_play_failed_hint'))),
      );
      return;
    }
    _externalSubtitles.showExternalSubtitlesMenu(
      context: context,
      colors: [
        Theme.of(context).primaryColor,
        Theme.of(context).colorScheme.surface
      ],
      scraperApiUrl: Provider.of<AppDependencyProvider>(context, listen: false)
          .raven23APIURL,
      mediaType: isMovie ? MediaType.movie : MediaType.tvShow,
      movieMetadata: isMovie
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
      tvMetadata: isMovie
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
      betterPlayerController: controller,
    );
  }

  @override
  void dispose() {
    _nativePlayerEvents?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeEventsListener(_onPlayerEvent);
      controller.dispose();
    }
    if (_initialized) {
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
            if (_usesNativeOfflinePlayer)
              AndroidView(
                viewType: 'com.m5ham3ds.raven23/offline_player',
                creationParams: <String, Object>{
                  'id': widget.download.id,
                },
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: _onNativePlayerCreated,
              )
            else if (_controller != null)
              BetterPlayer(controller: _controller!, key: _playerKey)
            else
              const Center(child: CircularProgressIndicator()),
            if (_nativePlaybackError != null)
              _OfflinePlaybackError(
                onClose: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}

/// What shows when a download won't play: the main player's error look over
/// the black video area, with a way back to Downloads, since switching
/// provider or retrying can't help a file on the device.
class _OfflinePlaybackError extends StatelessWidget {
  const _OfflinePlaybackError({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => PlayerErrorView(
        title: tr('offline_play_failed'),
        message: tr('offline_play_failed_hint'),
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
