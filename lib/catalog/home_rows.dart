import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import 'home_feed_controller.dart';
import 'home_hero.dart';
import 'media_item.dart';
import '../design/app_tokens.dart';
import '../manga/anilist/anilist_manga_service.dart';
import '../mobile/widgets/category_section.dart';
import '../mobile/widgets/hero_card.dart';
import '../mobile/widgets/home_optional_row.dart';
import '../mobile/widgets/media_rows.dart';
import '../screens/common/bookmark_screen.dart';
import '../widgets/common_widgets.dart'
    show AppStreamingService, appStreamingServices;
import '../widgets/hosted_ads_banner.dart';

/// The upcoming row's badge: its release date, "MAY 3", in the app's
/// language where the date formats for it are loaded.
String? _releaseBadge(BuildContext context, MediaItem item) {
  final date = DateTime.tryParse(item.releaseDate ?? '');
  if (date == null) return null;
  final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
  try {
    return DateFormat.MMMd(locale).format(date).toUpperCase();
  } catch (_) {
    return DateFormat.MMMd().format(date).toUpperCase();
  }
}

/// Home's rows for a loaded feed, top to bottom: the hero, then what to
/// watch next. Under All each chart comes as a pair, movies then series, so
/// no catalogue row mixes the two; only the viewer's own rows (Continue
/// Watching, My List) hold both. Three ads are spread down the page: a
/// banner directly under the hero, a medium rectangle after Trending (the
/// size advertisers bid on most) and a banner before the genre rows. Each
/// Home tab reports its own placement ids (`home_all_*`, `home_movies_*`,
/// `home_series_*`), shared by the remote banner placement catalog.
MediaItem _mangaMediaItem(MangaTitle title) => MediaItem(
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

List<Widget> homeRows(
  BuildContext context, {
  required HomeFilter filter,
  required HomeFeed feed,
  required List<MediaItem> continueWatching,
  required List<MediaItem> myList,
  required List<HomeHero> heroes,
  required List<String> Function(MediaItem item) genresFor,
  required ValueChanged<HomeHero> onHeroShown,
  required Future<List<MediaItem>> Function(HomeCategory category) loadCategory,
  required ValueChanged<HomeCategory> onOpenCategory,
  required ValueChanged<AppStreamingService> onOpenService,
  required void Function(MediaKind kind, HomeList list, String title)
  onOpenList,
  MangaCatalogue? mangaCatalogue,
  Map<MangaContentKind, MangaCatalogue> mangaCatalogues =
      const <MangaContentKind, MangaCatalogue>{},
  MangaContentKind mangaKind = MangaContentKind.all,
  ValueChanged<MangaTitle>? onMangaTap,
  ValueChanged<MangaTitle>? onMangaSources,
  void Function(String title, List<MangaTitle> items)? onMangaSeeAll,
  String? mangaHeroCategoryLabel,
}) {
  // Every Home destination shares the same placement ids and row spacing.
  final adBase = switch (filter) {
    HomeFilter.all => 'home_all',
    HomeFilter.movies => 'home_movies',
    HomeFilter.series => 'home_series',
    HomeFilter.anime => 'home_anime',
    HomeFilter.manga => 'home_manga',
  };
  HomeAdSlot adSlot(String slot, {bool tall = false}) => HomeAdSlot(
    placement: '${adBase}_$slot',
    variant: tall ? HostedBannerVariant.tall : HostedBannerVariant.standard,
  );

  bool isAnimeItem(MediaItem item) =>
      item.series?.isLikelyAnime == true ||
      item.recentEpisode?.isAnime == true ||
      item.upNext?.isAnime == true;
  // Manga is a first-class Home feed mode: it goes through this exact row
  // builder as Movies, Series and Anime, while keeping AniList entities and
  // data isolated from the TMDB video feeds.
  if (filter == HomeFilter.manga) {
    final catalogue = mangaCatalogue;
    if (catalogue == null || catalogue.isEmpty) return const <Widget>[];

    final titlesById = <int, MangaTitle>{};
    for (final source in <MangaCatalogue>[
      catalogue,
      ...mangaCatalogues.values,
    ]) {
      for (final shelf in source.homeShelves) {
        for (final title in shelf.items) {
          titlesById.putIfAbsent(title.id, () => title);
        }
      }
    }

    MangaTitle? titleFor(MediaItem item) => titlesById[item.id];
    void openTitle(MediaItem item) {
      final title = titleFor(item);
      if (title != null) onMangaTap?.call(title);
    }

    String? artworkFor(MediaItem item) {
      final title = titleFor(item);
      if (title == null) return item.posterUrl ?? item.backdropUrl;
      final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
      return wide
          ? (title.bannerUrl ?? title.coverUrl)
          : (title.coverUrl ?? title.bannerUrl);
    }

    List<String> factsFor(MediaItem item) {
      final title = titleFor(item);
      if (title == null) return const <String>[];
      return <String>[
        if (title.startDate case final date? when date.length >= 4)
          date.substring(0, 4),
        ...title.genres.take(2),
        if (title.averageScore case final score? when score > 0)
          '★ ${(score / 10).toStringAsFixed(1)}',
      ];
    }

    List<String> mangaGenresFor(MediaItem item) =>
        titleFor(item)?.genres.take(2).toList(growable: false) ??
        const <String>[];

    List<Widget> result = <Widget>[
      if (heroes.isNotEmpty)
        HeroCarousel(
          key: const ValueKey<HomeFilter>(HomeFilter.manga),
          heroes: heroes,
          genresFor: mangaGenresFor,
          onShown: onHeroShown,
          kickerLabel: mangaHeroCategoryLabel ?? tr('manga'),
          kindLabel: 'manga',
          factsFor: factsFor,
          artworkUrlFor: artworkFor,
          showTitleLogo: false,
          onTap: openTitle,
          primaryAction: (item) => openTitle(item),
          primaryLabel: tr('manga_read_action'),
          primaryIcon: Icons.menu_book_rounded,
          secondaryAction: (item) {
            final title = titleFor(item);
            if (title != null) onMangaSources?.call(title);
          },
          secondaryLabel: tr('manga_install_sources'),
          secondaryIcon: Icons.extension_rounded,
        ),
    ];

    void addMangaRow(
      String title,
      List<MangaTitle> mangaTitles, {
      bool topTen = false,
    }) {
      if (mangaTitles.isEmpty) return;
      final immutableTitles = List<MangaTitle>.unmodifiable(mangaTitles);
      final items = immutableTitles
          .map(_mangaMediaItem)
          .toList(growable: false);
      final seeAll = onMangaSeeAll == null
          ? null
          : () => onMangaSeeAll(title, immutableTitles);
      result.add(
        topTen
            ? TopTenRow(
                title: title,
                items: items,
                kindLabel: 'manga',
                enableTitleSheet: false,
                artworkUrlFor: artworkFor,
                onItemTap: openTitle,
                onSeeAll: seeAll,
              )
            : PosterRow(
                title: title,
                items: items,
                kindLabel: 'manga',
                enableTitleSheet: false,
                artworkUrlFor: artworkFor,
                onItemTap: openTitle,
                onSeeAll: seeAll,
              ),
      );
    }

    if (mangaKind == MangaContentKind.all) {
      const regions = <MangaContentKind>[
        MangaContentKind.manga,
        MangaContentKind.manhwa,
        MangaContentKind.manhua,
      ];
      String regionLabel(MangaContentKind kind) => switch (kind) {
        MangaContentKind.manga => tr('manga_type_manga'),
        MangaContentKind.manhwa => tr('manga_type_manhwa'),
        MangaContentKind.manhua => tr('manga_type_manhua'),
        MangaContentKind.all => tr('manga'),
      };

      // All has three independent regional Top 10 charts. These are the only
      // Top 10 shelves that appear in the mixed catalogue view.
      for (final region in regions) {
        final regional = mangaCatalogues[region];
        if (regional == null) continue;
        final top = regional.homeShelves.firstWhere(
          (shelf) => shelf.isTopTen,
          orElse: () => const MangaHomeShelf('manga_top_10', <MangaTitle>[]),
        );
        addMangaRow(
          '${tr('manga_top_10')} · ${regionLabel(region)}',
          top.items,
          topTen: true,
        );
      }

      // New releases and every ordinary genre/popularity shelf use the
      // deduplicated union of JP + KR + CN catalogues.
      for (final shelf in catalogue.homeShelves) {
        if (shelf.isTopTen || shelf.translationKey == 'trending') continue;
        if (shelf.translationKey == 'manga_recently_released') {
          addMangaRow(tr(shelf.translationKey), shelf.items);
          break;
        }
      }

      // Trending is deliberately split by region, unlike the other shelves.
      for (final region in regions) {
        final regional = mangaCatalogues[region];
        if (regional == null) continue;
        final trending = regional.homeShelves.firstWhere(
          (shelf) => shelf.translationKey == 'trending',
          orElse: () => const MangaHomeShelf('trending', <MangaTitle>[]),
        );
        addMangaRow(
          '${tr('trending')} · ${regionLabel(region)}',
          trending.items,
        );
      }

      for (final shelf in catalogue.homeShelves) {
        if (shelf.isTopTen ||
            shelf.translationKey == 'trending' ||
            shelf.translationKey == 'manga_recently_released') {
          continue;
        }
        addMangaRow(tr(shelf.translationKey), shelf.items);
      }
    } else {
      for (final shelf in catalogue.homeShelves) {
        addMangaRow(
          tr(shelf.translationKey),
          shelf.items,
          topTen: shelf.isTopTen,
        );
      }
    }
    return result;
  }

  final kinds = filter.kinds;
  final both = kinds.length > 1;

  // Anime is a full Home destination, not a four-row shortcut. Its feed is
  // built from the same header/hero/ad/continue/services/category components
  // as Movies and Series, while every item is constrained to Japanese
  // animation by the model's genre + original-language identity predicate.
  if (filter == HomeFilter.anime) {
    final animeContinue = continueWatching
        .where((item) => item.kind == MediaKind.series && isAnimeItem(item))
        .toList(growable: false);
    final animeSaved = myList
        .where((item) => item.kind == MediaKind.series && isAnimeItem(item))
        .toList(growable: false);
    final topAnime = feed.trendingAnime.take(10).toList(growable: false);
    final animeRows = <Widget>[
      if (heroes.isNotEmpty)
        HeroCarousel(
          key: const ValueKey<HomeFilter>(HomeFilter.anime),
          heroes: heroes,
          genresFor: genresFor,
          onShown: onHeroShown,
        ),
      adSlot('hero'),
      if (animeContinue.isNotEmpty)
        ContinueRow(title: tr('continue_watching'), items: animeContinue),
      if (topAnime.isNotEmpty)
        TopTenRow(
          title: tr('top_10_anime'),
          items: topAnime,
          onSeeAll: () => onOpenList(
            MediaKind.series,
            HomeList.trendingAnime,
            tr('top_10_anime'),
          ),
        ),
      if (feed.trendingAnime.isNotEmpty)
        PosterRow(
          title: tr('trending_anime'),
          items: feed.trendingAnime,
          onSeeAll: () => onOpenList(
            MediaKind.series,
            HomeList.trendingAnime,
            tr('trending_anime'),
          ),
        ),
      adSlot('trending', tall: true),
      if (animeSaved.isNotEmpty)
        PosterRow(
          title: tr('my_list'),
          items: animeSaved,
          onSeeAll: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const BookmarkScreen()),
          ),
        ),
      if (feed.newEpisodesAnime.isNotEmpty)
        PosterRow(
          title: tr('new_episodes_anime'),
          items: feed.newEpisodesAnime,
          onSeeAll: () => onOpenList(
            MediaKind.series,
            HomeList.newEpisodesAnime,
            tr('new_episodes_anime'),
          ),
        ),
      if (feed.popularAnime.isNotEmpty)
        PosterRow(
          title: tr('popular_anime'),
          items: feed.popularAnime,
          onSeeAll: () => onOpenList(
            MediaKind.series,
            HomeList.popularAnime,
            tr('popular_anime'),
          ),
        ),
      for (final shelf in feed.of(MediaKind.series).serviceShelves)
        PosterRow(
          title:
              '${tr('popular_series_on', namedArgs: <String, String>{'service': shelf.service.name})} · ${tr('anime')}',
          items: shelf.items,
          onSeeAll: () => onOpenService(shelf.service),
        ),
      ServiceRow(
        title: tr('streaming_services'),
        services: appStreamingServices,
        onOpen: onOpenService,
      ),
      if (feed.topRatedAnime.isNotEmpty)
        PosterRow(
          title: tr('top_rated_anime'),
          items: feed.topRatedAnime,
          onSeeAll: () => onOpenList(
            MediaKind.series,
            HomeList.topRatedAnime,
            tr('top_rated_anime'),
          ),
        ),
      adSlot('genres'),
      for (final category in feed.categories)
        CategorySection(
          key: ValueKey<String>('anime-category-${category.genre.genreID}'),
          category: category,
          kicker: tr('anime'),
          load: () => loadCategory(category),
          onSeeAll: () => onOpenCategory(category),
        ),
    ];
    return animeRows;
  }
  String titled(MediaKind kind, String movies, String series) =>
      tr(kind == MediaKind.movie ? movies : series);

  // The rows that share the first screens; keep them from repeating the
  // same few titles.
  final lead = limitRepeats(<List<MediaItem>>[
    continueWatching,
    for (final kind in kinds) feed.of(kind).topTen,
    for (final kind in kinds) feed.of(kind).trending,
    myList,
    for (final kind in kinds) feed.of(kind).newReleases,
  ]);
  var next = 0;
  List<MediaItem> take() => lead[next++];
  final shownContinue = take();
  final topTen = <MediaKind, List<MediaItem>>{for (final k in kinds) k: take()};
  final trending = <MediaKind, List<MediaItem>>{
    for (final k in kinds) k: take(),
  };
  final shownMyList = take();
  final newReleases = <MediaKind, List<MediaItem>>{
    for (final k in kinds) k: take(),
  };

  PosterRow listRow(
    MediaKind kind,
    HomeList list,
    String title,
    List<MediaItem> items, {
    String? Function(MediaItem item) badgeFor = recencyBadge,
  }) => PosterRow(
    title: title,
    items: items,
    badgeFor: badgeFor,
    onSeeAll: () => onOpenList(kind, list, title),
  );

  // One ad unit per Home tab; [adSlot] is shared by every mode above.
  return <Widget>[
    // The update notice is a fixed Home slot above these feed rows.
    if (heroes.isNotEmpty)
      HeroCarousel(
        key: ValueKey<HomeFilter>(filter),
        heroes: heroes,
        genresFor: genresFor,
        onShown: onHeroShown,
      ),
    // Directly below the hero.
    adSlot('hero'),
    if (shownContinue.isNotEmpty)
      ContinueRow(title: tr('continue_watching'), items: shownContinue),
    for (final kind in kinds)
      if (topTen[kind]!.isNotEmpty)
        TopTenRow(
          title: titled(kind, 'top_10_movies_today', 'top_10_series_today'),
          items: topTen[kind]!,
          onSeeAll: () => onOpenList(
            kind,
            HomeList.trendingToday,
            titled(kind, 'top_10_movies_today', 'top_10_series_today'),
          ),
        ),
    for (final kind in kinds)
      if (trending[kind]!.isNotEmpty)
        listRow(
          kind,
          HomeList.trendingWeek,
          titled(kind, 'trending_movies_week', 'trending_series_week'),
          trending[kind]!,
        ),
    if (filter == HomeFilter.all && feed.trendingAnime.isNotEmpty)
      PosterRow(
        title: tr('trending_anime'),
        items: feed.trendingAnime,
        onSeeAll: () => onOpenList(
          MediaKind.series,
          HomeList.trendingAnime,
          tr('trending_anime'),
        ),
      ),
    adSlot('trending', tall: true),
    if (shownMyList.isNotEmpty)
      PosterRow(
        title: tr('my_list'),
        items: shownMyList,
        onSeeAll: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const BookmarkScreen()),
        ),
      ),
    for (final kind in kinds)
      if (newReleases[kind]!.isNotEmpty)
        listRow(
          kind,
          HomeList.newReleases,
          titled(kind, 'new_movies', 'new_episodes_series'),
          newReleases[kind]!,
          // The row's title already says the episodes are new.
          badgeFor: (item) =>
              kind == MediaKind.series ? null : recencyBadge(item),
        ),
    if (filter == HomeFilter.all && feed.newEpisodesAnime.isNotEmpty)
      PosterRow(
        title: tr('new_episodes_anime'),
        items: feed.newEpisodesAnime,
        onSeeAll: () => onOpenList(
          MediaKind.series,
          HomeList.newEpisodesAnime,
          tr('new_episodes_anime'),
        ),
      ),
    for (final kind in kinds)
      if (feed.of(kind).popular.isNotEmpty)
        listRow(
          kind,
          HomeList.popular,
          titled(kind, 'popular_movies', 'popular_series'),
          feed.of(kind).popular,
        ),
    if (filter == HomeFilter.all && feed.popularAnime.isNotEmpty)
      PosterRow(
        title: tr('popular_anime'),
        items: feed.popularAnime,
        onSeeAll: () => onOpenList(
          MediaKind.series,
          HomeList.popularAnime,
          tr('popular_anime'),
        ),
      ),
    for (final kind in kinds)
      for (final shelf in feed.of(kind).serviceShelves)
        PosterRow(
          title: tr(
            kind == MediaKind.movie ? 'popular_movies_on' : 'popular_series_on',
            namedArgs: <String, String>{'service': shelf.service.name},
          ),
          items: shelf.items,
          onSeeAll: () => onOpenService(shelf.service),
        ),
    ServiceRow(
      title: tr('streaming_services'),
      services: appStreamingServices,
      onOpen: onOpenService,
    ),
    for (final kind in kinds)
      if (feed.of(kind).topRated.isNotEmpty)
        listRow(
          kind,
          HomeList.topRated,
          titled(kind, 'top_rated_movies', 'top_rated_series'),
          feed.of(kind).topRated,
        ),
    if (filter == HomeFilter.all && feed.topRatedAnime.isNotEmpty)
      PosterRow(
        title: tr('top_rated_anime'),
        items: feed.topRatedAnime,
        onSeeAll: () => onOpenList(
          MediaKind.series,
          HomeList.topRatedAnime,
          tr('top_rated_anime'),
        ),
      ),
    if (feed.of(MediaKind.movie).upcoming.isNotEmpty)
      listRow(
        MediaKind.movie,
        HomeList.upcoming,
        tr('upcoming_movies'),
        feed.of(MediaKind.movie).upcoming,
        badgeFor: (item) => _releaseBadge(context, item),
      ),
    adSlot('genres'),
    // RAVEN23's categorized feed: a few genres at random, each laid out its
    // own way, labelled with its kind where both are on show.
    for (final category in feed.categories)
      CategorySection(
        key: ValueKey<String>(
          'category-${category.kind.name}-${category.animeOnly}-${category.genre.genreID}',
        ),
        category: category,
        kicker: category.animeOnly
            ? tr('anime')
            : both
            ? titled(category.kind, 'movies', 'series')
            : null,
        load: () => loadCategory(category),
        onSeeAll: () => onOpenCategory(category),
      ),
  ];
}

/// A hosted ad between Home feed rows. Its optional row wrapper collapses the
/// trailing gap when no ad is available.
class HomeAdSlot extends HomeOptionalRow {
  HomeAdSlot({
    required this.placement,
    this.variant = HostedBannerVariant.standard,
    super.key,
  }) : super(
         child: _HostedAd(placement: placement, variant: variant),
       );

  final String placement;
  final HostedBannerVariant variant;
}

class _HostedAd extends StatelessWidget {
  const _HostedAd({required this.placement, required this.variant});

  final String placement;
  final HostedBannerVariant variant;

  @override
  Widget build(BuildContext context) =>
      RemoteHostedAdsBanner(placement: placement, variant: variant);
}
