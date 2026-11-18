import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/manga/anilist/anilist_manga_service.dart';
import 'package:raven23/manga/mihon/keiyoushi_extension_repository.dart';

MangaTitle _title(
  int id, {
  int? popularity,
  int? trending,
  int? score,
  String? startDate,
}) => MangaTitle(
  id: id,
  title: 'Manga $id',
  coverUrl: 'https://example.com/$id.jpg',
  popularity: popularity,
  trending: trending,
  averageScore: score,
  startDate: startDate,
);

MangaCatalogue _catalogue({
  List<MangaTitle> top10 = const <MangaTitle>[],
  List<MangaTitle> recentlyReleased = const <MangaTitle>[],
  List<MangaTitle> trending = const <MangaTitle>[],
  List<MangaTitle> popular = const <MangaTitle>[],
  List<MangaTitle> topRated = const <MangaTitle>[],
  List<MangaTitle> action = const <MangaTitle>[],
  List<MangaTitle> upcoming = const <MangaTitle>[],
}) => MangaCatalogue(
  top10: top10,
  recentlyReleased: recentlyReleased,
  trending: trending,
  popular: popular,
  topRated: topRated,
  action: action,
  upcoming: upcoming,
  romance: const <MangaTitle>[],
);

void main() {
  group('PHASE56 Manga catalogue aggregation', () {
    test('combines country catalogues, deduplicates IDs and ranks shelves', () {
      final japanese = _catalogue(
        top10: <MangaTitle>[
          _title(1, popularity: 500),
          _title(2, popularity: 300),
        ],
        recentlyReleased: <MangaTitle>[_title(1, startDate: '2026-11-10')],
        trending: <MangaTitle>[_title(1, trending: 100, popularity: 500)],
        popular: <MangaTitle>[
          _title(1, popularity: 500),
          _title(2, popularity: 300),
        ],
        topRated: <MangaTitle>[_title(1, score: 91), _title(2, score: 80)],
        upcoming: <MangaTitle>[
          _title(5, startDate: '2026-12-01'),
          _title(6),
        ],
        action: <MangaTitle>[_title(1, popularity: 500)],
      );
      final korean = _catalogue(
        top10: <MangaTitle>[
          _title(2, popularity: 300),
          _title(3, popularity: 900),
        ],
        recentlyReleased: <MangaTitle>[_title(4, startDate: '2026-11-09')],
        trending: <MangaTitle>[
          _title(3, trending: 200, popularity: 900),
          _title(2, trending: 10, popularity: 300),
        ],
        popular: <MangaTitle>[
          _title(3, popularity: 900),
          _title(2, popularity: 300),
        ],
        topRated: <MangaTitle>[_title(3, score: 95)],
      );

      final combined = MangaCatalogue.combine(<MangaCatalogue>[
        japanese,
        korean,
        _catalogue(), // An unavailable/empty region is safe to include.
      ]);

      expect(combined.top10.map((item) => item.id), <int>[3, 1, 2]);
      expect(combined.trending.map((item) => item.id), <int>[3, 1, 2]);
      expect(combined.popular.map((item) => item.id), <int>[3, 1, 2]);
      expect(combined.recentlyReleased.map((item) => item.id), <int>[1, 4]);
      expect(combined.topRated.map((item) => item.id), <int>[3, 1, 2]);
      expect(combined.upcoming.map((item) => item.id), <int>[5, 6]);
      expect(combined.action.map((item) => item.id), <int>[1]);
    });

    test(
      'falls back to popular titles when regional Top 10 shelves are absent',
      () {
        final combined = MangaCatalogue.combine(<MangaCatalogue>[
          _catalogue(
            popular: <MangaTitle>[
              _title(1, popularity: 100),
              _title(2, popularity: 200),
            ],
          ),
        ]);

        expect(combined.top10.map((item) => item.id), <int>[2, 1]);
      },
    );

    test('keeps an empty aggregate when every regional catalogue is empty', () {
      expect(MangaCatalogue.combine(const <MangaCatalogue>[]).isEmpty, isTrue);
      expect(
        MangaCatalogue.combine(<MangaCatalogue>[_catalogue()]).isEmpty,
        isTrue,
      );
    });
  });

  group('PHASE56 Keiyoushi raw repo.json trust metadata', () {
    const fingerprint =
        '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2';

    test('parses JSON text served with a non-JSON content type', () {
      final rawSidecar = jsonEncode(<String, Object>{
        'index_v2': 'https://example.com/repo/index.pb',
        'meta': <String, Object>{'signingKeyFingerprint': fingerprint},
      });

      expect(parseMihonRepositorySigningFingerprint(rawSidecar), fingerprint);
    });

    test('valid trust metadata enables only a valid HTTPS extension entry', () {
      final rawSidecar = jsonEncode(<String, Object>{
        'meta': <String, Object>{'signingKeyFingerprint': fingerprint},
      });
      final signer = parseMihonRepositorySigningFingerprint(rawSidecar);
      final validEntry = MangaExtensionEntry.fromIndex(<String, dynamic>{
        'name': 'Example',
        'packageName': 'eu.kanade.tachiyomi.extension.en.example',
        'resources': <String, dynamic>{
          'apkUrl': 'https://example.com/example.apk',
        },
      }, signingKey: signer);
      final untrustedEntry = MangaExtensionEntry.fromIndex(<String, dynamic>{
        'name': 'Example',
        'packageName': 'eu.kanade.tachiyomi.extension.en.example',
        'resources': <String, dynamic>{
          'apkUrl': 'https://example.com/example.apk',
        },
      });

      expect(validEntry.canInstall, isTrue);
      expect(untrustedEntry.canInstall, isFalse);
    });

    test('accepts only the exact nested signingKeyFingerprint field', () {
      expect(
        parseMihonRepositorySigningFingerprint(<String, Object>{
          'meta': <String, Object>{'signingKeyFingerprint': fingerprint},
        }),
        fingerprint,
      );
      final colonSeparatedUppercase = fingerprint
          .toUpperCase()
          .replaceAllMapped(RegExp(r'.{2}'), (match) => '${match[0]}:');
      expect(
        parseMihonRepositorySigningFingerprint(<String, Object>{
          'meta': <String, Object>{
            'signingKeyFingerprint': colonSeparatedUppercase,
          },
        }),
        fingerprint,
      );
      expect(
        parseMihonRepositorySigningFingerprint(<String, Object>{
          'meta': <String, Object>{'signingKey': fingerprint},
        }),
        isNull,
      );
      expect(
        parseMihonRepositorySigningFingerprint(<String, Object>{
          'signingKeyFingerprint': fingerprint,
        }),
        isNull,
      );
      expect(parseMihonRepositorySigningFingerprint('{broken json'), isNull);
    });
  });
}
