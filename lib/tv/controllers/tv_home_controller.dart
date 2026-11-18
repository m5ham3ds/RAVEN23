import '../../api/endpoints.dart';
import '../../catalog/catalog_controller.dart';
import '../../functions/network.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../models/tv_media_item.dart';

class TvHomeData {
  const TvHomeData({
    required this.popularMovies,
    required this.trendingMovies,
    required this.popularSeries,
    required this.trendingSeries,
    this.topMovies = const <TvMediaItem>[],
    this.topSeries = const <TvMediaItem>[],
    this.trendingAnime = const <TvMediaItem>[],
    this.popularAnime = const <TvMediaItem>[],
    this.newEpisodesSeries = const <TvMediaItem>[],
    this.newEpisodesAnime = const <TvMediaItem>[],
  });

  final List<TvMediaItem> popularMovies;
  final List<TvMediaItem> trendingMovies;
  final List<TvMediaItem> popularSeries;
  final List<TvMediaItem> trendingSeries;

  /// Today's ten most watched, for the Top 10 rows.
  final List<TvMediaItem> topMovies;
  final List<TvMediaItem> topSeries;
  final List<TvMediaItem> trendingAnime;
  final List<TvMediaItem> popularAnime;
  final List<TvMediaItem> newEpisodesSeries;
  final List<TvMediaItem> newEpisodesAnime;

  TvMediaItem? get hero {
    if (trendingMovies.isNotEmpty) return trendingMovies.first;
    if (trendingSeries.isNotEmpty) return trendingSeries.first;
    if (trendingAnime.isNotEmpty) return trendingAnime.first;
    if (popularAnime.isNotEmpty) return popularAnime.first;
    if (newEpisodesAnime.isNotEmpty) return newEpisodesAnime.first;
    if (popularMovies.isNotEmpty) return popularMovies.first;
    if (popularSeries.isNotEmpty) return popularSeries.first;
    return null;
  }

  bool get isEmpty =>
      popularMovies.isEmpty &&
      trendingMovies.isEmpty &&
      popularSeries.isEmpty &&
      trendingSeries.isEmpty &&
      trendingAnime.isEmpty &&
      popularAnime.isEmpty &&
      newEpisodesSeries.isEmpty &&
      newEpisodesAnime.isEmpty;
}

class TvHomeController {
  const TvHomeController();

  Future<TvHomeData> load({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final language = settings.appLanguage;
    final proxy = settings.enableProxy;
    final tmdbProxy = dependencies.tmdbProxy;
    String url(TvMediaKind kind, CatalogList list) =>
        CatalogController.listUrl(kind, list, language);

    Future<List<T>> safe<T>(Future<List<T>> future) async {
      try {
        return await future;
      } catch (_) {
        return <T>[];
      }
    }

    Future<List<TvMediaItem>> tvItems(String requestUrl) async =>
        (await safe(fetchTV(requestUrl, proxy, tmdbProxy)))
            .map(TvMediaItem.fromSeries)
            .toList(growable: false);

    final trendingSeriesFuture = tvItems(
      url(TvMediaKind.series, CatalogList.trendingWeek),
    );
    final popularSeriesFuture = tvItems(
      url(TvMediaKind.series, CatalogList.popular),
    );
    // loadTrendingAnimePage already returns catalog MediaItems. TvMediaItem
    // is a type alias for MediaItem, so converting these again through
    // fromSeries (which expects a TV model) is both unnecessary and invalid.
    final Future<List<TvMediaItem>> trendingAnimeFuture =
        CatalogController().loadTrendingAnimePage(
      page: 1,
      settings: settings,
      dependencies: dependencies,
    );
    final popularAnimeFuture = tvItems(Endpoints.popularAnimeTVUrl(
      language,
      includeAdult: settings.isAdult,
    ));
    final onTheAirFuture = tvItems(Endpoints.onTheAirUrl(language));
    final newEpisodesAnimeFuture = tvItems(Endpoints.newEpisodesAnimeTVUrl(
      language,
      DateTime.now(),
      includeAdult: settings.isAdult,
    ));
    final trendingTodayFuture = tvItems(
      url(TvMediaKind.series, CatalogList.trendingToday),
    );

    final popularMoviesFuture = safe(fetchMovies(
      url(TvMediaKind.movie, CatalogList.popular),
      proxy,
      tmdbProxy,
    ));
    final trendingMoviesFuture = safe(fetchMovies(
      url(TvMediaKind.movie, CatalogList.trendingWeek),
      proxy,
      tmdbProxy,
    ));
    final topMoviesFuture = safe(fetchMovies(
      url(TvMediaKind.movie, CatalogList.trendingToday),
      proxy,
      tmdbProxy,
    )).then(
      (items) => items.take(10).map(TvMediaItem.fromMovie).toList(),
    );

    final results = await Future.wait<List<TvMediaItem>>([
      trendingSeriesFuture,
      popularSeriesFuture,
      popularAnimeFuture,
      onTheAirFuture,
      newEpisodesAnimeFuture,
      trendingTodayFuture,
    ]);
    final trendingSeriesAll = results[0];
    final popularSeriesAll = results[1];
    final popularAnime = results[2].where(_isAnime).toList(growable: false);
    final airing = results[3];
    final newEpisodesAnime = results[4]
        .where(_isAnime)
        .toList(growable: false);
    final trendingToday = results[5];

    final List<TvMediaItem> trendingAnime = await trendingAnimeFuture;
    final regularTrending = trendingSeriesAll
        .where((item) => !_isAnime(item))
        .toList(growable: false);
    final regularPopular = popularSeriesAll
        .where((item) => !_isAnime(item))
        .toList(growable: false);
    final regularOnTheAir = airing
        .where((item) => !_isAnime(item))
        .toList(growable: false);

    return TvHomeData(
      popularMovies: (await popularMoviesFuture)
          .map(TvMediaItem.fromMovie)
          .toList(growable: false),
      trendingMovies: (await trendingMoviesFuture)
          .map(TvMediaItem.fromMovie)
          .toList(growable: false),
      popularSeries: regularPopular,
      trendingSeries: regularTrending,
      topMovies: (await topMoviesFuture).take(10).toList(growable: false),
      topSeries: trendingToday
          .where((item) => !_isAnime(item))
          .take(10)
          .toList(growable: false),
      trendingAnime: trendingAnime,
      popularAnime: popularAnime,
      newEpisodesSeries: regularOnTheAir,
      newEpisodesAnime: newEpisodesAnime,
    );
  }

  static bool _isAnime(TvMediaItem item) =>
      item.series?.isLikelyAnime == true;

}
