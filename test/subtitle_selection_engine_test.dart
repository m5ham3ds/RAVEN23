import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/models/external_subtitles.dart';
import 'package:raven23/services/subtitle_selection_engine.dart';

ExternalSubtitle _candidate({
  required String id,
  String language = 'en',
  String release = '',
  bool? exactIdentity = true,
  bool? trusted = false,
  int? ratingGood,
  int? ratingBad,
  int? downloadCount,
  String source = 'SubSource',
}) => ExternalSubtitle(
  id: id,
  url: 'https://subtitle.test/$id.srt',
  flagUrl: '',
  format: 'srt',
  encoding: 'UTF-8',
  display: language,
  language: language,
  media: 'movie',
  isHearingImpaired: false,
  release: release,
  source: source,
  isExactIdentity: exactIdentity,
  isTrustedUploader: trusted,
  ratingGood: ratingGood,
  ratingBad: ratingBad,
  downloadCount: downloadCount,
);

void main() {
  group('SubtitleSelectionEngine', () {
    test('filters only the explicitly selected language', () {
      final english = _candidate(id: 'english', language: 'en');
      final arabic = _candidate(id: 'arabic', language: 'ar');

      final selected = SubtitleSelectionEngine.rankForLanguage(
        candidates: [english, arabic],
        languageCode: 'English',
      );

      expect(selected, [same(english)]);
    });

    test('uses release signals before popularity', () {
      final popularWrongRelease = _candidate(
        id: 'popular',
        release: 'BluRay 720p',
        downloadCount: 100000,
      );
      final matchingSignals = _candidate(
        id: 'matching',
        release: 'Show.S01E02.WEB-DL.1080p.x265',
        downloadCount: 2,
      );

      final selected = SubtitleSelectionEngine.rankForLanguage(
        candidates: [popularWrongRelease, matchingSignals],
        languageCode: 'en',
        expectedRelease: '1080p WEB-DL',
      );

      expect(selected.map((item) => item.id), ['matching', 'popular']);
    });

    test('does not let provider name outrank uploader and rating evidence', () {
      final trustedCommunity = _candidate(
        id: 'trusted',
        trusted: true,
        source: 'Scraper API',
        ratingGood: 8,
        ratingBad: 1,
      );
      final untrustedPopular = _candidate(
        id: 'popular',
        trusted: false,
        source: 'SubSource',
        ratingGood: 5,
        ratingBad: 5,
        downloadCount: 50000,
      );

      final selected = SubtitleSelectionEngine.rankForLanguage(
        candidates: [untrustedPopular, trustedCommunity],
        languageCode: 'en',
      );

      expect(selected.first.id, 'trusted');
    });

    test('rejects a candidate explicitly marked as wrong media identity', () {
      final wrongIdentity = _candidate(id: 'wrong', exactIdentity: false);
      final unknownIdentity = _candidate(id: 'unknown', exactIdentity: null);

      final selected = SubtitleSelectionEngine.rankForLanguage(
        candidates: [wrongIdentity, unknownIdentity],
        languageCode: 'en',
      );

      expect(selected.map((item) => item.id), ['unknown']);
    });

    test('normalizes language aliases without changing displayed language', () {
      expect(SubtitleSelectionEngine.normalizeLanguageCode('ARA'), 'ar');
      expect(SubtitleSelectionEngine.normalizeLanguageCode('English'), 'en');
      expect(SubtitleSelectionEngine.normalizeLanguageCode('pt-BR'), 'pt');
    });
  });
}
