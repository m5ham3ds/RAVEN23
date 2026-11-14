import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/catalog/home_hero.dart';
import 'package:raven23/catalog/media_item.dart';
import 'package:raven23/manga/anilist/anilist_manga_service.dart';
import 'package:raven23/mobile/widgets/hero_card.dart';
import 'package:raven23/mobile/widgets/media_rows.dart';
import 'package:raven23/mobile/widgets/poster_card.dart';

MangaTitle _manga(int id) => MangaTitle(
  id: id,
  title: 'Manga $id',
  coverUrl: 'https://example.com/$id.jpg',
  popularity: 1000 - id,
  trending: 500 - id,
  averageScore: 90 - id,
  startDate: '2026-01-${(id % 28 + 1).toString().padLeft(2, '0')}',
);

void main() {
  test('video Home components keep their PHASE55 defaults', () {
    const item = MediaItem(
      kind: MediaKind.movie,
      id: 55,
      title: 'Baseline movie',
      overview: '',
      posterPath: '/poster.jpg',
      backdropPath: '/backdrop.jpg',
      rating: 7.5,
      releaseDate: '2026-01-01',
    );
    final hero = HeroCard(hero: HomeHero(item: item));
    final carousel = HeroCarousel(
      heroes: <HomeHero>[HomeHero(item: item)],
      genresFor: (_) => const <String>[],
    );
    final posters = PosterRow(items: const <MediaItem>[item]);
    final topTen = TopTenRow(title: 'Top 10', items: const <MediaItem>[item]);
    final poster = PosterCard(item: item, width: 180);

    expect(hero.artworkUrlFor, isNull);
    expect(hero.primaryAction, isNull);
    expect(hero.secondaryAction, isNull);
    expect(hero.kindLabel, isNull);
    expect(hero.showTitleLogo, isTrue);
    expect(carousel.artworkUrlFor, isNull);
    expect(posters.artworkUrlFor, isNull);
    expect(posters.enableTitleSheet, isTrue);
    expect(topTen.artworkUrlFor, isNull);
    expect(topTen.enableTitleSheet, isTrue);
    expect(poster.directArtworkUrl, isNull);
    expect(poster.enableTitleSheet, isTrue);
  });

  test('Home parity keeps the complete canonical 18-shelf Manga order', () {
    final catalogue = MangaCatalogue(
      top10: <MangaTitle>[_manga(1)],
      recentlyReleased: <MangaTitle>[_manga(2)],
      trending: <MangaTitle>[_manga(3)],
      popular: <MangaTitle>[_manga(4)],
      topRated: <MangaTitle>[_manga(5)],
      upcoming: <MangaTitle>[_manga(6)],
      completed: <MangaTitle>[_manga(7)],
      action: <MangaTitle>[_manga(8)],
      adventure: <MangaTitle>[_manga(9)],
      comedy: <MangaTitle>[_manga(10)],
      drama: <MangaTitle>[_manga(11)],
      fantasy: <MangaTitle>[_manga(12)],
      horror: <MangaTitle>[_manga(13)],
      mystery: <MangaTitle>[_manga(14)],
      romance: <MangaTitle>[_manga(15)],
      sciFi: <MangaTitle>[_manga(16)],
      supernatural: <MangaTitle>[_manga(17)],
      sliceOfLife: <MangaTitle>[_manga(18)],
    );

    expect(
      catalogue.homeShelves.map((shelf) => shelf.translationKey).toList(),
      <String>[
        'manga_top_10',
        'manga_recently_released',
        'trending',
        'popular',
        'top_rated',
        'manga_upcoming',
        'manga_completed',
        'action',
        'adventure',
        'comedy',
        'drama',
        'fantasy',
        'horror',
        'mystery',
        'romance',
        'sci_fi',
        'supernatural',
        'slice_of_life',
      ],
    );
    expect(catalogue.homeShelves, hasLength(18));
    expect(catalogue.homeShelves.first.isTopTen, isTrue);
    expect(
      catalogue.homeShelves.skip(1).every((shelf) => !shelf.isTopTen),
      isTrue,
    );
    expect(
      catalogue.homeShelves.every((shelf) => shelf.items.isNotEmpty),
      isTrue,
    );
  });

  test('All merges common genre shelves across Manga, Manhwa and Manhua', () {
    MangaCatalogue region(int base) => MangaCatalogue(
      top10: <MangaTitle>[_manga(base)],
      recentlyReleased: <MangaTitle>[_manga(base + 1)],
      trending: <MangaTitle>[_manga(base + 2)],
      popular: <MangaTitle>[_manga(base + 3)],
      topRated: <MangaTitle>[_manga(base + 4)],
      action: <MangaTitle>[_manga(base + 5)],
      adventure: <MangaTitle>[_manga(base + 6)],
      comedy: <MangaTitle>[_manga(base + 7)],
      drama: <MangaTitle>[_manga(base + 8)],
      fantasy: <MangaTitle>[_manga(base + 9)],
      horror: <MangaTitle>[_manga(base + 10)],
      mystery: <MangaTitle>[_manga(base + 11)],
      romance: <MangaTitle>[_manga(base + 12)],
      sciFi: <MangaTitle>[_manga(base + 13)],
      supernatural: <MangaTitle>[_manga(base + 14)],
      sliceOfLife: <MangaTitle>[_manga(base + 15)],
    );

    final manga = region(100);
    final manhwa = region(200);
    final manhua = region(300);
    final all = MangaCatalogue.combine(<MangaCatalogue>[manga, manhwa, manhua]);

    expect(
      all.action.map((item) => item.id),
      containsAll(<int>[105, 205, 305]),
    );
    expect(all.drama.map((item) => item.id), containsAll(<int>[108, 208, 308]));
    expect(
      all.romance.map((item) => item.id),
      containsAll(<int>[112, 212, 312]),
    );
    expect(
      all.popular.map((item) => item.id),
      containsAll(<int>[103, 203, 303]),
    );
    expect(all.top10.map((item) => item.id), containsAll(<int>[100, 200, 300]));
    expect(all.homeShelves, hasLength(18));
  });

  test('All catalogue aggregation retains every Manga home shelf', () {
    final source = MangaCatalogue(
      top10: <MangaTitle>[_manga(1)],
      recentlyReleased: <MangaTitle>[_manga(2)],
      trending: <MangaTitle>[_manga(3)],
      popular: <MangaTitle>[_manga(4)],
      topRated: <MangaTitle>[_manga(5)],
      upcoming: <MangaTitle>[_manga(6)],
      completed: <MangaTitle>[_manga(7)],
      action: <MangaTitle>[_manga(8)],
      adventure: <MangaTitle>[_manga(9)],
      comedy: <MangaTitle>[_manga(10)],
      drama: <MangaTitle>[_manga(11)],
      fantasy: <MangaTitle>[_manga(12)],
      horror: <MangaTitle>[_manga(13)],
      mystery: <MangaTitle>[_manga(14)],
      romance: <MangaTitle>[_manga(15)],
      sciFi: <MangaTitle>[_manga(16)],
      supernatural: <MangaTitle>[_manga(17)],
      sliceOfLife: <MangaTitle>[_manga(18)],
    );

    final result = MangaCatalogue.combine(<MangaCatalogue>[source]);

    expect(result.top10.map((item) => item.id), <int>[1]);
    expect(result.recentlyReleased.map((item) => item.id), <int>[2]);
    expect(result.trending.map((item) => item.id), <int>[3]);
    expect(result.popular.map((item) => item.id), <int>[4]);
    expect(result.topRated.map((item) => item.id), <int>[5]);
    expect(result.upcoming.map((item) => item.id), <int>[6]);
    expect(result.completed.map((item) => item.id), <int>[7]);
    expect(result.action.map((item) => item.id), <int>[8]);
    expect(result.adventure.map((item) => item.id), <int>[9]);
    expect(result.comedy.map((item) => item.id), <int>[10]);
    expect(result.drama.map((item) => item.id), <int>[11]);
    expect(result.fantasy.map((item) => item.id), <int>[12]);
    expect(result.horror.map((item) => item.id), <int>[13]);
    expect(result.mystery.map((item) => item.id), <int>[14]);
    expect(result.romance.map((item) => item.id), <int>[15]);
    expect(result.sciFi.map((item) => item.id), <int>[16]);
    expect(result.supernatural.map((item) => item.id), <int>[17]);
    expect(result.sliceOfLife.map((item) => item.id), <int>[18]);
  });
}
