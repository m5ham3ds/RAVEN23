import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/episode_identity_normalizer.dart';

void main() {
  group('EpisodeIdentityNormalizer', () {
    test('selects the requested season when episode numbers repeat', () {
      final match = EpisodeIdentityNormalizer.findExactEpisode(
        episodes: <dynamic>[
          <String, dynamic>{
            'title': 'S01E08 - Earlier episode',
            'url': 'https://source.example/season-1-episode-8',
          },
          <String, dynamic>{
            'title': 'S02E08 - Requested episode',
            'url': 'https://source.example/season-2-episode-8',
          },
        ],
        seasonNumber: 2,
        episodeNumber: 8,
      );

      expect(match?['url'], 'https://source.example/season-2-episode-8');
    });

    test('does not treat a missing season as a wildcard', () {
      final match = EpisodeIdentityNormalizer.findExactEpisode(
        episodes: <dynamic>[
          <String, dynamic>{
            'number': 8,
            'title': 'Episode 8',
            'url': 'https://source.example/episode-8',
          },
        ],
        seasonNumber: 2,
        episodeNumber: 8,
      );

      expect(match, isNull);
    });

    test('uses an explicit season declared by the parent detail response', () {
      final inheritedSeason =
          EpisodeIdentityNormalizer.explicitSeasonFromParent(<String, dynamic>{
            'season_number': 2,
            'episodes': <dynamic>[],
          });
      final match = EpisodeIdentityNormalizer.findExactEpisode(
        episodes: <dynamic>[
          <String, dynamic>{
            'episode_number': 8,
            'title': 'Episode 8',
            'url': 'https://source.example/s2e8',
          },
        ],
        seasonNumber: 2,
        episodeNumber: 8,
        inheritedSeasonNumber: inheritedSeason,
      );

      expect(inheritedSeason, 2);
      expect(match?['url'], 'https://source.example/s2e8');
    });

    test('parses season and episode from title, URL, and provider ID', () {
      for (final item in <Map<String, dynamic>>[
        <String, dynamic>{'title': 'Show S02E08'},
        <String, dynamic>{'url': 'https://source.example/watch/S02E08'},
        <String, dynamic>{'id': 'show-2x08'},
        <String, dynamic>{'name': 'Season 2 Episode 8'},
        <String, dynamic>{'name': 'الموسم 2 الحلقة 8'},
        <String, dynamic>{'episode_number': 'S02E08'},
      ]) {
        final coordinate = EpisodeIdentityNormalizer.fromProviderItem(item);
        expect(coordinate?.seasonNumber, 2, reason: '$item');
        expect(coordinate?.episodeNumber, 8, reason: '$item');
      }
    });

    test('rejects conflicting explicit and embedded coordinates', () {
      final coordinate =
          EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
            'season_number': 1,
            'episode_number': 8,
            'title': 'S02E08 - conflicting provider metadata',
          });

      expect(coordinate, isNull);
    });

    test('rejects conflicts between explicit season aliases', () {
      final coordinate = EpisodeIdentityNormalizer.fromProviderItem(
        <String, dynamic>{'season': 1, 'season_number': 2, 'episode_number': 8},
      );

      expect(coordinate, isNull);
    });

    test('rejects conflicting episode numbers in title and name aliases', () {
      final coordinate =
          EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
            'season_number': 2,
            'episode_number': 8,
            'title': 'Episode 8 - requested episode',
            'name': 'Episode 9 - conflicting display name',
          });

      expect(coordinate, isNull);
    });

    test('rejects malformed populated season and episode aliases', () {
      expect(
        EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
          'season': 'unknown',
          'season_number': 2,
          'episode_number': 8,
        }),
        isNull,
      );
      expect(
        EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
          'season_number': 2,
          'episode_number': 'not available',
          'number': 8,
        }),
        isNull,
      );
    });

    test('accepts textual aliases with an explicit paired coordinate', () {
      final coordinate = EpisodeIdentityNormalizer.fromProviderItem(
        <String, dynamic>{'season': 'Season 2', 'episode': 'S02E08'},
      );

      expect(coordinate?.seasonNumber, 2);
      expect(coordinate?.episodeNumber, 8);
    });

    test('rejects a title episode number that conflicts with an ID', () {
      final coordinate = EpisodeIdentityNormalizer.fromProviderItem(
        <String, dynamic>{'title': 'Episode 8', 'id': 'show-S02E09'},
      );

      expect(coordinate, isNull);
    });

    test('rejects different coordinates embedded in title and URL', () {
      final coordinate =
          EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
            'title': 'S01E08 - episode title',
            'url': 'https://source.example/show/S02E08',
          });

      expect(coordinate, isNull);
    });

    test('accepts repeated identical coordinates across metadata fields', () {
      final coordinate =
          EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
            'title': 'S02E08 - episode title',
            'url': 'https://source.example/show/S02E08',
            'episode_number': 8,
          });

      expect(coordinate?.seasonNumber, 2);
      expect(coordinate?.episodeNumber, 8);
    });

    test(
      'distinguishes an absent parent season from a conflicting declaration',
      () {
        expect(
          EpisodeIdentityNormalizer.hasSeasonDeclaration(<String, dynamic>{
            'episodes': <dynamic>[],
          }),
          isFalse,
        );
        expect(
          EpisodeIdentityNormalizer.hasSeasonDeclaration(<String, dynamic>{
            'season': 1,
            'season_number': 2,
          }),
          isTrue,
        );
        expect(
          EpisodeIdentityNormalizer.explicitSeasonFromParent(<String, dynamic>{
            'season': 1,
            'season_number': 2,
          }),
          isNull,
        );
      },
    );

    test('rejects conflicting season values in a parent detail response', () {
      final inheritedSeason =
          EpisodeIdentityNormalizer.explicitSeasonFromParent(<String, dynamic>{
            'season': 1,
            'season_number': 2,
          });

      expect(inheritedSeason, isNull);
    });

    test('rejects non-integral and negative coordinates', () {
      expect(
        EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
          'season': 2.5,
          'number': 8,
        }, inheritedSeasonNumber: 2),
        isNull,
      );
      expect(
        EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
          'season': -1,
          'number': 8,
        }),
        isNull,
      );
      expect(
        EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
          'season': 2,
          'number': 8.5,
        }),
        isNull,
      );
    });

    test(
      'rejects an embedded season that conflicts with its parent season',
      () {
        final coordinate = EpisodeIdentityNormalizer.fromProviderItem(
          <String, dynamic>{'title': 'S01E08'},
          inheritedSeasonNumber: 2,
        );

        expect(coordinate, isNull);
      },
    );

    test('does not mistake video dimensions for season and episode', () {
      final coordinate =
          EpisodeIdentityNormalizer.fromProviderItem(<String, dynamic>{
            'title': 'S02E08 - requested episode',
            'url': 'https://cdn.example/video/1920x1080/master.m3u8',
          });

      expect(coordinate?.seasonNumber, 2);
      expect(coordinate?.episodeNumber, 8);
    });

    test('accepts season zero specials without guessing other seasons', () {
      final coordinate = EpisodeIdentityNormalizer.fromProviderItem(
        <String, dynamic>{'title': 'S00E01 Special'},
      );

      expect(coordinate?.seasonNumber, 0);
      expect(coordinate?.episodeNumber, 1);
    });
  });
}
