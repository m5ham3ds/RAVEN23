import 'package:raven23/models/adsterra_playback_ads_config.dart';
import 'package:raven23/data/ads/content_ads.dart';
import 'package:raven23/services/adsterra_playback_ads_service.dart';
import 'package:raven23/widgets/ad_block_gate.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raven23/functions/function.dart';
import 'package:raven23/functions/network.dart';
import 'package:raven23/functions/video_utils.dart';
import 'package:raven23/functions/player_route_handoff.dart';
import 'package:raven23/models/tv_stream_metadata.dart';
import 'package:raven23/models/offline_download.dart';
import 'package:raven23/models/provider_video_source.dart';
import 'package:raven23/constants/app_constants.dart' show MediaType;
import 'package:raven23/models/provider_load_state.dart';
import 'package:raven23/services/globle_method.dart';
import 'package:raven23/services/offline_download_service.dart';
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
import '/provider/app_dependency_provider.dart';
import '/provider/offline_download_provider.dart';
import '/provider/settings_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:better_player_plus/better_player.dart';
import '../../models/sub_languages.dart';
import '../../widgets/common_widgets.dart';

import 'package:flutter/material.dart';
import '../../screens/common/player.dart';
import '../../screens/common/embedded_web_playback_screen.dart';
import '../../screens/common/download_selection_sheets.dart';
import '../../screens/common/manual_source_picker.dart';
import '../../tv/player/tv_player_screen.dart';

/// Finds a stream for a series' episode. A Kids or Family series' loader,
/// and the player it opens, are in its [ContentAdScope]: no ad is asked for.
class TVVideoLoader extends StatelessWidget {
  const TVVideoLoader({
    required this.metadata,
    required this.download,
    this.useTvPlayer = false,
    this.onTvPlayerExit,
    this.adStage = PlaybackAdStage.streamFound,
    super.key,
  });

  final TVStreamMetadata metadata;
  final bool download;
  final bool useTvPlayer;
  final VoidCallback? onTvPlayerExit;
  final PlaybackAdStage adStage;

  @override
  Widget build(BuildContext context) {
    final loader = _TVVideoLoader(
      metadata: metadata,
      download: download,
      useTvPlayer: useTvPlayer,
      onTvPlayerExit: onTvPlayerExit,
      adStage: adStage,
    );
    final id = metadata.tvId;
    if (id == null) return loader;
    return ContentAdGate(
      content: AdContent(series: true, id: id, genreIds: metadata.genreIds),
      holdChild: true,
      child: loader,
    );
  }
}

class _TVVideoLoader extends StatefulWidget {
  const _TVVideoLoader({
    required this.metadata,
    required this.download,
    this.useTvPlayer = false,
    this.onTvPlayerExit,
    this.adStage = PlaybackAdStage.streamFound,
  });

  final TVStreamMetadata metadata;
  final bool download;
  final bool useTvPlayer;
  final VoidCallback? onTvPlayerExit;

  /// The popup once a source is found: [PlaybackAdStage.episodeSwitch] or
  /// [PlaybackAdStage.movieSwitch] when the player itself started this load.
  final PlaybackAdStage adStage;

  @override
  State<_TVVideoLoader> createState() => _TVVideoLoaderState();
}

class _TVVideoLoaderState extends State<_TVVideoLoader> {
  RecentlyWatchedEpisodeController recentlyWatchedEpisodeController =
      RecentlyWatchedEpisodeController();

  List<RegularVideoLinks>? tvVideoLinks;
  List<RegularSubtitleLinks>? tvVideoSubs;

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

  @override
  void initState() {
    super.initState();
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
      // The player's episode list is not needed until it opens, so fetch it
      // alongside source loading instead of in front of it. Downloads never
      // open the player.
      final seasonEpisodesFetch = widget.download
          ? null
          : _fetchSeasonEpisodes();

      var isBookmarked = await recentlyWatchedEpisodeController.contain(
        widget.metadata.episodeId!,
      );
      int elapsed = 0;
      if (isBookmarked) {
        if (mounted) {
          var rEpisodes = Provider.of<RecentProvider>(
            context,
            listen: false,
          ).episodes;

          int index = rEpisodes.indexWhere(
            (element) => element.id == widget.metadata.episodeId,
          );
          // See [MovieVideoLoader]: the row can reach the database through a
          // cloud merge before this list snapshot is refreshed.
          if (index != -1) {
            setState(() {
              elapsed = rEpisodes[index].elapsed!;
            });
          }
          widget.metadata.elapsed = elapsed;
        }
      } else {
        widget.metadata.elapsed = 0;
      }

      final isUnreleased =
          widget.metadata.airDate != null &&
          !isReleased(widget.metadata.airDate!);
      if (isUnreleased) {
        GlobalMethods.showScaffoldMessage(
          tr('episode_may_not_be_available'),
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
              load: (provider) => ProviderLoader.loadTVFromProvider(
                provider: provider,
                tvId: widget.metadata.tvId!,
                seasonNumber: widget.metadata.seasonNumber!,
                episodeNumber: widget.metadata.episodeNumber!,
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
        tvVideoLinks = result.videoLinks;
        tvVideoSubs = result.subtitleLinks;
        _addSubtitles(result.subtitleLinks);
      }

      // Check if we found a working provider
      if (firstWorkingProviderCode == null && mounted) {
        _showErrorSheet(tr('tv_vid_404'));
        return;
      }

      // Prepare final video map (reversed for quality ordering)
      Map<String, String> reversedVids = VideoUtils.reverseVideoQualityMap(
        videos,
      );
      final videoFormats = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoFormatsToMap(tvVideoLinks ?? const []),
      );
      final videoHeaders = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoHeadersToMap(tvVideoLinks ?? const []),
      );
      final videoSizeTokens = VideoUtils.reverseVideoQualityMap(
        VideoUtils.convertVideoSizeTokensToMap(tvVideoLinks ?? const []),
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
          ).analytics.trackTVWatched(
            tvName: widget.metadata.seriesName,
            tvId: widget.metadata.tvId,
            episodeName: widget.metadata.episodeName,
            seasonNumber: widget.metadata.seasonNumber,
            episodeNumber: widget.metadata.episodeNumber,
          );
        }

        await seasonEpisodesFetch;
        if (!mounted) return;

        // Navigate to player with provider list for lazy loading
        handoffLoaderToPlayer<void>(context, (context) {
          final player = PlayerOne(
            mediaType: MediaType.tvShow,
            sources: reversedVids,
            subs: subs,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).colorScheme.surface,
            ],
            settings: settings,
            tvMetadata: widget.metadata,
            availableProviders:
                videoProviders, // Pass provider list for lazy loading
            currentProviderCode: firstWorkingProviderCode, // Current provider
            scraperApiUrl: _scraperApiUrl,
            videoFormats: videoFormats,
            videoHeaders: videoHeaders,
            videoSizeTokens: videoSizeTokens,
            initialVideoLinks: tvVideoLinks ?? const [],
            initialSubtitleLinks: tvVideoSubs ?? const [],
            providerScanSession: selection?.scanSession,
            cachedProviderResults:
                selection?.cachedProviderResults ??
                const <String, ProviderLoadResult>{},
            initialStreamUrl: selection?.selectedUrl,
            subtitleStyle: Provider.of<SettingsProvider>(
              context,
            ).subtitleTextStyle,
            onEpisodeChange: (episodeId, episodeNumber, seasonNumber) async {
              // This callback is now unused but kept for backwards compatibility
              // Episode changes are handled directly in the player
            },
            useTvControls: widget.useTvPlayer,
            onTvPlayerExit: widget.onTvPlayerExit,
          );
          return widget.useTvPlayer ? TvPlayerScreen(child: player) : player;
        });
      } else {
        if (mounted) {
          _showErrorSheet(tr('tv_vid_404'));
        }
      }
    } on Exception catch (e) {
      debugPrint('[TVVideoLoader] Exception loading video: $e');
      if (mounted) {
        _showErrorSheet(tr('tv_vid_404'));
      }
    }
  }

  /// Leaves the loader screen and reports the failure in a bottom sheet
  /// that can push a fresh TV loader when the user retries.
  void _showErrorSheet(String message) {
    final navigator = Navigator.of(context);
    final metadata = widget.metadata;
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
          builder: (_) => TVVideoLoader(
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

  /// Focus the carousel on the first provider still being fetched so the
  /// highlight does not linger on a provider that just failed or succeeded.
  /// Downloads never enter the legacy provider picker. Resolve every eligible
  /// installed source in one pass, then expose the shared one-row-per-quality
  /// catalogue (the same catalogue the player uses).
  Future<void> _scanAllSourcesAndQueueDownload() async {
    final eligible = videoProviders
        .where((provider) => provider.supportsMedia(_playbackMediaIdentity))
        .toList(growable: false);
    if (eligible.isEmpty) {
      _showErrorSheet(tr('tv_vid_404'));
      return;
    }

    // Share the playback cache with the episode download action. Cached
    // providers seed the same standard-height completion target; the scan
    // only schedules sources that have no reusable cached result.
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
            debugPrint('[TVVideoLoader] Playback cache save failed: $error');
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
            debugPrint('[TVVideoLoader] Adaptive quality scan failed: $error');
          })
          .whenComplete(() {
            adaptiveScansInProgress--;
            publish();
          });
      adaptiveTasks.add(task);
    }

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
      load: (provider) => ProviderLoader.loadTVFromProvider(
        provider: provider,
        tvId: widget.metadata.tvId!,
        seasonNumber: widget.metadata.seasonNumber!,
        episodeNumber: widget.metadata.episodeNumber!,
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

  /// Starts a bounded episode-provider scan and returns the first playable
  /// result while the remaining eligible providers continue in the background.
  MediaIdentity get _playbackMediaIdentity => ProviderLoader.episodeIdentity(
    tmdbId: widget.metadata.tvId!,
    title: widget.metadata.seriesName ?? 'Series ${widget.metadata.tvId}',
    seasonNumber: widget.metadata.seasonNumber!,
    episodeNumber: widget.metadata.episodeNumber!,
    episodeTmdbId: widget.metadata.episodeId,
    episodeAirDate: widget.metadata.airDate,
    isAnime: widget.metadata.isAnime,
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
        // The cached episode URL starts playback without waiting. The
        // supplemental scan then resolves only sources that were not
        // successfully cached during the previous viewing session.
        final supplementalScan = ProviderLoader.startScan(
          providers: providersNeedingScan,
          initialResults: cached.cachedProviderResults,
          unifiedMediaIdentity: identity,
          maxConcurrency: 3,
          load: (provider) => ProviderLoader.loadTVFromProvider(
            provider: provider,
            tvId: widget.metadata.tvId!,
            seasonNumber: widget.metadata.seasonNumber!,
            episodeNumber: widget.metadata.episodeNumber!,
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
      load: (provider) => ProviderLoader.loadTVFromProvider(
        provider: provider,
        tvId: widget.metadata.tvId!,
        seasonNumber: widget.metadata.seasonNumber!,
        episodeNumber: widget.metadata.episodeNumber!,
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
          '[TVVideoLoader] Request provider=${provider.displayName} '
          '(${provider.codeName}), tmdbId=${widget.metadata.tvId}, '
          'season=${widget.metadata.seasonNumber}, episode=${widget.metadata.episodeNumber}',
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
          mediaType: 'tv',
          contentId: widget.metadata.tvId,
          contentTitle: widget.metadata.seriesName,
          provider: provider.displayName,
          purpose: widget.download ? 'download' : 'playback',
          success: providerSucceeded,
          durationMs: durationMs,
          sourceCount: result.videoLinks?.length ?? 0,
          subtitleCount: result.subtitleLinks?.length ?? 0,
          error: ProviderLoader.sanitizeDiagnosticError(result.errorMessage),
        );
        debugPrint(
          '[TVVideoLoader] Response provider=${provider.displayName} '
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
        mediaType: 'tv',
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
    final subtitleTrack = _preferredSubtitle(subtitles);
    final posterPath = widget.metadata.posterPath;
    final quality = selected.qualityLabel;
    final maxHeight = selected.height ?? selected.adaptiveTargetHeight;
    final audioSelection = await DownloadSelectionSheets.chooseAudio(
      context,
      tracks: OfflineDownloadService.instance.getAudioTracks(
        url: url,
        format: format,
        headers: headers,
        maxVideoHeight: maxHeight,
      ),
    );
    if (!mounted) return;
    if (audioSelection == null) {
      Navigator.pop(context, false);
      return;
    }
    final season = widget.metadata.seasonNumber ?? 0;
    final episode = widget.metadata.episodeNumber ?? 0;
    try {
      await context.read<OfflineDownloadProvider>().enqueue(
        OfflineDownloadRequest(
          id: 'tv_${widget.metadata.tvId}_s${season}_e${episode}',
          url: url,
          format: format,
          title: widget.metadata.seriesName ?? 'TV episode',
          subtitle:
              'S${season.toString().padLeft(2, '0')} • E${episode.toString().padLeft(2, '0')} ${widget.metadata.episodeName ?? ''}',
          mediaType: 'episode',
          quality: quality,
          posterUrl: posterPath == null
              ? null
              : '$TMDB_BASE_IMAGE_URLw500$posterPath',
          maxVideoHeight: maxHeight,
          headers: headers,
          audioTrack: audioSelection.track,
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
          contentId: widget.metadata.tvId,
          seasonNumber: season,
          episodeNumber: episode,
          subtitleTrackUrl: subtitleTrack?.url,
          subtitleTrackName: subtitleTrack?.language,
          subtitleTrackHeaders: subtitleTrack?.headers ?? const {},
        ),
      );
      onSelected?.call(selected);
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'tv',
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
        mediaType: 'tv',
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
              title: widget.metadata.seriesName ?? 'This episode',
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
    final downloadLinks = tvVideoLinks ?? const <RegularVideoLinks>[];
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
            : 'download:tv');
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
        mediaType: 'tv',
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
    final season = widget.metadata.seasonNumber ?? 0;
    final episode = widget.metadata.episodeNumber ?? 0;
    final subtitleTrack = _preferredSubtitle(tvVideoSubs);
    try {
      final audioSelection = await DownloadSelectionSheets.chooseAudio(
        context,
        tracks: OfflineDownloadService.instance.getAudioTracks(
          url: url,
          format: format,
          headers: headers,
          maxVideoHeight: maxHeight,
        ),
      );
      if (!mounted) return;
      if (audioSelection == null) {
        Navigator.pop(context, false);
        return;
      }
      await context.read<OfflineDownloadProvider>().enqueue(
        OfflineDownloadRequest(
          id: 'tv_${widget.metadata.tvId}_s${season}_e$episode',
          url: url,
          format: format,
          title: widget.metadata.seriesName ?? 'TV episode',
          subtitle:
              'S${season.toString().padLeft(2, '0')} • E${episode.toString().padLeft(2, '0')} '
              '${widget.metadata.episodeName ?? ''} • ${selected.sourceDisplayName}',
          mediaType: 'episode',
          quality: selected.qualityLabel,
          posterUrl: widget.metadata.posterPath == null
              ? null
              : '${TMDB_BASE_IMAGE_URL}w500${widget.metadata.posterPath}',
          maxVideoHeight: maxHeight,
          headers: headers,
          audioTrack: audioSelection.track,
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
          contentId: widget.metadata.tvId,
          seasonNumber: season,
          episodeNumber: episode,
          subtitleTrackUrl: subtitleTrack?.url,
          subtitleTrackName: subtitleTrack?.language,
          subtitleTrackHeaders: subtitleTrack?.headers ?? const {},
        ),
      );
      settings.analytics.trackDownload(
        action: 'enqueue',
        mediaType: 'tv',
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
        mediaType: 'tv',
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
              title: widget.metadata.seriesName ?? 'This episode',
            ),
          ),
        ),
      );
      Navigator.pop(context, false);
    }
  }

  RegularSubtitleLinks? _preferredSubtitle(
    List<RegularSubtitleLinks>? subtitles,
  ) {
    if (subtitles == null || subtitles.isEmpty) return null;
    final preferred = settings.defaultSubtitleLanguage.toLowerCase();
    for (final subtitle in subtitles) {
      final language = subtitle.language?.toLowerCase() ?? '';
      if (subtitle.url?.isNotEmpty == true &&
          preferred.isNotEmpty &&
          (language == preferred ||
              language.startsWith(preferred) ||
              (preferred == 'en' && language.startsWith('english')))) {
        return subtitle;
      }
    }
    return subtitles.cast<RegularSubtitleLinks?>().firstWhere(
      (subtitle) => subtitle?.url?.isNotEmpty == true,
      orElse: () => null,
    );
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

  void getAppLanguage() {
    for (int i = 0; i < supportedLanguages.length; i++) {
      if (supportedLanguages[i].languageCode ==
          settings.defaultSubtitleLanguage) {
        foundIndex = i;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final season = widget.metadata.seasonNumber;
    final episode = widget.metadata.episodeNumber;
    final contextLine = <String>[
      if (widget.download) tr('download'),
      if (season != null && episode != null) 'S$season:E$episode',
      if (widget.metadata.episodeName?.trim().isNotEmpty == true)
        widget.metadata.episodeName!.trim(),
    ].join('  ·  ');
    return PlaybackLoadingScreen(
      title: widget.metadata.seriesName?.trim().isNotEmpty == true
          ? widget.metadata.seriesName!.trim()
          : widget.metadata.episodeName?.trim() ?? '',
      subtitle: contextLine,
      backdropPath: widget.metadata.backdropPath,
      posterPath: widget.metadata.posterPath,
      providers: providerStates,
      currentProviderIndex: currentProviderIndex,
    );
  }

  Future<void> _fetchSeasonEpisodes() async {
    try {
      if (widget.metadata.tvId != null &&
          widget.metadata.seasonNumber != null) {
        final isProxyEnabled = Provider.of<SettingsProvider>(
          context,
          listen: false,
        ).enableProxy;
        final proxyUrl = Provider.of<AppDependencyProvider>(
          context,
          listen: false,
        ).tmdbProxy;

        if (widget.metadata.allSeasons?.isNotEmpty != true) {
          final tvDetails = await fetchTVDetails(
            Endpoints.tvDetailsUrl(widget.metadata.tvId!, settings.appLanguage),
            isProxyEnabled,
            proxyUrl,
          );
          if (tvDetails.seasons?.isNotEmpty == true) {
            widget.metadata.allSeasons = tvDetails.seasons!
                .map((season) => SeasonMetadata.fromSeason(season))
                .toList();
          }
        }

        final selectedSeason = widget.metadata.seasonNumber!;
        final hasSelectedSeasonEpisodes =
            widget.metadata.seasonEpisodes?.isNotEmpty == true &&
            widget.metadata.seasonEpisodes!.every(
              (episode) => episode.seasonNumber == selectedSeason,
            );
        if (!hasSelectedSeasonEpisodes) {
          final seasonDetails = await fetchTVDetails(
            Endpoints.getSeasonDetails(
              widget.metadata.tvId!,
              selectedSeason,
              settings.appLanguage,
            ),
            isProxyEnabled,
            proxyUrl,
          );
          if (seasonDetails.episodes?.isNotEmpty == true) {
            widget.metadata.seasonEpisodes = seasonDetails.episodes!
                .map(
                  (episode) => EpisodeMetadata(
                    episodeId: episode.episodeId ?? 0,
                    episodeName:
                        episode.name ?? 'Episode ${episode.episodeNumber}',
                    episodeNumber: episode.episodeNumber ?? 0,
                    seasonNumber: selectedSeason,
                    stillPath: episode.stillPath,
                    airDate: episode.airDate,
                    runtime: null,
                    overview: episode.overview,
                    voteAverage: episode.voteAverage,
                  ),
                )
                .toList();
          }
        }

        // Set the season change callback
        widget.metadata.onSeasonChange = (int seasonNumber) async {
          // This will be called from the player when user changes season
          // We don't need to implement the fetch here, it's handled in the player
        };
      }
    } catch (e) {
      // If fetching episodes fails, continue without them
      debugPrint('Failed to fetch season episodes: $e');
    }
  }
}
