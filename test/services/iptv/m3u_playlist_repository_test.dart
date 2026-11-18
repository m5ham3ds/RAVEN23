import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/services/iptv/m3u_playlist_repository.dart';
import 'package:raven23/video_providers/unified/source_host_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    tempDirectory = await Directory.systemTemp.createTemp('raven23-m3u-repo-');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'remote playlist is parsed, cached and conditionally revalidated',
    () async {
      const playlist = '''#EXTM3U
#EXTINF:-1 tvg-id="channel.one" group-title="News",Channel One
https://stream.example/live.m3u8
''';
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            playlist,
            200,
            headers: <String, String>{
              'etag': '"playlist-v1"',
              'last-modified': 'Sun, 08 Nov 2026 00:00:00 GMT',
            },
          );
        }
        expect(request.headers['If-None-Match'], '"playlist-v1"');
        expect(
          request.headers['If-Modified-Since'],
          'Sun, 08 Nov 2026 00:00:00 GMT',
        );
        return http.Response('', 304);
      });
      final repository = M3uPlaylistRepository(
        preferences: preferences,
        client: client,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
        directoryProvider: () async => tempDirectory,
      );
      addTearDown(repository.close);

      final definition = await repository.addRemote(
        url: 'https://lists.example/playlist.m3u',
      );
      final first = await repository.loadContent(definition);
      expect(first.text, contains('Channel One'));
      expect(first.baseUri, Uri.parse('https://lists.example/playlist.m3u'));
      expect(calls, 1);

      // A fresh cache is used without a second network request.
      final cached = await repository.loadContent(definition);
      expect(cached.text, first.text);
      expect(calls, 1);

      // Explicit refresh sends validators and accepts HTTP 304 without losing data.
      final revalidated = await repository.loadContent(
        definition,
        refresh: true,
      );
      expect(revalidated.text, first.text);
      expect(calls, 2);
    },
  );

  test(
    'remote redirects are revalidated and cannot target loopback hosts',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          '',
          302,
          headers: <String, String>{'location': 'http://127.0.0.1/private.m3u'},
        );
      });
      final repository = M3uPlaylistRepository(
        preferences: preferences,
        client: client,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
        directoryProvider: () async => tempDirectory,
      );
      addTearDown(repository.close);

      final definition = await repository.addRemote(
        url: 'https://lists.example/redirect.m3u',
      );
      await expectLater(
        repository.loadContent(definition),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 1);
    },
  );

  test(
    'playlist count is bounded and duplicate URLs do not consume slots',
    () async {
      final repository = M3uPlaylistRepository(
        preferences: preferences,
        hostPolicy: const SourceHostPolicy(resolveDns: false),
        directoryProvider: () async => tempDirectory,
      );
      addTearDown(repository.close);

      final first = await repository.addRemote(
        url: 'https://lists.example/one.m3u',
        name: 'First',
      );
      final duplicate = await repository.addRemote(
        url: 'https://lists.example/one.m3u',
        name: 'Renamed',
      );
      expect(duplicate.id, first.id);
      for (
        var index = 2;
        index <= M3uPlaylistRepository.maxPlaylistCount;
        index++
      ) {
        await repository.addRemote(url: 'https://lists.example/$index.m3u');
      }
      await expectLater(
        repository.addRemote(url: 'https://lists.example/overflow.m3u'),
        throwsA(isA<FormatException>()),
      );
      expect(await repository.playlists(), hasLength(8));
    },
  );
}
