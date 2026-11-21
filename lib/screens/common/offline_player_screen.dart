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
  int? _browsedSeasonNumber;

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

  List<OfflineDownload> _seriesDownloads() {
    final all = context.read<OfflineDownloadProvider>().downloads;
    final current = widget.download;
    return all.where((item) {
      if (!item.isComplete || item.mediaType == 'movie') return false;
      if (current.contentId == null) return item.id == current.id;
      return item.contentId == current.contentId;
    }).toList()
      ..sort((a, b) {
        final season = (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
        if (season != 0) return season;
        return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
      });
  }

  List<OfflineDownload> _seasonDownloads([int? requestedSeason]) {
    final season = requestedSeason ??
        _browsedSeasonNumber ??
        widget.download.seasonNumber ??
        0;
    return _seriesDownloads()
        .where((item) => (item.seasonNumber ?? 0) == season)
        .toList(growable: false);
  }

  int? _intValue(Map<String, Object?>? row, String key) {
    final value = row?[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  num? _numValue(Map<String, Object?>? row, String key) {
    final value = row?[key];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  String? _stringValue(Map<String, Object?>? row, String key) =>
      row?[key]?.toString();

  String? _posterPathFromUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final segments = Uri.tryParse(value)?.pathSegments;
    if (segments == null) return null;
    final sizeIndex = segments.lastIndexWhere(
      (segment) => RegExp(r'^w\d+$').hasMatch(segment),
    );
    if (sizeIndex < 0 || sizeIndex + 1 >= segments.length) return null;
    return '/${segments.skip(sizeIndex + 1).join('/')}';
  }
  EpisodeMetadata _episodeMetadata(OfflineDownload item) {
    final number = item.episodeNumber ?? 0;
    final season = item.seasonNumber ?? 0;
    final rows = item.seasonEpisodes.where(
      (row) =>
          _intValue(row, 'episodeNumber') == number &&
          _intValue(row, 'seasonNumber') == season,
    );
    final row = rows.isEmpty ? null : rows.first;
    final savedName = _stringValue(row, 'episodeName')?.trim();
    final fallbackParts = (item.subtitle ?? '').split(' • ');
    final fallbackName = fallbackParts.length > 1
        ? fallbackParts[1].replaceFirst(RegExp(r'^E\d+\s*'), '').trim()
        : '';
    return EpisodeMetadata(
      episodeId: _intValue(row, 'episodeId') ?? 0,
      episodeName: savedName?.isNotEmpty == true
          ? savedName!
          : (fallbackName.isNotEmpty ? fallbackName : 'Episode $number'),
      episodeNumber: number,
      seasonNumber: season,
      stillPath: _stringValue(row, 'stillPath') ??
          item.seriesBackdropPath ??
          item.seriesPosterPath ??
          _posterPathFromUrl(item.posterUrl),
      airDate: _stringValue(row, 'airDate'),
      runtime: _intValue(row, 'runtime') ??
          (item.expectedDurationMs == null
              ? null
              : (item.expectedDurationMs! / 60000).round()),
      overview: _stringValue(row, 'overview'),
      voteAverage: _numValue(row, 'voteAverage'),
    );
  }

  TVStreamMetadata _tvMetadata() {
    final season = _browsedSeasonNumber ??
        widget.download.seasonNumber ??
        0;
    final downloadedSeries = _seriesDownloads();
    final mappedEpisodes = _seasonDownloads(season)
        .where((item) => item.episodeNumber != null)
        .map(_episodeMetadata)
        .toList(growable: false);
    final seasonNumbers = downloadedSeries
        .map((item) => item.seasonNumber ?? 0)
        .toSet()
        .toList()
      ..sort();
    final allSeasons = seasonNumbers.map((seasonNumber) {
      final episodeInSeason = downloadedSeries.firstWhere(
        (item) => (item.seasonNumber ?? 0) == seasonNumber,
      );
      final candidates = episodeInSeason.allSeasons.where(
        (row) => _intValue(row, 'seasonNumber') == seasonNumber,
      );
      final row = candidates.isEmpty ? null : candidates.first;
      final episodeCount = downloadedSeries
          .where((item) => (item.seasonNumber ?? 0) == seasonNumber)
          .length;
      return SeasonMetadata(
        seasonNumber: seasonNumber,
        seasonName: _stringValue(row, 'seasonName') ?? 'Season $seasonNumber',
        episodeCount: episodeCount,
        posterPath: _stringValue(row, 'posterPath'),
        overview: _stringValue(row, 'overview'),
      );
    }).toList(growable: false);
    final currentNumber = widget.download.episodeNumber ?? 0;
    final currentName = mappedEpisodes
            .where((item) => item.episodeNumber == currentNumber)
            .map((item) => item.episodeName)
            .firstOrNull ??
        'Episode $currentNumber';
    final metadata = TVStreamMetadata(
      elapsed: 0,
      episodeId: currentNumber,
      episodeName: currentName,
      episodeNumber: currentNumber,
      posterPath: widget.download.seriesPosterPath,
      backdropPath: widget.download.seriesBackdropPath,
      seasonNumber: widget.download.seasonNumber ?? 0,
      seriesName: widget.download.title,
      tvId: widget.download.contentId,
      airDate: null,
      episodeRuntime: widget.download.expectedDurationMs == null
          ? null
          : (widget.download.expectedDurationMs! / 60000).round(),
      seasonEpisodes: mappedEpisodes,
      allSeasons: allSeasons,
    );
    metadata.onSeasonChange = (seasonNumber) {
      metadata.seasonEpisodes = _seasonDownloads(seasonNumber)
          .where((item) => item.episodeNumber != null)
          .map(_episodeMetadata)
          .toList(growable: false);
    };
    return metadata;
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
