import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:raven23/services/daddylive_service.dart';
import 'package:raven23/services/ethio_sports_service.dart';

void main() {
  group('EthioSportsService', () {
    test(
      'keeps channel catalog available when the optional EPG is unavailable',
      () async {
        final requests = <Uri>[];
        final service = EthioSportsService(
          baseUrl: 'https://api.example/',
          client: MockClient((request) async {
            requests.add(request.url);
            if (request.url.path.endsWith('/channels')) {
              return _jsonResponse(<String, dynamic>{
                'success': true,
                'channels': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'event-17',
                    'name': 'Test fixture',
                    'categories': <String>['Football'],
                  },
                ],
              });
            }
            if (request.url.path.endsWith('/epg')) {
              return http.Response('<html>temporarily unavailable</html>', 503);
            }
            return http.Response('not found', 404);
          }),
        );
        addTearDown(service.close);

        final catalog = await service.getCatalog();

        expect(catalog.channels, hasLength(1));
        expect(catalog.channels.single.id, 'ethio:event-17');
        expect(catalog.channels.single.categories, <String>['Football']);
        expect(catalog.categories, <String>['Football']);
        expect(catalog.epg.days, isEmpty);
        expect(requests.map((uri) => uri.path).toSet(), <String>{
          '/api/v2/ethiosports/channels',
          '/api/v2/ethiosports/epg',
        });
      },
    );

    test(
      'removes the local channel namespace for stream lookup and preserves metadata',
      () async {
        Uri? requestedUri;
        final service = EthioSportsService(
          baseUrl: 'https://api.example',
          client: MockClient((request) async {
            requestedUri = request.url;
            return _jsonResponse(<String, dynamic>{
              'success': true,
              'url': '/streams/live.m3u8',
              'headers': <String, String>{'Referer': 'https://sports.example/'},
              'embedUrl': 'https://embed.example/event-17',
              'mediaType': 'hls',
              'expiresAt': '2030-01-01T00:00:00Z',
              'streams': <Map<String, dynamic>>[
                <String, dynamic>{
                  'url': '/streams/backup.mpd',
                  'headers': <String, String>{
                    'Origin': 'https://sports.example',
                  },
                  'mediaType': 'dash',
                  'expiresAt': '2030-01-01T00:00:00Z',
                  'title': 'Backup',
                },
              ],
            });
          }),
        );
        addTearDown(service.close);

        final stream = await service.getStream('ethio:event-17');

        expect(
          requestedUri!.path,
          '/api/v2/ethiosports/channels/event-17/stream',
        );
        expect(stream.url, 'https://api.example/streams/live.m3u8');
        expect(stream.headers['Referer'], 'https://sports.example/');
        expect(stream.embedUrl, 'https://embed.example/event-17');
        expect(stream.mediaType, 'hls');
        expect(stream.expiresAt, DateTime.utc(2030));
        expect(stream.variants, hasLength(1));
        expect(
          stream.variants.single.url,
          'https://api.example/streams/backup.mpd',
        );
        expect(stream.variants.single.mediaType, 'dash');
        expect(stream.variants.single.expiresAt, DateTime.utc(2030));
        expect(
          stream.variants.single.headers['Origin'],
          'https://sports.example',
        );
      },
    );

    test(
      'DaddyLive retains HTTP status across watch-page and API fallbacks',
      () async {
        final service = DaddyLiveService(
          baseUrl: 'https://api.example',
          client: MockClient(
            (request) async => http.Response('<html>access denied</html>', 403),
          ),
        );
        addTearDown(service.close);

        await expectLater(
          service.getStream('channel-1'),
          throwsA(
            isA<DaddyLiveException>().having(
              (error) => error.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      },
    );

    test(
      'retains HTTP status when an upstream block returns non-JSON HTML',
      () async {
        final service = EthioSportsService(
          baseUrl: 'https://api.example',
          client: MockClient(
            (request) async => http.Response('<html>access denied</html>', 403),
          ),
        );
        addTearDown(service.close);

        await expectLater(
          service.getCatalog(),
          throwsA(
            isA<DaddyLiveException>().having(
              (error) => error.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      },
    );
  });
}

http.Response _jsonResponse(Map<String, dynamic> json) => http.Response(
  jsonEncode(json),
  200,
  headers: const <String, String>{'content-type': 'application/json'},
);
