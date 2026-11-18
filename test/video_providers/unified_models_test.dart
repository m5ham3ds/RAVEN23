import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/stream_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaIdentity', () {
    test('builds an IMDb Stremio episode id without losing season/episode', () {
      const media = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Example Series',
        tmdbId: 42,
        seasonNumber: 2,
        episodeNumber: 7,
        externalIds: <String, String>{'imdb': 'tt1234567'},
      );

      expect(media.stremioType, 'series');
      expect(media.stremioId, 'tt1234567:2:7');
      expect(media.isEpisode, isTrue);
    });

    test('appends episode coordinates to namespaced source IDs', () {
      const media = MediaIdentity(
        type: UnifiedMediaType.anime,
        title: 'Example Anime',
        seasonNumber: 1,
        episodeNumber: 4,
        externalIds: <String, String>{'stremio': 'kitsu:12345'},
      );

      expect(media.stremioId, 'kitsu:12345:1:4');
    });

    test('normalizes anime episodes to the series playback kind', () {
      const media = MediaIdentity(
        type: UnifiedMediaType.anime,
        title: 'Example Anime',
        seasonNumber: 1,
        episodeNumber: 4,
      );

      expect(media.normalizedType, UnifiedMediaType.series);
      expect(media.stremioType, 'series');
      expect(media.isAnimeContent, isTrue);
      expect(media.isEpisode, isTrue);
      expect(media.playbackCacheKey, contains('series:'));
    });

    test('keeps Anime and Donghua as classifications, not playback kinds', () {
      const anime = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Anime series',
        seasonNumber: 1,
        episodeNumber: 1,
        contentClassification: MediaContentClassification.anime,
      );
      const donghua = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Donghua series',
        seasonNumber: 1,
        episodeNumber: 1,
        contentClassification: MediaContentClassification.donghua,
      );
      const animation = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Animated series',
        seasonNumber: 1,
        episodeNumber: 1,
        contentClassification: MediaContentClassification.animation,
      );

      expect(anime.normalizedType, UnifiedMediaType.series);
      expect(donghua.normalizedType, UnifiedMediaType.series);
      expect(animation.normalizedType, UnifiedMediaType.series);
      expect(anime.isAnimeContent, isTrue);
      expect(donghua.isAnimeContent, isTrue);
      expect(animation.isAnimeContent, isFalse);
      expect(animation.isAnimationContent, isTrue);
    });

    test('preserves editorial classification when adding external IDs', () {
      const media = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Donghua Series',
        seasonNumber: 1,
        episodeNumber: 2,
        contentClassification: MediaContentClassification.donghua,
      );

      final enriched = media.copyWithExternalIds(const <String, String>{
        'anilist': '12345',
        'mal': '67890',
      });

      expect(enriched.normalizedType, UnifiedMediaType.series);
      expect(
        enriched.normalizedClassification,
        MediaContentClassification.donghua,
      );
      expect(enriched.externalIds['anilist'], '12345');
      expect(enriched.externalIds['mal'], '67890');
    });

    test('keeps an anime feature film on the movie playback kind', () {
      const media = MediaIdentity(
        type: UnifiedMediaType.movie,
        title: 'Anime feature film',
        isAnimeContent: true,
      );

      expect(media.normalizedType, UnifiedMediaType.movie);
      expect(media.isAnimeContent, isTrue);
      expect(media.isEpisode, isFalse);
    });

    test('does not guess an unsupported Stremio id from a TMDB integer', () {
      const media = MediaIdentity(
        type: UnifiedMediaType.movie,
        title: 'Example Movie',
        tmdbId: 42,
      );

      expect(media.stremioId, isNull);
    });
  });

  group('UnifiedStreamOption', () {
    test(
      'round-trips headers, audio, nested subtitles and expiry metadata',
      () {
        final stream = UnifiedStreamOption(
          id: 'source-a::0',
          providerId: 'source-a',
          providerName: 'Source A',
          url: 'https://cdn.example/video.m3u8',
          quality: '1080p',
          container: StreamContainer.hls,
          headers: const <String, String>{'Referer': 'https://example.com/'},
          audioKind: StreamAudioKind.dub,
          audioLanguage: 'en',
          subtitles: const <UnifiedSubtitleTrack>[
            UnifiedSubtitleTrack(
              url: 'https://cdn.example/subs/ar.vtt',
              language: 'ar',
              format: 'vtt',
              isDefault: true,
            ),
          ],
          subtitleOffsetSeconds: 1.25,
          expiresAt: DateTime.utc(2026, 12, 1),
        );

        final restored = UnifiedStreamOption.fromJson(stream.toJson());
        expect(restored.url, stream.url);
        expect(restored.headers['Referer'], 'https://example.com/');
        expect(restored.audioKind, StreamAudioKind.dub);
        expect(restored.audioLanguage, 'en');
        expect(restored.subtitles.single.language, 'ar');
        expect(restored.subtitles.single.isDefault, isTrue);
        expect(restored.subtitleOffsetSeconds, 1.25);
        expect(restored.expiresAt, DateTime.utc(2026, 12, 1));
      },
    );
  });
}
