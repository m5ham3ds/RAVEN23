import 'dart:async';

import 'package:raven23/catalog/catalog_controller.dart';
import 'package:raven23/catalog/media_item.dart';
import 'package:raven23/catalog/media_search.dart';
import 'package:raven23/constants/app_constants.dart';
import 'package:raven23/mobile/app/mobile_nav_bar.dart';
import 'package:raven23/mobile/app/mobile_shell.dart';
import 'package:raven23/mobile/app/mobile_tabs.dart';
import 'package:raven23/mobile/screens/search_screen.dart';
import 'package:raven23/mobile/widgets/category_section.dart';
import 'package:raven23/mobile/widgets/poster_card.dart';
import 'package:raven23/models/genres.dart';
import 'package:raven23/models/movie.dart';
import 'package:raven23/models/person.dart';
import 'package:raven23/models/tv.dart';
import 'package:raven23/preferences/setting_preferences.dart';
import 'package:raven23/provider/app_dependency_provider.dart';
import 'package:raven23/provider/settings_provider.dart';
import 'package:raven23/services/app_session_state_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'support/visibility_detector_test_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

MediaItem _movie(int id, String title, {num popularity = 1}) =>
    MediaItem.fromMovie(Movie(id: id, title: title, popularity: popularity));
MediaItem _series(
  int id,
  String title, {
  num popularity = 1,
  bool anime = false,
}) => MediaItem.fromSeries(
  TV(
    id: id,
    name: title,
    popularity: popularity,
    originalLanguage: anime ? 'ja' : 'en',
    genreIds: anime ? <int>[16, 10759] : <int>[18],
  ),
);

/// Answers from a small catalogue; a query can be held back to arrive late.
class _FakeSource implements SearchSource {
  final List<String> asked = <String>[];
  final Map<String, Completer<void>> held = <String, Completer<void>>{};

  Future<void> _wait(String query) async => held[query]?.future;

  @override
  Future<List<MediaItem>> movies(String query) async {
    asked.add(query);
    await _wait(query);
    return <MediaItem>[
      if ('dune'.startsWith(query.toLowerCase()))
        _movie(1, 'Dune', popularity: 90),
      if ('dune'.startsWith(query.toLowerCase()))
        _movie(2, 'Dune: Part Two', popularity: 99),
      if (query.toLowerCase() == 'du') _movie(3, 'Duel'),
    ];
  }

  @override
  Future<List<MediaItem>> series(String query) async {
    await _wait(query);
    return <MediaItem>[
      if ('dune'.startsWith(query.toLowerCase())) ...<MediaItem>[
        _series(4, 'Dune: Prophecy', popularity: 50),
        _series(5, 'Dune Anime', popularity: 60, anime: true),
      ],
    ];
  }

  @override
  Future<List<Person>> people(String query) async {
    await _wait(query);
    return <Person>[
      if ('dune'.startsWith(query.toLowerCase()))
        Person(id: 9, name: 'Denis Villeneuve'),
    ];
  }
}

Future<SearchSuggestions> _suggestions() async => SearchSuggestions(
  topSearches: <MediaItem>[_movie(50, 'Top Movie'), _series(51, 'Top')],
  movieGenres: <Genres>[
    Genres(genreID: 35, genreName: 'Comedy'),
    Genres(genreID: 28, genreName: 'Action'),
  ],
  seriesGenres: <Genres>[Genres(genreID: 18, genreName: 'Drama')],
  animeGenres: <Genres>[
    Genres(genreID: 10759, genreName: 'Action & Adventure'),
  ],
);

late SharedPreferences _prefs;

Future<void> _setUp() async {
  dotenv.testLoad(fileInput: 'RAVEN23_API_URL=https://example.com');
  SharedPreferences.setMockInitialValues(<String, Object>{});
  _prefs = await SharedPreferences.getInstance();
  sharedPrefsSingleton = _prefs;
}

Widget _app(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsProvider()),
    ChangeNotifierProvider(create: (_) => AppDependencyProvider()),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

Future<List<MediaItem>> _pumpSearch(
  WidgetTester tester,
  _FakeSource source,
) async {
  final opened = <MediaItem>[];
  await tester.pumpWidget(
    _app(
      SearchScreen(
        source: source,
        loadSuggestions: _suggestions,
        openTitle: (_, item) => opened.add(item),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<List<String>> _recents() => SettingsPreferences().getRecentSearches();

void main() {
  setUp(configureImmediateVisibilityUpdatesForTest);
  setUp(_setUp);

  test('the top result is the exact match, else the most popular prefix', () {
    final movies = <MediaItem>[
      _movie(1, 'Dune', popularity: 90),
      _movie(2, 'Dune: Part Two', popularity: 99),
    ];
    final series = <MediaItem>[_series(4, 'Dune: Prophecy', popularity: 50)];
    expect(
      MediaSearch.topResultFor('dune', movies: movies, series: series)?.id,
      1,
    );
    expect(
      MediaSearch.topResultFor('dune part', movies: movies, series: series)?.id,
      2,
    );
    expect(
      MediaSearch.topResultFor('arrakis', movies: movies, series: series),
      isNull,
    );
    expect(MediaSearch.normalize('  Dune:  Part Two! '), 'dune part two');
    expect(
      MediaSearch.topResultFor(
        'dune anime',
        movies: const <MediaItem>[],
        series: const <MediaItem>[],
        anime: <MediaItem>[_series(5, 'Dune Anime', anime: true)],
      )?.id,
      5,
    );
  });

  testWidgets('a burst of typing sends one search, after the pause', (
    tester,
  ) async {
    final source = _FakeSource();
    await _pumpSearch(tester, source);
    for (final text in <String>['d', 'du', 'dun', 'dune']) {
      await _type(tester, text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(source.asked, isEmpty);
    await tester.pump(MediaSearch.debounce);
    await tester.pumpAndSettle();
    expect(source.asked, <String>['dune']);
    expect(find.text('top_result'), findsOneWidget);
  });

  testWidgets('Anime genres are shown as a separate genre section', (
    tester,
  ) async {
    final source = _FakeSource();
    await _pumpSearch(tester, source);
    expect(find.text('movie_genres'), findsOneWidget);
    expect(find.text('series_genres'), findsOneWidget);
    expect(find.text('anime_genres'), findsOneWidget);
    expect(find.text('Action & Adventure'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
  });

  test('Anime genre collections retain their own label and episodic kind', () {
    final settings = SettingsProvider();
    final dependencies = AppDependencyProvider();
    final collection = const CatalogController().genreCollection(
      kind: MediaKind.series,
      genre: Genres(genreID: 10759, genreName: 'Action & Adventure'),
      animeOnly: true,
      settings: settings,
      dependencies: dependencies,
    );
    expect(collection.id, 'anime-genre-10759');
    expect(collection.kicker, 'ANIME_GENRE');
    expect(collection.title, 'Action & Adventure');
    settings.dispose();
    dependencies.dispose();
  });

  testWidgets('one letter never searches', (tester) async {
    final source = _FakeSource();
    await _pumpSearch(tester, source);
    await _type(tester, 'd');
    await tester.pump(const Duration(seconds: 1));
    expect(source.asked, isEmpty);
    // The start page stays.
    expect(find.text('top_searches'), findsOneWidget);
  });

  testWidgets('an answer to an old query is dropped', (tester) async {
    final source = _FakeSource()..held['du'] = Completer<void>();
    await _pumpSearch(tester, source);
    await _type(tester, 'du');
    await tester.pump(MediaSearch.debounce);
    await _type(tester, 'dune');
    await tester.pump(MediaSearch.debounce);
    await tester.pumpAndSettle();
    expect(find.text('Duel'), findsNothing);

    // The old query answers last; it doesn't replace the new results.
    source.held['du']!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Duel'), findsNothing);
    expect(find.text('top_result'), findsOneWidget);
  });

  testWidgets('the last results stay up while the next query loads', (
    tester,
  ) async {
    final source = _FakeSource()..held['dun'] = Completer<void>();
    await _pumpSearch(tester, source);
    await _type(tester, 'dune');
    await tester.pump(MediaSearch.debounce);
    await tester.pumpAndSettle();
    await _type(tester, 'dun');
    await tester.pump(MediaSearch.debounce);
    await tester.pump();
    expect(find.text('top_result'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    source.held['dun']!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a search is remembered on submit or on opening a result only', (
    tester,
  ) async {
    final source = _FakeSource();
    final opened = await _pumpSearch(tester, source);
    await _type(tester, 'dune');
    await tester.pump(MediaSearch.debounce);
    await tester.pumpAndSettle();
    expect(await _recents(), isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(await _recents(), <String>['dune']);

    await SettingsPreferences().clearRecentSearches();
    await tester.tap(find.byType(FeatureCard));
    await tester.pumpAndSettle();
    expect(opened.single.id, isNotNull);
    expect(await _recents(), <String>['dune']);
  });

  testWidgets('search exposes five filters and separates Anime from Series', (
    tester,
  ) async {
    final source = _FakeSource();
    await _pumpSearch(tester, source);
    await _type(tester, 'dune');
    await tester.pump(MediaSearch.debounce);
    await tester.pumpAndSettle();

    for (final label in <String>[
      'filter_all',
      'movies',
      'series',
      'anime',
      'people',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.text('anime').first);
    await tester.pumpAndSettle();
    final shown = tester
        .widgetList<PosterCard>(find.byType(PosterCard))
        .map((card) => card.item)
        .toList();
    expect(shown, hasLength(1));
    expect(shown.single.title, 'Dune Anime');
    expect(shown.single.kind, MediaKind.series);

    await tester.tap(find.text('series').first);
    await tester.pumpAndSettle();
    final seriesShown = tester
        .widgetList<PosterCard>(find.byType(PosterCard))
        .map((card) => card.item)
        .toList();
    expect(seriesShown, hasLength(1));
    expect(seriesShown.single.title, 'Dune: Prophecy');
  });

  testWidgets('filter chips narrow the results', (tester) async {
    final source = _FakeSource();
    await _pumpSearch(tester, source);
    await _type(tester, 'dune');
    await tester.pump(MediaSearch.debounce);
    await tester.pumpAndSettle();
    expect(find.text('movies'), findsWidgets);

    await tester.tap(find.text('series').first);
    await tester.pumpAndSettle();
    expect(find.text('Dune: Prophecy'), findsNothing); // poster, no caption
    final kinds = tester
        .widgetList<PosterCard>(find.byType(PosterCard))
        .map((card) => card.item.kind)
        .toSet();
    expect(kinds, <MediaKind>{MediaKind.series});
    expect(find.text('top_result'), findsNothing);

    await tester.tap(find.text('people'));
    await tester.pumpAndSettle();
    expect(find.byType(PosterCard), findsNothing);
    expect(find.text('Denis Villeneuve'), findsOneWidget);
  });

  testWidgets('nothing found: say so, and suggest genres that match', (
    tester,
  ) async {
    await _pumpSearch(tester, _FakeSource());
    await _type(tester, 'com');
    await tester.pump(MediaSearch.debounce);
    await tester.pumpAndSettle();
    expect(find.text('no_matches_for'), findsOneWidget);
    expect(find.text('Comedy · movies'), findsOneWidget);
    expect(find.textContaining('Action'), findsNothing);
    expect(find.text('top_searches'), findsOneWidget);
  });

  testWidgets('recent searches: tap to search, long press to forget, Clear', (
    tester,
  ) async {
    await SettingsPreferences().addRecentSearch('Severance');
    await SettingsPreferences().addRecentSearch('dune');
    final source = _FakeSource();
    await _pumpSearch(tester, source);
    expect(find.text('Severance'), findsOneWidget);

    await tester.longPress(find.text('Severance'));
    await tester.pumpAndSettle();
    expect(find.text('Severance'), findsNothing);
    expect(await _recents(), <String>['dune']);

    await tester.tap(find.text('dune'));
    await tester.pump(MediaSearch.debounce);
    await tester.pumpAndSettle();
    expect(source.asked, <String>['dune']);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('clear'));
    await tester.pumpAndSettle();
    expect(await _recents(), isEmpty);
  });

  testWidgets('coming back from a result finds the page as it was', (
    tester,
  ) async {
    final source = _FakeSource();
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => SearchScreen(
            source: source,
            loadSuggestions: _suggestions,
            openTitle: (context, item) => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('details')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _type(tester, 'dune');
    await tester.pump(MediaSearch.debounce);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(offset, greaterThan(0));

    await tester.tap(find.byType(PosterCard).first);
    await tester.pumpAndSettle();
    expect(find.text('details'), findsOneWidget);
    Navigator.of(tester.element(find.text('details'))).pop();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'dune'), findsOneWidget);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      offset,
    );
    expect(source.asked, <String>['dune']);
  });

  testWidgets('the field opens on arriving at the tab, not at launch', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> pumpShell(String? startOn) async {
      if (startOn != null) {
        await _prefs.setString(
          AppSessionStateStore.handheldDestinationKey,
          startOn,
        );
      }
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: ChangeNotifierProvider(
            create: (_) => AppDependencyProvider(),
            child: MaterialApp(
              home: MobileShell(
                preferences: _prefs,
                tabBuilders: <MobileTab, WidgetBuilder>{
                  MobileTab.home: (_) => const SizedBox(),
                  MobileTab.search: (_) => SearchScreen(
                    source: _FakeSource(),
                    loadSuggestions: _suggestions,
                  ),
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool fieldFocused() => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;

    await pumpShell('search');
    expect(fieldFocused(), isFalse);
    await tester.pumpWidget(const SizedBox());

    await pumpShell('home');
    // Search is a secondary destination. Open the real overflow dock first,
    // then select Search as a user would from the production navigation.
    await tester.tap(
      find.descendant(
        of: find.byType(MobileNavBar),
        matching: find.byKey(const ValueKey<String>('mobile-nav-menu-toggle')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MobileNavBar),
        matching: find.text('search'),
      ),
    );
    await tester.pumpAndSettle();
    expect(fieldFocused(), isTrue);
  });

  for (final size in const <Size>[Size(768, 1024), Size(1024, 768)]) {
    testWidgets('a $size tablet, 1.3 text, right to left: nothing overflows', (
      tester,
    ) async {
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
            Directionality(
              textDirection: TextDirection.rtl,
              child: SearchScreen(
                source: _FakeSource(),
                loadSuggestions: _suggestions,
                openTitle: (_, __) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Suggestions, then results, then no results.
      expect(tester.takeException(), isNull);
      for (final query in <String>['dune', 'zzzzzz']) {
        await _type(tester, query);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('targets are 48 dp and labelled', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        SearchScreen(
          source: _FakeSource(),
          loadSuggestions: _suggestions,
          openTitle: (_, __) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
