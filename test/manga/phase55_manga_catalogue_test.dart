import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/manga/anilist/anilist_manga_service.dart';

void main() {
  group('PHASE55 Manga catalogue model', () {
    test(
      'All is unfiltered while Manga, Manhwa and Manhua map to origin country',
      () {
        expect(MangaContentKind.all.countryCode, isNull);
        expect(MangaContentKind.manga.countryCode, 'JP');
        expect(MangaContentKind.manhwa.countryCode, 'KR');
        expect(MangaContentKind.manhua.countryCode, 'CN');
      },
    );

    test(
      'MangaTitle retains origin, title, cover, dates and catalogue metadata',
      () {
        final title = MangaTitle.fromJson(<String, dynamic>{
          'id': 42,
          'title': <String, dynamic>{
            'romaji': 'Test Manga',
            'english': 'Test Manga English',
            'native': 'テスト',
          },
          'coverImage': <String, dynamic>{
            'large': 'https://example.com/cover.jpg',
          },
          'startDate': <String, dynamic>{'year': 2026, 'month': 11, 'day': 10},
          'countryOfOrigin': 'KR',
          'averageScore': 87,
          'popularity': 1200,
          'genres': <String>['Action', 'Drama'],
        });

        expect(title.id, 42);
        expect(title.title, 'Test Manga');
        expect(title.coverUrl, 'https://example.com/cover.jpg');
        expect(title.startDate, '2026-11-10');
        expect(title.countryOfOrigin, 'KR');
        expect(title.averageScore, 87);
        expect(title.popularity, 1200);
        expect(title.genres, <String>['Action', 'Drama']);
      },
    );

    test('catalogue is empty only when every shelf is empty', () {
      const empty = MangaCatalogue(
        recentlyReleased: <MangaTitle>[],
        trending: <MangaTitle>[],
        popular: <MangaTitle>[],
        topRated: <MangaTitle>[],
        action: <MangaTitle>[],
        romance: <MangaTitle>[],
      );
      const topTenOnly = MangaCatalogue(
        recentlyReleased: <MangaTitle>[],
        trending: <MangaTitle>[],
        popular: <MangaTitle>[],
        topRated: <MangaTitle>[],
        action: <MangaTitle>[],
        romance: <MangaTitle>[],
        top10: <MangaTitle>[MangaTitle(id: 1, title: 'Top', coverUrl: null)],
      );

      expect(empty.isEmpty, isTrue);
      expect(topTenOnly.isEmpty, isFalse);
    });
  });
}
