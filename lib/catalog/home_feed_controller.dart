import 'dart:math';

import '../api/endpoints.dart';
import '../models/genres.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/settings_provider.dart';
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
    this.catalog = const CatalogController(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SettingsProvider settings;
  final AppDependencyProvider dependencies;
  final CatalogController catalog;
  final DateTime Function() _now;

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
      );

  @override
  Future<List<MediaItem>> animeService(int providerId) =>
      catalog.loadAnimeServiceRow(
        providerId: providerId,
        settings: settings,
        dependencies: dependencies,
      );

  @override
  Future<List<Genres>> genres(MediaKind kind) => catalog.loadGenres(
    kind: kind,
    settings: settings,
    dependencies: dependencies,
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

  Future<HomeFeed> load(HomeFilter filter) async {
    // Manga is rendered by the same Home row pipeline, but its catalogue is
    // sourced independently from AniList rather than from the video catalogue.
    if (filter == HomeFilter.manga) return HomeFeed(filter: filter);
    final kinds = filter.kinds;
    final shelves = <(int, MediaKind)>[
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
    final includeAnime = filter == HomeFilter.all || filter == HomeFilter.anime;
    final genres = Future.wait(<Future<List<Genres>>>[
      filter.shows(MediaKind.movie)
          ? _orEmpty(source.genres(MediaKind.movie))
          : Future.value(const <Genres>[]),
      filter.shows(MediaKind.series)
          ? _orEmpty(source.genres(MediaKind.series))
          : Future.value(const <Genres>[]),
    ]);
    final animeTrending = includeAnime
        ? _orEmpty(source.list(MediaKind.series, HomeList.trendingAnime))
        : Future.value(const <MediaItem>[]);
    final animePopular = includeAnime
        ? _orEmpty(source.list(MediaKind.series, HomeList.popularAnime))
        : Future.value(const <MediaItem>[]);
    final animeNewEpisodes = includeAnime
        ? _orEmpty(source.list(MediaKind.series, HomeList.newEpisodesAnime))
        : Future.value(const <MediaItem>[]);
    final animeTopRated = includeAnime
        ? _orEmpty(source.list(MediaKind.series, HomeList.topRatedAnime))
        : Future.value(const <MediaItem>[]);
    final loaded = filter == HomeFilter.anime
        ? <(KindRows, List<MediaItem>)>[]
        : await Future.wait(<Future<(KindRows, List<MediaItem>)>>[
            for (final kind in kinds)
              _rowsFor(
                kind,
                shelves
                    .where((shelf) => shelf.$2 == kind)
                    .map((shelf) => shelf.$1)
                    .toList(growable: false),
              ),
          ]);
    final animeServiceShelves = filter == HomeFilter.anime
        ? await Future.wait<ServiceShelf?>(<Future<ServiceShelf?>>[
            for (final providerId in seriesShelfProviders)
              _shelf(providerId, MediaKind.series, animeOnly: true),
          ])
        : const <ServiceShelf?>[];
    final loadedGenres = await genres;
    final loadedAnime = await animeTopRated;
    final loadedTrendingAnime = await animeTrending;
    final loadedPopularAnime = await animePopular;
    final loadedNewEpisodesAnime = await animeNewEpisodes;
    return HomeFeed(
      filter: filter,
      trendingAnime: loadedTrendingAnime
          .where((item) => item.series?.isLikelyAnime == true)
          .take(rowLength)
          .toList(growable: false),
      popularAnime: loadedPopularAnime
          .where((item) => item.series?.isLikelyAnime == true)
          .take(rowLength)
          .toList(growable: false),
      newEpisodesAnime: loadedNewEpisodesAnime
          .where((item) => item.series?.isLikelyAnime == true)
          .take(rowLength)
          .toList(growable: false),
      topRatedAnime: loadedAnime
          .where((item) => item.series?.isLikelyAnime == true)
          .take(rowLength)
          .toList(growable: false),
      spotlight: filter == HomeFilter.anime
          ? loadedTrendingAnime
                .where((item) => item.series?.isLikelyAnime == true)
                .take(spotlightLength)
                .toList(growable: false)
          : interleave(<List<MediaItem>>[
              for (final kindRows in loaded) kindRows.$2,
            ]).take(spotlightLength).toList(growable: false),
      categories: filter == HomeFilter.anime
          ? _animeCategories(loadedGenres[1])
          : _categories(loadedGenres[0], loadedGenres[1]),
      rows: filter == HomeFilter.anime
          ? <MediaKind, KindRows>{
              MediaKind.series: KindRows(
                serviceShelves: animeServiceShelves
                    .whereType<ServiceShelf>()
                    .toList(growable: false),
              ),
            }
          : <MediaKind, KindRows>{
              for (var i = 0; i < kinds.length; i++) kinds[i]: loaded[i].$1,
            },
      movieGenres: loadedGenres[0],
      seriesGenres: loadedGenres[1],
    );
  }

  /// [kind]'s rows, and its share of the hero's spotlight.
  Future<(KindRows, List<MediaItem>)> _rowsFor(
    MediaKind kind,
    List<int> shelfProviders,
  ) async {
    Future<List<MediaItem>> list(HomeList list) async {
      final items = await _orEmpty(source.list(kind, list));
      if (kind != MediaKind.series || list == HomeList.topRatedAnime) {
        return items;
      }
      return items
          .where((item) => item.series?.isLikelyAnime != true)
          .toList(growable: false);
    }

    final shelves = Future.wait(<Future<ServiceShelf?>>[
      for (final providerId in shelfProviders) _shelf(providerId, kind),
    ]);
    final trendingWeek = list(HomeList.trendingWeek);
    final spotlight = trendingWeek.then(
      (trending) => _spotlight(kind, trending),
    );
    final lists = await Future.wait(<Future<List<MediaItem>>>[
      list(HomeList.trendingToday),
      trendingWeek,
      list(HomeList.popular),
      list(HomeList.newReleases),
      list(HomeList.topRated),
      list(HomeList.upcoming),
    ]);
    // Top 10, Trending and New releases lead the page; keep them from
    // showing the same few titles over and over.
    final lead = limitRepeats(<List<MediaItem>>[
      lists[0].take(10).toList(growable: false),
      lists[1],
      lists[3],
    ]);
    return (
      KindRows(
        topTen: lead[0],
        trending: _row(lead[1]),
        popular: _row(lists[2]),
        newReleases: _row(lead[2]),
        topRated: _row(lists[4]),
        upcoming: _row(lists[5]),
        serviceShelves: (await shelves).whereType<ServiceShelf>().toList(
          growable: false,
        ),
      ),
      await spotlight,
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
    final discovered = await _orEmpty(
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
    final loaded = await _orEmpty(
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

  static Future<List<T>> _orEmpty<T>(Future<List<T>> future) async {
    try {
      return await future;
    } catch (_) {
      return <T>[];
    }
  }
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
