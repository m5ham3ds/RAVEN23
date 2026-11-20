import 'package:raven23/models/adsterra_playback_ads_config.dart';
import 'package:raven23/data/ads/content_ads.dart';
import 'package:raven23/services/adsterra_playback_ads_service.dart';
import 'package:raven23/widgets/ad_block_gate.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raven23/functions/function.dart';
import 'package/raven23/functions/offline_download_ids.dart';
import 'package:raven23/functions/network.dart';
import 'package:raven23/functions/video_utils.dart';
import 'package:raven23/functions/player_route_handoff.dart';
import 'package:raven23/models/movie.dart';
import 'package:raven23/models/movie_stream_metadata.dart';
import 'package:raven23/models/offline_download.dart';
import 'package:raven23/models/provider_video_source.dart';
import 'package:raven23/models/provider_load_state.dart';
import 'package:raven23/services/globle_method.dart';
import 'package:raven23/services/offline_download_service.dart';
import 'package:raven23/services/external_subtitle_service.dart';
import 'package:raven23/models/external_subtitles.dart';
import 'package:raven23/widgets/playback_loading_screen.dart';
import 'package:raven23/video_providers/provider_loader.dart';
import '../../controllers/recently_watched_database_controller.dart';
import '../../provider/recently_watched_provider.dart';
import '../../video_providers/adaptive_quality_scanner.dart';
import '../../video_providers/common.dart';
import '../../video_providers/quality_catalog.dart';
import '../../video_providers/unified/stream_host_priority_manager.dart';
import '../../video_providers/names.dart';
import '../../video_providers/unified/media_identity.dart';
import '/api/endpoints.dart';
import '/constants/api_constants.dart';
import '/provider/offline_download_provider.dart';
import '/provider/app_dependency_provider.dart';
import '/provider/settings_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player.dart';
import '../../widgets/common_widgets.dart';
import 'package:raven23/constants/app_constants.dart' show MediaType;

import 'package:flutter/material.dart';
import '../../screens/common/player.dart';
import '../../screens/common/embedded_web_playback_screen.dart';
import '../../screens/common/download_selection_sheets.dart';
import '../../screens/common/manual_source_picker.dart';
import '../../tv/player/tv_player_screen.dart';

/// Finds a stream for a movie. A Kids or Family movie's loader, and the
/// player it opens, are in its [ContentAdScope]: no ad is asked for.
class MovieVideoLoader extends StatelessWidget {
  const MovieVideoLoader({
    required this.metadata,
    required this.download,
    this.useTvPlayer = false,
    this.onTvPlayerExit,
    this.adStage = PlaybackAdStage.streamFound,
    super.key,
  });

  final MovieStreamMetadata metadata;
  final bool download;
  final bool useTvPlayer;
  final VoidCallback? onTvPlayerExit;
  final PlaybackAdStage adStage;

  @override
  Widget build(BuildContext context) {
    final loader = _MovieVideoLoader(
      metadata: metadata,
      download: download,
      useTvPlayer: useTvPlayer,
      onTvPlayerExit: onTvPlayerExit,
      adStage: adStage,
    );
    final id = metadata.movieId;
    if (id == null) return loader;
    return ContentAdGate(
      content: AdContent(series: false, id: id, genreIds: metadata.genreIds),
      holdChild: true,
      child: loader,
    );
  }
}

class _MovieVideoLoader extends StatefulWidget {
  const _MovieVideoLoader({
    required this.download,
    required this.metadata,
    this.useTvPlayer = false,
    this.onTvPlayerExit,
    this.adStage = PlaybackAdStage.streamFound,
  });

  final bool download;
  final MovieStreamMetadata metadata;
  final bool useTvPlayer;
  final VoidCallback? onTvPlayerExit;

  /// The popup once a source is found: [PlaybackAdStage.episodeSwitch] or
  /// [PlaybackAdStage.movieSwitch] when the player itself started this load.
  final PlaybackAdStage adStage;

  @override
  State<_MovieVideoLoader> createState() => _MovieVideoLoaderState();
}

class _MovieVideoLoaderState extends State<_MovieVideoLoader> {
  RecentlyWatchedMoviesController recentlyWatchedMoviesController =
      RecentlyWatchedMoviesController();

  List<RegularVideoLinks>? movieVideoLinks;
  List<RegularSubtitleLinks>? movieVideoSubs;

  late SettingsProvider settings = Provider.of<SettingsProvider>(
    context,
    listen: false,
  );
  List<VideoProvider> videoProviders = [];
  List<ProviderLoadState> providerStates = [];
  final Map<String, Stopwatch> _providerStopwatches = {};
  int currentProviderIndex = 0;
  String _scraperApiUrl = '';
  PlaybackAdPreload? _adPreload;

  Map<String, String> videos = {};
  List<BetterPlayerSubtitlesSource> subs = [];

  // Collect all working providers
  List<ProviderVideoSource> availableProviders = [];

  late int foundIndex;

  /// The metadata this loader was built for, captured once. Route builders run
  /// again whenever route dependencies change, and callers construct a fresh
  /// [MovieStreamMetadata] inside them; swapping to that empty copy mid-flight
  /// would drop the fetched recommendations the player needs.
  late final MovieStreamMetadata _metadata;

  @override
  void initState() {
    super.initState();
    _metadata = widget.metadata;
    debugPrint(
      '[MovieRecommendationsDebug][LOADER_INIT] '
      'movieId=${_metadata.movieId} '
      'title=${_metadata.movieName} '
      'existingRecommendations=${_metadata.recommendations?.length ?? 0} '
      'download=${widget.download} useTvPlayer=${widget.useTvPlayer}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPlayback());
  }

  Future<void> _startPlayback() async {
    if (!mounted) return;
    if (!await AdBlockGate.instance.allowPlayback(
      context,
      download: widget.download,
      television: widget.useTvPlayer,
    )) {
      if (mounted) Navigator.pop(context, false);
      return;
    }
    if (!mounted) return;
    _adPreload = AdsterraPlaybackAdsService.instance.preloadStreamFound(
      context,
      download: widget.download,
      television: widget.useTvPlayer,
      stage: widget.adStage,
    );
    try {
      await loadVideo();
    } finally {
      _adPreload?.dispose();
    }
  }

  @override
  void dispose() {
    _adPreload?.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    _scraperApiUrl = Provider.of<AppDependencyProvider>(
      context,
      listen: false,
    ).raven23APIURL;
    // Use the same installed repository sources for playback and offline
    // downloads. The download flow still resolves each source freshly and
    // hands the exact URL, headers and container to OfflineDownloadService.
    var repositoryProviders = <VideoProvider>[];
    try {
      repositoryProviders = await ProviderLoader.installedSourceProviders(
        mediaIdentity: _playbackMediaIdentity,
      );
    } catch (error) {
      // A repository outage must not hide independent direct providers.
      debugPrint('[PlaybackSources][DISCOVERY_FAILED] $error');
    }
    // `installedSourceProviders` already applies this media's Primary and
    // Backup order, then remaining direct sources and embedded fallbacks.
    // Manually selected sources retain that order even if their upstream
    // manifest labels them as fallback.
    final directSources = repositoryProviders
        .where((provider) => !provider.isFallback)
        .toList(growable: false);
    final fallbackSources = repositoryProviders
        .where((provider) => provider.isFallback)
        .toList(growable: false);
    final providers = <VideoProvider>[...directSources, ...fallbackSources];
    final vixSrcIndex = await ProviderLoader.directVixSrcPrimaryIndex(
      _playbackMediaIdentity,
    );
    // VixSrc follows the persisted category-specific PRIMARY LIST marker for
    // Movies, Series and Anime. If the user removes it from PRIMARY, keep the
    // built-in provider last instead of silently promoting it.
    final insertionIndex = (vixSrcIndex ?? providers.length)
        .clamp(0, providers.length)
        .toInt();
    providers.insert(insertionIndex, VideoProvider.directVixSrc);
    // Per-media Primary/Backup lists are the authoritative repository order.
    // Do not let the legacy global provider-order preference override them.
    final orderedProviders = providers;
    if (!mounted) return;
    setState(() {
      videoProviders = orderedProviders;
      providerStates = orderedProviders
          .map(
            (provider) => ProviderLoadState(
              codeName: provider.codeName,
              fullName: provider.displayName,
              content: provider.content,
              status: provider.supportsMedia(_playbackMediaIdentity)
                  ? ProviderStatus.pending
                  : ProviderStatus.skipped,
              errorMessage: provider.supportsMedia(_playbackMediaIdentity)
                  ? null
                  : tr('provider_media_type_unsupported'),
            ),
          )
          .toList();
    });
  }

  Future<void> loadVideo() async {
    if (!mounted) return;
    try {
      await _loadProviders();
      if (widget.download) {
        await _scanAllSourcesAndQueueDownload();
        return;
      }
      // The player's recommendations are not needed until it opens, so fetch
      // them alongside source loading instead of in front of it. Downloads
      // never open the player.
      final recommendationsFetch = widget.download
          ? null
          : _fetchMovieRecommendations();

      var isBookmarked = await recentlyWatchedMoviesController.contain(
        _metadata.movieId!,
      );
      int elapsed = 0;
      if (isBookmarked) {
        var rMovies = Provider.of<RecentProvider>(
          context,
          listen: false,
        ).movies;
        int index = rMovies.indexWhere(
          (element) => element.id == _metadata.movieId,
        );
        // A cloud merge can add the row to the database before this snapshot of
        // the provider list catches up, so resume from the start if it is not
        // here yet rather than indexing past the end.
        if (index != -1) {
          setState(() {
            elapsed = rMovies[index].elapsed!;
          });
        }
        _metadata.elapsed = elapsed;
      } else {
        _metadata.elapsed = 0;
      }

      final isUnreleased =
          _metadata.releaseDate != null && !isReleased(_metadata.releaseDate!);
      if (isUnreleased) {
        GlobalMethods.showScaffoldMessage(
          tr('movie_may_not_be_available'),
          context,
        );
      }

      final manualPickRequired = !widget.download && !settings.autoLoadSources;

      ProviderSelection? selection;
      if (manualPickRequired) {
        // "Auto load sources" is off: let the user pick a provider and only
        // fetch that one. Re-prompt after a failed attempt so they can simply
        // choose another source.
        while (true) {
          if (!mounted) return;
          final picked = await showPlaybackProviderPicker(
            context: context,
            providers: videoProviders
                .where(
                  (provider) => provider.supportsMedia(_playbackMediaIdentity),
                )
                .toList(growable: false),
            useTvPlayer: widget.useTvPlayer,
          );
          if (!mounted) return;
          if (picked == null) {
            // Dismissed the picker: leave without playing anything.
            Navigator.pop(context);
            return;
          }
          selection = await _fetchSelection(providers: [picked]);
          if (selection != null) {
            // Keep the user's manual first-provider choice, then continue the
            // quality scan across every other eligible provider in background.
            final chosen = selection;
            chosen.scanSession?.cancel();
            final knownResults = <String, ProviderLoadResult>{
              ...chosen.cachedProviderResults,
              picked.codeName: chosen.result,
            };
            final remainingProviders = videoProviders
                .where(
                  (provider) =>
                      provider.supportsMedia(_playbackMediaIdentity) &&
                      !knownResults.containsKey(provider.codeName),
                )
                .toList(growable: false);
            final supplementalScan = ProviderLoader.startScan(
              providers: remainingProviders,
              initialResults: knownResults,
              unifiedMediaIdentity: _playbackMediaIdentity,
              maxConcurrency: 3,
              load: (provider) => ProviderLoader.loadMovieFromProvider(
                provider: provider,
                movieId: _metadata.movieId!,
                scraperApiUrl: _scraperApiUrl,
                mediaIdentity: _playbackMediaIdentity,
              ),
            );
            final chosenHasDirectStream = (chosen.result.videoLinks ?? const [])
                .any((link) => !link.isEmbeddedPlayer);
            final directFallback = chosenHasDirectStream
                ? null
                : await supplementalScan.firstDirectPlayable;
            final preferred = directFallback ?? chosen;
            selection = ProviderSelection(
              index: preferred.index,
              provider: preferred.provider,
              result: preferred.result,
              scanSession: supplementalScan,
              cachedProviderResults:
                  Map<String, ProviderLoadResult>.unmodifiable(knownResults),
              selectedUrl: preferred.selectedUrl,
              restoredFromCache: preferred.restoredFromCache,
            );
          }
          if (selection != null || !mounted) break;
        }
      } else {
        // Try sources one at a time until one returns playable links.
        selection = await _fetchSelection(providers: videoProviders);
      }

      if (selection != null) {
        if (!await AdsterraPlaybackAdsService.instance.streamFound(
              context,
              download: widget.download,
              television: widget.useTvPlayer,
              preload: _adPreload,
              stage: widget.adStage,
            ) ||
            !mounted) {
          return;
        }
      }
      if (widget.download && selection != null) {
        // Downloads scan all eligible providers, then render one unified
        // quality list. Do not route through the legacy provider picker.
        await selection.scanSession?.completed;
        if (!mounted) return;
        final scanResults = <String, ProviderLoadResult>{
          ...selection.cachedProviderResults,
          ...?selection.scanSession?.resolvedResults,
          selection.provider.codeName: selection.result,
        };
        await _enqueueUnifiedDownload(scanResults);
        return;
      }

      if (selection != null) {
        final selectedLinks =
            selection.result.videoLinks ?? const <RegularVideoLinks>[];
        final directLinks = selectedLinks
            .where((link) => !link.isEmbeddedPlayer)
            .toList(growable: false);
        final embeddedLinks = selectedLinks
            .where(
              (link) =>
                  link.isEmbeddedPlayer && link.url?.trim().isNotEmpty == true,
            )
            .toList(growable: false);
        if (directLinks.isEmpty && embeddedLinks.isNotEmpty) {
          _showSelectedProvider(selection.provider);
          if (widget.download) {
            _showErrorSheet(
              'An embedded provider page cannot be downloaded as a video file.',
            );
            return;
          }
          final embedded = embeddedLinks.first;
          await handoffLoaderToPlayer<void>(
            context,
            (context) => EmbeddedWebPlaybackScreen(
              url: embedded.url!,
              sourceName: embedded.server?.trim().isNotEmpty == true
                  ? embedded.server!.trim()
                  : selection!.provider.displayName,
              sourceId: embedded.providerCode ?? selection!.provider.codeName,
              headers: embedded.headers ?? const <String, String>{},
              requiresManualVerification: embedded.embedRequiresVerification,
              useTvControls: widget.useTvPlayer,
            ),
          );
          return;
        }
      }

      final firstWorkingProviderCode = selection?.provider.codeName;
      if (selection != null) {
        _showSelectedProvider(selection.provider);
        final result = selection.result;
        videos = VideoUtils.convertVideoLinksToMap(result.videoLinks!);
        movieVideoLinks = result.videoLinks;
        movieVideoSubs = result.subtitleLinks;
        _addSubtitles(result.subtitleLinks);
      }

      // Check if we found a working provider
      if (firstWorkingProviderCode == null && mounted) {
        _showErrorSheet(tr('movie_vid_404'));
        return;
      }

      // Prepare final video map (reversed for quality ordering)
      Map<String, String> reversedVids = VideoUtils.reverseVideoQualityMap(
        videos,
      );
      final videoFormats = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoFormatsToMap(movieVideoLinks ?? const []),
      );
      final videoHeaders = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoHeadersToMap(movieVideoLinks ?? const []),
      );
      final videoSizeTokens = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoSizeTokensToMap(movieVideoLinks ?? const []),
      );

      if (firstWorkingProviderCode != null && mounted) {
        if (widget.download) {
          await _enqueueDownload(
            providerName: selection?.provider.displayName,
            downloadProvider: selection?.provider,
          );
          return;
        }
        if (!isUnreleased) {
          Provider.of<SettingsProvider>(
            context,
            listen: false,
          ).analytics.trackMovieWatched(
            movieName: _metadata.movieName,
            movieId: _metadata.movieId,
            isAdult: _metadata.isAdult ?? 'unknown',
          );
        }

        await recommendationsFetch;
        if (!mounted) return;

        // Navigate to player with provider list for lazy loading
        debugPrint(
          '[MovieRecommendationsDebug][PLAYER_HANDOFF] '
          'movieId=${_metadata.movieId} '
          'title=${_metadata.movieName} '
          'recommendations=${_metadata.recommendations?.length ?? 0} '
          'recommendationIds=${_metadata.recommendations?.map((movie) => movie.movieId).join(',') ?? 'none'}',
        );
        handoffLoaderToPlayer<void>(context, (context) {
          debugPrint(
            '[MovieRecommendationsDebug][PLAYER_CREATED] '
            'movieId=${_metadata.movieId} '
            'recommendations=${_metadata.recommendations?.length ?? 0} '
            'recommendationsNull=${_metadata.recommendations == null} '
            'useTvPlayer=${widget.useTvPlayer}',
          );
          final player = PlayerOne(
            mediaType: MediaType.movie,
            sources: reversedVids,
            subs: subs,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).colorScheme.surface,
            ],
            settings: settings,
            movieMetadata: _metadata,
            availableProviders:
                videoProviders, // Pass provider list for lazy loading
            currentProviderCode: firstWorkingProviderCode, // Current provider
            scraperApiUrl: _scraperApiUrl,
            videoFormats: videoFormats,
            videoHeaders: videoHeaders,
            videoSizeTokens: videoSizeTokens,
            initialVideoLinks: movieVideoLinks ?? const [],
            initialSubtitleLinks: movieVideoSubs ?? const [],
            providerScanSession: selection?.scanSession,
            cachedProviderResults:
                selection?.cachedProviderResults ??
                const <String, ProviderLoadResult>{},
            initialStreamUrl: selection?.selectedUrl,
            subtitleStyle: Provider.of<SettingsProvider>(
              context,
            ).subtitleTextStyle,
            useTvControls: widget.useTvPlayer,
            onTvPlayerExit: widget.onTvPlayerExit,
          );
          return widget.useTvPlayer ? TvPlayerScreen(child: player) : player;
        });
      } else {
        if (mounted) {
          _showErrorSheet(tr('movie_vid_404'));
        }
      }
    } on Exception catch (e) {
      debugPrint('[MovieVideoLoader] Exception loading video: $e');
      if (mounted) {
        _showErrorSheet(tr('movie_vid_404'));
      }
    }
  }

  /// Focus the carousel on the first provider still being fetched so the
  /// highlight does not linger on a provider that just failed or succeeded.
  /// Downloads never enter the legacy provider picker. Resolve every eligible
  /// installed source in one pass, then expose the shared one-row-per-quality
  /// catalogue (the same catalogue the player uses).
  Future<void> _scanAllSourcesAndQueueDownload() async {
    await _ensureExpectedMovieRuntime();
    if (!mounted) return;
    final eligible = videoProviders
        .where((provider) => provider.supportsMedia(_playbackMediaIdentity))
        .toList(growable: false);
    if (eligible.isEmpty) {
      _showErrorSheet(tr('movie_vid_404'));
      return;
    }

    // Reuse the exact playback cache first. Only providers with no cached
    // result are scheduled, and the standard heights remain completion
    // targets rather than a whitelist of selectable qualities.
    final restored = await ProviderLoader.restoreCachedSelection(
      identity: _playbackMediaIdentity,
      providers: eligible,
    );
    if (!mounted) return;
    final resultsByProvider = <String, ProviderLoadResult>{
      ...?restored?.cachedProviderResults,
    };
    final providersToScan = eligible
        .where((provider) => !resultsByProvider.containsKey(provider.codeName))
        .toList(growable: false);
    final entriesNotifier = ValueNotifier<List<QualityCatalogEntry>>(
      PlaybackQualityCatalog.collect(
        linksByProvider: _downloadLinksByProvider(resultsByProvider),
        preferredServerOrder: StreamHostPriorityManager.instance.currentOrder,
      ),
    );
    final searchingNotifier = ValueNotifier<bool>(true);
    final adaptiveScanner = AdaptiveQualityScanner();
    final adaptiveTasks = <Future<void>>[];
    final adaptiveSignatures = <String>{};
    final qualityReady = Completer<void>();
    var adaptiveScansInProgress = 0;
    var scanFinished = false;
    var pickerActive = true;
    ProviderScanSession? activeScan;
    var lastProviderCode = restored?.provider.codeName;
    var lastUrl = restored?.selectedUrl;
    Future<void> cacheWriteQueue = Future<void>.value();

    void publish() {
      if (pickerActive) {
        entriesNotifier.value = PlaybackQualityCatalog.collect(
          linksByProvider: _downloadLinksByProvider(resultsByProvider),
          preferredServerOrder:
              StreamHostPriorityManager.instance.currentOrder,
        );
        searchingNotifier.value = !scanFinished || adaptiveScansInProgress > 0;
        if (entriesNotifier.value.isNotEmpty && !qualityReady.isCompleted) {
          qualityReady.complete();
        }
      }
      if (scanFinished && adaptiveScansInProgress == 0 &&
          entriesNotifier.value.isEmpty && !qualityReady.isCompleted) {
        qualityReady.complete();
      }
    }

    void queueCacheWrite() {
      final snapshot = Map<String, ProviderLoadResult>.of(resultsByProvider);
      cacheWriteQueue = cacheWriteQueue
          .then(
            (_) => ProviderLoader.persistResolvedResults(
              identity: _playbackMediaIdentity,
              providers: eligible,
              results: snapshot,
              lastProviderCode: lastProviderCode,
              lastUrl: lastUrl,
            ),
          )
          .catchError((Object error) {
            debugPrint('[MovieVideoLoader] Playback cache save failed: $error');
          });
    }

    void startAdaptiveScan(RegularVideoLinks link) {
      if (!AdaptiveQualityScanner.isCandidate(link)) return;
      final url = link.url?.trim() ?? '';
      if (url.isEmpty) return;
      final headers = (link.headers ?? const <String, String>{}).entries
          .map((entry) => '${entry.key.toLowerCase()}:${entry.value}')
          .toList()
        ..sort();
      if (!adaptiveSignatures.add('$url|${headers.join('|')}')) return;
      adaptiveScansInProgress++;
      final task = adaptiveScanner
          .scan(link)
          .then<void>((heights) {
            final changed =
                link.availableHeights.toSet().difference(heights.toSet()).isNotEmpty ||
                heights.toSet().difference(link.availableHeights.toSet()).isNotEmpty;
            link.availableHeights = heights;
            if (heights.isNotEmpty) link.isAdaptive = true;
            activeScan?.reportAdaptiveQualityHeights(heights);
            if (changed) queueCacheWrite();
            publish();
          })
          .catchError((Object error) {
            debugPrint('[MovieVideoLoader] Adaptive quality scan failed: $error');
          })
          .whenComplete(() {
            adaptiveScansInProgress--;
            publish();
          });
      adaptiveTasks.add(task);
    }

    // Cached adaptive masters are inspected without delaying the picker.
    for (final result in resultsByProvider.values) {
      for (final link in result.videoLinks ?? const <RegularVideoLinks>[]) {
        startAdaptiveScan(link);
      }
    }
    publish();

    final scan = activeScan = ProviderLoader.startScan(
      providers: providersToScan,
      initialResults: resultsByProvider,
      unifiedMediaIdentity: _playbackMediaIdentity,
      maxConcurrency: 3,
      continueAfterFirstPlayable: true,
      stopAfterStandardQualities: true,
      load: (provider) => ProviderLoader.loadMovieFromProvider(
        provider: provider,
        movieId: _metadata.movieId!,
        scraperApiUrl: _scraperApiUrl,
        mediaIdentity: _playbackMediaIdentity,
      ),
      onResult: (_, provider, result) {
        if (result.videoLinks?.isNotEmpty == true) {
          resultsByProvider[provider.codeName] = result;
          for (final link in result.videoLinks!) {
            startAdaptiveScan(link);
          }
          publish();
          queueCacheWrite();
        }
      },
    );
    scan.completed.then((_) async {
      scanFinished = true;
      publish();
      await Future.wait(adaptiveTasks);
      adaptiveScanner.dispose();
      publish();
      queueCacheWrite();
    });

    try {
      // With no cache, wait only until the first concrete quality appears;
      // the remaining servers continue in the background while the picker is
      // already available and receives their new qualities live.
      await qualityReady.future;
      if (!mounted) return;
      if (entriesNotifier.value.isEmpty) {
        _showErrorSheet(
          'No direct downloadable video qualities were returned by the installed sources.',
        );
        return;
      }
      await _enqueueUnifiedDownload(
        resultsByProvider,
        entriesListenable: entriesNotifier,
        searchingListenable: searchingNotifier,
        onSelected: (entry) {
          lastProviderCode = entry.sourceProviderCode;
          lastUrl = entry.link.url;
          queueCacheWrite();
        },
      );
    } finally {
      pickerActive = false;
      entriesNotifier.dispose();
      searchingNotifier.dispose();
    }
  }

  Map<String, List<RegularVideoLinks>> _downloadLinksByProvider(
    Map<String, ProviderLoadResult> resultsByProvider,
  ) => <String, List<RegularVideoLinks>>{
    for (final entry in resultsByProvider.entries)
      if (entry.value.videoLinks?.isNotEmpty == true)
        entry.key: entry.value.videoLinks!,
  };


  int _firstLoadingProviderIndex() {
    for (var index = 0; index < providerStates.length; index++) {
      if (providerStates[index].status == ProviderStatus.loading) {
        return index;
      }
    }
    return currentProviderIndex;
  }

  /// Shows [provider] as the one selected for playback.
  void _showSelectedProvider(VideoProvider provider) {
    if (!mounted) return;
    setState(() {
      currentProviderIndex = videoProviders.indexWhere(
        (candidate) => candidate.codeName == provider.codeName,
      );
    });
  }

  /// Starts a bounded provider scan, returns the first playable result, and
  /// lets the remaining eligible providers resolve in the background.
  MediaIdentity get _playbackMediaIdentity => ProviderLoader.movieIdentity(
    tmdbId: _metadata.movieId!,
    title: _metadata.movieName ?? 'Movie ${_metadata.movieId}',
    year: _metadata.releaseYear,
    isAnime: _metadata.isAnimeContent,
  );

  Future<ProviderSelection?> _fetchSelection({
    required List<VideoProvider> providers,
  }) async {
    final identity = _playbackMediaIdentity;
    // Reuse the last playback URL before contacting providers. Downloads keep
    // their existing fresh-resolution path and never reuse playback cache.
    if (!widget.download) {
      final cached = await ProviderLoader.restoreCachedSelection(
        identity: identity,
        providers: providers,
      );
      if (cached != null) {
        final cachedProviderCodes = cached.cachedProviderResults.keys.toSet();
        final providersNeedingScan = providers
            .where(
              (provider) =>
                  provider.supportsMedia(identity) &&
                  !cachedProviderCodes.contains(provider.codeName),
            )
            .toList(growable: false);
        // Resume from the last valid URL immediately, while filling only the
        // provider gaps left by the previous playback session. Cached provider
        // results seed the quality target, so already-known 480/720/1080
        // heights do not cause redundant provider requests.
        final supplementalScan = ProviderLoader.startScan(
          providers: providersNeedingScan,
          initialResults: cached.cachedProviderResults,
          unifiedMediaIdentity: identity,
          maxConcurrency: 3,
          load: (provider) => ProviderLoader.loadMovieFromProvider(
            provider: provider,
            movieId: _metadata.movieId!,
            scraperApiUrl: _scraperApiUrl,
            mediaIdentity: identity,
          ),
        );
        debugPrint(
          '[PlaybackCache][HIT] provider=${cached.provider.codeName} '
          'cachedProviders=${cachedProviderCodes.length} '
          'supplementalProviders=${providersNeedingScan.length}',
        );
        return ProviderSelection(
          index: cached.index,
          provider: cached.provider,
          result: cached.result,
          scanSession: supplementalScan,
          cachedProviderResults: cached.cachedProviderResults,
          selectedUrl: cached.selectedUrl,
          restoredFromCache: true,
        );
      }
    }

    final scan = ProviderLoader.startScan(
      providers: providers,
      unifiedMediaIdentity: identity,
      maxConcurrency: 3,
      continueAfterFirstPlayable: true,
      stopAfterStandardQualities: !widget.download,
      load: (provider) => ProviderLoader.loadMovieFromProvider(
        provider: provider,
        movieId: _metadata.movieId!,
        scraperApiUrl: _scraperApiUrl,
        mediaIdentity: identity,
      ),
      onStart: (index, provider) {
        _providerStopwatches[provider.codeName] = Stopwatch()..start();
        if (!mounted) return;
        setState(() {
          final providerIndex = providerStates.indexWhere(
            (state) => state.codeName == provider.codeName,
          );
          if (providerIndex != -1) {
            providerStates[providerIndex] = providerStates[providerIndex]
                .copyWith(status: ProviderStatus.loading, errorMessage: null);
          }
          currentProviderIndex = _firstLoadingProviderIndex();
        });
        debugPrint(
          '[MovieVideoLoader] Request provider=${provider.displayName} '
          '(${provider.codeName}), tmdbId=${_metadata.movieId}',
        );
      },
      onResult: (index, provider, result) {
        final durationMs =
            _providerStopwatches
                .remove(provider.codeName)
                ?.elapsedMilliseconds ??
            0;
        final providerSucceeded =
            result.success && result.videoLinks?.isNotEmpty == true;
        settings.analytics.trackProviderAttempt(
          mediaType: 'movie',
          contentId: _metadata.movieId,
          contentTitle: _metadata.movieName,
          provider: provider.displayName,
          purpose: widget.download ? 'download' : 'playback',
          success: providerSucceeded,
          durationMs: durationMs,
          sourceCount: result.videoLinks?.length ?? 0,
          subtitleCount: result.subtitleLinks?.length ?? 0,
          error: ProviderLoader.sanitizeDiagnosticError(result.errorMessage),
        );
        debugPrint(
          '[MovieVideoLoader] Response provider=${provider.displayName} '
          'success=$providerSucceeded links=${result.videoLinks?.length ?? 0} '
          'subtitles=${result.subtitleLinks?.length ?? 0} '
          'error=${ProviderLoader.sanitizeDiagnosticError(result.errorMessage)}',
        );
        if (mounted) {
          setState(() {
            final providerIndex = providerStates.indexWhere(
              (state) => state.codeName == provider.codeName,
            );
            if (providerIndex != -1) {
              providerStates[providerIndex] = providerStates[providerIndex]
                  .copyWith(
                    status: providerSucceeded
                        ? ProviderStatus.success
                        : ProviderStatus.failed,
                    errorMessage: ProviderLoader.sanitizeDiagnosticError(
                      result.errorMessage,
                    ),
                  );
            }
            currentProviderIndex = _firstLoadingProviderIndex();
          });
        }
      },
    );
    return await scan.firstPlayable;
  }

  /// Leaves the loader screen and reports the failure in a bottom sheet that
  /// can push a fresh loader when the user retries.
  void _showErrorSheet(String message) {
    final navigator = Navigator.of(context);
    final metadata = _metadata;
    final download = widget.download;
    final useTvPlayer = widget.useTvPlayer;
    final onTvPlayerExit = widget.onTvPlayerExit;
    final adStage = widget.adStage;
    navigator.pop();
    ReportErrorWidget.show(
      navigator.context,
      error: message,
      onRetry: () => navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => MovieVideoLoader(
            metadata: metadata,
            download: download,
            useTvPlayer: useTvPlayer,
            onTvPlayerExit: onTvPlayerExit,
            adStage: adStage,
          ),
        ),
      ),
    );
  }

  Future<void> _ensureExpectedMovieRuntime() async {
    if ((_metadata.runtime ?? 0) > 0 || _metadata.movieId == null) return;
    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final dependencies = Provider.of<AppDependencyProvider>(
        context,
        listen: false,
      );
      final details = await fetchMovieDetails(
        Endpoints.movieDetailsUrl(
          _metadata.movieId!,
          settingsProvider.appLanguage,
        ),
        settingsProvider.enableProxy,
        dependencies.tmdbProxy,
      );
      if ((details.runtime ?? 0) > 0) _metadata.runtime = details.runtime;
      _metadata.genreIds ??= details.genreIds;
      _metadata.originalLanguage ??= details.originalLanguage;
      _metadata.isAnime = _metadata.isAnime || details.isLikelyAnime;
    } catch (error) {
      debugPrint('[OfflineDownload][RUNTIME_LOOKUP_FAILED] $error');
    }
  }

  Future<void> _enqueueUnifiedDownload(
    Map<String, ProviderLoadResult> resultsByProvider, {
    ValueListenable<List<QualityCatalogEntry>>? entriesListenable,
    ValueListenable<bool>? searchingListenable,
    ValueChanged<QualityCatalogEntry>? onSelected,
  }) async {
    final linksByProvider = _downloadLinksByProvider(resultsByProvider);
    final entries = PlaybackQualityCatalog.collect(
      linksByProvider: linksByProvider,
      preferredServerOrder: StreamHostPriorityManager.instance.currentOrder,
    );
    if (entries.isEmpty && entriesListenable == null) {
      _showErrorSheet(
        'No direct downloadable video qualities were returned by the installed sources.',
      );
      return;
    }
    final selected = await DownloadSelectionSheets.showQualityCatalog(
      context,
      entries: entries,
      entriesListenable: entriesListenable,
      searchingListenable: searchingListenable,
    );
    if (!mounted) return;
    if (selected == null) {
      settings.analytics.trackDownload(
        action: 'quality_selection',
        mediaType: 'movie',
        outcome: 'cancelled',
      );
      Navigator.pop(context, false);
      return;
    }

    final url = selected.link.url?.trim() ?? '';
    if (url.isEmpty) {
      _showErrorSheet('The selected quality returned an empty video URL.');
      return;
    }
    final format = VideoUtils.downloadFormat(url: url, link: selected.link);
    final headers =
        selected.link.headers ??
        VideoUtils.inferVideoHeaders(url) ??
        const <String, String>{};
    final sourceProvider = videoProviders.cast<VideoProvider?>().firstWhere(
      (provider) => provider?.codeName == selected.sourceProviderCode,
      orElse: () => videoProviders.cast<VideoProvider?>().firstWhere(
        (provider) => provider?.codeName == selected.providerCode,
        orElse: () => null,
      ),
    );
    final sourceResult =
        resultsByProvider[selected.sourceProviderCode] ??
        resultsByProvider[selected.providerCode];
    final sourceLinks =
        sourceResult?.videoLinks ?? <RegularVideoLinks>[selected.link];
    final subtitles = sourceResult?.subtitleLinks;
    final posterPath = _metadata.posterPath;
    final quality = selected.qualityLabel;
    final maxHeight = selected.height ?? selected.adaptiveTargetHeight;
    final externalSubtitleFuture = ExternalSubtitleService(_scraperApiUrl).fetchMovieSubtitles(
      _metadata.movieId ?? 0,
      title: _metadata.movieName,
      year: _metadata.releaseYear,
      preferredLanguageCode: context.read<SettingsProvider>().defaultSubtitleLanguage,
    ).catchError((Object _) => <ExternalSubtitle>[]);
    final subtitleSelection = await DownloadSelectionSheets.chooseSubtitle(
      context,
      tracks: subtitles ?? const <RegularSubtitleLinks>[],
      externalTracks: externalSubtitleFuture,
    );
    if (!mounted) return;
    if (subtitleSelection == null) {
      Navigator.pop(context, false);
      return;
    }
    final subtitleTrack = subtitleSelection.track;
    final externalSubtitle = subtitleSelection.externalTrack;
    final subtitleContent = externalSubtitle == null
        ? null
        : await ExternalSubtitleService(_scraperApiUrl)
            .downloadAndNormalizeForPlayback(externalSubtitle);
    if (!mounted) return;
    try {
      await context.read<OfflineDownloadProvider>().enqueue(
        OfflineDownloadRequest(
          id: movieOfflineDownloadId(_metadata.movieId!),
          url: url,
          format: format,
          title: _metadata.movieName ?? 'Movie',
          subtitle: sourceProvider?.displayName == null
              ? null
              : 'From ${sourceProvider!.displayName}',
          mediaType: 'movie',
          quality: quality,
          posterUrl: posterPath == null
              ? null
              : '${TMDB_BASE_IMAGE_URL}w500$posterPath',
          maxVideoHeight: maxHeight,
          headers: headers,
          streamIdentity: <String, Object?>{
            'server': selected.link.server?.trim().isNotEmpty == true
                ? selected.link.server!.trim()
                : sourceProvider?.displayName ?? selected.providerCode,
            'providerCode': selected.providerCode,
            'sourceProviderCode': selected.sourceProviderCode,
            'sourceKey': selected.sourceKey,
            'quality': selected.qualityLabel,
            'format': format,
          },
          source: OfflineDownloadSource.forSelection(
            provider: sourceProvider,
            apiBaseUrl: _scraperApiUrl,
            links: sourceLinks,
            url: url,
          ),
          contentId: _metadata.movieId,
          subtitleTrackUrl: subtitleTrack?.url,
          subtitleTrackName: externalSubtitle?.language ?? subtitleTrack?.language,
          subtitleTrackHeaders: subtitleTrack?.headers ?? const {},
          subtitleTrackContent: subtitleContent,
          audioLanguages: (_metadata.isAnimeContent ? const <String>['ja', 'en'] : const <String>['en']),
          expectedDurationMs: (_metadata.runtime != null && _metadata.runtime! > 0 ? _metadata.runtime! * 60 * 1000 : null),
        ),
      );
      onSelected?.call(selected);
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'movie',
        outcome: 'success',
        provider: selected.link.server ?? sourceProvider?.displayName,
        quality: quality,
      );
      if (mounted) {
        AdsterraPlaybackAdsService.instance.afterDownloadQueued(context);
        Navigator.pop(context, true);
      }
    } catch (error) {
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'movie',
        outcome: isAlreadyDownloaded(error) ? 'already_downloaded' : 'error',
        provider: selected.link.server ?? sourceProvider?.displayName,
        quality: quality,
        error: error.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            offlineEnqueueErrorMessage(
              error,
              title: _metadata.movieName ?? 'This movie',
            ),
          ),
        ),
      );
      Navigator.pop(context, false);
    }
  }

  Future<void> _enqueueDownload({
    String? providerName,
    VideoProvider? downloadProvider,
  }) async {
    final downloadLinks = movieVideoLinks ?? const <RegularVideoLinks>[];
    var inferredProviderCode = '';
    for (final link in downloadLinks) {
      final candidate = link.providerCode?.trim() ?? '';
      if (candidate.isNotEmpty) {
        inferredProviderCode = candidate;
        break;
      }
    }
    final providerCode =
        downloadProvider?.codeName ??
        (inferredProviderCode.isNotEmpty
            ? inferredProviderCode
            : 'download:movie');
    final entries = await PlaybackQualityCatalog.collectWithAdaptiveDiscovery(
      linksByProvider: <String, List<RegularVideoLinks>>{
        providerCode: downloadLinks,
      },
      preferredServerOrder: StreamHostPriorityManager.instance.currentOrder,
    );
    if (!mounted) return;
    if (entries.isEmpty) {
      _showErrorSheet(
        'No direct downloadable video qualities were returned by the selected source.',
      );
      return;
    }

    final selected = await DownloadSelectionSheets.showQualityCatalog(
      context,
      entries: entries,
    );
    if (!mounted) return;
    if (selected == null) {
      settings.analytics.trackDownload(
        action: 'quality_selection',
        mediaType: 'movie',
        outcome: 'cancelled',
        provider: providerName,
      );
      Navigator.pop(context, false);
      return;
    }

    final url = selected.link.url?.trim() ?? '';
    if (url.isEmpty) {
      _showErrorSheet('The selected quality returned an empty video URL.');
      return;
    }
    final format = VideoUtils.downloadFormat(url: url, link: selected.link);
    final headers =
        selected.link.headers ??
        VideoUtils.inferVideoHeaders(url) ??
        const <String, String>{};
    final maxHeight = selected.height ?? selected.adaptiveTargetHeight;
    try {
      final externalSubtitleFuture = ExternalSubtitleService(_scraperApiUrl).fetchMovieSubtitles(
        _metadata.movieId ?? 0,
        title: _metadata.movieName,
        year: _metadata.releaseYear,
        preferredLanguageCode: context.read<SettingsProvider>().defaultSubtitleLanguage,
      ).catchError((Object _) => <ExternalSubtitle>[]);
      final subtitleSelection = await DownloadSelectionSheets.chooseSubtitle(
        context,
        tracks: movieVideoSubs ?? const <RegularSubtitleLinks>[],
        externalTracks: externalSubtitleFuture,
      );
      if (!mounted) return;
      if (subtitleSelection == null) {
        Navigator.pop(context, false);
        return;
      }
      final subtitleTrack = subtitleSelection.track;
      final externalSubtitle = subtitleSelection.externalTrack;
      final subtitleContent = externalSubtitle == null
          ? null
          : await ExternalSubtitleService(_scraperApiUrl)
              .downloadAndNormalizeForPlayback(externalSubtitle);
      if (!mounted) return;
      await context.read<OfflineDownloadProvider>().enqueue(
        OfflineDownloadRequest(
          id: movieOfflineDownloadId(_metadata.movieId!),
          url: url,
          format: format,
          title: _metadata.movieName ?? 'Movie',
          subtitle: 'From ${selected.sourceDisplayName}',
          mediaType: 'movie',
          quality: selected.qualityLabel,
          posterUrl: _metadata.posterPath == null
              ? null
              : '${TMDB_BASE_IMAGE_URL}w500${_metadata.posterPath}',
          maxVideoHeight: maxHeight,
          headers: headers,
          streamIdentity: <String, Object?>{
            'server': selected.sourceDisplayName,
            'providerCode': selected.providerCode,
            'sourceProviderCode': selected.sourceProviderCode,
            'sourceKey': selected.sourceKey,
            'quality': selected.qualityLabel,
            'format': format,
          },
          source: OfflineDownloadSource.forSelection(
            provider: downloadProvider,
            apiBaseUrl: _scraperApiUrl,
            links: downloadLinks,
            url: url,
          ),
          contentId: _metadata.movieId,
          subtitleTrackUrl: subtitleTrack?.url,
          subtitleTrackName: externalSubtitle?.language ?? subtitleTrack?.language,
          subtitleTrackHeaders: subtitleTrack?.headers ?? const {},
          subtitleTrackContent: subtitleContent,
          audioLanguages: (_metadata.isAnimeContent ? const <String>['ja', 'en'] : const <String>['en']),
          expectedDurationMs: (_metadata.runtime != null && _metadata.runtime! > 0 ? _metadata.runtime! * 60 * 1000 : null),
        ),
      );
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'movie',
        outcome: 'success',
        provider: selected.sourceDisplayName,
        quality: selected.qualityLabel,
      );
      if (mounted) {
        AdsterraPlaybackAdsService.instance.afterDownloadQueued(context);
        Navigator.pop(context, true);
      }
    } catch (error) {
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'movie',
        outcome: isAlreadyDownloaded(error) ? 'already_downloaded' : 'error',
        provider: selected.sourceDisplayName,
        quality: selected.qualityLabel,
        error: error.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            offlineEnqueueErrorMessage(
              error,
              title: _metadata.movieName ?? 'This movie',
            ),
          ),
        ),
      );
      Navigator.pop(context, false);
    }
  }

  void _addSubtitles(List<RegularSubtitleLinks>? subtitleLinks) {
    if (subtitleLinks == null || subtitleLinks.isEmpty) return;
    final preferredLang = settings.defaultSubtitleLanguage.toLowerCase();

    for (final subLink in subtitleLinks) {
      final subLanguage = subLink.language ?? 'Unknown';
      final normalizedLanguage = subLanguage.toLowerCase();
      final isPreferred =
          preferredLang.isNotEmpty &&
          (normalizedLanguage.startsWith(preferredLang) ||
              normalizedLanguage == preferredLang ||
              (preferredLang == 'en' &&
                  normalizedLanguage.startsWith('english')));
      subs.add(
        BetterPlayerSubtitlesSource(
          type: BetterPlayerSubtitlesSourceType.network,
          urls: [subLink.url ?? ''],
          name: subLanguage,
          selectedByDefault: isPreferred,
          headers: subLink.headers,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final releaseYear =
        _metadata.releaseYear?.toString() ??
        _metadata.releaseDate?.split('-').first;
    final contextLine = <String>[
      if (widget.download) tr('download'),
      if (releaseYear?.isNotEmpty == true && releaseYear != '0') releaseYear!,
    ].join('  ·  ');
    return PlaybackLoadingScreen(
      title: _metadata.movieName?.trim().isNotEmpty == true
          ? _metadata.movieName!.trim()
          : tr('movie'),
      subtitle: contextLine,
      backdropPath: _metadata.backdropPath,
      posterPath: _metadata.posterPath,
      providers: providerStates,
      currentProviderIndex: currentProviderIndex,
    );
  }

  Future<void> _fetchMovieRecommendations() async {
    final movieId = _metadata.movieId;
    final isProxyEnabled = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(
      context,
      listen: false,
    ).tmdbProxy;
    final language = settings.appLanguage;
    debugPrint(
      '[MovieRecommendationsDebug][FETCH_START] '
      'movieId=$movieId language=$language '
      'proxyEnabled=$isProxyEnabled proxyConfigured=${proxyUrl.isNotEmpty} '
      'mounted=$mounted',
    );
    if (movieId == null) {
      debugPrint(
        '[MovieRecommendationsDebug][FETCH_SKIPPED] reason=missing_movie_id',
      );
      return;
    }

    final recommendations = await _loadRecommendations(
      movieId: movieId,
      isProxyEnabled: isProxyEnabled,
      proxyUrl: proxyUrl,
      language: language,
    );
    _metadata.recommendations = recommendations;
    debugPrint(
      '[MovieRecommendationsDebug][METADATA_SET] '
      'movieId=$movieId count=${recommendations.length} '
      'items=${recommendations.map((movie) => '${movie.movieId}:${movie.title}').join(' | ')}',
    );

    // Set the movie change callback
    _metadata.onMovieChange = (int movieId) async {
      // This will be called from the player when user selects a movie
    };
  }

  /// TMDB's "recommendations" is frequently empty for newer or niche titles, so
  /// fall back to the broader "similar" list before giving up.
  Future<List<MovieRecommendation>> _loadRecommendations({
    required int movieId,
    required bool isProxyEnabled,
    required String proxyUrl,
    required String language,
  }) async {
    var movies = await _fetchRecommendationList(
      label: 'recommendations',
      endpoint: Endpoints.getMovieRecommendations(movieId, 1, language),
      isProxyEnabled: isProxyEnabled,
      proxyUrl: proxyUrl,
    );
    if (movies.isEmpty) {
      debugPrint(
        '[MovieRecommendationsDebug][FALLBACK_SIMILAR] movieId=$movieId',
      );
      movies = await _fetchRecommendationList(
        label: 'similar',
        endpoint: Endpoints.getSimilarMovies(movieId, 1, language),
        isProxyEnabled: isProxyEnabled,
        proxyUrl: proxyUrl,
      );
    }
    return movies
        .take(10)
        .map(MovieRecommendation.fromMovie)
        .toList(growable: false);
  }

  Future<List<Movie>> _fetchRecommendationList({
    required String label,
    required String endpoint,
    required bool isProxyEnabled,
    required String proxyUrl,
  }) async {
    try {
      final movies = await fetchMovies(
        endpoint,
        isProxyEnabled,
        proxyUrl,
        debugLabel: 'MovieRecommendationsDebug',
      );
      debugPrint(
        '[MovieRecommendationsDebug][FETCH_RESULT] '
        'label=$label rawCount=${movies.length} '
        'rawIds=${movies.take(10).map((movie) => movie.id).join(',')}',
      );
      return movies;
    } catch (error, stackTrace) {
      // A failed list is not fatal; the other list (or an empty result) is used.
      debugPrint(
        '[MovieRecommendationsDebug][FETCH_FAILED] '
        'label=$label type=${error.runtimeType} error=$error',
      );
      debugPrintStack(
        label: '[MovieRecommendationsDebug][FETCH_FAILED_STACK]',
        stackTrace: stackTrace,
      );
      return const <Movie>[];
    }
  }
}
