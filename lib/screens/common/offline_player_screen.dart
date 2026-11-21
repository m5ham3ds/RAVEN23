import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/movie_stream_metadata.dart';
import '../../models/offline_download.dart';
import '../../models/tv_stream_metadata.dart';
import '../../provider/offline_download_provider.dart';
import '../../provider/settings_provider.dart';
import 'player.dart';

/// Offline playback is deliberately routed through PlayerOne. The only
/// source passed to BetterPlayer is the validated, app-private local MP4
/// prepared from the completed Media3 cache.
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
  bool _started = false;
  bool _preparing = true;
  String? _localPath;
  String? _error;

  bool get _isMovie => widget.download.mediaType == 'movie';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_prepareLocalFile());
  }

  Future<void> _prepareLocalFile() async {
    try {
      final downloads = context.read<OfflineDownloadProvider>();
      await downloads.refresh();
      if (!mounted) return;
      final path = await downloads.prepareForPlayback(widget.download.id);
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _preparing = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _error = error.toString();
      });
    }
  }

  List<OfflineDownload> _seasonDownloads() {
    final all = context.read<OfflineDownloadProvider>().downloads;
    final current = widget.download;
    final episodes = all.where((item) {
      if (!item.isComplete || item.mediaType == 'movie') return false;
      if (item.id == current.id) return true;
      return current.contentId != null &&
          item.contentId == current.contentId &&
          item.seasonNumber == current.seasonNumber;
    }).toList()
      ..sort((a, b) =>
          (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));
    return episodes;
  }

  TVStreamMetadata _tvMetadata() {
    final episodes = _seasonDownloads();
    final season = widget.download.seasonNumber ?? 0;
    final mappedEpisodes = episodes
        .where((item) => item.episodeNumber != null)
        .map(
          (item) => EpisodeMetadata(
            // The offline switch callback resolves by season/episode number;
            // this id is only a local menu identity, not an online TMDB id.
            episodeId: item.episodeNumber!,
            episodeName: item.subtitle?.trim().isNotEmpty == true
                ? item.subtitle!.trim()
                : 'Episode ${item.episodeNumber}',
            episodeNumber: item.episodeNumber!,
            seasonNumber: item.seasonNumber ?? season,
          ),
        )
        .toList(growable: false);
    final currentNumber = widget.download.episodeNumber ?? 0;
    final currentName = widget.download.subtitle?.trim().isNotEmpty == true
        ? widget.download.subtitle!.trim()
        : 'Episode $currentNumber';
    return TVStreamMetadata(
      elapsed: 0,
      episodeId: currentNumber,
      episodeName: currentName,
      episodeNumber: currentNumber,
      posterPath: null,
      backdropPath: null,
      seasonNumber: season,
      seriesName: widget.download.title,
      tvId: widget.download.contentId,
      airDate: null,
      episodeRuntime: widget.download.expectedDurationMs == null
          ? null
          : (widget.download.expectedDurationMs! / 60000).round(),
      seasonEpisodes: mappedEpisodes,
      allSeasons: <SeasonMetadata>[
        SeasonMetadata(
          seasonNumber: season,
          seasonName: 'Season $season',
          episodeCount: mappedEpisodes.length,
        ),
      ],
    );
  }

  MovieStreamMetadata _movieMetadata() => MovieStreamMetadata(
        backdropPath: null,
        elapsed: 0,
        movieId: widget.download.contentId,
        movieName: widget.download.title,
        posterPath: null,
        releaseYear: null,
        isAdult: false,
        releaseDate: null,
        runtime: widget.download.expectedDurationMs == null
            ? null
            : (widget.download.expectedDurationMs! / 60000).round(),
      );

  Future<void> _playDownloadedEpisode(EpisodeMetadata episode) async {
    final downloads = context.read<OfflineDownloadProvider>();
    await downloads.refresh();
    if (!mounted) return;
    OfflineDownload? target;
    for (final item in downloads.downloads) {
      if (item.isComplete &&
          item.mediaType != 'movie' &&
          item.contentId == widget.download.contentId &&
          item.seasonNumber == episode.seasonNumber &&
          item.episodeNumber == episode.episodeNumber) {
        target = item;
        break;
      }
    }
    if (target == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('This episode is no longer available offline.')),
      );
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflinePlayerScreen(download: target!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = _localPath;
    if (path != null) {
      final settings = context.read<SettingsProvider>();
      final accent = Theme.of(context).colorScheme.primary;
      return PlayerOne(
        sources: const <String, String>{},
        subs: const [],
        colors: <Color>[accent],
        settings: settings,
        movieMetadata: _isMovie ? _movieMetadata() : null,
        tvMetadata: _isMovie ? null : _tvMetadata(),
        mediaType: _isMovie ? MediaType.movie : MediaType.tvShow,
        subtitleStyle: settings.subtitleTextStyle,
        offlineDownload: widget.download,
        offlineFilePath: path,
        onOfflineEpisodeSelected: _isMovie ? null : _playDownloadedEpisode,
      );
    }

    final export = context.watch<OfflineDownloadProvider>()
        .exportFor(widget.download.id);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_preparing) ...[
                  const SizedBox.square(
                    dimension: 34,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    export?.state == 'queued'
                        ? 'Queued for offline preparation'
                        : export?.progress == null
                            ? tr('preparing_offline_video')
                            : 'Preparing offline video ${export!.progress}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (export?.progress != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 240,
                      child: LinearProgressIndicator(
                        value: export!.progress! / 100,
                        minHeight: 3,
                      ),
                    ),
                  ],
                ] else ...[
                  const Icon(Icons.error_outline, color: Colors.white70, size: 42),
                  const SizedBox(height: 14),
                  Text(
                    _error ?? tr('offline_play_failed_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _started = true;
                        _preparing = true;
                        _error = null;
                      });
                      unawaited(_prepareLocalFile());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
