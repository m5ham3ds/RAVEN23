import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/models/live_tv.dart';
import 'package:raven23/models/xmltv_epg.dart';
import 'package:raven23/services/iptv/xmltv_epg_mapper.dart';
import 'package:raven23/services/iptv/xmltv_epg_parser.dart';

void main() {
  const parser = XmlTvEpgParser();

  test('parses channels and normalizes explicit XMLTV offsets to UTC', () {
    const feed = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE tv SYSTEM "xmltv.dtd">
<tv generator-info-name="fixture">
  <channel id="world.news"><display-name lang="en">World News</display-name><icon src="https://cdn.example/news.png"/></channel>
  <programme start="20261108080000 +0200" stop="20261108090000 +0200" channel="world.news">
    <title lang="en">Morning Bulletin</title><desc>Daily headlines</desc><category>News</category>
  </programme>
</tv>''';

    final guide = parser.parse(feed);

    expect(guide.channels, hasLength(1));
    expect(guide.channels.single.displayName, 'World News');
    expect(guide.channels.single.icon, 'https://cdn.example/news.png');
    expect(guide.programmes, hasLength(1));
    expect(guide.programmes.single.startUtc, DateTime.utc(2026, 11, 8, 6));
    expect(guide.programmes.single.stopUtc, DateTime.utc(2026, 11, 8, 7));
    expect(guide.programmes.single.categories, <String>['News']);
  });

  test(
    'calculates Now and Next from intervals and handles overlapping entries',
    () {
      final guide = XmlTvGuide(
        channels: const <XmlTvChannel>[XmlTvChannel(id: 'one')],
        programmes: <XmlTvProgramme>[
          XmlTvProgramme(
            channelId: 'one',
            startUtc: DateTime.utc(2026, 11, 8, 7),
            stopUtc: DateTime.utc(2026, 11, 8, 9),
            title: 'Earlier overlapping programme',
          ),
          XmlTvProgramme(
            channelId: 'one',
            startUtc: DateTime.utc(2026, 11, 8, 7, 30),
            stopUtc: DateTime.utc(2026, 11, 8, 8, 30),
            title: 'Current programme',
          ),
          XmlTvProgramme(
            channelId: 'one',
            startUtc: DateTime.utc(2026, 11, 8, 9),
            stopUtc: DateTime.utc(2026, 11, 8, 10),
            title: 'Next programme',
          ),
        ],
      );

      final nowNext = guide.nowNext('one', at: DateTime.utc(2026, 11, 8, 8));
      expect(nowNext.now?.title, 'Current programme');
      expect(nowNext.next?.title, 'Next programme');
      expect(guide.nowNext('missing', at: DateTime.utc(2026)).now, isNull);
    },
  );

  test(
    'treats offsetless XMLTV timestamps as UTC and handles negative offsets',
    () {
      const feed = '''<tv>
      <channel id="one"><display-name>One</display-name></channel>
      <programme start="20261108080000" stop="20261108090000" channel="one"><title>Offsetless</title></programme>
      <programme start="20261108010000 -0500" stop="20261108020000 -0500" channel="one"><title>Negative offset</title></programme>
    </tv>''';

      final guide = parser.parse(feed);

      expect(guide.programmes, hasLength(2));
      expect(guide.programmes.first.startUtc, DateTime.utc(2026, 11, 8, 6));
      expect(guide.programmes.last.startUtc, DateTime.utc(2026, 11, 8, 8));
    },
  );

  test('drops invalid intervals and duplicate programmes', () {
    const feed = '''<tv>
      <channel id="one"><display-name>One</display-name></channel>
      <programme start="20261108080000 +0000" stop="20261108090000 +0000" channel="one"><title>Repeat</title></programme>
      <programme start="20261108080000 +0000" stop="20261108090000 +0000" channel="one"><title>Repeat</title></programme>
      <programme start="20261108090000 +0000" stop="20261108080000 +0000" channel="one"><title>Bad interval</title></programme>
      <programme start="invalid" stop="invalid" channel="one"><title>Bad time</title></programme>
    </tv>''';

    final guide = parser.parse(feed);
    expect(guide.programmes, hasLength(1));
    expect(guide.programmes.single.title, 'Repeat');
  });

  test('rejects internal DTD/entity declarations and malformed XML', () {
    expect(
      () => parser.parse('<!DOCTYPE tv [<!ENTITY x "boom">]><tv/>'),
      throwsA(isA<XmlTvParseException>()),
    );
    expect(
      () => parser.parse('<!ENTITY x "boom"><tv/>'),
      throwsA(isA<XmlTvParseException>()),
    );
    expect(
      () => parser.parse('<tv><channel></tv>'),
      throwsA(isA<XmlTvParseException>()),
    );
  });

  test('enforces channel and programme count limits', () {
    const feed = '''<tv>
      <channel id="one"><display-name>One</display-name></channel>
      <channel id="two"><display-name>Two</display-name></channel>
      <programme start="20261108080000 +0000" stop="20261108090000 +0000" channel="one"><title>One</title></programme>
    </tv>''';

    expect(
      () => const XmlTvEpgParser(maxChannels: 1).parse(feed),
      throwsA(isA<XmlTvParseException>()),
    );
    expect(
      () => const XmlTvEpgParser(maxProgrammes: 0).parse(feed),
      throwsA(isA<XmlTvParseException>()),
    );
  });

  test('rejects wrong root and over-limit feeds', () {
    expect(
      () => parser.parse('<playlist/>'),
      throwsA(isA<XmlTvParseException>()),
    );
    expect(
      () => const XmlTvEpgParser(maxBytes: 8).parse('<tv>too large</tv>'),
      throwsA(isA<XmlTvParseException>()),
    );
  });

  test(
    'uses exact tvg-id matching to enrich current and next channel labels',
    () {
      final guide = XmlTvGuide(
        channels: const <XmlTvChannel>[XmlTvChannel(id: 'news.exact')],
        programmes: <XmlTvProgramme>[
          XmlTvProgramme(
            channelId: 'news.exact',
            startUtc: DateTime.utc(2026, 11, 8, 7),
            stopUtc: DateTime.utc(2026, 11, 8, 8),
            title: 'On now',
          ),
          XmlTvProgramme(
            channelId: 'news.exact',
            startUtc: DateTime.utc(2026, 11, 8, 8),
            stopUtc: DateTime.utc(2026, 11, 8, 9),
            title: 'Coming next',
          ),
          XmlTvProgramme(
            channelId: 'news.other',
            startUtc: DateTime.utc(2026, 11, 8, 7),
            stopUtc: DateTime.utc(2026, 11, 8, 8),
            title: 'Must not match by name',
          ),
        ],
      );
      const channel = Channel(
        id: 'm3u:list:one',
        name: 'World News',
        tvgId: 'news.exact',
      );
      const nearMatch = Channel(
        id: 'm3u:list:two',
        name: 'World News',
        tvgId: 'News.Exact',
      );

      final enriched = XmlTvEpgMapper.enrichChannels(
        const <Channel>[channel, nearMatch],
        <XmlTvGuide>[guide],
        at: DateTime.utc(2026, 11, 8, 7, 30),
      );

      expect(enriched.first.nowPlaying, 'On now');
      expect(enriched.first.nextUp, 'Coming next');
      expect(enriched.last.nowPlaying, isNull);
    },
  );

  test('adapts matched XMLTV programmes for the existing schedule UI', () {
    final guide = XmlTvGuide(
      channels: const <XmlTvChannel>[XmlTvChannel(id: 'sports.one')],
      programmes: <XmlTvProgramme>[
        XmlTvProgramme(
          channelId: 'sports.one',
          startUtc: DateTime.utc(2026, 11, 8, 7),
          stopUtc: DateTime.utc(2026, 11, 8, 8),
          title: 'Match One',
          categories: const <String>['Sports'],
        ),
      ],
    );
    const channel = Channel(
      id: 'm3u:list:one',
      name: 'Sports One',
      tvgId: 'sports.one',
    );

    final legacy = XmlTvEpgMapper.toLegacyGuide(
      const <Channel>[channel],
      <XmlTvGuide>[guide],
    );

    expect(legacy.days, hasLength(1));
    expect(legacy.days.single.categories.single.name, 'Sports');
    expect(
      legacy.days.single.categories.single.events.single.title,
      'Match One',
    );
    expect(
      legacy.days.single.categories.single.events.single.channels.single.id,
      channel.id,
    );
  });
}
