import 'package:easy_localization/easy_localization.dart';
import '../api/endpoints.dart';
import '../data/ads/content_ads.dart';
import '../controllers/bookmark_database_controller.dart';
import '../functions/network.dart';
import '../models/genres.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../widgets/common_widgets.dart'
    show AppStreamingService, appStreamingServices;
import 'media_item.dart';

/// The TMDB lists behind a Movies or Series page's rows, and TV Home's.
enum CatalogList {
  /// Today's most watched, for the Top 10.
  trendingToday,
  trendingWeek,
  popular,
  topRated,

  /// Upcoming movies, or series with new episodes on the air.
  fresh,
}

/// A streaming service's most popular titles, for its row on a catalog page.
class ServiceShelf {
  const ServiceShelf({required this.service, required this.items});

  final AppStreamingService service;
  final List<MediaItem> items;
}

/// Everything a Movies or Series page shows, fetched together.
class CatalogData {
  const CatalogData({
    required this.kind,
    required this.topTen,
    required this.trending,
    required this.popular,
    required this.topRated,
    required this.fresh,
    required this.serviceShelves,
    required this.genres,
  });

  final MediaKind kind;

  /// Today's ten most watched.
  final List<MediaItem> topTen;
  final List<MediaItem> trending;
  final List<MediaItem> popular;
  final List<MediaItem> topRated;

  /// Upcoming movies, or series with new episodes on the air.
  final List<MediaItem> fresh;
  final List<ServiceShelf> serviceShelves;
  final List<Genres> genres;

  MediaItem? get featured => trending.isNotEmpty
      ? trending.first
      : popular.isNotEmpty
      ? popular.first
      : null;
}

/// A catalog opened from a shortcut tile, loaded a page at a time.
class MediaCollection {
  const MediaCollection({
    required this.id,
    required this.title,
    required this.kicker,
    required this.loadPage,
    this.logoAsset,
    this.adPlacement,
    this.adFree = false,
  });

  final String id;
  final String title;

  /// The hosted ad placement the collection's page reports, if it shows one.
  final String? adPlacement;

  /// A Kids or Family genre: its page shows no ads, Plus or not.
  final bool adFree;

  /// What kind of collection it is, shown above the title.
  final String kicker;
  final String? logoAsset;

  /// Loads the 1-based [page]; an empty page means the collection has ended.
  final Future<List<MediaItem>> Function(int page) loadPage;
}

/// What Search shows before anything is typed.
class SearchSuggestions {
  const SearchSuggestions({
    required this.topSearches,
    required this.movieGenres,
    required this.seriesGenres,
    required this.animeGenres,
  });

  static const empty = SearchSuggestions(
    topSearches: <MediaItem>[],
    movieGenres: <Genres>[],
    seriesGenres: <Genres>[],
    animeGenres: <Genres>[],
  );

  /// Today's most watched, movies and series in turn.
  final List<MediaItem> topSearches;
  final List<Genres> movieGenres;
  final List<Genres> seriesGenres;
  final List<Genres> animeGenres;
}

class CatalogController {
  const CatalogController();

  /// TMDB TV genres that are meaningful facets for Japanese animation.
  /// General broadcast genres (news, reality, talk, soap) are intentionally
  /// omitted from the Anime genres section.
  static const Set<int> animeGenreIds = <int>{
    // Animation (16) is already mandatory for every anime request; only
    // secondary genres belong in the Anime genres picker.
    10759, // Action & Adventure
    35, // Comedy
    80, // Crime
    99, // Documentary
    18, // Drama
    10751, // Family
    10762, // Kids
    9648, // Mystery
    10765, // Sci-Fi & Fantasy
    10768, // War & Politics
    37, // Western
  };

  /// Each part fails on its own, so a missing one leaves the rest standing.
  Future<SearchSuggestions> loadSearchSuggestions({
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final language = settings.appLanguage;
    List<Genres> named(List<Genres> genres) => genres
        .where((genre) => genre.genreID != null && genre.genreName != null)
        .toList(growable: false);
    final results = await Future.wait<Object>(<Future<Object>>[
      _fetch(
        MediaKind.movie,
        Endpoints.trendingMoviesTodayUrl(language),
        settings,
        dependencies,
      ),
      _fetch(
        MediaKind.series,
        Endpoints.trendingTVTodayUrl(language),
        settings,
        dependencies,
      ),
      _orEmpty(
        fetchGenre(
          Endpoints.movieGenresUrl(language),
          settings.enableProxy,
          dependencies.tmdbProxy,
        ),
      ),
      _orEmpty(
        fetchGenre(
          Endpoints.tvGenresUrl(language),
          settings.enableProxy,
          dependencies.tmdbProxy,
        ),
      ),
    ]);
    final movies = results[0] as List<MediaItem>;
    final series = results[1] as List<MediaItem>;
    final seriesGenres = named(results[3] as List<Genres>);
    return SearchSuggestions(
      topSearches: <MediaItem>[
        for (var i = 0; i < 5; i++) ...<MediaItem>[
          if (i < movies.length) movies[i],
          if (i < series.length) series[i],
        ],
      ].take(10).toList(growable: false),
      movieGenres: named(results[2] as List<Genres>),
      seriesGenres: seriesGenres,
      animeGenres: seriesGenres
          .where((genre) => animeGenreIds.contains(genre.genreID))
          .toList(growable: false),
    );
  }

  /// The services given their own row on each page, by TMDB provider id.
  static const _movieShelfProviders = <int>[8, 9, 337, 384];
  static const _seriesShelfProviders = <int>[8, 384, 9, 15];

  static const _rowLength = 20;

  /// TMDB serves no list or discover page past this one.
  static const _lastPage = 500;

  /// The TMDB list behind [list] for [kind], so a row and its See all read
  /// the same one.
  static String listUrl(MediaKind kind, CatalogList list, String language) {
    final isMovie = kind == MediaKind.movie;
    return switch (list) {
      CatalogList.trendingToday =>
        isMovie
            ? Endpoints.trendingMoviesTodayUrl(language)
            : Endpoints.trendingTVTodayUrl(language),
      CatalogList.trendingWeek =>
        isMovie
            ? Endpoints.trendingMoviesUrl(language)
            : Endpoints.trendingTVUrl(language),
      CatalogList.popular =>
        isMovie
            ? Endpoints.popularMoviesUrl(language)
            : Endpoints.popularTVUrl(language),
      CatalogList.topRated =>
        isMovie
            ? Endpoints.topRatedUrl(language)
            : Endpoints.topRatedTVUrl(language),
      CatalogList.fresh =>
        isMovie
            ? Endpoints.upcomingMoviesUrl(language)
            : Endpoints.onTheAirUrl(language),
    };
  }

  Future<CatalogData> loadCatalog({
    required MediaKind kind,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final language = settings.appLanguage;
    final isMovie = kind == MediaKind.movie;
    Future<List<MediaItem>> row(CatalogList list) async {
      final items = await _fetch(
        kind,
        listUrl(kind, list, language),
        settings,
        dependencies,
      );
      // The Series catalog is intentionally separate from the dedicated
      // Anime Home rows and Anime provider tabs.
      return kind == MediaKind.series
          ? items
                .where((item) => item.series?.isLikelyAnime != true)
                .toList(growable: false)
          : items;
    }

    final providers = (isMovie ? _movieShelfProviders : _seriesShelfProviders)
        .map(serviceFor)
        .whereType<AppStreamingService>()
        .toList(growable: false);
    final shelves = Future.wait(<Future<ServiceShelf>>[
      for (final service in providers)
        _fetch(
          kind,
          _serviceUrl(kind, service.providerId!, 1, language),
          settings,
          dependencies,
        ).then(
          (items) => ServiceShelf(
            service: service,
            items: kind == MediaKind.series
                ? items
                      .where((item) => item.series?.isLikelyAnime != true)
                      .toList(growable: false)
                : items,
          ),
        ),
    ]);
    final genres = _orEmpty(
      fetchGenre(
        isMovie
            ? Endpoints.movieGenresUrl(language)
            : Endpoints.tvGenresUrl(language),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ),
    );
    final lists = await Future.wait(<Future<List<MediaItem>>>[
      row(CatalogList.trendingWeek),
      row(CatalogList.popular),
      row(CatalogList.topRated),
      row(CatalogList.fresh),
      row(CatalogList.trendingToday),
    ]);
    return CatalogData(
      kind: kind,
      topTen: lists[4].take(10).toList(growable: false),
      trending: lists[0],
      popular: lists[1],
      topRated: lists[2],
      fresh: lists[3],
      serviceShelves: await shelves,
      genres: (await genres)
          .where((genre) => genre.genreID != null && genre.genreName != null)
          .toList(growable: false),
    );
  }

  MediaCollection serviceCollection({
    required MediaKind kind,
    required AppStreamingService service,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    bool animeOnly = false,
  }) {
    if (animeOnly && kind != MediaKind.series) {
      throw ArgumentError.value(
        kind,
        'kind',
        'Anime streaming collections are episodic TV',
      );
    }
    final serviceId = service.providerId?.toString() ?? service.stableKey;
    return MediaCollection(
      id: '${animeOnly ? 'anime' : kind.name}-service-$serviceId',
      title: service.name,
      kicker: animeOnly
          ? tr('anime')
          : !service.isWatchProvider
          ? tr('studio_or_network_catalog')
          : kind == MediaKind.movie
          ? tr('tv_movies_on_this_service')
          : tr('tv_series_on_this_service'),
      logoAsset: service.imagePath,
      loadPage: (page) => _fetchPage(
        page,
        () => service.isWatchProvider
            ? _fetch(
                kind,
                _serviceUrl(
                  kind,
                  service.providerId!,
                  page,
                  settings.appLanguage,
                  animeOnly: animeOnly,
                  includeAdult: settings.isAdult,
                ),
                settings,
                dependencies,
                strict: true,
              ).then(
                (items) => kind == MediaKind.series
                    ? items
                          .where(
                            (item) => animeOnly
                                ? item.series?.isLikelyAnime == true
                                : item.series?.isLikelyAnime != true,
                          )
                          .toList(growable: false)
                    : items,
              )
            : _brandServicePage(
                kind: kind,
                service: service,
                page: page,
                animeOnly: animeOnly,
                settings: settings,
                dependencies: dependencies,
              ),
      ),
    );
  }

  /// Fetches studio/network catalogs without confusing company/network ids
  /// with JustWatch watch-provider ids. Different TMDB source types are
  /// queried separately, then merged by title identity.
  Future<List<MediaItem>> _brandServicePage({
    required MediaKind kind,
    required AppStreamingService service,
    required int page,
    required bool animeOnly,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final urls = <String>[];
    if (kind == MediaKind.movie) {
      if (service.movieCompanyIds.isNotEmpty) {
        urls.add(
          Endpoints.productionCompanyMoviesUrl(
            service.movieCompanyIds,
            page,
            settings.appLanguage,
            includeAdult: settings.isAdult,
          ),
        );
      }
    } else {
      if (service.tvCompanyIds.isNotEmpty) {
        urls.add(
          Endpoints.productionCompanyTVUrl(
            service.tvCompanyIds,
            page,
            settings.appLanguage,
            includeAdult: settings.isAdult,
            animeOnly: animeOnly,
          ),
        );
      }
      for (final networkId in service.tvNetworkIds) {
        urls.add(
          Endpoints.televisionNetworkTVUrl(
            networkId,
            page,
            settings.appLanguage,
            includeAdult: settings.isAdult,
            animeOnly: animeOnly,
          ),
        );
      }
    }
    if (urls.isEmpty) return const <MediaItem>[];
    final results = await Future.wait<List<MediaItem>>([
      for (final url in urls)
        _orEmpty(_fetch(kind, url, settings, dependencies, strict: true)),
    ]);
    var merged = _unique(results.expand((items) => items));
    if (kind == MediaKind.series) {
      merged = merged
          .where(
            (item) => animeOnly
                ? item.series?.isLikelyAnime == true
                : item.series?.isLikelyAnime != true,
          )
          .toList(growable: false);
    }
    final sorted = List<MediaItem>.of(merged)
      ..sort((a, b) => (b.popularity ?? 0).compareTo(a.popularity ?? 0));
    return sorted.take(_rowLength).toList(growable: false);
  }

  MediaCollection genreCollection({
    required MediaKind kind,
    required Genres genre,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    bool animeOnly = false,
    bool excludeAnime = false,
  }) {
    if (animeOnly && kind != MediaKind.series) {
      throw ArgumentError.value(kind, 'kind', 'Anime genres are episodic TV');
    }
    if (animeOnly && excludeAnime) {
      throw ArgumentError(
        'A genre collection cannot include and exclude anime',
      );
    }
    final isMovie = kind == MediaKind.movie;
    return MediaCollection(
      id: '${animeOnly ? 'anime' : kind.name}-genre-${genre.genreID}',
      title: genre.genreName!,
      adFree: FamilyGenres.includes(
        series: !isMovie,
        genreIds: <int>[genre.genreID!],
      ),
      kicker: tr(
        animeOnly
            ? 'anime_genre'
            : isMovie
            ? 'tv_movie_genre'
            : 'tv_series_genre',
      ).toUpperCase(),
      loadPage: (page) => _fetchPage(
        page,
        () =>
            _fetch(
              kind,
              isMovie
                  ? Endpoints.getMoviesForGenre(
                      genre.genreID!,
                      page,
                      settings.appLanguage,
                    )
                  : animeOnly
                  ? Endpoints.getAnimeTVShowsForGenre(
                      genre.genreID!,
                      page,
                      settings.appLanguage,
                      includeAdult: settings.isAdult,
                    )
                  : Endpoints.getTVShowsForGenre(
                      genre.genreID!,
                      page,
                      settings.appLanguage,
                    ),
              settings,
              dependencies,
              strict: true,
            ).then((items) {
              if (kind != MediaKind.series || (!animeOnly && !excludeAnime)) {
                return items;
              }
              return items
                  .where(
                    (item) => animeOnly
                        ? item.series?.isLikelyAnime == true
                        : item.series?.isLikelyAnime != true,
                  )
                  .toList(growable: false);
            }),
      ),
    );
  }

  /// Any TMDB list of [kind] at [url], a page at a time.
  MediaCollection listCollection({
    required String id,
    required MediaKind kind,
    required String url,
    required String title,
    required String kicker,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    String? adPlacement,
    bool animeOnly = false,
    bool excludeAnime = false,
  }) {
    if (animeOnly && kind != MediaKind.series) {
      throw ArgumentError.value(
        kind,
        'kind',
        'Anime collections are episodic TV',
      );
    }
    if (animeOnly && excludeAnime) {
      throw ArgumentError('A collection cannot include and exclude anime');
    }
    return MediaCollection(
      id: id,
      title: title,
      kicker: kicker,
      adPlacement: adPlacement,
      loadPage: (page) => _fetchPage(page, () {
        final uri = Uri.parse(url);
        return _fetch(
          kind,
          uri
              .replace(
                queryParameters: <String, String>{
                  ...uri.queryParameters,
                  'page': '$page',
                },
              )
              .toString(),
          settings,
          dependencies,
          strict: true,
        ).then((items) {
          if (kind != MediaKind.series || (!animeOnly && !excludeAnime)) {
            return items;
          }
          return items
              .where(
                (item) => animeOnly
                    ? item.series?.isLikelyAnime == true
                    : item.series?.isLikelyAnime != true,
              )
              .toList(growable: false);
        });
      }),
    );
  }

  /// Loads one page of the current Anime chart. TMDB's global TV trend
  /// ranking is the primary source; popularity-ranked Japanese animation
  /// fills its remaining positions. Both are filtered by the Phase 11 anime
  /// identity rule and de-duplicated before returning.
  Future<List<MediaItem>> loadTrendingAnimePage({
    required int page,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    String pageUrl(String url) {
      final uri = Uri.parse(url);
      return uri
          .replace(
            queryParameters: <String, String>{
              ...uri.queryParameters,
              'page': '$page',
            },
          )
          .toString();
    }

    final results = await Future.wait<List<MediaItem>>([
      _orEmpty(
        _fetch(
          MediaKind.series,
          pageUrl(Endpoints.trendingTVUrl(settings.appLanguage)),
          settings,
          dependencies,
          strict: true,
        ),
      ),
      _orEmpty(
        _fetch(
          MediaKind.series,
          pageUrl(
            Endpoints.popularAnimeTVUrl(
              settings.appLanguage,
              includeAdult: settings.isAdult,
            ),
          ),
          settings,
          dependencies,
          strict: true,
        ),
      ),
    ]);
    final seen = <String>{};
    final combined = <MediaItem>[];
    for (final item in results.expand((items) => items)) {
      if (item.series?.isLikelyAnime == true &&
          (settings.isAdult || item.series?.adult != true) &&
          item.id >= 0 &&
          seen.add(item.stableId)) {
        combined.add(item);
      }
    }
    return combined.take(_rowLength).toList(growable: false);
  }

  /// A paginated, composite Anime chart for the Home row's See all action.
  MediaCollection trendingAnimeCollection({
    required String title,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) => MediaCollection(
    id: 'series-trending-anime',
    title: title,
    kicker: tr('anime').toUpperCase(),
    adPlacement: 'tv_list',
    loadPage: (page) => _fetchPage(
      page,
      () => loadTrendingAnimePage(
        page: page,
        settings: settings,
        dependencies: dependencies,
      ),
    ),
  );

  /// The whole of one of a catalog page's [list]s, from its row's See all.
  MediaCollection catalogListCollection({
    required MediaKind kind,
    required CatalogList list,
    required String title,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    bool excludeAnime = false,
  }) {
    return listCollection(
      id: '${kind.name}-${list.name}',
      kind: kind,
      url: listUrl(kind, list, settings.appLanguage),
      title: title,
      kicker: tr(kind == MediaKind.movie ? 'movies' : 'series').toUpperCase(),
      settings: settings,
      dependencies: dependencies,
      excludeAnime: excludeAnime,
    );
  }

  /// Past TMDB's last page a collection has ended, rather than failed.
  static Future<List<MediaItem>> _fetchPage(
    int page,
    Future<List<MediaItem>> Function() fetch,
  ) => page > _lastPage ? Future.value(const <MediaItem>[]) : fetch();

  /// One row from [url], empty if it fails.
  Future<List<MediaItem>> loadRow({
    required MediaKind kind,
    required String url,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    bool strict = false,
  }) => _fetch(kind, url, settings, dependencies, strict: strict);

  /// A watch-provider's Japanese-animation titles for the Anime Home row.
  /// This is deliberately separate from [loadServiceRow], whose Series
  /// results exclude anime and whose Movie results include normal animation.
  Future<List<MediaItem>> loadAnimeServiceRow({
    required int providerId,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final items = await _fetch(
      MediaKind.series,
      _serviceUrl(
        MediaKind.series,
        providerId,
        1,
        settings.appLanguage,
        animeOnly: true,
        includeAdult: settings.isAdult,
      ),
      settings,
      dependencies,
    );
    return items
        .where((item) => item.series?.isLikelyAnime == true)
        .toList(growable: false);
  }

  /// A service's most popular titles of [kind], empty if it fails.
  Future<List<MediaItem>> loadServiceRow({
    required MediaKind kind,
    required int providerId,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final items = await _fetch(
      kind,
      _serviceUrl(kind, providerId, 1, settings.appLanguage),
      settings,
      dependencies,
    );
    return kind == MediaKind.series
        ? items
              .where((item) => item.series?.isLikelyAnime != true)
              .toList(growable: false)
        : items;
  }

  /// The named genres of [kind], empty if they fail.
  Future<List<Genres>> loadGenres({
    required MediaKind kind,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final genres = await _orEmpty(
      fetchGenre(
        kind == MediaKind.movie
            ? Endpoints.movieGenresUrl(settings.appLanguage)
            : Endpoints.tvGenresUrl(settings.appLanguage),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ),
    );
    return genres
        .where((genre) => genre.genreID != null && genre.genreName != null)
        .toList(growable: false);
  }

  static AppStreamingService? serviceFor(int providerId) {
    for (final service in appStreamingServices) {
      if (service.providerId == providerId) return service;
    }
    return null;
  }

  static String _serviceUrl(
    MediaKind kind,
    int providerId,
    int page,
    String language, {
    bool animeOnly = false,
    bool includeAdult = false,
  }) {
    if (animeOnly) {
      if (kind != MediaKind.series) {
        throw ArgumentError.value(
          kind,
          'kind',
          'Anime streaming collections are episodic TV',
        );
      }
      return Endpoints.watchProvidersAnimeTVShows(
        providerId,
        page,
        language,
        includeAdult: includeAdult,
      );
    }
    return kind == MediaKind.movie
        ? Endpoints.watchProvidersMovies(providerId, page, language)
        : Endpoints.watchProvidersTVShows(providerId, page, language);
  }

  /// A page's rows fail on their own: a missing row leaves the rest of the
  /// page standing. A [strict] fetch lets the failure through, for a screen
  /// that has nothing else to show.
  Future<List<MediaItem>> _fetch(
    MediaKind kind,
    String url,
    SettingsProvider settings,
    AppDependencyProvider dependencies, {
    bool strict = false,
  }) async {
    final Future<List<MediaItem>> items = kind == MediaKind.movie
        ? fetchMovies(
            url,
            settings.enableProxy,
            dependencies.tmdbProxy,
          ).then((movies) => movies.map(MediaItem.fromMovie).toList())
        : fetchTV(
            url,
            settings.enableProxy,
            dependencies.tmdbProxy,
          ).then((series) => series.map(MediaItem.fromSeries).toList());
    final loaded = strict ? await items : await _orEmpty(items);
    return _unique(
      loaded,
    ).take(strict ? loaded.length : _rowLength).toList(growable: false);
  }

  static Future<List<T>> _orEmpty<T>(Future<List<T>> future) async {
    try {
      return await future;
    } catch (_) {
      return <T>[];
    }
  }

  Future<List<MediaItem>> search({
    required String query,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    final encodedQuery = Uri.encodeQueryComponent(query.trim());
    final results = await Future.wait<List<MediaItem>>([
      fetchMovies(
        Endpoints.movieSearchUrl(
          encodedQuery,
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ).then((items) => items.map(MediaItem.fromMovie).toList(growable: false)),
      fetchTV(
        Endpoints.tvSearchUrl(
          encodedQuery,
          settings.isAdult,
          settings.appLanguage,
        ),
        settings.enableProxy,
        dependencies.tmdbProxy,
      ).then(
        (items) => items.map(MediaItem.fromSeries).toList(growable: false),
      ),
    ]);
    return _unique(results.expand((items) => items));
  }

  Future<List<MediaItem>> loadLibrary() async {
    final results = await Future.wait<List<MediaItem>>([
      MovieDatabaseController().getMovieList().then(
        (items) => items.map(MediaItem.fromMovie).toList(growable: false),
      ),
      TVDatabaseController().getTVList().then(
        (items) => items.map(MediaItem.fromSeries).toList(growable: false),
      ),
    ]);
    return results.expand((items) => items).toList(growable: false);
  }

  List<MediaItem> _unique(Iterable<MediaItem> items) {
    final found = <String>{};
    return items
        .where((item) => item.id >= 0 && found.add(item.stableId))
        .toList(growable: false);
  }
}
