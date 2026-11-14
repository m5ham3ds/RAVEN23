import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/catalog_controller.dart';
import '../../catalog/continue_watching.dart';
import '../../catalog/home_feed_controller.dart';
import '../../catalog/home_hero.dart';
import '../../catalog/home_rows.dart';
import '../../catalog/media_item.dart';
import '../../catalog/title_logos.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../models/genres.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/downloads_screen.dart';
import '../../screens/common/live_tv_screen.dart';
import '../../screens/common/update_screen.dart';
import '../../services/ambient_theme_service.dart';
import '../../widgets/common_widgets.dart' show AppStreamingService;
import '../app/mobile_tabs.dart';
import '../collections.dart';
import '../my_list.dart';
import '../widgets/filter_chips.dart';
import '../widgets/genre_sheet.dart';
import '../widgets/hero_card.dart';
import '../widgets/home_header.dart';
import '../widgets/home_optional_row.dart';
import '../widgets/home_page_frame.dart';
import '../widgets/media_art.dart';
import '../widgets/page_kit.dart' show EmptyState;
import '../widgets/plus_card.dart';
import '../widgets/skeletons.dart';
import 'collection_screen.dart';

export '../../catalog/home_rows.dart' show HomeAdSlot, homeRows;

/// Finds a colour to tint the top of Home with, from an image URL.
typedef TintFinder = Future<Color?> Function(String imageUrl);

/// The phone's Home: a featured title, then rows of what to watch next, all
/// narrowed by the filter chips at the top.
///
/// Each filter's rows are fetched once and kept for the session; pulling down
/// refreshes the rows on show but not the featured title, which stays put so
/// the page doesn't shift under the viewer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    this.source,
    this.findTint = DominantImageColor.extract,
    this.showTitleLogos = true,
    this.now,
    this.initialFilter,
    super.key,
  });

  /// Where the rows come from; TMDB by default.
  final HomeFeedSource? source;
  final TintFinder? findTint;

  /// Whether to look up logo artwork for the featured title.
  final bool showTitleLogos;

  /// The time the featured-title rules are judged at, for tests.
  final DateTime Function()? now;

  /// The catalogue subset opened by a secondary navigation destination.
  final HomeFilter? initialFilter;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late HomeFilter _filter;
  bool _started = false;

  /// Fades the rows in on a new filter; the outgoing rows just go, as the
  /// tabs do, so there is never two pages' worth of rows to draw.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  final Map<HomeFilter, HomeFeed> _feeds = <HomeFilter, HomeFeed>{};
  final Map<HomeFilter, Future<void>> _loading = <HomeFilter, Future<void>>{};
  final Set<HomeFilter> _failed = <HomeFilter>{};
  final Map<HomeFilter, List<HomeHero>> _heroes =
      <HomeFilter, List<HomeHero>>{};
  final Map<String, Color?> _tints = <String, Color?>{};

  /// The colour of the hero on show, washing down the top of the page. A
  /// notifier, so the hero turning doesn't rebuild the rows.
  final ValueNotifier<Color?> _tint = ValueNotifier<Color?>(null);
  MediaItem? _shownHero;

  /// Each category row's titles, fetched once for the session.
  final Map<String, Future<List<MediaItem>>> _categoryItems =
      <String, Future<List<MediaItem>>>{};
  MobileTabController? _tabs;
  MobileTab? _resetTab;
  TitleLogos? _logos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = MobileTabScope.maybeOf(context);
    if (!identical(tabs, _tabs)) {
      final oldResetTab = _resetTab;
      if (oldResetTab != null) _tabs?.removeResetListener(oldResetTab, _reset);
      _tabs = tabs;
    }
    if (!_started) {
      _started = true;
      _filter =
          widget.initialFilter ??
          (tabs == null
              ? HomeFilter.all
              : MobileTab.filterFor(tabs.current) == HomeFilter.all
              ? tabs.initialHomeFilter
              : MobileTab.filterFor(tabs.current));
      _resetTab = _tabForFilter(_filter);
      _tabs?.addResetListener(_resetTab!, _reset);
      _load(_filter);
    }
    if (widget.showTitleLogos) _logos = _logosFor(context);
  }

  @override
  void dispose() {
    final resetTab = _resetTab;
    if (resetTab != null) _tabs?.removeResetListener(resetTab, _reset);
    _logos?.dispose();
    _fade.dispose();
    _tint.dispose();
    super.dispose();
  }

  /// Logos found this session; a new language or proxy starts over, since
  /// both change what TMDB returns.
  TitleLogos _logosFor(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();
    final current = _logos;
    if (current != null &&
        current.language == TitleLogos.languageCode(settings.appLanguage) &&
        current.proxyEnabled == settings.enableProxy &&
        current.proxyUrl == dependencies.tmdbProxy) {
      return current;
    }
    current?.dispose();
    return TitleLogos(
      language: settings.appLanguage,
      proxyEnabled: settings.enableProxy,
      proxyUrl: dependencies.tmdbProxy,
    );
  }

  HomeFeedSource _source() =>
      widget.source ??
      CatalogHomeFeedSource(
        settings: context.read<SettingsProvider>(),
        dependencies: context.read<AppDependencyProvider>(),
      );

  HomeFeedController _controller() => HomeFeedController(_source());

  Future<List<MediaItem>> _category(HomeCategory category) =>
      _categoryItems.putIfAbsent(
        '${category.kind.name}-${category.animeOnly}-${category.genre.genreID}',
        () =>
            (category.animeOnly
                    ? _source().animeGenre(category.genre.genreID!)
                    : _source().genre(category.kind, category.genre.genreID!))
                .then((items) {
                  if (category.kind != MediaKind.series) return items;
                  return items
                      .where(
                        (item) => category.animeOnly
                            ? item.series?.isLikelyAnime == true
                            : item.series?.isLikelyAnime != true,
                      )
                      .toList(growable: false);
                })
                .catchError((Object _) => const <MediaItem>[]),
      );

  void _openCategory(HomeCategory category) {
    if (!category.animeOnly) {
      openGenreCollection(
        context,
        category.kind,
        category.genre,
        excludeAnime: category.kind == MediaKind.series,
      );
      return;
    }
    final catalog = const CatalogController();
    _openCollection(
      catalog.genreCollection(
        kind: MediaKind.series,
        genre: category.genre,
        animeOnly: true,
        settings: context.read<SettingsProvider>(),
        dependencies: context.read<AppDependencyProvider>(),
      ),
    );
  }

  Future<void> _load(HomeFilter filter) {
    _failed.remove(filter);
    return _loading[filter] = _controller()
        .load(filter)
        .then(
          (feed) {
            if (!mounted) return;
            final first = _feeds[filter] == null;
            setState(() {
              if (feed.isEmpty && first) {
                _failed.add(filter);
              } else if (!feed.isEmpty) {
                _feeds[filter] = feed;
              }
            });
            if (first && filter == _filter) _fade.forward(from: 0);
          },
          onError: (Object _) {
            if (mounted && _feeds[filter] == null) {
              setState(() => _failed.add(filter));
            }
          },
        );
  }

  static MobileTab _tabForFilter(HomeFilter filter) => switch (filter) {
    HomeFilter.all => MobileTab.home,
    HomeFilter.movies => MobileTab.movies,
    HomeFilter.series => MobileTab.series,
    HomeFilter.anime => MobileTab.anime,
    HomeFilter.manga => MobileTab.manga,
  };

  void _select(HomeFilter filter) {
    final destination = _tabForFilter(filter);
    if (_tabs != null && _tabs!.current != destination) {
      _tabs!.select(destination);
      return;
    }
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _fade.forward(from: 0);
    if (!_feeds.containsKey(filter) && !_failed.contains(filter)) {
      _load(filter);
    }
  }

  /// Reselecting a category returns to that category's first view.
  void _reset() => _select(widget.initialFilter ?? HomeFilter.all);

  Future<void> _refresh() => _load(_filter);

  /// Back to the skeleton while the failed filter loads again.
  void _retry() {
    setState(() => _failed.remove(_filter));
    _load(_filter);
  }

  List<MediaItem> _continueWatching(BuildContext context) {
    final recent = context.watch<RecentProvider?>();
    if (recent == null) return const <MediaItem>[];
    return continueWatchingItems(
      movies: recent.movies,
      episodes: recent.episodes,
      upNext: recent.upNext,
      filter: _filter,
    );
  }

  /// The hero's titles for the current filter, chosen once.
  List<HomeHero> _heroesFor(HomeFeed feed, List<MediaItem> continueWatching) =>
      _heroes.putIfAbsent(
        _filter,
        () => chooseHomeHeroes(
          filter: _filter,
          feed: feed,
          continueWatching: continueWatching,
          now: widget.now?.call(),
        ),
      );

  void _onHeroShown(HomeHero hero) {
    _shownHero = hero.item;
    _tint.value = _tints[hero.item.stableId];
    _findTint(hero.item);
  }

  void _findTint(MediaItem item) {
    final findTint = widget.findTint;
    final key = item.stableId;
    if (findTint == null || _tints.containsKey(key)) return;
    _tints[key] = null;
    // Called as the hero turns, outside build.
    final url = tmdbImageUrl(
      context,
      item.posterPath ?? item.backdropPath,
      size: 'w185/',
      listen: false,
    );
    if (url == null) return;
    findTint(url).then((color) {
      if (!mounted || color == null) return;
      _tints[key] = color;
      if (_shownHero?.stableId == key) _tint.value = color;
    }, onError: (Object _) {});
  }

  MediaCollection _translated(
    MediaCollection collection,
    String kicker, {
    String? adPlacement,
  }) => MediaCollection(
    id: collection.id,
    title: collection.title,
    kicker: kicker.toUpperCase(),
    logoAsset: collection.logoAsset,
    adPlacement: adPlacement ?? collection.adPlacement,
    adFree: collection.adFree,
    loadPage: collection.loadPage,
  );

  Future<void> _openCollection(MediaCollection collection) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CollectionScreen(collection: collection),
        ),
      );

  /// A row's whole list, from its "See all".
  void _openList(MediaKind kind, HomeList list, String title) {
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();
    final catalog = const CatalogController();
    final source = CatalogHomeFeedSource(
      settings: settings,
      dependencies: dependencies,
    );
    final MediaCollection collection;
    if (list == HomeList.trendingAnime) {
      // Keep the See all page on the same composite, anime-filtered source as
      // the Home row instead of falling back to an unfiltered popularity URL.
      collection = catalog.trendingAnimeCollection(
        title: title,
        settings: settings,
        dependencies: dependencies,
      );
    } else {
      final url = source.urlFor(kind, list);
      if (url == null) return;
      collection = catalog.listCollection(
        id: 'home-${kind.name}-${list.name}',
        kind: kind,
        url: url,
        title: title,
        kicker:
            ((list == HomeList.trendingAnime ||
                        list == HomeList.popularAnime ||
                        list == HomeList.newEpisodesAnime ||
                        list == HomeList.topRatedAnime)
                    ? tr('anime')
                    : kind == MediaKind.movie
                    ? tr('movies')
                    : tr('series'))
                .toUpperCase(),
        settings: settings,
        dependencies: dependencies,
        animeOnly:
            list == HomeList.popularAnime ||
            list == HomeList.newEpisodesAnime ||
            list == HomeList.topRatedAnime,
        excludeAnime:
            kind == MediaKind.series &&
            list != HomeList.popularAnime &&
            list != HomeList.newEpisodesAnime &&
            list != HomeList.topRatedAnime,
        // The placements of the old Movies and Series list pages.
        adPlacement: kind == MediaKind.movie ? 'movie_list' : 'tv_list',
      );
    }
    _openCollection(collection);
  }

  /// Every streaming service opens separate Movies, Series and Anime grids.
  /// Anime remains episodic TV and uses the existing streaming-TV ad slot.
  void _openService(AppStreamingService service) {
    const catalog = CatalogController();
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();

    MediaCollection collection(
      MediaKind kind, {
      bool animeOnly = false,
      required String adPlacement,
    }) => _translated(
      catalog.serviceCollection(
        kind: kind,
        service: service,
        settings: settings,
        dependencies: dependencies,
        animeOnly: animeOnly,
      ),
      service.isWatchProvider
          ? tr('streaming_services')
          : tr('studio_or_network_catalog'),
      adPlacement: adPlacement,
    );

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CollectionScreen.tabbed(
          tabs: <(String, MediaCollection)>[
            (
              tr('movies'),
              collection(MediaKind.movie, adPlacement: 'streaming_movies'),
            ),
            (
              tr('series'),
              collection(MediaKind.series, adPlacement: 'streaming_tv'),
            ),
            (
              tr('anime'),
              collection(
                MediaKind.series,
                animeOnly: true,
                adPlacement: 'streaming_tv',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCategories(HomeFeed? feed) async {
    final animeOnly = _filter == HomeFilter.anime;
    final picked = await showGenreSheet(
      context,
      movieGenres: animeOnly
          ? const <Genres>[]
          : feed?.movieGenres ?? const <Genres>[],
      seriesGenres: animeOnly
          ? (feed?.seriesGenres ?? const <Genres>[])
                .where(
                  (genre) =>
                      CatalogController.animeGenreIds.contains(genre.genreID),
                )
                .toList(growable: false)
          : feed?.seriesGenres ?? const <Genres>[],
      animeOnly: animeOnly,
    );
    if (picked == null || !mounted) return;
    final (kind, genre) = picked;
    if (animeOnly) {
      final catalog = const CatalogController();
      await _openCollection(
        catalog.genreCollection(
          kind: MediaKind.series,
          genre: genre,
          animeOnly: true,
          settings: context.read<SettingsProvider>(),
          dependencies: context.read<AppDependencyProvider>(),
        ),
      );
    } else {
      await openGenreCollection(
        context,
        kind,
        genre,
        excludeAnime: kind == MediaKind.series,
      );
    }
  }

  List<String> _genreNames(HomeFeed feed, MediaItem item) {
    final genres = item.kind == MediaKind.movie
        ? feed.movieGenres
        : feed.seriesGenres;
    final names = <int, String>{
      for (final genre in genres)
        if (genre.genreID != null && genre.genreName != null)
          genre.genreID!: genre.genreName!,
    };
    return item.genreIds
        .map((id) => names[id])
        .whereType<String>()
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final feed = _feeds[_filter];
    final continueWatching = _continueWatching(context);
    final heroes = feed == null
        ? const <HomeHero>[]
        : _heroesFor(feed, continueWatching);
    final media = MediaQuery.of(context);
    final headerHeight = media.padding.top + HomeHeader.barHeight;

    final List<Widget> content;
    if (feed != null) {
      final rows = homeRows(
        context,
        filter: _filter,
        feed: feed,
        continueWatching: continueWatching,
        myList: MyList.items(context, filter: _filter),
        heroes: heroes,
        genresFor: (item) => _genreNames(feed, item),
        onHeroShown: _onHeroShown,
        loadCategory: _category,
        onOpenCategory: _openCategory,
        onOpenService: _openService,
        onOpenList: _openList,
      );
      // Now and then, a Plus invitation a few rows down (never the top).
      if (_filter == HomeFilter.all && rows.length > 3) {
        rows.insert(3, const HomeOptionalRow(child: PlusSpotlight()));
      }
      content = <Widget>[
        SliverFadeTransition(
          opacity: _fade,
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) => rows[index] is HomeOptionalRow
                ? rows[index]
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
                    child: rows[index],
                  ),
          ),
        ),
      ];
    } else if (_failed.contains(_filter)) {
      content = <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState.error(
            message: tr('home_load_failed'),
            onRetry: _retry,
          ),
        ),
      ];
    } else {
      content = const <Widget>[SliverToBoxAdapter(child: HomeSkeleton())];
    }

    final page = HomePageFrame(
      tint: _tint,
      backgroundHeight: headerHeight + HeroCard.heightFor(context),
      headerHeight: headerHeight,
      header: HomeHeaderDelegate(
        topInset: media.padding.top,
        palette: AppPalette.of(context),
        reduceMotion: media.disableAnimations,
        chips: _chips(feed),
        onSearch: () => _tabs?.select(MobileTab.search),
        onDownloads: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()),
        ),
      ),
      onRefresh: _refresh,
      scrollController: _tabs?.scrollController(_resetTab ?? MobileTab.home),
      updateNotice: const HomeOptionalRow(child: UpdateBottom()),
      content: content,
      tintEnabled: feed != null,
    );

    final logos = _logos;
    return logos == null ? page : TitleLogoScope(logos: logos, child: page);
  }

  List<FilterChipSpec> _chips(HomeFeed? feed) {
    final showLiveTv =
        context.watch<AppDependencyProvider?>()?.displayLiveTV ?? false;
    return <FilterChipSpec>[
      FilterChipSpec(
        label: tr('filter_all'),
        selected: _filter == HomeFilter.all,
        onTap: () => _select(HomeFilter.all),
      ),
      FilterChipSpec(
        label: tr('movies'),
        selected: _filter == HomeFilter.movies,
        onTap: () => _select(HomeFilter.movies),
      ),
      FilterChipSpec(
        label: tr('series'),
        selected: _filter == HomeFilter.series,
        onTap: () => _select(HomeFilter.series),
      ),
      if (showLiveTv)
        FilterChipSpec(
          label: tr('live_tv'),
          icon: PhosphorIcons.broadcast(),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const ChannelList()),
          ),
        ),
      FilterChipSpec(
        label: tr('categories'),
        dropdown: true,
        onTap: () => _openCategories(feed),
      ),
    ];
  }
}
