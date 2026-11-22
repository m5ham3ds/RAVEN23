import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:raven23/models/external_subtitles.dart';
import 'package:raven23/services/external_subtitle_service.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/media_identity_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String? _headerValue(http.Request request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput:
          'OPENSUBTITLES_API_KEY=\nSUBSOURCE_API_KEY=\nARABICSUBS_PROXY_URL=',
    );
  });

  group('ExternalSubtitleService', () {
    test(
      'does not call the legacy OpenSubtitles endpoint when no v1 key is set',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          return http.Response('[]', 200);
        });
        final resolver = MediaIdentityResolver(
          lookup: (UnifiedMediaType type, int tmdbId) async => 'tt1234567',
        );
        final service = ExternalSubtitleService(
          '',
          client: client,
          identityResolver: resolver,
          openSubtitlesApiKey: '',
        );

        final results = await service.fetchMovieSubtitles(
          42,
          title: 'Example movie',
          year: 2025,
          preferredLanguageCode: 'ar',
        );

        expect(results, isEmpty);
        expect(
          requests.where(
            (request) => request.url.host == 'rest.opensubtitles.org',
          ),
          isEmpty,
        );
        expect(
          requests.where(
            (request) => request.url.host == 'api.opensubtitles.com',
          ),
          isEmpty,
        );
      },
    );

    test(
      'matches ArabicSubs only by exact TMDB provider identity',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/search') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 16,
                    'providerId': '42',
                    'type': 'movie',
                    'year': 2025,
                    'title': 'Example movie',
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path == '/titles/16/subtitles') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 12345,
                    'originalFilename': 'Example.Movie.2025.WEB-DL.srt',
                    'releaseLabel': 'WEB-DL 1080p',
                    'hearingImpaired': false,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        });
        final resolver = MediaIdentityResolver(
          lookup: (UnifiedMediaType type, int tmdbId) async => 'tt1234567',
        );
        final service = ExternalSubtitleService(
          '',
          client: client,
          identityResolver: resolver,
          arabicSubsProxyUrl: 'https://arabicsubs-proxy.example.test',
        );

        final results = await service.fetchMovieSubtitles(
          42,
          title: 'Example movie',
          year: 2025,
          preferredLanguageCode: 'ar',
        );

        expect(results, hasLength(1));
        expect(results.single.source, 'ArabicSubs');
        expect(results.single.id, 'arabicsubs_12345');
        expect(results.single.url, 'arabicsubs-proxy://subtitle/12345');
        expect(results.single.language, 'ar');
        expect(
          requests.map((request) => request.url.path),
          containsAllInOrder(['/search', '/titles/16/subtitles']),
        );
      },
    );

    test(
      'does not fall back to same-title/year ArabicSubs results without TMDB id',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/search') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 17,
                    'type': 'movie',
                    'year': 2025,
                    'title': 'Example movie',
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        });
        final service = ExternalSubtitleService(
          '',
          client: client,
          identityResolver: MediaIdentityResolver(
            lookup: (UnifiedMediaType type, int tmdbId) async => 'tt1234567',
          ),
          arabicSubsProxyUrl: 'https://arabicsubs-proxy.example.test',
        );

        final results = await service.fetchMovieSubtitles(
          42,
          title: 'Example movie',
          year: 2025,
          preferredLanguageCode: 'ar',
        );

        expect(results, isEmpty);
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/search');
      },
    );

    test(
      'uses OpenSubtitles v1 Arabic search and downloads its temporary link',
      () async {
        const arabicSrt = '1\n00:00:01,000 --> 00:00:02,000\nمرحبا\n';
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.url.host == 'api.opensubtitles.com' &&
              request.method == 'GET' &&
              request.url.path.endsWith('/subtitles')) {
            expect(_headerValue(request, 'Api-Key'), 'test-open-key');
            expect(_headerValue(request, 'User-Agent'), 'RAVEN23 PRO v1.0');
            expect(request.url.queryParameters['languages'], 'ar,en');
            expect(request.url.queryParameters['ai_translated'], 'exclude');
            expect(request.url.queryParameters['machine_translated'], 'exclude');
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'attributes': {
                      'language': 'ara',
                      'hearing_impaired': false,
                      'release': 'Example.Arabic.Release',
                      'download_count': 321,
                      'new_download_count': 12,
                      'ratings': 8.5,
                      'votes': 4,
                      'fps': 23.976,
                      'from_trusted': true,
                      'foreign_parts_only': false,
                      'upload_date': '2026-10-01T12:00:00Z',
                      'uploader': {
                        'name': 'Trusted Contributor',
                        'rank': 'trusted',
                      },
                      'files': [
                        {'file_id': 4567, 'file_name': 'arabic.srt'},
                      ],
                    },
                  },
                  {
                    'attributes': {
                      'language': 'ara',
                      'ai_translated': true,
                      'release': 'Example.AI.Generated',
                      'files': [
                        {'file_id': 4568, 'file_name': 'ai.srt'},
                      ],
                    },
                  },
                  {
                    'attributes': {
                      'language': 'ara',
                      'machine_translated': true,
                      'release': 'Example.Machine.Generated',
                      'files': [
                        {'file_id': 4569, 'file_name': 'machine.srt'},
                      ],
                    },
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.host == 'api.opensubtitles.com' &&
              request.method == 'POST' &&
              request.url.path.endsWith('/download')) {
            expect(_headerValue(request, 'Api-Key'), 'test-open-key');
            expect(jsonDecode(request.body)['file_id'], 4567);
            return http.Response(
              jsonEncode({'link': 'https://download.example.test/arabic.srt'}),
              200,
            );
          }
          if (request.url.host == 'download.example.test') {
            return http.Response.bytes(utf8.encode(arabicSrt), 200);
          }
          return http.Response('not found', 404);
        });
        final resolver = MediaIdentityResolver(
          lookup: (UnifiedMediaType type, int tmdbId) async => 'tt1234567',
        );
        final service = ExternalSubtitleService(
          '',
          client: client,
          identityResolver: resolver,
          openSubtitlesApiKey: 'test-open-key',
        );

        final results = await service.fetchMovieSubtitles(
          42,
          title: 'Example movie',
          year: 2025,
          preferredLanguageCode: 'ar',
        );
        expect(results, hasLength(1));
        expect(results.single.language, 'ar');
        expect(results.single.url, 'opensubtitles-v1://file/4567');
        expect(results.single.downloadCount, 321);
        expect(results.single.newDownloadCount, 12);
        expect(results.single.providerRating, 8.5);
        expect(results.single.providerVotes, 4);
        expect(results.single.frameRate, 23.976);
        expect(results.single.uploaderName, 'Trusted Contributor');
        expect(results.single.uploaderRank, 'trusted');
        expect(results.single.isTrustedUploader, isTrue);
        expect(results.single.createdAt, '2026-10-01T12:00:00Z');

        final vtt = await service.downloadAndNormalizeForPlayback(
          results.single,
        );
        expect(vtt, contains('WEBVTT'));
        expect(vtt, contains('مرحبا'));
        expect(
          requests.where(
            (request) => request.url.host == 'api.opensubtitles.com',
          ),
          hasLength(2),
        );
      },
    );

    test(
      'searches documented SubSource API by IMDb and filters the exact episode',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.url.host == 'rest.opensubtitles.org') {
            return http.Response('[]', 200);
          }
          if (request.url.host == 'api.subsource.net' &&
              request.url.path == '/api/v1/movies/search') {
            expect(request.method, 'GET');
            expect(_headerValue(request, 'X-API-Key'), 'test-subsource-key');
            expect(request.url.queryParameters['searchType'], 'imdb');
            expect(request.url.queryParameters['imdb'], 'tt1234567');
            expect(request.url.queryParameters['type'], 'series');
            expect(request.url.queryParameters['season'], '1');
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'movieId': 9901,
                    'imdbId': 'tt1234567',
                    'type': 'series',
                    'releaseYear': 2022,
                    'season': 1,
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.host == 'api.subsource.net' &&
              request.url.path == '/api/v1/subtitles') {
            expect(_headerValue(request, 'X-API-Key'), 'test-subsource-key');
            expect(request.url.queryParameters['movieId'], '9901');
            if (request.url.queryParameters['language'] == 'english') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [
                    {
                      'subtitleId': 10,
                      'movieId': 9901,
                      'language': 'english',
                      'releaseInfo': ['Example.Show.S01E02.1080p.WEB-DL'],
                      'hearingImpaired': false,
                      'foreignParts': false,
                      'productionType': 'retail',
                      'releaseType': 'web',
                      'downloads': 17,
                      'framerate': 23.976,
                      'rating': {'good': 5, 'bad': 1, 'total': 6},
                      'contributors': [
                        {'id': 7, 'displayname': 'Example Translator'},
                      ],
                      'createdAt': '2026-01-01T00:00:00.000Z',
                    },
                    {
                      'subtitleId': 11,
                      'movieId': 9901,
                      'language': 'english',
                      'releaseInfo': ['Example.Show.S01E03.1080p.WEB-DL'],
                      'hearingImpaired': false,
                      'productionType': 'retail',
                    },
                    {
                      'subtitleId': 12,
                      'movieId': 9901,
                      'language': 'french',
                      'releaseInfo': ['Example.Show.S01E02.1080p.WEB-DL'],
                    },
                    {
                      'subtitleId': 13,
                      'movieId': 9901,
                      'language': 'english',
                      'releaseInfo': ['Example.Show.S01E02-E04.PACK'],
                    },
                  ],
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'success': true, 'data': []}), 200);
          }
          return http.Response('not found', 404);
        });
        final resolver = MediaIdentityResolver(
          lookup: (UnifiedMediaType type, int tmdbId) async => 'tt1234567',
        );
        final service = ExternalSubtitleService(
          '',
          client: client,
          identityResolver: resolver,
          subSourceApiKey: 'test-subsource-key',
        );

        final results = await service.fetchTVSubtitles(
          99,
          1,
          2,
          title: 'Example Show',
          preferredLanguageCode: 'en',
        );

        expect(results, hasLength(1));
        final subtitle = results.single;
        expect(subtitle.source, 'SubSource');
        expect(subtitle.id, 'subsource_v2_10');
        expect(subtitle.url, 'subsource-v2://subtitle/10');
        expect(subtitle.release, 'Example.Show.S01E02.1080p.WEB-DL');
        expect(subtitle.productionType, 'retail');
        expect(subtitle.releaseType, 'web');
        expect(subtitle.downloadCount, 17);
        expect(subtitle.ratingGood, 5);
        expect(subtitle.ratingBad, 1);
        expect(subtitle.uploaderName, 'Example Translator');
        expect(subtitle.providerVotes, 6);
        expect(subtitle.frameRate, 23.976);
        expect(
          requests.where(
            (request) => request.url.path == '/api/v1/movies/search',
          ),
          hasLength(1),
        );
        expect(
          requests.where(
            (request) => request.url.path == '/api/v1/subtitles',
          ),
          isNotEmpty,
        );
      },
    );

    test(
      'downloads SubSource ZIP directly from the documented download endpoint',
      () async {
        const srt =
            '1\n00:00:01,000 --> 00:00:02,000\nDocumented API subtitle\n';
        final archive = Archive()
          ..addFile(
            ArchiveFile(
              'track.srt',
              utf8.encode(srt).length,
              Uint8List.fromList(utf8.encode(srt)),
            ),
          );
        final zipBytes = ZipEncoder().encodeBytes(archive);
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          expect(request.method, 'GET');
          expect(_headerValue(request, 'X-API-Key'), 'test-subsource-key');
          if (request.url.path == '/api/v1/subtitles/20/download') {
            return http.Response.bytes(zipBytes, 200);
          }
          return http.Response('not found', 404);
        });
        final service = ExternalSubtitleService(
          '',
          client: client,
          subSourceApiKey: 'test-subsource-key',
        );
        final source = await service.convertToBetterPlayerSource(
          ExternalSubtitle(
            id: 'subsource_v2_20',
            url: 'subsource-v2://subtitle/20',
            flagUrl: '',
            format: 'auto',
            encoding: 'zip/auto',
            display: 'English',
            language: 'en',
            media: 'movie',
            isHearingImpaired: false,
            release: 'Example.Release',
            source: 'SubSource',
          ),
        );

        expect(source.content, contains('WEBVTT'));
        expect(source.content, contains('Documented API subtitle'));
        expect(requests, hasLength(1));
      },
    );

    test(
      'decompresses an OpenSubtitles gzip download with its required user agent',
      () async {
        const srt = '1\n00:00:01,000 --> 00:00:02,000\nOpenSubtitles cue\n';
        final compressed = gzip.encode(utf8.encode(srt));
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          return http.Response.bytes(compressed, 200);
        });
        final service = ExternalSubtitleService('', client: client);
        final source = await service.convertToBetterPlayerSource(
          ExternalSubtitle(
            id: 'opensubtitles_44',
            url: 'https://dl.opensubtitles.org/sub/44.gz',
            flagUrl: '',
            format: 'srt',
            encoding: 'gzip/auto',
            display: 'English',
            language: 'en',
            media: 'movie',
            isHearingImpaired: false,
            release: 'Example.Release',
            source: 'OpenSubtitles',
          ),
        );

        expect(source.content, contains('WEBVTT'));
        expect(source.content, contains('OpenSubtitles cue'));
        expect(
          _headerValue(requests.single, 'user-agent'),
          'RAVEN23 PRO v1.0',
        );
        expect(
          _headerValue(requests.single, 'x-user-agent'),
          'RAVEN23 PRO v1.0',
        );
      },
    );

    test(
      'keeps different releases while deduplicating repeated release records',
      () {
        ExternalSubtitle make(
          String id,
          String url,
          String release,
          String source,
        ) => ExternalSubtitle(
          id: id,
          url: url,
          flagUrl: '',
          format: 'srt',
          encoding: 'UTF-8',
          display: 'English',
          language: 'en',
          media: 'movie',
          isHearingImpaired: false,
          release: release,
          source: source,
        );
        final merged = ExternalSubtitleService.mergeSearchResultsForTesting(
          <ExternalSubtitle>[
            make('1', 'https://one.test/1', 'Movie.Release.A', 'OpenSubtitles'),
            make('2', 'https://two.test/2', 'Movie.Release.A', 'SubSource'),
            make('3', 'https://three.test/3', 'Movie.Release.B', 'SubSource'),
          ],
          'en',
        );
        expect(merged, hasLength(2));
        expect(
          merged.map((item) => item.release),
          containsAll(<String>['Movie.Release.A', 'Movie.Release.B']),
        );
      },
    );

    test(
      'puts Arabic before English when Arabic is the preferred subtitle language',
      () {
        ExternalSubtitle make({required String id, required String language}) =>
            ExternalSubtitle(
              id: id,
              url: 'https://subtitle.test/$id.srt',
              flagUrl: '',
              format: 'srt',
              encoding: 'UTF-8',
              display: language == 'ar' ? 'Arabic' : 'English',
              language: language,
              media: 'movie',
              isHearingImpaired: false,
              release: 'Release.$id',
              source: 'OpenSubtitles',
            );
        final results = ExternalSubtitleService.mergeSearchResultsForTesting(
          <ExternalSubtitle>[
            make(id: 'en', language: 'en'),
            make(id: 'ar', language: 'ar'),
          ],
          'ar',
        );
        expect(results.first.language, 'ar');
        expect(results.last.language, 'en');
      },
    );

    test('prefers SubSource for Arabic before duplicate-release removal', () {
      ExternalSubtitle make({
        required String id,
        required String source,
        required String url,
      }) => ExternalSubtitle(
        id: id,
        url: url,
        flagUrl: '',
        format: 'srt',
        encoding: 'UTF-8',
        display: 'Arabic',
        language: 'ar',
        media: 'movie',
        isHearingImpaired: false,
        release: 'Resident.Evil.2026.WEB',
        source: source,
      );

      final results = ExternalSubtitleService.mergeSearchResultsForTesting(
        <ExternalSubtitle>[
          make(
            id: 'opensubs',
            source: 'OpenSubtitles',
            url: 'https://opensubs.test/ar.srt',
          ),
          make(
            id: 'scraper',
            source: 'Scraper API',
            url: 'https://scraper.test/ar.srt',
          ),
          make(
            id: 'subsource',
            source: 'SubSource',
            url: 'https://subsource.test/ar.zip',
          ),
        ],
        'ar',
      );

      expect(results, hasLength(1));
      expect(results.single.source, 'SubSource');
    });

    test('episode matching does not confuse E02 with E020', () {
      final matcher = ExternalSubtitleService.episodePatternForTesting(1, 2);
      expect(matcher.hasMatch('Example.S01E02.1080p'), isTrue);
      expect(matcher.hasMatch('Example.1x02.1080p'), isTrue);
      expect(matcher.hasMatch('Example.S01E020.1080p'), isFalse);
    });

    test('keeps SubSource when Arabic providers return the same URL', () {
      ExternalSubtitle make(String source) => ExternalSubtitle(
        id: source,
        url: 'https://subtitles.test/resident-evil-ar.zip',
        flagUrl: '',
        format: 'zip',
        encoding: 'zip/auto',
        display: 'Arabic',
        language: 'ar',
        media: 'movie',
        isHearingImpaired: false,
        release: 'Resident.Evil.2026.WEB',
        source: source,
      );

      final results = ExternalSubtitleService.mergeSearchResultsForTesting(
        <ExternalSubtitle>[make('OpenSubtitles'), make('SubSource')],
        'ar',
      );

      expect(results, hasLength(1));
      expect(results.single.source, 'SubSource');
    });
  });
}
