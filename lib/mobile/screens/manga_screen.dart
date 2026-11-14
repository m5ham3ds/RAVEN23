import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../catalog/home_feed_controller.dart';
import '../../catalog/home_hero.dart';
import '../../catalog/home_rows.dart' show homeRows;
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../manga/anilist/anilist_manga_service.dart';
import '../../manga/mihon/mihon_source_browser_screen.dart';
import '../../manga/ui/manga_work_screen.dart';
import '../../screens/common/downloads_screen.dart';
import '../../screens/common/update_screen.dart';
import '../../services/ambient_theme_service.dart';
import '../app/mobile_tabs.dart';
import '../widgets/filter_chips.dart';
import '../widgets/hero_card.dart';
import '../widgets/home_header.dart';
import '../widgets/home_optional_row.dart';
import '../widgets/home_page_frame.dart';
import '../widgets/media_art.dart' show ArtPlaceholder;
import '../widgets/page_kit.dart' show EmptyState, SearchPill;
import '../widgets/skeletons.dart';

class MangaScreen extends StatefulWidget {
  const MangaScreen({super.key, this.service});

  final AniListMangaService? service;

  @override
  State<MangaScreen> createState() => _MangaScreenState();
}

class _MangaScreenState extends State<MangaScreen>
    with SingleTickerProviderStateMixin {
  late final AniListMangaService _service =
      widget.service ?? AniListMangaService();
  late final AnimationController _fade;
  final ValueNotifier<Color?> _tint = ValueNotifier<Color?>(null);
  final Map<int, Color?> _tints = <int, Color?>{};
  int? _shownHeroId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Map<MangaContentKind, MangaCatalogue> _catalogues =
      <MangaContentKind, MangaCatalogue>{};

  MangaCatalogue? _mixedCatalogue;
  List<MangaTitle>? _searchResults;
  MangaContentKind _kind = MangaContentKind.all;
  bool _loading = true;
  bool _searching = false;
  bool _searchExpanded = false;
  int _searchRequestId = 0;
  int _catalogueRequestId = 0;
  String? _error;

  MangaCatalogue? get _catalogue =>
      _kind == MangaContentKind.all ? _mixedCatalogue : _catalogues[_kind];

  bool _hasCatalogue(MangaContentKind kind) {
    final value = kind == MangaContentKind.all
        ? _mixedCatalogue
        : _catalogues[kind];
    return value != null && !value.isEmpty;
  }

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fade.dispose();
    _tint.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final kind = _kind;
    final requestId = ++_catalogueRequestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    if (kind == MangaContentKind.all) {
      // Build All from the three canonical country feeds. A separate
      // unfiltered request duplicated most of this payload and made the
      // entire page fail when that single large query was rate-limited.
      final regionalKinds = <MangaContentKind>[
        MangaContentKind.manga,
        MangaContentKind.manhwa,
        MangaContentKind.manhua,
      ];
      final failures = <Object>[];
      final futures = regionalKinds
          .map((regional) async {
            final cached = _catalogues[regional];
            final usableCached = cached != null && !cached.isEmpty
                ? cached
                : null;
            if (!forceRefresh && usableCached != null) return usableCached;
            try {
              final loaded = await _service.home(kind: regional);
              if (loaded.isEmpty && usableCached != null) return usableCached;
              return loaded.isEmpty ? null : loaded;
            } catch (error) {
              failures.add(error);
              // Keep a previously loaded regional shelf available during a
              // refresh outage instead of replacing it with an empty catalogue.
              return usableCached;
            }
          })
          .toList(growable: false);
      final results = await Future.wait(futures);
      if (!mounted || requestId != _catalogueRequestId) return;

      final available = <MangaCatalogue>[];
      for (var index = 0; index < regionalKinds.length; index++) {
        final result = results[index];
        if (result == null || result.isEmpty) {
          _catalogues.remove(regionalKinds[index]);
          continue;
        }
        _catalogues[regionalKinds[index]] = result;
        available.add(result);
      }
      final combined = MangaCatalogue.combine(available);
      setState(() {
        _mixedCatalogue = combined.isEmpty ? null : combined;
        _loading = false;
        _error = combined.isEmpty && failures.isNotEmpty
            ? failures.first.toString()
            : null;
      });
      if (!combined.isEmpty) _fade.forward(from: 0);
      return;
    }

    // Category pages need only their own country feed. Do not make a global
    // catalogue request a prerequisite for Japanese/Korean/Chinese content.
    try {
      final cached = _catalogues[kind];
      final usableCached = cached != null && !cached.isEmpty ? cached : null;
      final result = !forceRefresh && usableCached != null
          ? usableCached
          : await _service.home(kind: kind);
      if (!mounted || requestId != _catalogueRequestId) return;
      final effective = result.isEmpty && usableCached != null
          ? usableCached
          : result;
      setState(() {
        if (effective.isEmpty) {
          _catalogues.remove(kind);
        } else {
          _catalogues[kind] = effective;
        }
        _loading = false;
        _error = null;
      });
      if (!effective.isEmpty) _fade.forward(from: 0);
    } catch (error) {
      if (!mounted || requestId != _catalogueRequestId) return;
      setState(() {
        _error = _hasCatalogue(kind) ? null : error.toString();
        _loading = false;
      });
    }
  }

  void _switchKind(MangaContentKind kind) {
    if (kind == _kind) return;
    _searchRequestId++;
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _kind = kind;
      _searchResults = null;
      _searching = false;
      _error = null;
      _shownHeroId = null;
      _tint.value = null;
      _loading = !_hasCatalogue(kind);
    });
    _fade.forward(from: 0);
    if (!_hasCatalogue(kind)) _load();
  }

  void _toggleSearch() {
    final expand = !_searchExpanded;
    setState(() {
      _searchExpanded = expand;
      if (!expand) {
        _searchController.clear();
        _searchResults = null;
        _searching = false;
        _error = null;
      }
    });
    if (expand) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
    }
  }

  void _onSearchChanged(String value) {
    _searchRequestId++;
    setState(() {
      _searchResults = null;
      _searching = false;
      _error = null;
    });
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    final requestId = ++_searchRequestId;
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await _service.search(query, kind: _kind);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = result;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _error = error.toString();
        _searching = false;
      });
    }
  }

  Future<void> _retry() {
    final query = _searchController.text.trim();
    return query.isEmpty ? _load(forceRefresh: true) : _search(query);
  }

  void _openTitle(MangaTitle title) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MangaDetailScreen(title: title, service: _service),
    ),
  );

  List<MangaTitle> _featuredForCatalogue(MangaCatalogue? catalogue) {
    if (catalogue == null) return const <MangaTitle>[];
    // Home always leads with a featured carousel when a feed has content.
    // Use the strongest available Manga shelf as fallback, so sparse regions
    // cannot lose their hero while another shelf still contains titles.
    final featured =
        <List<MangaTitle>>[
          catalogue.trending,
          catalogue.popular,
          catalogue.topRated,
          catalogue.recentlyReleased,
          catalogue.top10,
          catalogue.upcoming,
          catalogue.completed,
          catalogue.action,
          catalogue.adventure,
          catalogue.comedy,
          catalogue.drama,
          catalogue.fantasy,
          catalogue.horror,
          catalogue.mystery,
          catalogue.romance,
          catalogue.sciFi,
          catalogue.supernatural,
          catalogue.sliceOfLife,
        ].firstWhere(
          (shelf) => shelf.isNotEmpty,
          orElse: () => const <MangaTitle>[],
        );
    return featured.take(8).toList(growable: false);
  }

  List<MangaTitle> _featuredForCurrentKind() =>
      _featuredForCatalogue(_catalogue);

  List<FilterChipSpec> _kindChips() => <FilterChipSpec>[
    FilterChipSpec(
      label: tr('all'),
      selected: _kind == MangaContentKind.all,
      onTap: () => _switchKind(MangaContentKind.all),
    ),
    FilterChipSpec(
      label: tr('manga_type_manga'),
      selected: _kind == MangaContentKind.manga,
      onTap: () => _switchKind(MangaContentKind.manga),
    ),
    FilterChipSpec(
      label: tr('manga_type_manhwa'),
      selected: _kind == MangaContentKind.manhwa,
      onTap: () => _switchKind(MangaContentKind.manhwa),
    ),
    FilterChipSpec(
      label: tr('manga_type_manhua'),
      selected: _kind == MangaContentKind.manhua,
      onTap: () => _switchKind(MangaContentKind.manhua),
    ),
  ];

  MediaItem _mediaItem(MangaTitle title) => MediaItem(
    kind: MediaKind.movie,
    id: title.id,
    stableKey: 'manga:${title.id}',
    title: title.title,
    overview: title.description ?? '',
    posterPath: null,
    backdropPath: null,
    posterUrl: title.coverUrl,
    backdropUrl: title.bannerUrl,
    rating: title.averageScore == null ? null : title.averageScore! / 10,
    releaseDate: title.startDate,
  );

  MangaTitle? _featuredTitle(int id) =>
      _featuredForCurrentKind().where((title) => title.id == id).firstOrNull;

  String get _heroCategoryLabel => switch (_kind) {
    MangaContentKind.all => tr('manga'),
    MangaContentKind.manga => tr('manga_type_manga'),
    MangaContentKind.manhwa => tr('manga_type_manhwa'),
    MangaContentKind.manhua => tr('manga_type_manhua'),
  };

  void _onHeroShown(HomeHero hero) {
    final title = _featuredTitle(hero.item.id);
    _shownHeroId = title?.id;
    _tint.value = title == null ? null : _tints[title.id];
    if (title == null || _tints.containsKey(title.id)) return;
    _tints[title.id] = null;
    // Match the exact artwork variant shown by Home's shared HeroCard on
    // this device (poster on phones, backdrop on wider layouts).
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    final imageUrl =
        (wide
                ? (title.bannerUrl ?? title.coverUrl)
                : (title.coverUrl ?? title.bannerUrl))
            ?.trim();
    if (imageUrl == null || imageUrl.isEmpty) return;
    DominantImageColor.extract(imageUrl).then((color) {
      if (!mounted || color == null) return;
      _tints[title.id] = color;
      if (_shownHeroId == title.id) _tint.value = color;
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final gutter = AppSpace.gutter(context);
    final catalogue = _catalogue;
    final searchResults = _searchResults;
    final headerHeight = media.padding.top + HomeHeader.barHeight;

    final List<Widget> content;
    if (_searching) {
      content = const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    } else if (_loading && catalogue == null) {
      content = const <Widget>[SliverToBoxAdapter(child: HomeSkeleton())];
    } else if (_error != null &&
        (catalogue == null || _searchController.text.trim().isNotEmpty)) {
      content = <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState.error(message: _error!, onRetry: _retry),
        ),
      ];
    } else if (searchResults != null) {
      if (searchResults.isEmpty) {
        content = <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(tr('manga_no_results'))),
          ),
        ];
      } else {
        content = <Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              AppSpace.sm,
              gutter,
              media.padding.bottom + AppSpace.xl,
            ),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _MangaPoster(
                  title: searchResults[index],
                  onTap: () => _openTitle(searchResults[index]),
                  width:
                      (media.size.width -
                          gutter * 2 -
                          10 * (_gridCount(media.size.width) - 1)) /
                      _gridCount(media.size.width),
                ),
                childCount: searchResults.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridCount(media.size.width),
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 2 / 3,
              ),
            ),
          ),
        ];
      }
    } else if (catalogue == null || catalogue.isEmpty) {
      content = <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState.error(
            message: tr('manga_catalogue_empty'),
            onRetry: _retry,
          ),
        ),
      ];
    } else {
      final featured = _featuredForCurrentKind();
      final rows = homeRows(
        context,
        filter: HomeFilter.manga,
        feed: HomeFeed(filter: HomeFilter.manga),
        continueWatching: const <MediaItem>[],
        myList: const <MediaItem>[],
        heroes: featured
            .map((title) => HomeHero(item: _mediaItem(title)))
            .toList(growable: false),
        genresFor: (item) =>
            _featuredTitle(item.id)?.genres.take(2).toList(growable: false) ??
            const <String>[],
        onHeroShown: _onHeroShown,
        loadCategory: (_) async => const <MediaItem>[],
        onOpenCategory: (_) {},
        onOpenService: (_) {},
        onOpenList: (_, __, ___) {},
        mangaCatalogue: catalogue,
        mangaCatalogues: _catalogues,
        mangaKind: _kind,
        onMangaTap: _openTitle,
        onMangaSeeAll: (title, items) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => _MangaCollectionScreen(
              title: title,
              items: items,
              onTap: _openTitle,
            ),
          ),
        ),
        onMangaSources: (title) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MihonSourceBrowserScreen(initialQuery: title.title),
          ),
        ),
        mangaHeroCategoryLabel: _heroCategoryLabel,
      );
      content = <Widget>[
        SliverFadeTransition(
          opacity: _fade,
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
              child: rows[index],
            ),
          ),
        ),
      ];
    }

    final page = HomePageFrame(
      tint: _tint,
      backgroundHeight: headerHeight + HeroCard.heightFor(context),
      headerHeight: headerHeight,
      header: HomeHeaderDelegate(
        topInset: media.padding.top,
        palette: AppPalette.of(context),
        reduceMotion: media.disableAnimations,
        chips: _kindChips(),
        onSearch: _toggleSearch,
        onDownloads: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()),
        ),
        searchActive: _searchExpanded,
      ),
      onRefresh: () => _load(forceRefresh: true),
      scrollController: MobileTabScope.maybeOf(
        context,
      )?.scrollController(MobileTab.manga),
      afterHeader: <Widget>[
        if (_searchExpanded)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                AppSpace.md,
                gutter,
                AppSpace.md,
              ),
              child: SearchPill(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hint: tr('manga_search_hint'),
                onChanged: _onSearchChanged,
                onSubmitted: _search,
                onClear: () {
                  _searchRequestId++;
                  setState(() {
                    _searchResults = null;
                    _searching = false;
                    _error = null;
                  });
                },
                searching: _searching,
              ),
            ),
          ),
      ],
      updateNotice: const HomeOptionalRow(child: UpdateBottom()),
      content: content,
      tintEnabled: catalogue != null,
    );
    return page;
  }

  int _gridCount(double width) => width >= 900
      ? 6
      : width >= 700
      ? 5
      : width >= 520
      ? 4
      : 3;
}

class _MangaCollectionScreen extends StatelessWidget {
  const _MangaCollectionScreen({
    required this.title,
    required this.items,
    required this.onTap,
  });

  final String title;
  final List<MangaTitle> items;
  final ValueChanged<MangaTitle> onTap;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final gutter = AppSpace.gutter(context);
    final width = media.size.width;
    final columns = width >= 1100
        ? 7
        : width >= 850
        ? 6
        : width >= 650
        ? 5
        : width >= 480
        ? 4
        : 3;
    final cardWidth = (width - gutter * 2 - 10 * (columns - 1)) / columns;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          gutter,
          AppSpace.md,
          gutter,
          media.padding.bottom + AppSpace.xl,
        ),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 2 / 3,
        ),
        itemBuilder: (context, index) => _MangaPoster(
          title: items[index],
          onTap: () => onTap(items[index]),
          width: cardWidth,
        ),
      ),
    );
  }
}

class _MangaPoster extends StatelessWidget {
  const _MangaPoster({
    required this.title,
    required this.onTap,
    required this.width,
  });

  final MangaTitle title;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final cardWidth = width;
    return Semantics(
      button: true,
      label: title.title,
      child: Material(
        color: palette.raisedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: cardWidth,
            height: cardWidth * 1.5,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (title.coverUrl != null)
                  CachedNetworkImage(
                    imageUrl: title.coverUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        ColoredBox(color: palette.raisedSurface),
                    errorWidget: (_, __, ___) => const ArtPlaceholder(),
                  )
                else
                  const ArtPlaceholder(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.hairline, width: .5),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Work-level Manga/Manhwa/Manhua detail experience. Source matching, chapter
/// management and reading now live inside the selected catalogue work.
class MangaDetailScreen extends StatelessWidget {
  const MangaDetailScreen({
    required this.title,
    required this.service,
    super.key,
  });

  final MangaTitle title;
  final AniListMangaService service;

  @override
  Widget build(BuildContext context) =>
      MangaWorkScreen(title: title, service: service);
}
