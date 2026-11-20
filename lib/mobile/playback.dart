import 'package:raven23/services/adsterra_playback_ads_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../catalog/details_controller.dart';
import '../api/endpoints.dart';
import '../functions/network.dart';
import '../functions/offline_download_ids.dart';
import '../models/offline_download.dart';
import '../provider/offline_download_provider.dart';
import '../screens/common/offline_player_screen.dart';
import '../catalog/episode_choice.dart';
import '../catalog/media_item.dart';
import '../data/ads/content_ads.dart';
import '../catalog/up_next.dart';
import '../models/movie.dart';
import '../models/movie_stream_metadata.dart';
import '../models/recently_watched.dart';
import '../models/tv.dart';
import '../models/tv_stream_metadata.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/recently_watched_provider.dart';
import '../provider/settings_provider.dart';
import '../screens/movie/movie_detail.dart';
import '../screens/movie/movie_video_loader.dart';
import '../screens/tv/tv_detail.dart';
import '../screens/tv/tv_video_loader.dart';

/// Opening and playing titles from the phone's browse pages.
abstract final class MobilePlayback {
  /// Remote playback can be disabled without hiding completed local media.
  static bool canPlay(BuildContext context, [MediaItem? item]) {
    if (context.read<AppDependencyProvider?>()?.displayWatchNowButton ?? true) {
      return true;
    }
    if (item == null) return false;
    final downloads =
        context.read<OfflineDownloadProvider?>()?.downloads ??
        const <OfflineDownload>[];
    return item.kind == MediaKind.movie
        ? findCompletedOfflineDownload(downloads, movieOfflineDownloadId(item.id)) != null
        : latestCompletedEpisodeDownload(downloads, seriesId: item.id) != null;
  }

  /// Where [item] would pick up, from what the viewer has watched.
  static ResumePoint? resumeFor(BuildContext context, MediaItem item) {
    final recent = context.read<RecentProvider?>();
    if (recent == null) return null;
    return ResumePoint.forItem(
      item,
      movies: recent.movies,
      episodes: recent.episodes,
    );
  }

  static Future<void> openDetails(BuildContext context, MediaItem item) {
    final heroId = 'mobile-${item.stableId}';
    final Widget page = item.kind == MediaKind.movie
        ? MovieDetailPage(
            movie: item.movie ??
                Movie(
                  id: item.id,
                  title: item.title,
                  posterPath: item.posterPath,
                  backdropPath: item.backdropPath,
                  overview: item.overview,
                  releaseDate: item.releaseDate,
                  voteAverage: item.rating,
                ),
            heroId: heroId,
          )
        : TVDetailPage(
            tvSeries: item.series ??
                TV(
                  id: item.id,
                  name: item.title,
                  originalName: item.title,
                  posterPath: item.posterPath,
                  backdropPath: item.backdropPath,
                  overview: item.overview,
                  firstAirDate: item.releaseDate,
                  voteAverage: item.rating,
                ),
            heroId: heroId,
          );
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  /// Plays [item] from where the viewer is: a movie part way through, a
  /// series at its episode in progress or the next one, else from the start.
  /// Opens the details page instead when playing is turned off.
  /// [onReady] dismisses an originating sheet once preparation is complete;
  /// returning false cancels playback if that sheet has already been left.
  static Future<void> play(
    BuildContext context,
    MediaItem item, {
    bool Function()? onReady,
  }) async {
    if (!context.mounted) return;
    final recent = context.read<RecentProvider?>();
    final recentEpisodes = recent?.episodes ?? const <RecentEpisode>[];
    final downloads =
        context.read<OfflineDownloadProvider?>()?.downloads ??
        const <OfflineDownload>[];

    if (item.kind == MediaKind.movie) {
      final local = findCompletedOfflineDownload(downloads, movieOfflineDownloadId(item.id));
      if (local != null) {
        if (onReady?.call() == false || !context.mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => OfflinePlayerScreen(download: local),
          ),
        );
        return;
      }
    } else {
      final next = upNextFor(
        item,
        episodes: recentEpisodes,
        upNext: recent?.upNext ?? const <UpNext>[],
      );
      RecentEpisode? latestRecent = item.recentEpisode;
      if (latestRecent == null) {
        for (final candidate in recentEpisodes) {
          if (candidate.seriesId == item.id && !candidate.isDeleted) {
            latestRecent = candidate;
            break;
          }
        }
      }
      final targetSeason =
          next?.season ?? item.upNext?.season ?? latestRecent?.seasonNum;
      final targetEpisode =
          next?.episode ?? item.upNext?.episode ?? latestRecent?.episodeNum;
      final remoteEnabled =
          context.read<AppDependencyProvider?>()?.displayWatchNowButton ?? true;
      final exactLocal =
          targetSeason != null && targetEpisode != null
              ? findCompletedEpisodeDownload(
                  downloads,
                  seriesId: item.id,
                  seasonNumber: targetSeason,
                  episodeNumber: targetEpisode,
                )
              : null;
      final local = exactLocal ??
          ((!remoteEnabled || targetSeason == null || targetEpisode == null)
              ? latestCompletedEpisodeDownload(downloads, seriesId: item.id)
              : null);
      if (local != null) {
        if (onReady?.call() == false || !context.mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => OfflinePlayerScreen(download: local),
          ),
        );
        return;
      }
    }

    if (!canPlay(context, item)) {
      if (onReady?.call() == false || !context.mounted) return;
      return openDetails(context, item);
    }
    final resume = resumeFor(context, item);
    if (item.kind == MediaKind.movie) {
      return _playMovie(context, item,
          elapsed: resume?.elapsed, onReady: onReady);
    }
    final next = upNextFor(
      item,
      episodes: recentEpisodes,
      upNext: recent?.upNext ?? const <UpNext>[],
    );
    return _playSeries(context, item, next == null ? resume : null, next,
        onReady: onReady);
  }

  static Future<void> _playMovie(
    BuildContext context,
    MediaItem item, {
    int? elapsed,
    bool Function()? onReady,
  }) async {
    // The host must be current before presenting a before-loader ad.
    if (onReady?.call() == false) return;
    if (!await AdsterraPlaybackAdsService.instance
            .beforeLoader(context, content: AdContent.of(item)) ||
        !context.mounted) {
      return;
    }
    final movie = item.movie;
    MovieDetails? movieDetails;
    if (item.genreIds.isEmpty || movie?.originalLanguage == null) {
      try {
        final settings = context.read<SettingsProvider>();
        final dependencies = context.read<AppDependencyProvider>();
        movieDetails = await fetchMovieDetails(
          Endpoints.movieDetailsUrl(item.id, settings.appLanguage),
          settings.enableProxy,
          dependencies.tmdbProxy,
        );
      } catch (_) {}
    }
    if (!context.mounted) return;
    debugPrint(
      '[MovieRecommendationsDebug][MOBILE_PLAYBACK_PLAY] '
      'movieId=${item.id} title=${item.title} '
      'recommendationsProvided=false (fetched by MovieVideoLoader)',
    );
    final metadata = MovieStreamMetadata(
      backdropPath: item.backdropPath,
      elapsed: elapsed,
      movieId: item.id,
      movieName: item.title,
      posterPath: item.posterPath,
      releaseYear:
          int.tryParse(item.year ?? '') ?? item.recentMovie?.releaseYear ?? 0,
      isAdult: movie?.adult,
      releaseDate: item.releaseDate ?? movie?.releaseDate,
      genreIds: item.genreIds.isNotEmpty
          ? item.genreIds
          : movieDetails?.genreIds,
      originalLanguage: movie?.originalLanguage ?? movieDetails?.originalLanguage,
      isAnime: movieDetails?.isLikelyAnime == true,
    );
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MovieVideoLoader(
          download: false,
          metadata: metadata,
        ),
      ),
    );
  }

  static Future<void> _playSeries(
    BuildContext context,
    MediaItem item,
    ResumePoint? resume,
    UpNext? upNext, {
    bool Function()? onReady,
  }) async {
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();
    const controller = MediaDetailsController();
    try {
      final details = await controller.load(
        item: item,
        settings: settings,
        dependencies: dependencies,
      );
      final choice = await chooseEpisode(
        seasons: details.seasons,
        resume: resume,
        upNext: upNext,
        loadSeason: (season) => controller.loadSeason(
          seriesId: item.id,
          seasonNumber: season,
          settings: settings,
          dependencies: dependencies,
        ),
      );
      if (choice == null || !context.mounted) return;
      if (onReady?.call() == false) return;
      final local = context
          .read<OfflineDownloadProvider?>()
          ?.downloadForId(episodeOfflineDownloadId(
            item.id,
            choice.episode.seasonNumber,
            choice.episode.episodeNumber,
          ));
      if (local?.isComplete == true) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => OfflinePlayerScreen(download: local!),
          ),
        );
        return;
      }
      if (!await AdsterraPlaybackAdsService.instance
              .beforeLoader(context, content: AdContent.of(item)) ||
          !context.mounted) {
        return;
      }
      final episode = choice.episode;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TVVideoLoader(
            download: false,
            metadata: TVStreamMetadata(
              elapsed: choice.elapsed,
              episodeId: episode.episodeId,
              episodeName: episode.name,
              episodeNumber: episode.episodeNumber,
              posterPath: item.posterPath,
              backdropPath: episode.stillPath ?? item.backdropPath,
              seasonNumber: episode.seasonNumber,
              seriesName: item.title,
              tvId: item.id,
              airDate: episode.airDate,
              episodeRuntime: episode.runtime,
              seasonEpisodes: choice.seasonEpisodes
                  .where((episode) => episode.episodeId != null)
                  .map(EpisodeMetadata.fromEpisodeList)
                  .toList(growable: false),
              isAnime: item.series?.isLikelyAnime == true ||
                  details.seriesDetails?.isLikelyAnime == true,
              genreIds: item.genreIds.isNotEmpty
                  ? item.genreIds
                  : details.seriesDetails?.genreIds,
              allSeasons: details.seriesDetails?.seasons
                  ?.where((season) => season.seasonNumber != null)
                  .map(SeasonMetadata.fromSeason)
                  .toList(growable: false),
            ),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('episodes_load_failed'))),
        );
      }
    }
  }
}
