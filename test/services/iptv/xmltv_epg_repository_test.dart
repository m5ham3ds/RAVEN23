import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/services/iptv/xmltv_epg_repository.dart';
import 'package:raven23/video_providers/unified/source_host_policy.dart';

const _feed = '''<tv>
  <channel id="one"><display-name>One</display-name></channel>
  <programme start="20261108080000 +0000" stop="20261108090000 +0000" channel="one"><title>Programme</title></programme>
</tv>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'downloads, parses and returns a fresh compressed cache entry',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.url.host, 'guide.example');
        return http.Response(
          _feed,
          200,
          headers: <String, String>{'etag': '"guide-v1"'},
        );
      });
      final repository = XmlTvEpgRepository(
        client: client,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      );

      final first = await repository.load('https://guide.example/epg.xml');
      final second = await repository.load('https://guide.example/epg.xml');

      expect(first.guide.programmes, hasLength(1));
      expect(first.isStale, isFalse);
      expect(second.guide.programmes.single.title, 'Programme');
      expect(requests, 1);
      repository.close();
    },
  );

  test(
    'sends HTTP validators and refreshes cache after 304 Not Modified',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response(
            _feed,
            200,
            headers: <String, String>{'etag': '"guide-v1"'},
          );
        }
        expect(request.headers['If-None-Match'], '"guide-v1"');
        return http.Response('', 304);
      });
      final repository = XmlTvEpgRepository(
        client: client,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
        cacheTtl: Duration.zero,
      );

      await repository.load('https://guide.example/epg.xml');
      final refreshed = await repository.load(
        'https://guide.example/epg.xml',
        refresh: true,
      );

      expect(refreshed.isStale, isFalse);
      expect(refreshed.guide.programmes.single.title, 'Programme');
      expect(requests, 2);
      repository.close();
    },
  );

  test(
    'uses an explicit stale marker if a previously valid feed fails',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        if (requests == 1) return http.Response(_feed, 200);
        return http.Response('unavailable', 503);
      });
      final repository = XmlTvEpgRepository(
        client: client,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
        cacheTtl: Duration.zero,
        staleLimit: const Duration(days: 3),
      );

      final initial = await repository.load('https://guide.example/epg.xml');
      final stale = await repository.load(
        'https://guide.example/epg.xml',
        refresh: true,
      );

      expect(initial.isStale, isFalse);
      expect(stale.isStale, isTrue);
      expect(stale.guide.programmes.single.title, 'Programme');
      repository.close();
    },
  );

  test(
    'revalidates every redirect and refuses a private destination',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response(
          '',
          302,
          headers: <String, String>{'location': 'http://127.0.0.1/private.xml'},
        );
      });
      final repository = XmlTvEpgRepository(
        client: client,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
      );

      await expectLater(
        repository.load('https://guide.example/redirect.xml'),
        throwsA(isA<FormatException>()),
      );
      expect(requests, 1);
      repository.close();
    },
  );

  test('rejects feeds above the declared content-length limit', () async {
    final client = MockClient(
      (request) async => http.Response(
        'too-large',
        200,
        headers: <String, String>{
          'content-length': '${XmlTvEpgRepository.maxFeedBytes + 1}',
        },
      ),
    );
    final repository = XmlTvEpgRepository(
      client: client,
      hostPolicy: const SourceHostPolicy(resolveDns: false),
    );

    await expectLater(
      repository.load('https://guide.example/large.xml'),
      throwsA(isA<FormatException>()),
    );
    repository.close();
  });
}
