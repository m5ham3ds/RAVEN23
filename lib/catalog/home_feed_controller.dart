import 'dart:math';

import '../api/endpoints.dart';
import '../models/genres.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
import '../services/tmdb_connectivity.dart';
import '../widgets/common_widgets.dart' show AppStreamingService;
import 'catalog_controller.dart';
import 'media_item.dart';

/// What the phone's Home page shows: everything, or one kind.
enum HomeFilter {
  all,
  movies,
  series,
  anime,
  manga;

  List<MediaKind> get kinds => switch (this) {
    HomeFilter.all => const <MediaKind>[MediaKind.movie, MediaKind.series],
    HomeFilter.movies => const <MediaKind>[MediaKind.movie],
    HomeFilter.series ||
    HomeFilter.anime => const <MediaKind>[MediaKind.series],
    HomeFilter.manga => const <MediaKind>[],
  };

  bool shows(MediaKind kind) => kinds.contains(kind);
}

/// The lists a Home row is built from.
enum HomeList {
  /// Today's most watched, for the Top 10 and the hero.
  trendingToday,
  trendingWeek,
  popular,
  topRated,

  /// Movies in cinemas, or series with episodes on the air.
  newReleases,

  /// Movies still to come. Series have none.
  upcoming,

  /// Japanese animation discovered from TMDB, not a hard-coded title list.
  trendingAnime,
  popularAnime,
  newEpisodesAnime,
  topRatedAnime,
}

/// Where Home's lists come from, so tests can feed it their own.
abstract class HomeFeedSource {
  /// Test/custom sources assume online unless they explicitly model offline.
  Future<bool> get isOnline async => true;

  Future<List<MediaItem>> list(MediaKind kind, HomeList list);

  /// Popular titles of [kind] from one [year] and genre, a page deep: the
  /// random picks the hero mixes with what's trending.
  Future<List<MediaItem>> discover(
    MediaKind kind, {
    required int page,
    required int year,
    required int genreId,
  });

  /// The first page of a genre, for a category row.
  Future<List<MediaItem>> genre(MediaKind kind, int genreId);

  /// Dedicated Japanese-animation genre query. Fakes and alternate sources
  /// may fall back to the regular series genre query; the catalog source
  /// overrides this with the strict Animation + Japanese-language endpoint.
  Future<List<MediaItem>> animeGenre(int genreId) =>
      genre(MediaKind.series, genreId);

  Future<List<MediaItem>> service(MediaKind kind, int providerId);

  /// Anime-only watch-provider shelf; defaults keep test sources compatible.
  Future<List<MediaItem>> animeService(int providerId) =>
      service(MediaKind.series, providerId);

  Future<List<Genres>> genres(MediaKind kind);
}

/// TMDB through the app's usual fetchers and proxy settings.
class CatalogHomeFeedSource implements HomeFeedSource {
  const CatalogHomeFeedSource({
    required this.settings,
    required this.dependencies,
    this.catalog = const CatalogController(
      retryLimit: 0,
      requestTimeout: Duration(seconds: 8),
    ),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SettingsProvider settings;
  final AppDependencyProvider dependencies;
  final CatalogController catalog;
  final DateTime Function() _now;

  @override
  Future<bool> get isOnline =>
      TmdbConnectivity.instance.checkReachability(dependencies.tmdbProxy);

  /// The TMDB list behind [list] for [kind], or null where there is none
  /// (upcoming series).
  String? urlFor(MediaKind kind, HomeList list) {
    final language = settings.appLanguage;
    final isMovie = kind == MediaKind.movie;
    return switch (list) {
      HomeList.trendingToday =>
        isMovie
            ? Endpoints.trendingMoviesTodayUrl(language)
            : Endpoints.trendingTVTodayUrl(language),
      HomeList.trendingWeek =>
        isMovie
            ? Endpoints.trendingMoviesUrl(language)
            : Endpoints.trendingTVUrl(language),
      HomeList.popular =>
        isMovie
            ? Endpoints.popularMoviesUrl(language)
            : Endpoints.popularTVUrl(language),
      HomeList.topRated =>
        isMovie
            ? Endpoints.topRatedUrl(language)
            : Endpoints.topRatedTVUrl(language),
      HomeList.newReleases =>
        isMovie
            ? Endpoints.nowPlayingMoviesUrl(1, language)
            : Endpoints.onTheAirUrl(language),
      HomeList.upcoming =>
        isMovie ? Endpoints.upcomingMoviesUrl(language) : null,
      // Trending Anime combines TMDB's global TV trend with the dedicated
      // popularity-ranked Anime discovery query; it has no single URL.
      HomeList.trendingAnime => null,
      HomeList.popularAnime =>
        isMovie
            ? null
            : Endpoints.popularAnimeTVUrl(
                language,
                includeAdult: settings.isAdult,
              ),
      HomeList.newEpisodesAnime =>
        isMovie
            ? null
            : Endpoints.newEpisodesAnimeTVUrl(
                language,
                _now(),
                includeAdult: settings.isAdult,
              ),
      HomeList.topRatedAnime =>
        isMovie
            ? null
            : Endpoints.topRatedAnimeTVUrl(
                language,
                includeAdult: settings.isAdult,
              ),
    };
  }

  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) async {
    if (kind == MediaKind.movie &&
        <HomeList>{
          HomeList.trendingAnime,
          HomeList.popularAnime,
          HomeList.newEpisodesAnime,
          HomeList.topRatedAnime,
        }.contains(list)) {
      return const <MediaItem>[];
    }
    if (kind == MediaKind.series && list == HomeList.trendingAnime) {
      return catalog.loadTrendingAnimePage(
        page: 1,
        settings: settings,
        dependencies: dependencies,
        strict: true,
      );
    }
    final url = urlFor(kind, list);
    if (url == null) return const <MediaItem>[];
    final items = await _load(kind, url);
    if (_isAnimeList(list)) {
      return items.where(_isAnime).toList(growable: false);
    }
    // Keep the general series shelves distinct from anime shelves. Anime is
    // still MediaKind.series, but the UI has explicit anime rows for it.
    if (kind == MediaKind.series) {
      return items.where((item) => !_isAnime(item)).toList(growable: false);
    }
    return items;
  }

  Future<List<MediaItem>> _load(MediaKind kind, String url) => catalog.loadRow(
    kind: kind,
    url: url,
    settings: settings,
    dependencies: dependencies,
    strict: true,
  );

  static bool _isAnime(MediaItem item) => item.series?.isLikelyAnime == true;

  static bool _isAnimeList(HomeList list) => <HomeList>{
    HomeList.trendingAnime,
    HomeList.popularAnime,
    HomeList.newEpisodesAnime,
    HomeList.topRatedAnime,
  }.contains(list);

  @override
  Future<List<MediaItem>> discover(
    MediaKind kind, {
    required int page,
    required int year,
    required int genreId,
  }) {
    final language = settings.appLanguage;
    return catalog.loadRow(
      kind: kind,
      url: kind == MediaKind.movie
          ? Endpoints.randomDiscoverMoviesUrl(
              language,
              page: page,
              year: '$year',
              genreId: '$genreId',
            )
          : Endpoints.randomDiscoverTVUrl(
              language,
              page: page,
              year: '$year',
              genreId: '$genreId',
            ),
      settings: settings,
      dependencies: dependencies,
      strict: true,
    );
  }

  @override
  Future<List<MediaItem>> genre(MediaKind kind, int genreId) async {
    final language = settings.appLanguage;
    final items = await catalog.loadRow(
      kind: kind,
      url: kind == MediaKind.movie
          ? Endpoints.getMoviesForGenre(genreId, 1, language)
          : Endpoints.getTVShowsForGenre(genreId, 1, language),
      settings: settings,
      dependencies: dependencies,
      strict: true,
    );
    // Ordinary Series genre shelves must not absorb Japanese anime.
    return kind == MediaKind.series
        ? items
              .where((item) => item.series?.isLikelyAnime != true)
              .toList(growable: false)
        : items;
  }

  @override
  Future<List<MediaItem>> animeGenre(int genreId) async {
    final items = await catalog.loadRow(
      kind: MediaKind.series,
      url: Endpoints.getAnimeTVShowsForGenre(
        genreId,
        1,
        settings.appLanguage,
        includeAdult: settings.isAdult,
      ),
      settings: settings,
      dependencies: dependencies,
      strict: true,
    );
    return items
        .where((item) => item.series?.isLikelyAnime == true)
        .toList(growable: false);
  }

  @override
  Future<List<MediaItem>> service(MediaKind kind, int providerId) =>
      catalog.loadServiceRow(
        kind: kind,
        providerId: providerId,
        settings: settings,
        dependencies: dependencies,
        strict: true,
      );

  @override
  Future<List<MediaItem>> animeService(int providerId) =>
      catalog.loadAnimeServiceRow(
        providerId: providerId,
        settings: settings,
        dependencies: dependencies,
        strict: true,
      );

  @override
  Future<List<Genres>> genres(MediaKind kind) => catalog.loadGenres(
    kind: kind,
    settings: settings,
    dependencies: dependencies,
    strict: true,
  );
}

/// One kind's rows on Home. Movies and series never share a catalogue row,
/// so it's always clear which a poster is.
class KindRows {
  const KindRows({
    this.topTen = const <MediaItem>[],
    this.trending = const <MediaItem>[],
    this.popular = const <MediaItem>[],
    this.newReleases = const <MediaItem>[],
    this.topRated = const <MediaItem>[],
    this.upcoming = const <MediaItem>[],
    this.serviceShelves = const <ServiceShelf>[],
  });

  static const empty = KindRows();

  final List<MediaItem> topTen;
  final List<MediaItem> trending;
  final List<MediaItem> popular;

  /// Movies in cinemas, or series with episodes on the air.
  final List<MediaItem> newReleases;
  final List<MediaItem> topRated;

  /// Movies still to come; series have none.
  final List<MediaItem> upcoming;
  final List<ServiceShelf> serviceShelves;

  MediaItem? get first =>
      topTen.firstOrNull ?? trending.firstOrNull ?? popular.firstOrNull;

  bool get isEmpty =>
      topTen.isEmpty &&
      trending.isEmpty &&
      popular.isEmpty &&
      newReleases.isEmpty &&
      topRated.isEmpty &&
      upcoming.isEmpty &&
      serviceShelves.every((shelf) => shelf.items.isEmpty);
}

/// Everything Home fetches for one filter.
///
/// Continue Watching and My List are not here: they are the viewer's own and
/// change while Home is open, so Home reads them live and passes them through
/// [limitRepeats] with these rows.
class HomeFeed {
  const HomeFeed({
    required this.filter,
    this.spotlight = const <MediaItem>[],
    this.categories = const <HomeCategory>[],
    this.rows = const <MediaKind, KindRows>{},
    this.movieGenres = const <Genres>[],
    this.seriesGenres = const <Genres>[],
    this.trendingAnime = const <MediaItem>[],
    this.popularAnime = const <MediaItem>[],
    this.newEpisodesAnime = const <MediaItem>[],
    this.topRatedAnime = const <MediaItem>[],
    this.hadErrors = false,
  });

  final HomeFilter filter;

  /// The hero's titles, in turn: what's trending this week alternating with
  /// random picks from a genre and year, as RAVEN23's hero always has.
  final List<MediaItem> spotlight;

  /// A few genres picked at random for this visit, each with its own layout.
  final List<HomeCategory> categories;

  /// Each kind the filter shows, with its own rows.
  final Map<MediaKind, KindRows> rows;
  final List<Genres> movieGenres;
  final List<Genres> seriesGenres;

  /// Trending and popular Japanese animation, still episodic TV.
  final List<MediaItem> trendingAnime;
  final List<MediaItem> popularAnime;

  /// Japanese animation with an episode aired in the recent seven-day window.
  final List<MediaItem> newEpisodesAnime;

  /// Highest-rated Japanese animation, still represented as episodic TV.
  final List<MediaItem> topRatedAnime;

  /// At least one catalogue request failed. Empty successful responses are
  /// deliberately kept distinct so the UI can show No results vs Retry.
  final bool hadErrors;

  KindRows of(MediaKind kind) => rows[kind] ?? KindRows.empty;

  /// The spotlight's first, else the best-known title there is.
  MediaItem? get hero =>
      spotlight.firstOrNull ??
      filter.kinds.map((kind) => of(kind).first).nonNulls.firstOrNull ??
      trendingAnime.firstOrNull ??
      popularAnime.firstOrNull ??
      newEpisodesAnime.firstOrNull ??
      topRatedAnime.firstOrNull;

  bool get isEmpty =>
      trendingAnime.isEmpty &&
      popularAnime.isEmpty &&
      newEpisodesAnime.isEmpty &&
      topRatedAnime.isEmpty &&
      categories.isEmpty &&
      rows.values.every((kind) => kind.isEmpty);
}

/// How a category row lays out its titles, varied so a run of them doesn't
/// read as the same row repeated.
enum CategoryLayout {
  /// A wide feature card for the first title, posters for the rest.
  feature,

  /// Wide stills, then posters.
  stillsAndPosters,

  /// Two rows of posters.
  twoPosterRows,

  /// A row of wide stills.
  stills,

  /// A row of posters.
  posters,
}

/// One of Home's random genre rows.
class HomeCategory {
  const HomeCategory({
    required this.kind,
    required this.genre,
    required this.layout,
    this.animeOnly = false,
  });

  final MediaKind kind;
  final Genres genre;
  final CategoryLayout layout;
  final bool animeOnly;
}

class _HomeBaseRows {
  const _HomeBaseRows({
    required this.kind,
    required this.today,
    required this.week,
    required this.popular,
    required this.initialRows,
  });

  final MediaKind kind;
  final List<MediaItem> today;
  final List<MediaItem> week;
  final List<MediaItem> popular;
  final KindRows initialRows;
}

/// Loads [HomeFeed]s. Every list fails on its own, so a missing one leaves
/// the rest of Home standing.
class HomeFeedController {
  HomeFeedController(this.source, {Random? random, DateTime Function()? now})
    : _random = random ?? Random(),
      _now = now ?? DateTime.now;

  final HomeFeedSource source;
  final Random _random;
  final DateTime Function() _now;

  /// The genres the hero's random picks come from, as the old Movies and
  /// Series pages had them.
  static const movieSpotlightGenres = <int>[
    28, 12, 16, 35, 80, 99, 18, 10751, 14, 36, //
    27, 10402, 9648, 10749, 878, 10770, 53, 10752, 37,
  ];
  static const seriesSpotlightGenres = <int>[
    10759, 16, 35, 80, 99, 18, 10751, 10762, //
    9648, 10763, 10764, 10765, 10766, 10767, 10768, 37,
  ];

  /// The earliest year the hero's random picks come from.
  static const spotlightFirstYear = 1990;
  static const spotlightLength = 10;

  /// How many random genre rows a visit gets.
  static const categoryCount = 5;

  /// The services given a row, by TMDB provider id, in order.
  static const movieShelfProviders = <int>[8, 9, 337, 384];
  static const seriesShelfProviders = <int>[8, 384, 9, 15];

  /// Under All, each service's row is of the kind it's best known for, so
  /// the page doesn't carry two rows per service.
  static const allShelves = <(int, MediaKind)>[
    (8, MediaKind.series),
    (9, MediaKind.movie),
    (384, MediaKind.series),
    (337, MediaKind.movie),
  ];

  static const rowLength = 20;

  /// How many of the leading rows a title may appear in.
  static const maxLeadAppearances = 2;

  bool _hadErrors = false;

  Future<List<T>> _safeList<T>(Future<List<T>> request) async {
    try {
      return await request;
    } catch (_) {
      _hadErrors = true;
      return <T>[];
    }
  }

  /// Loads the important chart rows first, then enriches the feed with
  /// provider shelves, genres, random discovery and optional Anime shelves.
  /// [onProgress] lets the screen paint the first useful rows while the less
  /// important requests are still running.
  Future<HomeFeed> load(
    HomeFilter filter, {
    void Function(HomeFeed feed)? onProgress,
  }) async {
    _hadErrors = false;
    if (filter == HomeFilter.manga) return HomeFeed(filter: filter);

    final kinds = filter.kinds;
    final includeAnime = filter == HomeFilter.all || filter == HomeFilter.anime;

    List<MediaItem> trendingAnime = const <MediaItem>[];
    List<MediaItem> popularAnime = const <MediaItem>[];
    List<MediaItem> newEpisodesAnime = const <MediaItem>[];
    List<MediaItem> topRatedAnime = const <MediaItem>[];

    HomeFeed snapshotForBaseRows(Map<MediaKind, _HomeBaseRows> loaded) {
      final rows = <MediaKind, KindRows>{
        for (final kind in kinds)
          if (loaded.containsKey(kind)) kind: loaded[kind]!.initialRows,
      };
      return HomeFeed(
        filter: filter,
        spotlight: interleave(<List<MediaItem>>[
          for (final kind in kinds)
            if (loaded.containsKey(kind)) loaded[kind]!.week,
        ]).take(spotlightLength).toList(growable: false),
        rows: rows,
        hadErrors: _hadErrors,
      );
    }

    HomeFeed snapshotForAnimeRows(Map<HomeList, List<MediaItem>> loaded) {
      final trending = loaded[HomeList.trendingAnime] ?? const <MediaItem>[];
      return HomeFeed(
        filter: filter,
        spotlight: trending.take(spotlightLength).toList(growable: false),
        trendingAnime: trending,
        popularAnime: loaded[HomeList.popularAnime] ?? const <MediaItem>[],
        newEpisodesAnime:
            loaded[HomeList.newEpisodesAnime] ?? const <MediaItem>[],
        topRatedAnime: loaded[HomeList.topRatedAnime] ?? const <MediaItem>[],
        hadErrors: _hadErrors,
      );
    }

    // Stage 1: primary charts. Each media type is published as soon as its
    // own core requests finish, so a slow Series response cannot hold back
    // Movies on the shared All page.
    final baseByKind = <MediaKind, _HomeBaseRows>{};
    if (filter == HomeFilter.anime) {
      final animeByList = <HomeList, List<MediaItem>>{};
      const animeCoreLists = <HomeList>[
        HomeList.trendingAnime,
        HomeList.popularAnime,
        HomeList.newEpisodesAnime,
        HomeList.topRatedAnime,
      ];
      await Future.wait<void>(<Future<void>>[
        for (final list in animeCoreLists)
          () async {
            final loaded = _animeItems(
              await _safeList(source.list(MediaKind.series, list)),
            );
            animeByList[list] = loaded;
            final snapshot = snapshotForAnimeRows(animeByList);
            if (!snapshot.isEmpty) onProgress?.call(snapshot);
          }(),
      ]);
      trendingAnime =
          animeByList[HomeList.trendingAnime] ?? const <MediaItem>[];
      popularAnime = animeByList[HomeList.popularAnime] ?? const <MediaItem>[];
      newEpisodesAnime =
          animeByList[HomeList.newEpisodesAnime] ?? const <MediaItem>[];
      topRatedAnime =
          animeByList[HomeList.topRatedAnime] ?? const <MediaItem>[];
    } else {
      await Future.wait<void>(<Future<void>>[
        for (final kind in kinds)
          () async {
            baseByKind[kind] = await _baseRowsFor(kind);
            final snapshot = snapshotForBaseRows(baseByKind);
            if (!snapshot.isEmpty) onProgress?.call(snapshot);
          }(),
      ]);
    }
    final baseRows = <_HomeBaseRows>[
      for (final kind in kinds)
        if (baseByKind.containsKey(kind)) baseByKind[kind]!,
    ];

    final baseFeed = filter == HomeFilter.anime
        ? snapshotForAnimeRows(<HomeList, List<MediaItem>>{
            HomeList.trendingAnime: trendingAnime,
            HomeList.popularAnime: popularAnime,
            HomeList.newEpisodesAnime: newEpisodesAnime,
            HomeList.topRatedAnime: topRatedAnime,
          })
        : snapshotForBaseRows(baseByKind);

    // Probe after the core requests so stale SQLite entries can be served
    // immediately by the cache interceptor, even when the device is offline.
    // If the route is unavailable, keep any retained core rows and do not fan
    // out into optional genres, discovery, anime or provider shelves.
    final online = await source.isOnline;
    if (!online || (_hadErrors && baseFeed.isEmpty)) {
      // A successful cache hit is still usable while offline. Only surface a
      // network error when one of the catalogue requests actually failed.
      return HomeFeed(
        filter: baseFeed.filter,
        spotlight: baseFeed.spotlight,
        categories: baseFeed.categories,
        rows: baseFeed.rows,
        movieGenres: baseFeed.movieGenres,
        seriesGenres: baseFeed.seriesGenres,
        trendingAnime: baseFeed.trendingAnime,
        popularAnime: baseFeed.popularAnime,
        newEpisodesAnime: baseFeed.newEpisodesAnime,
        topRatedAnime: baseFeed.topRatedAnime,
        // The connectivity probe is intentionally independent from catalogue
        // requests. A cached, successful empty response remains an empty
        // result while offline; only failed catalogue requests show Retry.
        hadErrors: baseFeed.hadErrors,
      );
    }

    // Stage 2: optional metadata and discovery. The core rows are already
    // visible, so these requests cannot hold up first paint. Load in small
    // groups rather than launching every optional TMDB request at once.
    final loadedGenres = await Future.wait<List<Genres>>(<Future<List<Genres>>>[
      filter.shows(MediaKind.movie)
          ? _safeList(source.genres(MediaKind.movie))
          : Future.value(const <Genres>[]),
      filter.shows(MediaKind.series) || filter == HomeFilter.anime
          ? _safeList(source.genres(MediaKind.series))
          : Future.value(const <Genres>[]),
    ]);

    final completedRows = <KindRows>[];
    if (filter != HomeFilter.anime) {
      for (final base in baseRows) {
        completedRows.add(await _completeRows(base));
      }
    }

    final loadedSpotlights = filter == HomeFilter.anime
        ? <List<MediaItem>>[trendingAnime]
        : await _loadInBatches<List<MediaItem>>(
            <Future<List<MediaItem>> Function()>[
              for (var index = 0; index < kinds.length; index++)
                () => _spotlight(kinds[index], baseRows[index].week),
            ],
          );

    final shelfProviders = <(int, MediaKind)>[
      ...switch (filter) {
        HomeFilter.all => allShelves,
        HomeFilter.movies => <(int, MediaKind)>[
          for (final id in movieShelfProviders) (id, MediaKind.movie),
        ],
        HomeFilter.series => <(int, MediaKind)>[
          for (final id in seriesShelfProviders) (id, MediaKind.series),
        ],
        HomeFilter.anime || HomeFilter.manga => const <(int, MediaKind)>[],
      },
    ];
    final loadedShelves = await _loadInBatches<ServiceShelf?>(
      <Future<ServiceShelf?> Function()>[
        for (final shelf in shelfProviders) () => _shelf(shelf.$1, shelf.$2),
      ],
    );

    final loadedAnimeLists = includeAnime && filter != HomeFilter.anime
        ? await _loadInBatches<List<MediaItem>>(<
            Future<List<MediaItem>> Function()
          >[
            () => _safeList(
              source.list(MediaKind.series, HomeList.trendingAnime),
            ),
            () =>
                _safeList(source.list(MediaKind.series, HomeList.popularAnime)),
            () => _safeList(
              source.list(MediaKind.series, HomeList.newEpisodesAnime),
            ),
            () => _safeList(
              source.list(MediaKind.series, HomeList.topRatedAnime),
            ),
          ])
        : <List<MediaItem>>[
            trendingAnime,
            popularAnime,
            newEpisodesAnime,
            topRatedAnime,
          ];

    final loadedAnimeServices = filter == HomeFilter.anime
        ? await _loadInBatches<ServiceShelf?>(
            <Future<ServiceShelf?> Function()>[
              for (final providerId in seriesShelfProviders)
                () => _shelf(providerId, MediaKind.series, animeOnly: true),
            ],
          )
        : const <ServiceShelf?>[];

    if (filter != HomeFilter.anime) {
      trendingAnime = _animeItems(loadedAnimeLists[0]);
      popularAnime = _animeItems(loadedAnimeLists[1]);
      newEpisodesAnime = _animeItems(loadedAnimeLists[2]);
      topRatedAnime = _animeItems(loadedAnimeLists[3]);
    }

    final rows = <MediaKind, KindRows>{};
    for (var index = 0; index < baseRows.length; index++) {
      final kind = kinds[index];
      final base = completedRows[index];
      rows[kind] = KindRows(
        topTen: base.topTen,
        trending: base.trending,
        popular: base.popular,
        newReleases: base.newReleases,
        topRated: base.topRated,
        upcoming: base.upcoming,
        serviceShelves: loadedShelves
            .whereType<ServiceShelf>()
            .where(
              (shelf) => shelfProviders.any(
                (entry) =>
                    entry.$2 == kind &&
                    CatalogController.serviceFor(entry.$1)?.stableKey ==
                        shelf.service.stableKey,
              ),
            )
            .toList(growable: false),
      );
    }
    if (filter == HomeFilter.anime) {
      rows[MediaKind.series] = KindRows(
        serviceShelves: loadedAnimeServices.whereType<ServiceShelf>().toList(
          growable: false,
        ),
      );
    }

    final finalFeed = HomeFeed(
      filter: filter,
      spotlight: filter == HomeFilter.anime
          ? trendingAnime.take(spotlightLength).toList(growable: false)
          : interleave(
              loadedSpotlights,
            ).take(spotlightLength).toList(growable: false),
      categories: filter == HomeFilter.anime
          ? _animeCategories(loadedGenres[1])
          : _categories(loadedGenres[0], loadedGenres[1]),
      rows: rows,
      movieGenres: loadedGenres[0],
      seriesGenres: loadedGenres[1],
      trendingAnime: trendingAnime.take(rowLength).toList(growable: false),
      popularAnime: popularAnime.take(rowLength).toList(growable: false),
      newEpisodesAnime: newEpisodesAnime
          .take(rowLength)
          .toList(growable: false),
      topRatedAnime: topRatedAnime.take(rowLength).toList(growable: false),
      hadErrors: _hadErrors,
    );
    onProgress?.call(finalFeed);
    return finalFeed;
  }

  Future<List<T>> _loadInBatches<T>(
    List<Future<T> Function()> loaders, {
    int batchSize = 3,
  }) async {
    final values = <T>[];
    for (var start = 0; start < loaders.length; start += batchSize) {
      final end = start + batchSize < loaders.length
          ? start + batchSize
          : loaders.length;
      values.addAll(
        await Future.wait<T>(loaders.sublist(start, end).map((load) => load())),
      );
    }
    return values;
  }

  List<MediaItem> _animeItems(List<MediaItem> items) => items
      .where((item) => item.series?.isLikelyAnime == true)
      .take(rowLength)
      .toList(growable: false);

  Future<_HomeBaseRows> _baseRowsFor(MediaKind kind) async {
    final lists = await Future.wait<List<MediaItem>>(<Future<List<MediaItem>>>[
      _safeList(source.list(kind, HomeList.trendingToday)),
      _safeList(source.list(kind, HomeList.trendingWeek)),
      _safeList(source.list(kind, HomeList.popular)),
    ]);
    final today = lists[0];
    final week = lists[1];
    final popular = lists[2];
    final leading = limitRepeats(<List<MediaItem>>[
      today.take(10).toList(growable: false),
      week,
    ]);
    return _HomeBaseRows(
      kind: kind,
      today: today,
      week: week,
      popular: popular,
      initialRows: KindRows(
        topTen: leading[0],
        trending: _row(leading[1]),
        popular: _row(popular),
      ),
    );
  }

  Future<KindRows> _completeRows(_HomeBaseRows base) async {
    final optional =
        await Future.wait<List<MediaItem>>(<Future<List<MediaItem>>>[
          _safeList(source.list(base.kind, HomeList.newReleases)),
          _safeList(source.list(base.kind, HomeList.topRated)),
          _safeList(source.list(base.kind, HomeList.upcoming)),
        ]);
    final releases = optional[0];
    final topRated = optional[1];
    final upcoming = optional[2];
    final leading = limitRepeats(<List<MediaItem>>[
      base.today.take(10).toList(growable: false),
      base.week,
      releases,
    ]);
    return KindRows(
      topTen: leading[0],
      trending: _row(leading[1]),
      popular: _row(base.popular),
      newReleases: _row(leading[2]),
      topRated: _row(topRated),
      upcoming: _row(upcoming),
    );
  }

  /// RAVEN23's hero for [kind]: this week's trending in turn with random
  /// popular titles from a random genre, year (1990 on) and page (1 to 5),
  /// only titles with artwork, ten at most. Trending alone if the random
  /// pick finds nothing.
  Future<List<MediaItem>> _spotlight(
    MediaKind kind,
    List<MediaItem> trending,
  ) async {
    final genres = kind == MediaKind.movie
        ? movieSpotlightGenres
        : seriesSpotlightGenres;
    final thisYear = _now().year;
    final discovered = await _safeList(
      source.discover(
        kind,
        page: _random.nextInt(5) + 1,
        year:
            spotlightFirstYear +
            _random.nextInt(thisYear - spotlightFirstYear + 1),
        genreId: genres[_random.nextInt(genres.length)],
      ),
    );
    // Random discover can include Japanese animation even when its requested
    // page is Series. Keep the same separation as the chart/service rows.
    final random = kind == MediaKind.series
        ? discovered
              .where((item) => item.series?.isLikelyAnime != true)
              .toList(growable: false)
        : discovered;
    bool hasArt(MediaItem item) =>
        item.backdropPath != null || item.posterPath != null;
    final picks = random.where(hasArt).toList()..shuffle(_random);
    final combined = interleave(<List<MediaItem>>[
      trending.where(hasArt).toList(growable: false),
      picks,
    ]).take(spotlightLength).toList(growable: false);
    return combined.isNotEmpty ? combined : trending;
  }

  /// [categoryCount] genres at random from those on show, each given one of
  /// the layouts, shuffled so no two visits look alike.
  List<HomeCategory> _categories(
    List<Genres> movieGenres,
    List<Genres> seriesGenres,
  ) {
    final pool = <(MediaKind, Genres)>[
      for (final genre in movieGenres) (MediaKind.movie, genre),
      for (final genre in seriesGenres) (MediaKind.series, genre),
    ]..shuffle(_random);
    final layouts = List<CategoryLayout>.of(CategoryLayout.values)
      ..shuffle(_random);
    final picked = pool.take(categoryCount).toList(growable: false);
    return <HomeCategory>[
      for (var i = 0; i < picked.length; i++)
        HomeCategory(
          kind: picked[i].$1,
          genre: picked[i].$2,
          layout: layouts[i % layouts.length],
        ),
    ];
  }

  List<HomeCategory> _animeCategories(List<Genres> seriesGenres) {
    final eligible =
        seriesGenres
            .where(
              (genre) =>
                  CatalogController.animeGenreIds.contains(genre.genreID),
            )
            .toList(growable: false)
          ..shuffle(_random);
    final layouts = List<CategoryLayout>.of(CategoryLayout.values)
      ..shuffle(_random);
    final picked = eligible.take(categoryCount).toList(growable: false);
    return <HomeCategory>[
      for (var i = 0; i < picked.length; i++)
        HomeCategory(
          kind: MediaKind.series,
          genre: picked[i],
          layout: layouts[i % layouts.length],
          animeOnly: true,
        ),
    ];
  }

  Future<ServiceShelf?> _shelf(
    int providerId,
    MediaKind kind, {
    bool animeOnly = false,
  }) async {
    final AppStreamingService? service = CatalogController.serviceFor(
      providerId,
    );
    if (service == null) return null;
    final loaded = await _safeList(
      animeOnly
          ? source.animeService(providerId)
          : source.service(kind, providerId),
    );
    final filtered = kind == MediaKind.series
        ? loaded
              .where(
                (item) => animeOnly
                    ? item.series?.isLikelyAnime == true
                    : item.series?.isLikelyAnime != true,
              )
              .toList(growable: false)
        : loaded;
    final items = interleave(<List<MediaItem>>[filtered]);
    if (items.isEmpty) return null;
    return ServiceShelf(service: service, items: _row(items));
  }

  static List<MediaItem> _row(List<MediaItem> items) =>
      items.take(rowLength).toList(growable: false);
}

/// A title's identity across rows: an episode in Continue Watching is the
/// same title as its series on a poster.
String titleKey(MediaItem item) => '${item.kind.name}:${item.id}';

/// [lists] taken in turn, one from each, skipping titles already taken and
/// items without an id.
List<MediaItem> interleave(List<List<MediaItem>> lists) {
  final seen = <String>{};
  final result = <MediaItem>[];
  final longest = lists.fold<int>(
    0,
    (length, list) => list.length > length ? list.length : length,
  );
  for (var i = 0; i < longest; i++) {
    for (final list in lists) {
      if (i >= list.length) continue;
      final item = list[i];
      if (item.id >= 0 && seen.add(titleKey(item))) result.add(item);
    }
  }
  return result;
}

/// [rows], in page order, with each title kept in at most [max] of them:
/// later appearances past the limit are dropped.
List<List<MediaItem>> limitRepeats(
  List<List<MediaItem>> rows, {
  int max = HomeFeedController.maxLeadAppearances,
}) {
  final counts = <String, int>{};
  final result = <List<MediaItem>>[];
  for (final row in rows) {
    final kept = <MediaItem>[];
    final inRow = <String>{};
    for (final item in row) {
      final key = titleKey(item);
      if (!inRow.add(key) || (counts[key] ?? 0) >= max) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      kept.add(item);
    }
    result.add(List<MediaItem>.unmodifiable(kept));
  }
  return result;
}
