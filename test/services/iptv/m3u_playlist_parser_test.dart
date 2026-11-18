import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/services/iptv/live_tv_category_mapper.dart';
import 'package:raven23/services/iptv/m3u_playlist_parser.dart';

void main() {
  const parser = M3uPlaylistParser();

  test('parses quoted EXTINF metadata and VLC headers', () {
    const playlist = '''#EXTM3U
#EXTINF:-1 tvg-id="news.world" tvg-name="World News" tvg-logo="https://cdn.example/logo.png" group-title="International News",World News HD
#EXTVLCOPT:http-user-agent=RAVEN23-Test/1.0
#EXTVLCOPT:http-referrer=https://provider.example/
#EXTVLCOPT:http-cookie=must-not-be-forwarded
https://stream.example/news/index.m3u8
''';

    final result = parser.parse(playlist, playlistNamespace: 'test-source');

    expect(result.kind, M3uPlaylistKind.channelList);
    expect(result.channels, hasLength(1));
    final channel = result.channels.single;
    expect(channel.name, 'World News HD');
    expect(channel.tvgId, 'news.world');
    expect(channel.logo, 'https://cdn.example/logo.png');
    expect(channel.groupTitle, 'International News');
    expect(channel.url, 'https://stream.example/news/index.m3u8');
    expect(channel.headers, <String, String>{
      'User-Agent': 'RAVEN23-Test/1.0',
      'Referer': 'https://provider.example/',
    });
  });

  test('reads XMLTV feed URLs when the M3U header starts with a BOM', () {
    const playlist =
        '\uFEFF#EXTM3U url-tvg="https://guide.example/main.xml"\n'
        '#EXTINF:-1 tvg-id="one",One\n'
        'https://stream.example/one.m3u8\n';
    final result = parser.parse(playlist, playlistNamespace: 'bom-epg');

    expect(result.isChannelList, isTrue);
    expect(result.epgUrls, <String>['https://guide.example/main.xml']);
  });

  test('reads one or more XMLTV feed URLs from M3U header metadata', () {
    const playlist =
        '''#EXTM3U url-tvg="https://guide.example/main.xml,https://guide.example/extra.xml"
#EXTINF:-1 tvg-id="one",One
https://stream.example/one.m3u8
''';
    final result = parser.parse(playlist, playlistNamespace: 'epg');

    expect(result.isChannelList, isTrue);
    expect(result.epgUrls, <String>[
      'https://guide.example/main.xml',
      'https://guide.example/extra.xml',
    ]);
  });

  test('resolves relative stream and logo URLs against a remote playlist', () {
    const playlist = '''#EXTM3U
#EXTINF:-1 tvg-id="local.one" tvg-logo="../logos/one.png" group-title="Sports",Local Sports
streams/one.m3u8
''';
    final result = parser.parse(
      playlist,
      baseUri: Uri.parse('https://lists.example/region/playlist.m3u'),
      playlistNamespace: 'remote',
    );

    expect(
      result.channels.single.url,
      'https://lists.example/region/streams/one.m3u8',
    );
    expect(result.channels.single.logo, 'https://lists.example/logos/one.png');
  });

  test('uses stable source-namespaced identity and de-duplicates tvg-id', () {
    const playlist = '''#EXTM3U
#EXTINF:-1 tvg-id="same.id" group-title="Sports",First
https://a.example/live.m3u8
#EXTINF:-1 tvg-id="same.id" group-title="Sports",Duplicate
https://b.example/live.m3u8
''';
    final first = parser.parse(playlist, playlistNamespace: 'provider-a');
    final second = parser.parse(playlist, playlistNamespace: 'provider-a');
    final otherProvider = parser.parse(
      playlist,
      playlistNamespace: 'provider-b',
    );

    expect(first.channels, hasLength(1));
    expect(first.channels.single.id, second.channels.single.id);
    expect(first.channels.single.id, isNot(otherProvider.channels.single.id));
    expect(first.channels.single.name, 'First');
  });

  test(
    'rejects HLS media playlists instead of treating segments as channels',
    () {
      const hls = '''#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:8
#EXTINF:8.0,
segment001.ts
#EXT-X-ENDLIST
''';
      final result = parser.parse(hls);

      expect(result.kind, M3uPlaylistKind.hlsMediaPlaylist);
      expect(result.channels, isEmpty);
    },
  );

  test('does not accept file, javascript, credentialed or unresolved URLs', () {
    const playlist = '''#EXTM3U
#EXTINF:-1,File
file:///sdcard/channel.ts
#EXTINF:-1,Script
javascript:alert(1)
#EXTINF:-1,Credentials
https://user:pass@stream.example/live.m3u8
#EXTINF:-1,Relative without base
live.m3u8
''';
    final result = parser.parse(playlist);

    expect(result.kind, M3uPlaylistKind.invalid);
    expect(result.channels, isEmpty);
  });

  test('maps known groups without collapsing unknown categories into All', () {
    expect(mapLiveTvGroup('Football - Sports'), 'Sports');
    expect(mapLiveTvGroup('World News'), 'News');
    expect(mapLiveTvGroup('Kids Cartoons'), 'Kids');
    expect(mapLiveTvGroup('Local Community'), 'Local Community');
    expect(mapLiveTvGroup(''), isNull);
  });
}
