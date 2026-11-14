import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/manga/ui/manga_source_matcher.dart';

void main() {
  group('mangaTitleMatchScore', () {
    test('ranks exact title first', () {
      expect(
        mangaTitleMatchScore(<String>['Solo Leveling'], 'Solo Leveling'),
        1,
      );
    });

    test('ignores punctuation and case', () {
      expect(
        mangaTitleMatchScore(<String>['Solo Leveling'], 'SOLO-LEVELING'),
        1,
      );
    });

    test('uses alternate AniList titles', () {
      expect(
        mangaTitleMatchScore(<String>[
          'Solo Leveling',
          '나 혼자만 레벨업',
        ], '나 혼자만 레벨업'),
        1,
      );
    });

    test('keeps unrelated source results below a strong match', () {
      final matching = mangaTitleMatchScore(<String>[
        'Solo Leveling',
      ], 'Solo Leveling: Ragnarok');
      final unrelated = mangaTitleMatchScore(<String>[
        'Solo Leveling',
      ], 'The Beginning After the End');
      expect(matching, greaterThan(unrelated));
    });
  });

  group('mangaTitleMatches', () {
    test('accepts exact aliases after harmless source decorations', () {
      expect(
        mangaTitleMatches(<String>[
          'Solo Leveling',
          '나 혼자만 레벨업',
        ], 'Solo Leveling (2024) HD'),
        isTrue,
      );
      expect(
        mangaTitleMatches(<String>['Solo Leveling', '나 혼자만 레벨업'], '나 혼자만 레벨업'),
        isTrue,
      );
    });

    test(
      'rejects related or partially overlapping titles for auto binding',
      () {
        expect(
          mangaTitleMatches(<String>[
            'Solo Leveling',
          ], 'Solo Leveling: Ragnarok'),
          isFalse,
        );
        expect(
          mangaTitleMatches(<String>[
            'The Reluctant Preacher',
          ], 'The Reluctant Preacher of the Estate'),
          isFalse,
        );
      },
    );
  });

  group('buildMangaTitleQueries', () {
    test('returns every distinct AniList title and synonym', () {
      expect(
        buildMangaTitleQueries(
          romaji: 'Yeokdaegeum Yeongji Seolgyesa',
          english: 'The Greatest Estate Developer',
          native: '역대급 영지 설계사',
          synonyms: <String>[
            'The Greatest Estate Developer',
            'The Best Estate Designer',
            '역대급 영지 설계사',
          ],
        ),
        <String>[
          'Yeokdaegeum Yeongji Seolgyesa',
          'The Greatest Estate Developer',
          '역대급 영지 설계사',
          'The Best Estate Designer',
        ],
      );
    });
  });

  group('parseMangaChapterNumber', () {
    test('parses numeric and numeric-string metadata', () {
      expect(parseMangaChapterNumber(12.5, 'Special'), 12.5);
      expect(parseMangaChapterNumber('7', 'Chapter title'), 7);
    });

    test('extracts chapter numbers from English and Arabic names', () {
      expect(parseMangaChapterNumber(-1, 'Chapter 10.5 - The Test'), 10.5);
      expect(parseMangaChapterNumber(-1, 'الفصل ١٢ - بداية جديدة'), 12);
      expect(parseMangaChapterNumber(-1, 'الحلقة ٣'), 3);
    });

    test('does not treat Mihon unset sentinel as a chapter number', () {
      expect(parseMangaChapterNumber(-1, 'Special extra'), isNull);
      expect(parseMangaChapterNumber('-1', 'Extra'), isNull);
    });
  });
}
