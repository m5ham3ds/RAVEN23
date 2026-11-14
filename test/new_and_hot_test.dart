import 'package:raven23/api/endpoints.dart';
import 'package:raven23/catalog/catalog_controller.dart';
import 'package:raven23/catalog/media_item.dart';
import 'package:raven23/catalog/new_and_hot.dart';
import 'package:raven23/models/genres.dart';
import 'package:raven23/models/movie.dart';
import 'package:raven23/models/tv.dart';
import 'package:raven23/provider/app_dependency_provider.dart';
import 'package:raven23/provider/settings_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem movie(
  int id,
  String? date, {
  num popularity = 0,
  String? art = '/a',
}) => MediaItem.fromMovie(
  Movie(
    id: id,
    title: 'Movie $id',
    releaseDate: date,
    posterPath: art,
    popularity: popularity,
  ),
);

MediaItem series(int id, String? date, {num popularity = 0}) =>
    MediaItem.fromSeries(
      TV(
        id: id,
        name: 'Series $id',
        firstAirDate: date,
        backdropPath: '/b',
        popularity: popularity,
      ),
    );

class _FakeCatalogController extends CatalogController {
  _FakeCatalogController(this.items);

  final List<MediaItem> items;
  final List<String> requestedUrls = <String>[];
  MediaKind? requestedKind;

  @override
  Future<List<MediaItem>> loadRow({
    required MediaKind kind,
    required String url,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
    bool strict = false,
  }) async {
    requestedKind = kind;
    requestedUrls.add(url);
    return items;
  }

  @override
  Future<List<MediaItem>> loadTrendingAnimePage({
    required int page,
    required SettingsProvider settings,
    required AppDependencyProvider dependencies,
  }) async {
    requestedKind = MediaKind.series;
    String withPage(String url) {
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

    requestedUrls
      ..add(withPage(Endpoints.trendingTVUrl(settings.appLanguage)))
      ..add(
        withPage(
          Endpoints.popularAnimeTVUrl(
            settings.appLanguage,
            includeAdult: settings.isAdult,
          ),
        ),
      );
    final seen = <String>{};
    return items
        .where(
          (item) =>
              item.series?.isLikelyAnime == true && seen.add(item.stableId),
        )
        .take(20)
        .toList(growable: false);
  }
}

class FakeHotSource implements NewAndHotSource {
  bool failUpcoming = false;
  bool failPremieres = false;
  int upcomingCalls = 0;
  int premiereCalls = 0;
  int movieTrendCalls = 0;
  int seriesTrendCalls = 0;
  int animeTrendCalls = 0;

  @override
  Future<List<MediaItem>> upcomingMovies() async {
    upcomingCalls++;
    if (failUpcoming) throw Exception('offline');
    return <MediaItem>[movie(1, '2026-09-27')];
  }

  @override
  Future<List<MediaItem>> seriesPremieres(DateTime today) async {
    premiereCalls++;
    if (failPremieres) throw Exception('offline');
    return <MediaItem>[series(2, '2026-09-28')];
  }

  @override
  Future<List<MediaItem>> trending(MediaKind kind) async {
    if (kind == MediaKind.movie) {
      movieTrendCalls++;
      return <MediaItem>[movie(3, '2026-09-20')];
    }
    seriesTrendCalls++;
    return <MediaItem>[series(4, '2026-09-20')];
  }

  @override
  Future<List<MediaItem>> trendingAnime() async {
    animeTrendCalls++;
    return <MediaItem>[
      MediaItem.fromSeries(
        TV(
          id: 90,
          name: 'Anime 90',
          originalLanguage: 'ja',
          genreIds: <int>[16, 10759],
        ),
      ),
    ];
  }

  @override
  Future<List<Genres>> genres(MediaKind kind) async => <Genres>[];
}

void main() {
  setUp(
    () => dotenv.testLoad(fileInput: 'TMDB_API_KEY=key\nRAVEN23_API_URL=x'),
  );

  test('premieres query covers sixty days and follows adult setting', () {
    final url = Endpoints.upcomingSeriesPremieresUrl(
      'ar',
      DateTime(2026, 9, 27),
      includeAdult: true,
    );
    expect(url, contains('first_air_date.gte=2026-09-27'));
    expect(url, contains('first_air_date.lte=2026-11-26'));
    expect(url, contains('include_adult=true'));
    expect(url, contains('language=ar'));
  });

  test(
    'popular Anime discovery has no manual-title or vote-count allowlist',
    () {
      final popular = Uri.parse(
        Endpoints.popularAnimeTVUrl('ar', includeAdult: true),
      );
      final params = popular.queryParameters;
      expect(popular.path, '/3/discover/tv');
      expect(params['with_genres'], '16');
      expect(params['with_original_language'], 'ja');
      expect(params['include_adult'], 'true');
      expect(params['sort_by'], 'popularity.desc');
      expect(params.containsKey('vote_count.gte'), isFalse);
      expect(params['language'], 'ar');

      final rated = Uri.parse(Endpoints.topRatedAnimeTVUrl('ar'));
      expect(rated.queryParameters['vote_count.gte'], '30');
      expect(rated.queryParameters['with_genres'], '16');
      expect(rated.queryParameters['with_original_language'], 'ja');
    },
  );

  test(
    'the catalogue source keeps only Japanese animated TV in Top 10 Anime',
    () async {
      final catalog = _FakeCatalogController(<MediaItem>[
        MediaItem.fromSeries(
          TV(
            id: 1,
            name: 'Japanese Anime',
            originalLanguage: 'ja',
            genreIds: <int>[16, 10759],
          ),
        ),
        MediaItem.fromSeries(
          TV(
            id: 2,
            name: 'Japanese Drama',
            originalLanguage: 'ja',
            genreIds: <int>[18],
          ),
        ),
        MediaItem.fromSeries(
          TV(
            id: 3,
            name: 'English Animation',
            originalLanguage: 'en',
            genreIds: <int>[16],
          ),
        ),
      ]);
      final settings = SettingsProvider();
      final dependencies = AppDependencyProvider();
      final source = CatalogNewAndHotSource(
        settings: settings,
        dependencies: dependencies,
        catalog: catalog,
      );

      final items = await source.trendingAnime();

      expect(catalog.requestedKind, MediaKind.series);
      expect(items.map((item) => item.id), <int>[1]);
      expect(catalog.requestedUrls, hasLength(2));
      final animeUrls = List<String>.of(catalog.requestedUrls);

      final regularSeries = await source.trending(MediaKind.series);
      expect(regularSeries.map((item) => item.id), <int>[2, 3]);
      final trending = Uri.parse(animeUrls.first);
      final popular = Uri.parse(animeUrls.last);
      expect(trending.path, '/3/trending/tv/week');
      expect(popular.path, '/3/discover/tv');
      expect(popular.queryParameters['with_genres'], '16');
      expect(popular.queryParameters['with_original_language'], 'ja');
      expect(popular.queryParameters['include_adult'], 'false');
      settings.dispose();
      dependencies.dispose();
    },
  );

  test('anime genre requests always remain Japanese animation', () {
    final url = Endpoints.getAnimeTVShowsForGenre(10759, 2, 'en');
    final params = Uri.parse(url).queryParameters;
    expect(Uri.parse(url).path, '/3/discover/tv');
    expect(params['with_genres'], '16,10759');
    expect(params['with_original_language'], 'ja');
    expect(params['include_adult'], 'false');
    final adultUrl = Endpoints.getAnimeTVShowsForGenre(
      10759,
      2,
      'en',
      includeAdult: true,
    );
    expect(Uri.parse(adultUrl).queryParameters['include_adult'], 'true');
    expect(params['page'], '2');
  });

  test('groups dates soonest first and sorts the day by popularity', () {
    final groups = groupPremieres(
      <MediaItem>[
        movie(1, '2026-10-02', popularity: 1),
        movie(2, '2026-09-28', popularity: 2),
      ],
      <MediaItem>[
        series(3, '2026-09-28', popularity: 9),
        series(4, '2026-10-02', popularity: 5),
      ],
      DateTime(2026, 9, 27),
    );
    expect(groups.map((group) => group.date.day), <int>[28, 2]);
    expect(groups.first.items.map((item) => item.id), <int>[3, 2]);
    expect(groups.last.items.map((item) => item.id), <int>[4, 1]);
  });

  test('drops yesterday, missing dates, and missing art; includes today', () {
    final groups = groupPremieres(
      <MediaItem>[
        movie(1, '2026-09-26'),
        movie(2, '2026-09-27'),
        movie(3, null),
        movie(4, '2026-09-28', art: null),
      ],
      <MediaItem>[],
      DateTime(2026, 9, 27, 23, 59),
    );
    expect(groups.single.items.single.id, 2);
  });

  test('an incomplete duplicate does not hide a dated title with artwork', () {
    final groups = groupPremieres(
      <MediaItem>[movie(7, null), movie(7, '2026-09-28')],
      <MediaItem>[],
      DateTime(2026, 9, 27),
    );
    expect(groups.single.items.single.id, 7);
  });

  test('top ten dedupes and caps an oversized source response', () {
    final list = <MediaItem>[
      for (var i = 0; i < 20; i++) movie(i, '2026-09-27'),
      movie(0, '2026-09-27'),
    ];
    expect(
      topTen(list).map((item) => item.id),
      List<int>.generate(10, (i) => i),
    );
  });

  test('everyone watching alternates kinds and stops at twenty', () {
    final list = everyoneWatching(
      <MediaItem>[for (var i = 0; i < 20; i++) movie(i, '2026-09-27')],
      <MediaItem>[for (var i = 0; i < 20; i++) series(i, '2026-09-27')],
    );
    expect(list.length, 20);
    expect(list.take(4).map((item) => item.kind), <MediaKind>[
      MediaKind.movie,
      MediaKind.series,
      MediaKind.movie,
      MediaKind.series,
    ]);
  });

  test('each load calls only the selected segment source', () async {
    final source = FakeHotSource();
    final catalog = NewAndHotCatalog(source, now: () => DateTime(2026, 9, 27));
    await catalog.load(HotSegment.comingSoon);
    expect(source.upcomingCalls, 1);
    expect(source.premiereCalls, 1);
    expect(source.movieTrendCalls, 0);
    expect(source.seriesTrendCalls, 0);
    expect(source.animeTrendCalls, 0);
    await catalog.load(HotSegment.topSeries);
    expect(source.movieTrendCalls, 0);
    expect(source.seriesTrendCalls, 1);
    final anime = await catalog.load(HotSegment.topAnime);
    expect(source.animeTrendCalls, 1);
    expect(anime.items.map((item) => item.id), <int>[90]);
  });

  test(
    'one kind failing leaves the other; both failing fails the segment',
    () async {
      final source = FakeHotSource()..failPremieres = true;
      final catalog = NewAndHotCatalog(
        source,
        now: () => DateTime(2026, 9, 27),
      );
      final feed = await catalog.load(HotSegment.comingSoon);
      expect(feed.groups.single.items.single.id, 1);
      source.failUpcoming = true;
      await expectLater(catalog.load(HotSegment.comingSoon), throwsException);
    },
  );
}
