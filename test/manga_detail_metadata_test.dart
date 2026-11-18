import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/manga/anilist/anilist_manga_service.dart';

void main() {
  group('MangaTitle detail metadata', () {
    test('parses characters and staff into separate collections', () {
      final title = MangaTitle.fromJson(<String, dynamic>{
        'id': 7,
        'title': <String, dynamic>{'romaji': 'Solo Leveling'},
        'characters': <String, dynamic>{
          'edges': <dynamic>[
            <String, dynamic>{
              'role': 'MAIN',
              'node': <String, dynamic>{
                'id': 91,
                'name': <String, dynamic>{'full': 'Sung Jinwoo'},
                'image': <String, dynamic>{
                  'large': 'https://img.example/jinwoo.jpg',
                },
              },
            },
          ],
        },
        'staff': <String, dynamic>{
          'edges': <dynamic>[
            <String, dynamic>{
              'role': 'Story & Art',
              'node': <String, dynamic>{
                'id': 92,
                'name': <String, dynamic>{'full': 'DUBU'},
                'image': <String, dynamic>{
                  'large': 'https://img.example/dubu.jpg',
                },
              },
            },
          ],
        },
      });

      expect(title.characters, hasLength(1));
      expect(title.characters.single.name, 'Sung Jinwoo');
      expect(title.characters.single.isStaff, isFalse);
      expect(title.staff, hasLength(1));
      expect(title.staff.single.role, 'Story & Art');
      expect(title.staff.single.isStaff, isTrue);
    });

    test('keeps manga relations and excludes anime and light novels', () {
      final title = MangaTitle.fromJson(<String, dynamic>{
        'id': 7,
        'title': <String, dynamic>{'romaji': 'Example'},
        'relations': <String, dynamic>{
          'edges': <dynamic>[
            <String, dynamic>{
              'relationType': 'SEQUEL',
              'node': <String, dynamic>{
                'id': 8,
                'type': 'MANGA',
                'format': 'MANGA',
                'title': <String, dynamic>{'romaji': 'Example 2'},
              },
            },
            <String, dynamic>{
              'relationType': 'ADAPTATION',
              'node': <String, dynamic>{
                'id': 9,
                'type': 'ANIME',
                'format': 'TV',
                'title': <String, dynamic>{'romaji': 'Example Anime'},
              },
            },
            <String, dynamic>{
              'relationType': 'SOURCE',
              'node': <String, dynamic>{
                'id': 10,
                'type': 'MANGA',
                'format': 'NOVEL',
                'title': <String, dynamic>{'romaji': 'Example Novel'},
              },
            },
          ],
        },
      });

      expect(title.relations, hasLength(1));
      expect(title.relations.single.id, 8);
      expect(title.relations.single.title, 'Example 2');
    });

    test('parses AniList work metadata and spoiler-aware tags', () {
      final title = MangaTitle.fromJson(<String, dynamic>{
        'id': 77,
        'title': <String, dynamic>{
          'romaji': 'Metadata example',
          'native': '作品',
        },
        'averageScore': 86,
        'popularity': 12000,
        'favourites': 850,
        'source': 'ORIGINAL',
        'countryOfOrigin': 'JP',
        'startDate': <String, dynamic>{'year': 2020, 'month': 3, 'day': 4},
        'endDate': <String, dynamic>{'year': 2022, 'month': 5, 'day': 6},
        'synonyms': <String>['Alias one', 'Alias two'],
        'tags': <dynamic>[
          <String, dynamic>{
            'name': 'Time Travel',
            'rank': 88,
            'isMediaSpoiler': false,
          },
          <String, dynamic>{
            'name': 'Hidden Identity',
            'rank': 67,
            'isMediaSpoiler': true,
          },
        ],
      });

      expect(title.averageScore, 86);
      expect(title.favourites, 850);
      expect(title.sourceMaterial, 'ORIGINAL');
      expect(title.countryOfOrigin, 'JP');
      expect(title.startDate, '2020-03-04');
      expect(title.endDate, '2022-05-06');
      expect(title.nativeTitle, '作品');
      expect(title.synonyms, <String>['Alias one', 'Alias two']);
      expect(title.tags, hasLength(2));
      expect(title.tags.first.rank, 88);
      expect(title.tags.first.isSpoiler, isFalse);
      expect(title.tags.last.isSpoiler, isTrue);
    });

    test('handles missing optional detail fields', () {
      final title = MangaTitle.fromJson(<String, dynamic>{
        'id': 11,
        'title': <String, dynamic>{'romaji': 'Minimal Title'},
      });
      expect(title.characters, isEmpty);
      expect(title.staff, isEmpty);
      expect(title.relations, isEmpty);
    });
  });
}
