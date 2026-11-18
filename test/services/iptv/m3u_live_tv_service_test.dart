import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/services/iptv/m3u_live_tv_service.dart';
import 'package:raven23/services/iptv/m3u_playlist_repository.dart';
import 'package:raven23/services/iptv/xmltv_epg_repository.dart';
import 'package:raven23/video_providers/unified/source_host_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late SharedPreferences preferences;
  late M3uLiveTvService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
    tempDirectory = await Directory.systemTemp.createTemp('raven23-m3u-test-');
    final repository = M3uPlaylistRepository(
      preferences: preferences,
      directoryProvider: () async => tempDirectory,
    );
    service = M3uLiveTvService(repository: repository);
  });

  tearDown(() async {
    service.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('imports local M3U, exposes groups and resolves its stream', () async {
    const playlist = '''#EXTM3U
#EXTINF:-1 tvg-id="sports.one" tvg-logo="https://cdn.example/logo.png" group-title="Sports",Sports One
#EXTVLCOPT:http-origin=https://provider.example
https://media.example/live.m3u8
''';
    await service.addLocalPlaylist(
      filename: 'local.m3u',
      bytes: utf8.encode(playlist),
      name: 'My channels',
    );

    final catalog = await service.getCatalog();
    expect(catalog.channels, hasLength(1));
    expect(catalog.channels.single.name, 'Sports One');
    expect(catalog.channels.single.categories, <String>['Sports']);
    expect(catalog.categories, <String>['Sports']);

    final stream = await service.getStream(catalog.channels.single.id);
    expect(stream.url, 'https://media.example/live.m3u8');
    expect(stream.headers, <String, String>{
      'Origin': 'https://provider.example',
    });
    expect(stream.mediaType, 'hls');
  });

  test('maps XMLTV programmes to M3U tvg-id and fills Now/Next', () async {
    final now = DateTime.now().toUtc();
    String stamp(DateTime value) {
      String two(int part) => part.toString().padLeft(2, '0');
      return '${value.year}${two(value.month)}${two(value.day)}'
          '${two(value.hour)}${two(value.minute)}${two(value.second)} +0000';
    }

    final feed =
        '''<tv>
      <channel id="sports.one"><display-name>Sports One</display-name></channel>
      <programme start="${stamp(now.subtract(const Duration(minutes: 30)))}" stop="${stamp(now.add(const Duration(minutes: 30)))}" channel="sports.one"><title>Playing now</title><category>Sports</category></programme>
      <programme start="${stamp(now.add(const Duration(minutes: 30)))}" stop="${stamp(now.add(const Duration(minutes: 90)))}" channel="sports.one"><title>Coming next</title><category>Sports</category></programme>
    </tv>''';
    final epgRepository = XmlTvEpgRepository(
      preferences: preferences,
      client: MockClient((request) async => http.Response(feed, 200)),
      hostPolicy: const SourceHostPolicy(resolveDns: false),
    );
    service.close();
    final repository = M3uPlaylistRepository(
      preferences: preferences,
      directoryProvider: () async => tempDirectory,
    );
    service = M3uLiveTvService(
      repository: repository,
      epgRepository: epgRepository,
    );
    await service.addLocalPlaylist(
      filename: 'epg.m3u',
      bytes: utf8.encode('''#EXTM3U url-tvg="https://guide.example/epg.xml"
#EXTINF:-1 tvg-id="sports.one" group-title="Sports",Sports One
https://media.example/live.m3u8
'''),
    );

    final catalog = await service.getCatalog();

    expect(catalog.channels.single.tvgId, 'sports.one');
    expect(catalog.channels.single.nowPlaying, 'Playing now');
    expect(catalog.channels.single.nextUp, 'Coming next');
    expect(catalog.epg.days, isNotEmpty);
    expect(
      catalog.epg.days.first.categories.first.events.first.title,
      'Playing now',
    );
  });

  test('EPG failure does not prevent channel catalog or playback', () async {
    final epgRepository = XmlTvEpgRepository(
      preferences: preferences,
      client: MockClient((request) async => http.Response('unavailable', 503)),
      hostPolicy: const SourceHostPolicy(resolveDns: false),
    );
    service.close();
    service = M3uLiveTvService(
      repository: M3uPlaylistRepository(
        preferences: preferences,
        directoryProvider: () async => tempDirectory,
      ),
      epgRepository: epgRepository,
    );
    await service.addLocalPlaylist(
      filename: 'no-epg.m3u',
      bytes: utf8.encode('''#EXTM3U url-tvg="https://guide.example/epg.xml"
#EXTINF:-1 tvg-id="sports.one",Sports One
https://media.example/live.m3u8
'''),
    );

    final catalog = await service.getCatalog();
    final stream = await service.getStream(catalog.channels.single.id);

    expect(catalog.channels, hasLength(1));
    expect(catalog.channels.single.nowPlaying, isNull);
    expect(catalog.epg.days, isEmpty);
    expect(stream.url, 'https://media.example/live.m3u8');
  });

  test('does not persist the original external device file path', () async {
    await service.addLocalPlaylist(
      filename: '/storage/emulated/0/Download/tv.m3u',
      bytes: utf8.encode(
        '''#EXTM3U\n#EXTINF:-1,One\nhttps://tv.example/one.m3u8\n''',
      ),
    );

    final definitions = await service.playlists();
    expect(definitions, hasLength(1));
    expect(definitions.single.localPath, startsWith(tempDirectory.path));
    expect(
      definitions.single.localPath,
      isNot(contains('/storage/emulated/0')),
    );
  });

  test('rejects HLS media files as imported channel playlists', () async {
    await expectLater(
      service.addLocalPlaylist(
        filename: 'media.m3u8',
        bytes: utf8.encode('''#EXTM3U\n#EXT-X-TARGETDURATION:8\n'''),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
