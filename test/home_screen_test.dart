import 'dart:async';

import 'package:raven23/catalog/home_feed_controller.dart';
import 'package:raven23/catalog/home_hero.dart';
import 'package:raven23/catalog/media_item.dart';
import 'package:raven23/catalog/up_next.dart';
import 'package:raven23/constants/app_constants.dart';
import 'package:raven23/constants/theme_data.dart';
import 'package:raven23/mobile/screens/home_screen.dart';
import 'package:raven23/mobile/screens/manga_screen.dart';
import 'package:raven23/mobile/widgets/category_section.dart';
import 'package:raven23/mobile/widgets/hero_card.dart';
import 'package:raven23/mobile/widgets/home_optional_row.dart';
import 'package:raven23/mobile/widgets/media_rows.dart';
import 'package:raven23/mobile/widgets/skeletons.dart';
import 'package:raven23/models/app_colors.dart';
import 'package:raven23/models/genres.dart';
import 'package:raven23/models/movie.dart';
import 'package:raven23/models/recently_watched.dart';
import 'package:raven23/models/tv.dart';
import 'package:raven23/manga/anilist/anilist_manga_service.dart';
import 'package:raven23/provider/app_dependency_provider.dart';
import 'package:raven23/provider/bookmark_provider.dart';
import 'package:raven23/provider/recently_watched_provider.dart';
import 'package:raven23/provider/settings_provider.dart';
import 'package:raven23/screens/common/update_screen.dart';
import 'package:raven23/widgets/hosted_ads_banner.dart';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'support/visibility_detector_test_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/scroll_until_built.dart';

MediaItem _item(MediaKind kind, int id) => kind == MediaKind.movie
    ? MediaItem.fromMovie(Movie(id: id, title: 'Movie $id'))
    : MediaItem.fromSeries(TV(id: id, name: 'Series $id'));

List<MediaItem> _movies(Iterable<int> ids) =>
    ids.map((id) => _item(MediaKind.movie, id)).toList();
List<MediaItem> _series(Iterable<int> ids) =>
    ids.map((id) => _item(MediaKind.series, id)).toList();

MediaItem _anime(int id) => MediaItem.fromSeries(
  TV(
    id: id,
    name: 'Anime $id',
    originalLanguage: 'ja',
    genreIds: <int>[16, 10759],
  ),
);

class _FakeSource implements HomeFeedSource {
  _FakeSource([this.fail = false]);

  bool fail;
  int loads = 0;

  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) async {
    loads++;
    if (fail) throw Exception('offline');
    // TMDB has no upcoming list for series.
    if (list == HomeList.upcoming && kind == MediaKind.series) {
      return const <MediaItem>[];
    }
    if (list == HomeList.topRatedAnime) return <MediaItem>[_anime(199)];
    if (list == HomeList.trendingAnime) return <MediaItem>[_anime(198)];
    if (list == HomeList.popularAnime) return <MediaItem>[_anime(197)];
    if (list == HomeList.newEpisodesAnime) return <MediaItem>[_anime(196)];
    final base = kind == MediaKind.movie ? 1 : 101;
    final ids = switch (list) {
      HomeList.trendingToday => <int>[base, base + 1, base + 2],
      HomeList.trendingWeek => <int>[base + 3, base + 4],
      HomeList.popular => <int>[base + 5],
      HomeList.topRated => <int>[base + 6],
      HomeList.newReleases => <int>[base + 7],
      HomeList.upcoming => <int>[base + 8],
      HomeList.trendingAnime => <int>[base + 9],
      HomeList.popularAnime => <int>[base + 10],
      HomeList.newEpisodesAnime => <int>[base + 11],
      HomeList.topRatedAnime => <int>[base + 12],
    };
    return kind == MediaKind.movie ? _movies(ids) : _series(ids);
  }

  @override
  Future<List<MediaItem>> service(MediaKind kind, int providerId) async =>
      !fail && providerId == 8
      ? (kind == MediaKind.movie ? _movies([40]) : _series([140]))
      : const <MediaItem>[];

  @override
  Future<List<MediaItem>> animeGenre(int genreId) async =>
      fail ? const <MediaItem>[] : <MediaItem>[_anime(600 + genreId)];

  @override
  Future<List<MediaItem>> animeService(int providerId) async {
    if (fail) return const <MediaItem>[];
    final items = await service(MediaKind.series, providerId);
    return items
        .where((item) => item.series?.isLikelyAnime == true)
        .toList(growable: false);
  }

  @override
  Future<List<Genres>> genres(MediaKind kind) async => const <Genres>[];

  @override
  Future<List<MediaItem>> discover(
    MediaKind kind, {
    required int page,
    required int year,
    required int genreId,
  }) async => const <MediaItem>[];

  @override
  Future<List<MediaItem>> genre(MediaKind kind, int genreId) async =>
      _movies([70, 71]);
}

class _DelayedMangaService extends AniListMangaService {
  _DelayedMangaService(this.gate, this.catalogue);

  final Completer<void> gate;
  final MangaCatalogue catalogue;

  @override
  Future<MangaCatalogue> home({MangaContentKind? kind, DateTime? now}) async {
    await gate.future;
    return catalogue;
  }
}

class _AnimeLeakSource extends _FakeSource {
  @override
  Future<List<MediaItem>> discover(
    MediaKind kind, {
    required int page,
    required int year,
    required int genreId,
  }) async => kind == MediaKind.series ? <MediaItem>[_anime(501)] : const [];

  @override
  Future<List<MediaItem>> service(MediaKind kind, int providerId) async =>
      kind == MediaKind.series && providerId == 8
      ? <MediaItem>[_anime(502)]
      : super.service(kind, providerId);
}

class _FakeRecent extends ChangeNotifier implements RecentProvider {
  _FakeRecent({List<RecentMovie> movies = const [], this.upNext = const []})
    : movies = List.of(movies);

  @override
  final List<RecentMovie> movies;
  @override
  final List<RecentEpisode> episodes = <RecentEpisode>[];
  @override
  final List<UpNext> upNext;

  @override
  Future<void> deleteMovie(int id) async {
    movies.removeWhere((movie) => movie.id == id);
    notifyListeners();
  }

  @override
  Future<void> addMovie(RecentMovie movie) async {
    movies.add(movie);
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBookmarks extends ChangeNotifier implements BookmarkProvider {
  @override
  List<Movie> movies = <Movie>[];
  @override
  List<TV> tvShows = <TV>[];

  @override
  bool isMovieBookmarked(int id) => movies.any((movie) => movie.id == id);
  @override
  bool isTVBookmarked(int id) => tvShows.any((series) => series.id == id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RecentMovie _recentMovie(int id) => RecentMovie(
  backdropPath: '/b.jpg',
  dateTime: DateTime.now().toString(),
  elapsed: 600,
  id: id,
  posterPath: null,
  releaseYear: 2024,
  remaining: 3000,
  title: 'Movie $id',
);

Future<void> _setUp() async {
  dotenv.testLoad(fileInput: 'RAVEN23_API_URL=https://example.com');
  SharedPreferences.setMockInitialValues(<String, Object>{});
  sharedPrefsSingleton = await SharedPreferences.getInstance();
}

ThemeData _theme(BuildContext context, String mode) => Styles.themeData(
  appThemeMode: mode,
  isM3Enabled: true,
  lightDynamicColor: null,
  darkDynamicColor: null,
  context: context,
  appColor: AppColorsList().appColors(mode != 'light').first,
);

Widget _app({
  required Widget child,
  RecentProvider? recent,
  BookmarkProvider? bookmarks,
  AppDependencyProvider? dependencies,
  String mode = 'dark',
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsProvider()),
    ChangeNotifierProvider(
      create: (_) => dependencies ?? AppDependencyProvider(),
    ),
    ChangeNotifierProvider<RecentProvider>.value(
      value: recent ?? _FakeRecent(),
    ),
    ChangeNotifierProvider<BookmarkProvider>.value(
      value: bookmarks ?? _FakeBookmarks(),
    ),
  ],
  child: Builder(
    builder: (context) => MaterialApp(
      theme: _theme(context, mode),
      home: Scaffold(body: child),
    ),
  ),
);

/// The rows Home would show for [feed], by what each is.
Future<List<Widget>> _rows(
  WidgetTester tester, {
  required HomeFilter filter,
  required HomeFeed feed,
  List<MediaItem> continueWatching = const [],
  List<MediaItem> myList = const [],
  MangaCatalogue? mangaCatalogue,
  Map<MangaContentKind, MangaCatalogue> mangaCatalogues =
      const <MangaContentKind, MangaCatalogue>{},
  MangaContentKind mangaKind = MangaContentKind.all,
}) async {
  late List<Widget> rows;
  await tester.pumpWidget(
    _app(
      child: Builder(
        builder: (context) {
          rows = homeRows(
            context,
            filter: filter,
            feed: feed,
            continueWatching: continueWatching,
            myList: myList,
            heroes: <HomeHero>[
              if (feed.hero case final hero?) HomeHero(item: hero),
            ],
            genresFor: (_) => const <String>[],
            onHeroShown: (_) {},
            loadCategory: (_) async => const <MediaItem>[],
            onOpenCategory: (_) {},
            onOpenService: (_) {},
            onOpenList: (_, __, ___) {},
            mangaCatalogue: mangaCatalogue,
            mangaCatalogues: mangaCatalogues,
            mangaKind: mangaKind,
            // Production MangaScreen supplies a navigator callback. The
            // row-builder fixture supplies a harmless callback so See All
            // wiring is exercised rather than accidentally disabled.
            onMangaSeeAll: (_, __) {},
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return rows;
}

String _describe(Widget row) => switch (row) {
  HeroCarousel() => 'hero',
  HomeAdSlot() => 'ad',
  HomeOptionalRow() => 'update',
  CategorySection() => 'category',
  ContinueRow(:final title) => title,
  TopTenRow(:final title) => title,
  PosterRow(:final title) => title ?? '',
  ServiceRow(:final title) => title,
  _ => row.runtimeType.toString(),
};

void main() {
  setUp(configureImmediateVisibilityUpdatesForTest);
  setUp(_setUp);

  test('Manga Home filter never queries the video catalogue', () async {
    final source = _FakeSource();
    final feed = await HomeFeedController(source).load(HomeFilter.manga);

    expect(feed.filter, HomeFilter.manga);
    expect(feed.isEmpty, isTrue);
    expect(HomeFilter.manga.kinds, isEmpty);
    expect(source.loads, 0);
  });

  testWidgets('Manga shows Home skeleton until uncached catalogues arrive', (
    tester,
  ) async {
    final gate = Completer<void>();
    final service = _DelayedMangaService(
      gate,
      MangaCatalogue(
        recentlyReleased: const <MangaTitle>[],
        trending: const <MangaTitle>[],
        popular: <MangaTitle>[
          MangaTitle(
            id: 800,
            title: 'Loaded Manga',
            coverUrl: null,
            popularity: 800,
          ),
        ],
        topRated: const <MangaTitle>[],
        action: const <MangaTitle>[],
        romance: const <MangaTitle>[],
      ),
    );

    await tester.pumpWidget(_app(child: MangaScreen(service: service)));
    expect(find.byType(HomeSkeleton), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HomeSkeleton), findsNothing);
    expect(find.byType(HeroCarousel), findsOneWidget);
  });

  testWidgets('Manga uses the shared Home row builder and keeps its own rows', (
    tester,
  ) async {
    MangaTitle title(int id) => MangaTitle(
      id: id,
      title: 'Manga $id',
      coverUrl: 'https://example.com/$id.jpg',
      bannerUrl: 'https://example.com/$id-banner.jpg',
      popularity: 1000 - id,
      trending: 500 - id,
      averageScore: 90 - id,
      startDate: '2026-01-01',
    );

    MangaCatalogue catalogue({required int base}) => MangaCatalogue(
      top10: <MangaTitle>[title(base)],
      recentlyReleased: <MangaTitle>[title(base + 1)],
      trending: <MangaTitle>[title(base + 2)],
      popular: <MangaTitle>[title(base + 3)],
      topRated: <MangaTitle>[title(base + 4)],
      upcoming: <MangaTitle>[title(base + 5)],
      completed: <MangaTitle>[title(base + 6)],
      action: <MangaTitle>[title(base + 7)],
      adventure: <MangaTitle>[title(base + 8)],
      comedy: <MangaTitle>[title(base + 9)],
      drama: <MangaTitle>[title(base + 10)],
      fantasy: <MangaTitle>[title(base + 11)],
      horror: <MangaTitle>[title(base + 12)],
      mystery: <MangaTitle>[title(base + 13)],
      romance: <MangaTitle>[title(base + 14)],
      sciFi: <MangaTitle>[title(base + 15)],
      supernatural: <MangaTitle>[title(base + 16)],
      sliceOfLife: <MangaTitle>[title(base + 17)],
    );

    final regions = <MangaContentKind, MangaCatalogue>{
      MangaContentKind.manga: catalogue(base: 101),
      MangaContentKind.manhwa: catalogue(base: 201),
      MangaContentKind.manhua: catalogue(base: 301),
    };
    final combined = MangaCatalogue.combine(regions.values);
    final rows = await _rows(
      tester,
      filter: HomeFilter.manga,
      feed: HomeFeed(
        filter: HomeFilter.manga,
        spotlight: <MediaItem>[
          MediaItem(
            kind: MediaKind.movie,
            id: 1,
            title: 'Manga 1',
            overview: '',
            posterPath: null,
            backdropPath: null,
            rating: 9,
            releaseDate: '2026-01-01',
            stableKey: 'manga:1',
            posterUrl: 'https://example.com/1.jpg',
          ),
        ],
      ),
      mangaCatalogue: combined,
      mangaCatalogues: regions,
    );

    expect(rows, hasLength(23)); // Hero + 22 All shelves.
    expect(rows.first, isA<HeroCarousel>());
    expect(rows.whereType<TopTenRow>(), hasLength(3));
    expect(rows.whereType<PosterRow>(), hasLength(19));
    expect(rows.whereType<ServiceRow>(), isEmpty);
    expect(rows.whereType<ContinueRow>(), isEmpty);
    expect(rows.whereType<CategorySection>(), isEmpty);
    expect(
      rows.whereType<PosterRow>().first.items.map((item) => item.id),
      containsAll(<int>[102, 202, 302]),
    );
    final mergedDrama = rows.whereType<PosterRow>().singleWhere(
      (row) => row.items.any((item) => item.id == 111),
    );
    expect(
      mergedDrama.items.map((item) => item.id),
      containsAll(<int>[111, 211, 311]),
    );
    expect(
      rows.whereType<TopTenRow>().every((row) => row.onSeeAll != null),
      isTrue,
    );
    expect(
      rows.whereType<PosterRow>().every((row) => row.onSeeAll != null),
      isTrue,
    );
    expect(
      rows.whereType<PosterRow>().where(
        (row) => (row.title ?? '').contains(' · '),
      ),
      hasLength(3),
      reason: 'All must keep three separate regional Trending rows',
    );

    // A catalogue being available to the Manga adapter must never inject
    // its titles into the regular Home (All) feed.
    final standardHomeRows = await _rows(
      tester,
      filter: HomeFilter.all,
      feed: HomeFeed(filter: HomeFilter.all),
      mangaCatalogue: combined,
      mangaCatalogues: regions,
    );
    expect(
      standardHomeRows
          .whereType<PosterRow>()
          .expand((row) => row.items)
          .any((item) => (item.stableKey ?? '').startsWith('manga:')),
      isFalse,
    );

    // A selected region still gets the same 18 Home shelves, but only its
    // own catalogue titles (no cross-region rows in a narrowed view).
    final manhwaRows = await _rows(
      tester,
      filter: HomeFilter.manga,
      feed: HomeFeed(filter: HomeFilter.manga),
      mangaCatalogue: regions[MangaContentKind.manhwa],
      mangaCatalogues: regions,
      mangaKind: MangaContentKind.manhwa,
    );
    expect(manhwaRows, hasLength(18));
    expect(manhwaRows.whereType<TopTenRow>(), hasLength(1));
    expect(
      manhwaRows.whereType<PosterRow>().first.items.single.stableKey,
      'manga:202',
    );
  });

  testWidgets('All: the rows in order, three ads spread down the page', (
    tester,
  ) async {
    final feed = await HomeFeedController(_FakeSource()).load(HomeFilter.all);
    final rows = await _rows(
      tester,
      filter: HomeFilter.all,
      feed: feed,
      continueWatching: _movies([90]),
      myList: _series([150]),
    );
    // Every chart comes as a pair, movies then series; only the viewer's
    // own rows hold both. One ad sits under the hero, two further down.
    expect(rows.map(_describe), <String>[
      'hero',
      'ad',
      'continue_watching',
      'top_10_movies_today',
      'top_10_series_today',
      'trending_movies_week',
      'trending_series_week',
      'trending_anime',
      'ad',
      'my_list',
      'new_movies',
      'new_episodes_series',
      'new_episodes_anime',
      'popular_movies',
      'popular_series',
      'popular_anime',
      'popular_series_on',
      'streaming_services',
      'top_rated_movies',
      'top_rated_series',
      'top_rated_anime',
      'upcoming_movies',
      'ad',
    ]);
    // Each slot carries its own ad-tag id, and the tab's own prefix.
    expect(rows.whereType<HomeAdSlot>().map((slot) => slot.placement), <String>[
      'home_all_hero',
      'home_all_trending',
      'home_all_genres',
    ]);
    // The mid-feed slot is the medium rectangle.
    expect(
      rows.whereType<HomeAdSlot>().map((slot) => slot.variant),
      <HostedBannerVariant>[
        HostedBannerVariant.standard,
        HostedBannerVariant.tall,
        HostedBannerVariant.standard,
      ],
    );
    // And no catalogue row mixes the two.
    for (final row in rows.whereType<PosterRow>()) {
      if (row.title == 'my_list') continue;
      expect(
        row.items.map((item) => item.kind).toSet(),
        hasLength(1),
        reason: row.title,
      );
    }
  });

  test(
    'Anime never leaks into Series through random discovery or services',
    () async {
      final source = _AnimeLeakSource();
      final controller = HomeFeedController(source);

      final seriesFeed = await controller.load(HomeFilter.series);
      expect(seriesFeed.trendingAnime, isEmpty);
      expect(seriesFeed.popularAnime, isEmpty);
      expect(seriesFeed.newEpisodesAnime, isEmpty);
      expect(seriesFeed.topRatedAnime, isEmpty);
      expect(
        seriesFeed.spotlight.every(
          (item) => item.series?.isLikelyAnime != true,
        ),
        isTrue,
      );
      expect(
        seriesFeed
            .of(MediaKind.series)
            .serviceShelves
            .every(
              (shelf) => shelf.items.every(
                (item) => item.series?.isLikelyAnime != true,
              ),
            ),
        isTrue,
      );

      final animeFeed = await controller.load(HomeFilter.anime);
      expect(animeFeed.trendingAnime, isNotEmpty);
      expect(
        animeFeed.spotlight.every((item) => item.series?.isLikelyAnime == true),
        isTrue,
      );
      expect(animeFeed.of(MediaKind.series).serviceShelves, isNotEmpty);
      expect(
        animeFeed
            .of(MediaKind.series)
            .serviceShelves
            .every(
              (shelf) => shelf.items.every(
                (item) => item.series?.isLikelyAnime == true,
              ),
            ),
        isTrue,
      );
    },
  );

  testWidgets('Anime page uses Home rows and each catalogue row has See All', (
    tester,
  ) async {
    final feed = await HomeFeedController(_FakeSource()).load(HomeFilter.anime);
    final rows = await _rows(tester, filter: HomeFilter.anime, feed: feed);
    expect(rows.first, isA<HeroCarousel>());
    expect(rows.whereType<TopTenRow>(), hasLength(1));
    expect(rows.whereType<TopTenRow>().single.title, 'top_10_anime');
    expect(rows.whereType<TopTenRow>().single.onSeeAll, isNotNull);
    expect(
      rows
          .whereType<PosterRow>()
          .where((row) => row.title != 'my_list')
          .every((row) => row.onSeeAll != null),
      isTrue,
    );
  });

  testWidgets('Movies and Series title their Top 10 for the kind', (
    tester,
  ) async {
    for (final (filter, title) in <(HomeFilter, String)>[
      (HomeFilter.movies, 'top_10_movies_today'),
      (HomeFilter.series, 'top_10_series_today'),
    ]) {
      final feed = await HomeFeedController(_FakeSource()).load(filter);
      final rows = await _rows(tester, filter: filter, feed: feed);
      expect(rows.map(_describe), contains(title));
      final top = rows.whereType<TopTenRow>().single;
      expect(top.onSeeAll, isNotNull);
      expect(
        top.items.every(
          (item) =>
              item.kind ==
              (filter == HomeFilter.movies
                  ? MediaKind.movie
                  : MediaKind.series),
        ),
        isTrue,
      );
    }
    // Series has no upcoming row.
    final series = await HomeFeedController(
      _FakeSource(),
    ).load(HomeFilter.series);
    final rows = await _rows(tester, filter: HomeFilter.series, feed: series);
    expect(rows.map(_describe), isNot(contains('upcoming_movies')));
  });

  testWidgets('a title shows in at most two of the first five rows', (
    tester,
  ) async {
    final feed = await HomeFeedController(_FakeSource()).load(HomeFilter.all);
    // Movie 1 is #1 today; put it in Continue Watching and My List too.
    final rows = await _rows(
      tester,
      filter: HomeFilter.all,
      feed: feed,
      continueWatching: _movies([1]),
      myList: _movies([1, 60]),
    );
    final myList = rows.whereType<PosterRow>().firstWhere(
      (row) => row.title == 'my_list',
    );
    expect(myList.items.map((item) => item.id), <int>[60]);
    expect(rows.whereType<TopTenRow>().first.items.first.id, 1);
  });

  testWidgets('loads, fades in, and switches filter', (tester) async {
    final source = _FakeSource();
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: source,
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HeroCarousel), findsOneWidget);
    final homeScroll = find
        .descendant(
          of: find.byType(CustomScrollView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    // Assert lazy Home shelves in the same top-to-bottom order in which
    // homeRows builds them; a forward-only scroll cannot revisit earlier rows.
    for (final label in <String>[
      'top_10_movies_today',
      'trending_anime',
      'new_episodes_series',
      'new_episodes_anime',
      'popular_anime',
      'top_rated_anime',
    ]) {
      await scrollUntilBuiltAndVisible(
        tester,
        homeScroll,
        find.text(label),
        delta: 240,
      );
    }

    // Return to the top after validating lower lazy slivers. The pinned
    // filter header remains interactive throughout this scroll.
    tester.state<ScrollableState>(homeScroll).position.jumpTo(0);
    await tester.pumpAndSettle();

    await tester.tap(find.text('movies'));
    await tester.pumpAndSettle();
    expect(find.text('top_rated_anime'), findsNothing);

    await tester.tap(find.text('filter_all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('series'));
    await tester.pumpAndSettle();
    tester.state<ScrollableState>(homeScroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('top_10_series_today'), findsOneWidget);
    expect(find.text('top_10_movies_today'), findsNothing);
    expect(find.text('top_rated_anime'), findsNothing);

    // Back to All: already loaded, so nothing is fetched again.
    final loads = source.loads;
    await tester.tap(find.text('filter_all'));
    await tester.pumpAndSettle();
    tester.state<ScrollableState>(homeScroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('top_10_movies_today'), findsOneWidget);
    expect(source.loads, loads);
  });

  testWidgets('update notice stays below filters and above the hero', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'RAVEN23',
      packageName: 'com.test.fq',
      version: '4.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    final dependencies = AppDependencyProvider()
      ..setUpdateConfiguration(
        forced: false,
        latestVersion: '4.2.0',
        latestBuild: 2,
        minimumBuild: 0,
        downloadUrl: 'https://example.com/update.apk',
        changeLog: '',
      );
    await tester.pumpWidget(
      _app(
        dependencies: dependencies,
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UpdateBottom), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(UpdateBottom)).dy,
      lessThan(tester.getTopLeft(find.byType(HeroCarousel)).dy),
    );
    expect(
      find.descendant(
        of: find.byType(UpdateBottom),
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );
  });

  testWidgets('the featured title stays put across a refresh', (tester) async {
    await tester.pumpWidget(
      _app(
        recent: _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]),
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    List<HomeHero> heroes() =>
        tester.widget<HeroCarousel>(find.byType(HeroCarousel)).heroes;
    final hero = heroes().first;
    expect(hero.continuing, isTrue);
    expect(hero.item.id, 90);
    // Then RAVEN23's spotlight: this week's trending.
    expect(heroes().length, greaterThan(1));

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(heroes().first.item.stableId, hero.item.stableId);
  });

  testWidgets('when nothing loads, a quiet message and Retry', (tester) async {
    final source = _FakeSource(true);
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: source,
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('home_load_failed'), findsOneWidget);

    source.fail = false;
    await tester.tap(find.text('retry'));
    await tester.pumpAndSettle();
    expect(find.byType(HeroCarousel), findsOneWidget);
  });

  for (final mode in <String>['dark', 'amoled', 'light']) {
    testWidgets('$mode: the accent only on the kicker and progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          mode: mode,
          recent: _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]),
          child: HomeScreen(
            source: _FakeSource(),
            findTint: null,
            showTitleLogos: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final accent = Theme.of(
        tester.element(find.byType(HomeScreen)),
      ).colorScheme.primary;
      // No text in the accent: the heroes' labels are white beside the
      // accented mark.
      final accentTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => text.style?.color == accent)
          .map((text) => text.data);
      expect(accentTexts, isEmpty);
      expect(find.text('CONTINUE_WATCHING'), findsOneWidget);
      expect(find.text('RAVEN23'), findsOneWidget);
      final accentIcons = tester
          .widgetList<Icon>(find.byType(Icon))
          .where((icon) => icon.color == accent);
      expect(accentIcons, isEmpty);
    });
  }

  for (final size in const <Size>[
    Size(600, 960),
    Size(768, 1024),
    Size(1024, 768),
    Size(1366, 1024),
  ]) {
    testWidgets(
      'a $size tablet, large text, right to left: nothing overflows',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: _app(
              recent: _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]),
              bookmarks: _FakeBookmarks()..movies = <Movie>[Movie(id: 60)],
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: HomeScreen(
                  source: _FakeSource(),
                  findTint: null,
                  showTitleLogos: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 12; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        expect(find.text('upcoming_movies'), findsOneWidget);
      },
    );
  }

  testWidgets('a small phone, large text, right to left: nothing overflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 780),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _app(
          recent: _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]),
          bookmarks: _FakeBookmarks()..movies = <Movie>[Movie(id: 60)],
          // Inside the app, whose own locale would otherwise set the
          // direction.
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: HomeScreen(
              source: _FakeSource(),
              findTint: null,
              showTitleLogos: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Scroll the whole page through so every row is laid out.
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('upcoming_movies'), findsOneWidget);
  });

  testWidgets('the hero turns on its own, and holds while touched', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final heroes = tester
        .widget<HeroCarousel>(find.byType(HeroCarousel))
        .heroes;
    expect(heroes.length, greaterThan(1));
    String shown() => tester
        .widget<HeroCard>(find.byType(HeroCard).hitTestable().first)
        .hero
        .item
        .stableId;
    expect(shown(), heroes[0].item.stableId);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(shown(), heroes[1].item.stableId);

    // A finger on the card: no turn.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HeroCarousel)),
    );
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(shown(), heroes[1].item.stableId);
    // Let go without tapping, which would open the title.
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('random genre rows close the page', (tester) async {
    final feed = HomeFeed(
      filter: HomeFilter.movies,
      categories: <HomeCategory>[
        for (final layout in CategoryLayout.values)
          HomeCategory(
            kind: MediaKind.movie,
            genre: Genres(genreID: layout.index, genreName: layout.name),
            layout: layout,
          ),
      ],
    );
    final rows = await _rows(tester, filter: HomeFilter.movies, feed: feed);
    expect(
      rows.reversed.take(CategoryLayout.values.length).map(_describe),
      everyElement('category'),
    );

    // Each layout lays out without trouble on a phone.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final section in rows.whereType<CategorySection>()) {
      await tester.pumpWidget(
        _app(
          child: SingleChildScrollView(
            child: CategorySection(
              category: section.category,
              load: () async => _movies([1, 2, 3, 4, 5, 6, 7, 8]),
              onSeeAll: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(section.category.genre.genreName!), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('under All, a genre row says which kind it is', (tester) async {
    final feed = HomeFeed(
      filter: HomeFilter.all,
      categories: <HomeCategory>[
        HomeCategory(
          kind: MediaKind.series,
          genre: Genres(genreID: 18, genreName: 'Drama'),
          layout: CategoryLayout.posters,
        ),
      ],
    );
    final all = await _rows(tester, filter: HomeFilter.all, feed: feed);
    expect(all.whereType<CategorySection>().single.kicker, 'series');
    final series = await _rows(
      tester,
      filter: HomeFilter.series,
      feed: HomeFeed(filter: HomeFilter.series, categories: feed.categories),
    );
    expect(series.whereType<CategorySection>().single.kicker, isNull);
  });

  testWidgets('a flick sideways moves the hero on, and back', (tester) async {
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final heroes = tester
        .widget<HeroCarousel>(find.byType(HeroCarousel))
        .heroes;
    String shown() => tester
        .widget<HeroCard>(find.byType(HeroCard).hitTestable().last)
        .hero
        .item
        .stableId;
    await tester.fling(find.byType(HeroCarousel), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(shown(), heroes[1].item.stableId);
    // Mid-crossfade both cards are there, one fading over the other.
    await tester.fling(find.byType(HeroCarousel), const Offset(300, 0), 1000);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HeroCard), findsNWidgets(2));
    await tester.pumpAndSettle();
    expect(shown(), heroes[0].item.stableId);
  });

  testWidgets('the page takes the hero\'s colour as it turns', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(
      _app(
        child: HomeScreen(
          source: _PosterSource(),
          findTint: (url) async {
            asked.add(url);
            return const Color(0xFF2D5BD6);
          },
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Looked up outside build, as the hero is first shown, without error.
    expect(asked, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(asked, hasLength(2));
  });

  testWidgets('Continue Watching: ⋮ offers Resume, Details and Remove, '
      'with Undo', (tester) async {
    final recent = _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]);
    await tester.pumpWidget(
      _app(
        recent: recent,
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('more_options'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('more_options'));
    await tester.pumpAndSettle();
    expect(find.text('resume_title'), findsWidgets);
    expect(find.text('details'), findsOneWidget);
    // A movie has no episodes to pick.
    expect(find.text('episodes'), findsNothing);

    await tester.tap(find.text('remove_from_row'));
    await tester.pumpAndSettle();
    expect(recent.movies, isEmpty);
    expect(find.byType(ContinueRow), findsNothing);
    expect(find.text('removed_from_row'), findsOneWidget);

    await tester.tap(find.text('undo'));
    await tester.pumpAndSettle();
    expect(recent.movies.single.id, 90);
    expect(find.byType(ContinueRow), findsOneWidget);
  });

  testWidgets("a series' next episode shows as one, and plays as one", (
    tester,
  ) async {
    final next = UpNext(
      seriesId: 7,
      seriesName: 'Severance',
      finishedSeason: 2,
      finishedEpisode: 4,
      season: 2,
      episode: 5,
      backdropPath: '/b.jpg',
      watchedAt: DateTime.now(),
    );
    await tester.pumpWidget(
      _app(
        recent: _FakeRecent(upNext: <UpNext>[next]),
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // It leads the hero, offering the episode itself.
    final hero = tester
        .widget<HeroCarousel>(find.byType(HeroCarousel))
        .heroes
        .first;
    expect(hero.item.upNext?.label, 'S2:E5');
    expect(find.text('play_episode'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byTooltip('more_options'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('S2:E5'), findsWidgets);
    expect(find.textContaining('next_episode'), findsOneWidget);
    await tester.tap(find.byTooltip('more_options'));
    await tester.pumpAndSettle();
    expect(find.text('episodes'), findsOneWidget);
  });

  testWidgets('targets are 48 dp and labelled', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        recent: _FakeRecent(movies: <RecentMovie>[_recentMovie(90)]),
        bookmarks: _FakeBookmarks()..movies = <Movie>[Movie(id: 60)],
        child: HomeScreen(
          source: _FakeSource(),
          findTint: null,
          showTitleLogos: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}

/// Like [_FakeSource], with posters, so the hero has artwork to take a
/// colour from.
class _PosterSource extends _FakeSource {
  @override
  Future<List<MediaItem>> list(MediaKind kind, HomeList list) async =>
      (await super.list(kind, list))
          .map(
            (item) => MediaItem(
              kind: item.kind,
              id: item.id,
              title: item.title,
              overview: '',
              posterPath: '/p${item.id}.jpg',
              backdropPath: null,
              rating: null,
              releaseDate: null,
            ),
          )
          .toList();
}
