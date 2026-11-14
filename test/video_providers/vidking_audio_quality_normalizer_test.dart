import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/vidking_audio_quality_normalizer.dart';

void main() {
  group('VidkingAudioQualityNormalizer', () {
    test('normalizes allow-listed language names and language tags', () {
      expect(
        VidkingAudioQualityNormalizer.normalizeAudioLanguage('English'),
        'English',
      );
      expect(
        VidkingAudioQualityNormalizer.normalizeAudioLanguage('en-US'),
        'English',
      );
      expect(
        VidkingAudioQualityNormalizer.normalizeAudioLanguage('Hindi'),
        'Hindi',
      );
      expect(
        VidkingAudioQualityNormalizer.normalizeAudioLanguage('hi-IN'),
        'Hindi',
      );
      expect(
        VidkingAudioQualityNormalizer.normalizeAudioLanguage('ar_SA'),
        'Arabic',
      );
    });

    test('does not guess languages from arbitrary labels', () {
      for (final value in <String>[
        'Multi',
        'English dub 1080p',
        'Original + Multi Audio',
        'All Languages',
        'Provider-X',
        '1080p',
      ]) {
        expect(
          VidkingAudioQualityNormalizer.normalizeAudioLanguage(value),
          isNull,
          reason: 'Unexpected language inference for "$value"',
        );
      }
    });

    test(
      'migrates legacy Vyse and Fade language values out of qualityFilter',
      () {
        for (final entry in <(String, String)>[
          ('vyse', 'English'),
          ('fade', 'Hindi'),
        ]) {
          final normalized = VidkingAudioQualityNormalizer.normalizeDescriptor(
            SourceEngineDescriptor(
              rawType: 'vidking-direct',
              kind: SourceEngineKind.vidkingDirect,
              endpoint: 'sources-with-title',
              qualityFilter: entry.$2,
            ),
          );
          expect(normalized.audioLanguage, entry.$2, reason: entry.$1);
          expect(normalized.qualityFilter, isNull, reason: entry.$1);
        }
      },
    );

    test('keeps explicit audio language and resolution filter independent', () {
      final normalized = VidkingAudioQualityNormalizer.normalizeDescriptor(
        const SourceEngineDescriptor(
          rawType: 'vidking-direct',
          kind: SourceEngineKind.vidkingDirect,
          endpoint: 'sources-with-title',
          audioLanguage: 'Arabic',
          language: 'hindi',
          qualityFilter: '1080p',
        ),
      );

      expect(normalized.audioLanguage, 'Arabic');
      expect(normalized.qualityFilter, '1080p');
      expect(
        VidkingAudioQualityNormalizer.resolveAudioLanguage(
          preferredAudioLanguage: 'English',
          engine: normalized,
        ),
        'English',
      );
      expect(
        VidkingAudioQualityNormalizer.resolveAudioLanguage(engine: normalized),
        'Arabic',
      );
    });

    test('uses the recognized engine language only as a source default', () {
      const source = SourceManifest(
        id: 'catalog-english',
        name: 'Catalog English',
        language: 'English',
        engine: SourceEngineDescriptor(
          rawType: 'vidking-direct',
          kind: SourceEngineKind.vidkingDirect,
          endpoint: 'sources-with-title',
        ),
      );
      expect(source.language, 'English');
      expect(
        VidkingAudioQualityNormalizer.resolveAudioLanguage(
          engine: source.engine,
        ),
        isNull,
        reason: 'Catalog language must not be treated as audio language',
      );

      const legacyDefault = SourceEngineDescriptor(
        rawType: 'vidking-direct',
        kind: SourceEngineKind.vidkingDirect,
        endpoint: 'sources-with-title',
        language: 'german',
      );
      final normalizedLegacy =
          VidkingAudioQualityNormalizer.normalizeDescriptor(legacyDefault);
      expect(normalizedLegacy.audioLanguage, isNull);
      expect(normalizedLegacy.language, 'german');
      expect(
        VidkingAudioQualityNormalizer.resolveAudioLanguage(
          engine: normalizedLegacy,
        ),
        'German',
      );
    });

    test('recognizes only explicit video quality aliases', () {
      final expected = <String, String>{
        '720': '720p',
        'HD': '720p',
        '1080p': '1080p',
        'Full HD': '1080p',
        '4K': '2160p',
        'UHD': '2160p',
        '4K HDR': '2160p',
        'UHD HDR': '2160p',
      };
      for (final entry in expected.entries) {
        expect(
          VidkingAudioQualityNormalizer.normalizeQualityFilter(entry.key),
          entry.value,
        );
      }
      expect(
        VidkingAudioQualityNormalizer.normalizeQualityFilter('Hindi'),
        isNull,
      );
      expect(
        VidkingAudioQualityNormalizer.normalizeQualityFilter('English'),
        isNull,
      );
    });

    test('720p, 1080p and 4K filters are independent from audio language', () {
      const languages = <String>['English', 'Hindi', 'Arabic'];
      const qualities = <String, String>{
        '720p': '720p',
        '1080p': '1080p',
        '4K': '2160p',
      };
      const streamLabels = <String, String>{
        '720p': '720p',
        '1080p': '1080p',
        '4K': '4K HDR',
      };

      for (final language in languages) {
        for (final quality in qualities.entries) {
          final descriptor = VidkingAudioQualityNormalizer.normalizeDescriptor(
            SourceEngineDescriptor(
              rawType: 'vidking-direct',
              kind: SourceEngineKind.vidkingDirect,
              endpoint: 'sources-with-title',
              audioLanguage: language,
              qualityFilter: quality.key,
            ),
          );
          expect(descriptor.audioLanguage, language);
          expect(descriptor.qualityFilter, quality.value);
          expect(
            VidkingAudioQualityNormalizer.matchesQualityFilter(
              filter: descriptor.qualityFilter,
              streamQuality: streamLabels[quality.key]!,
            ),
            isTrue,
            reason: '$language should not affect ${quality.key}',
          );
          expect(
            VidkingAudioQualityNormalizer.matchesQualityFilter(
              filter: descriptor.qualityFilter,
              streamQuality: '480p',
            ),
            isFalse,
            reason: '${quality.key} should only compare video quality',
          );
        }
      }
    });

    test(
      'unknown filter and unknown stream quality never drop valid streams',
      () {
        expect(
          VidkingAudioQualityNormalizer.matchesQualityFilter(
            filter: 'Hindi',
            streamQuality: '1080p',
          ),
          isTrue,
        );
        expect(
          VidkingAudioQualityNormalizer.matchesQualityFilter(
            filter: '1080p',
            streamQuality: 'Provider Adaptive',
          ),
          isTrue,
        );
        expect(
          VidkingAudioQualityNormalizer.matchesQualityFilter(
            filter: 'Auto',
            streamQuality: '720p',
          ),
          isTrue,
        );
      },
    );

    test('does not rewrite descriptors for other engine types', () {
      const stremio = SourceEngineDescriptor(
        rawType: 'stremio',
        kind: SourceEngineKind.stremio,
        audioLanguage: 'ar',
        qualityFilter: 'Hindi',
      );
      expect(
        identical(
          VidkingAudioQualityNormalizer.normalizeDescriptor(stremio),
          stremio,
        ),
        isTrue,
      );
    });
  });
}
