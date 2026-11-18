import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/functions/video_utils.dart';
import 'package:raven23/video_providers/common.dart';
import 'package:raven23/video_providers/quality_catalog.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);

  test(
    'keeps same-height server choices and honors returned host priority',
    () {
      final catalog = PlaybackQualityCatalog.collect(
        linksByProvider: <String, List<RegularVideoLinks>>{
          'jett': <RegularVideoLinks>[
            RegularVideoLinks(
              url: 'https://jett.example/1080.mp4',
              quality: '1080p',
              server: 'Jett',
              providerCode: 'jett',
            ),
          ],
          'vixsrc': <RegularVideoLinks>[
            RegularVideoLinks(
              url: 'https://vixsrc.example/1080.mp4',
              quality: '1080p',
              server: 'VixSrc',
              providerCode: 'vixsrc',
            ),
          ],
        },
        preferredServerOrder: const <String>['VixSrc', 'Jett'],
      );
      expect(catalog, hasLength(2));
      expect(catalog.map((entry) => entry.link.url), <String?>[
        'https://vixsrc.example/1080.mp4',
        'https://jett.example/1080.mp4',
      ]);
    },
  );

  test(
    'does not expose provider Auto without concrete manifest renditions',
    () {
      final catalog = PlaybackQualityCatalog.collect(
        linksByProvider: <String, List<RegularVideoLinks>>{
          'jett': <RegularVideoLinks>[
            RegularVideoLinks(
              url: 'https://jett.example/master',
              quality: 'Auto · Jett',
              server: 'Jett',
            ),
          ],
        },
        now: now,
      );

      expect(catalog, isEmpty);
    },
  );

  test(
    'collects every quality from every provider, including nonstandard heights',
    () {
      final links = <String, List<RegularVideoLinks>>{
        'jett': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://jett.example/2160.mpd',
            quality: '2160p',
            server: 'Jett',
            providerCode: 'jett',
            isDash: true,
          ),
          RegularVideoLinks(
            url: 'https://jett.example/1440.mpd',
            quality: '1440p',
            server: 'Jett',
            providerCode: 'jett',
            isDash: true,
          ),
          RegularVideoLinks(
            url: 'https://jett.example/1080.mpd',
            quality: '1080p',
            server: 'Jett',
            providerCode: 'jett',
            isDash: true,
          ),
          RegularVideoLinks(
            url: 'https://jett.example/360.mp4',
            quality: '360p',
            server: 'Jett',
            providerCode: 'jett',
          ),
          RegularVideoLinks(
            url: 'https://jett.example/270.mp4',
            quality: '270',
            server: 'Jett',
            providerCode: 'jett',
          ),
        ],
        'sova': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://sova.example/1080.m3u8',
            quality: '1080p',
            server: 'Sova',
            providerCode: 'sova',
            isM3U8: true,
          ),
          RegularVideoLinks(
            url: 'https://sova.example/720.mp4',
            quality: '720p',
            server: 'Sova',
            providerCode: 'sova',
          ),
          RegularVideoLinks(
            url: 'https://sova.example/480.mp4',
            quality: '480p',
            server: 'Sova',
            providerCode: 'sova',
          ),
          RegularVideoLinks(
            url: 'https://sova.example/180.mp4',
            quality: '180',
            server: 'Sova',
            providerCode: 'sova',
          ),
        ],
        'phoenix': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://phoenix.example/master.m3u8',
            quality: 'Auto',
            server: 'Phoenix',
            providerCode: 'phoenix',
            isM3U8: true,
            isAdaptive: true,
            availableHeights: <int>[540, 360],
          ),
        ],
        'unified:sources': <RegularVideoLinks>[
          // The aggregate bucket mirrors originals and must not duplicate them.
          RegularVideoLinks(
            url: 'https://jett.example/1080.mpd',
            quality: '1080p',
            server: 'Jett',
            providerCode: 'jett',
            isDash: true,
          ),
        ],
      };

      final catalog = PlaybackQualityCatalog.collect(
        linksByProvider: links,
        now: now,
      );
      final urls = catalog.map((entry) => entry.link.url).toList();
      final heights = catalog.map((entry) => entry.height).toList();

      expect(
        urls,
        containsAll(<String>[
          'https://jett.example/2160.mpd',
          'https://jett.example/1440.mpd',
          'https://jett.example/1080.mpd',
          'https://sova.example/1080.m3u8',
          'https://sova.example/720.mp4',
          'https://sova.example/480.mp4',
          'https://phoenix.example/master.m3u8',
          'https://jett.example/360.mp4',
          'https://jett.example/270.mp4',
          'https://sova.example/180.mp4',
        ]),
      );
      expect(urls, contains('https://sova.example/1080.m3u8'));
      expect(
        urls.where((url) => url == 'https://jett.example/1080.mpd'),
        hasLength(1),
      );
      expect(heights.first, 2160);
      expect(heights.whereType<int>().toSet(), <int>{
        2160,
        1440,
        1080,
        720,
        540,
        480,
        360,
        270,
        180,
      });
      expect(heights.where((height) => height == 1080), hasLength(2));
      expect(heights.where((height) => height == 360), hasLength(2));
      final phoenixEntries = catalog
          .where((entry) => entry.link.server == 'Phoenix')
          .toList(growable: false);
      expect(phoenixEntries.map((entry) => entry.qualityLabel), <String>[
        '540p',
        '360p',
      ]);
    },
  );

  test(
    'expands supplied adaptive heights even when legacy flag is missing',
    () {
      final catalog = PlaybackQualityCatalog.collect(
        linksByProvider: <String, List<RegularVideoLinks>>{
          'unified:sources': <RegularVideoLinks>[
            RegularVideoLinks(
              url: 'https://provider.example/opaque?sig=1',
              quality: 'Auto',
              server: 'Jett',
              providerCode: 'unified:sources',
              isDash: true,
              availableHeights: <int>[1080, 720, 480, 360, 270, 180],
            ),
          ],
        },
        now: now,
      );

      expect(
        catalog.map((entry) => entry.qualityLabel),
        containsAll(<String>['1080p', '720p', '480p', '360p', '270p', '180p']),
      );
      expect(
        catalog.where((entry) => entry.adaptiveTargetHeight != null),
        hasLength(6),
      );
    },
  );

  test('keeps same-height servers and selects the active exact source', () {
    final catalog = PlaybackQualityCatalog.collect(
      linksByProvider: <String, List<RegularVideoLinks>>{
        'jett': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://jett.example/movie.m3u8',
            quality: '1080p',
            server: 'Jett',
            providerCode: 'jett',
            isM3U8: true,
          ),
        ],
        'sova': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://sova.example/movie.mp4',
            quality: '1080p',
            server: 'Sova',
            providerCode: 'sova',
          ),
        ],
      },
      activeProviderCode: 'sova',
      activeSourceKey: '1080p',
      activeStreamUrl: 'https://sova.example/movie.mp4',
      now: now,
    );

    expect(catalog, hasLength(2));
    final sovaEntry = catalog.singleWhere(
      (entry) => entry.link.server == 'Sova',
    );
    expect(
      PlaybackQualitySelection.isSelected(
        entry: sovaEntry,
        activeProviderCode: 'sova',
        activeSourceKey: '1080p',
        activeStreamUrl: 'https://sova.example/movie.mp4',
      ),
      isTrue,
    );
  });

  test('includes real source-engine links stored under the unified bucket', () {
    final catalog = PlaybackQualityCatalog.collect(
      linksByProvider: <String, List<RegularVideoLinks>>{
        'unified:sources': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://jett.example/1080.mpd',
            quality: '1080p',
            server: 'Jett',
            providerCode: 'unified:sources',
            isDash: true,
          ),
          RegularVideoLinks(
            url: 'https://sova.example/720.m3u8',
            quality: '720p',
            server: 'Sova',
            providerCode: 'unified:sources',
            isM3U8: true,
          ),
        ],
      },
      now: now,
    );

    expect(catalog, hasLength(2));
    expect(
      catalog.map((entry) => entry.link.server),
      containsAll(['Jett', 'Sova']),
    );
    expect(
      catalog.map((entry) => entry.link.url),
      containsAll([
        'https://jett.example/1080.mpd',
        'https://sova.example/720.m3u8',
      ]),
    );
  });

  test('does not offer expired links in the quality picker', () {
    final catalog = PlaybackQualityCatalog.collect(
      linksByProvider: <String, List<RegularVideoLinks>>{
        'jett': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://jett.example/expired.mp4',
            quality: '1080p',
            server: 'Jett',
            providerCode: 'jett',
            expiresAt: now.subtract(const Duration(seconds: 1)),
          ),
          RegularVideoLinks(
            url: 'https://jett.example/valid.mp4',
            quality: '360p',
            server: 'Jett',
            providerCode: 'jett',
            expiresAt: now.add(const Duration(minutes: 5)),
          ),
        ],
      },
      now: now,
    );

    expect(catalog, hasLength(1));
    expect(catalog.single.link.url, 'https://jett.example/valid.mp4');
  });

  test(
    'keeps server-specific same-quality links and the active source identity',
    () {
      final links = <RegularVideoLinks>[
        RegularVideoLinks(
          url: 'https://engine.example/playback',
          quality: '1080p',
          server: 'Jett',
          providerCode: 'unified:sources',
          headers: const <String, String>{'Referer': 'https://jett.example/'},
        ),
        RegularVideoLinks(
          url: 'https://engine.example/playback',
          quality: '1080p',
          server: 'Sova',
          providerCode: 'unified:sources',
          headers: const <String, String>{'Referer': 'https://sova.example/'},
        ),
        RegularVideoLinks(
          url: 'https://engine.example/playback',
          quality: '720p',
          server: 'Jett',
          providerCode: 'unified:sources',
        ),
      ];
      final keys = VideoUtils.videoSourceKeys(links);
      final catalog = PlaybackQualityCatalog.collect(
        linksByProvider: <String, List<RegularVideoLinks>>{
          'unified:sources': links,
        },
        activeProviderCode: 'unified:sources',
        activeSourceKey: keys[1],
        activeStreamUrl: links[1].url,
        now: now,
      );

      expect(catalog, hasLength(3));
      expect(catalog.map((entry) => entry.qualityLabel), <String>[
        '1080p',
        '1080p',
        '720p',
      ]);
      expect(catalog.any((entry) => entry.sourceKey == keys[1]), isTrue);

      final selected = catalog
          .where(
            (entry) => PlaybackQualitySelection.isSelected(
              entry: entry,
              activeProviderCode: 'unified:sources',
              activeSourceKey: keys[1],
              activeStreamUrl: links[1].url,
            ),
          )
          .toList(growable: false);
      expect(selected, hasLength(1));
      expect(selected.single.link.server, 'Sova');
    },
  );

  test(
    'normalizes lower discovered resolutions into tappable quality labels',
    () {
      final catalog = PlaybackQualityCatalog.collect(
        linksByProvider: <String, List<RegularVideoLinks>>{
          'unified:sources': <RegularVideoLinks>[
            for (final quality in <String>['360', '270', '180', '140'])
              RegularVideoLinks(
                url: 'https://quality.example/$quality',
                quality: quality,
                server: 'Jett',
                providerCode: 'unified:sources',
              ),
          ],
        },
        now: now,
      );

      expect(catalog.map((entry) => entry.qualityLabel), <String>[
        '360p',
        '270p',
        '180p',
        '140p',
      ]);
    },
  );

  test(
    'uses the owning provider source key when aggregate results arrive first',
    () {
      final link = RegularVideoLinks(
        url: 'https://jett.example/shared-stream',
        quality: '720p',
        server: 'Jett',
        providerCode: 'jett',
      );
      final catalog = PlaybackQualityCatalog.collect(
        linksByProvider: <String, List<RegularVideoLinks>>{
          // Unified Sources may be inserted before a provider's own raw list.
          'unified:sources': <RegularVideoLinks>[link],
          'jett': <RegularVideoLinks>[link],
        },
        now: now,
      );

      expect(catalog, hasLength(1));
      expect(catalog.single.sourceProviderCode, 'jett');
      expect(catalog.single.sourceKey, '720p');
    },
  );

  test(
    'exposes the same source and container details for the download menu',
    () {
      final catalog = PlaybackQualityCatalog.collect(
        linksByProvider: <String, List<RegularVideoLinks>>{
          'unified:sources': <RegularVideoLinks>[
            RegularVideoLinks(
              url: 'https://cdn.example/opaque?token=abc',
              quality: '1080p',
              server: 'Jett',
              providerCode: 'unified:sources',
              streamContainer: 'mp4',
              headers: const <String, String>{
                'Referer': 'https://source.test/',
              },
            ),
          ],
        },
        now: now,
      );

      expect(catalog, hasLength(1));
      expect(catalog.single.sourceDisplayName, 'Jett');
      expect(catalog.single.formatLabel, 'MP4');
      expect(
        catalog.single.selectionSubtitle,
        'Jett · MP4  •  Request headers',
      );
    },
  );

  test('keeps embedded pages out of the quality list', () {
    final catalog = PlaybackQualityCatalog.collect(
      linksByProvider: <String, List<RegularVideoLinks>>{
        'unified:sources': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://embed.example/watch',
            quality: 'unknown quality',
            server: 'Embed Server',
            isEmbeddedPlayer: true,
          ),
          RegularVideoLinks(
            url: 'https://video.example/720.mp4',
            quality: '720p',
            server: 'Direct Server',
          ),
        ],
      },
      now: now,
    );

    expect(catalog, hasLength(1));
    expect(catalog.single.qualityLabel, '720p');
    expect(catalog.single.link.isEmbeddedPlayer, isFalse);
  });

  test(
    'preferred startup source ignores provider Auto when concrete qualities exist',
    () {
      final preferred = VideoUtils.preferredVideoSource(<String, String>{
        'Auto · VixSrc Direct': 'https://vixsrc.example/master.m3u8',
        '1080p · HdHub': 'https://hdhub.example/1080.mp4',
        '720p · VixSrc Direct': 'https://vixsrc.example/720.mp4',
      }, 0);

      expect(preferred?.key, '720p · VixSrc Direct');

      final masterOnly = VideoUtils.preferredVideoSource(<String, String>{
        'Auto · VixSrc Direct': 'https://vixsrc.example/master.m3u8',
      }, 0);
      // A master-only stream may bootstrap playback internally, but it is never
      // returned by the user-facing quality catalog or download picker.
      expect(masterOnly?.key, 'Auto · VixSrc Direct');
    },
  );

  test(
    'legacy download quality keys keep server alternatives and remove Auto',
    () {
      expect(
        VideoUtils.uniqueQualityKeys(<String>[
          'Auto · VixSrc Direct',
          '1080p · HdHub',
          '1080p · PeerTube Films',
          '720p · VixSrc Direct',
          'Adaptive · Phoenix',
        ]),
        <String>[
          '1080p · HdHub',
          '1080p · PeerTube Films',
          '720p · VixSrc Direct',
        ],
      );
    },
  );

  test('automatic policy chooses the best rendition within safe bandwidth', () {
    final selected = PlaybackAutoQualityPolicy.chooseHeight(
      renditions: const <PlaybackQualityRendition>[
        PlaybackQualityRendition(height: 480, bitrateBitsPerSecond: 1_200_000),
        PlaybackQualityRendition(height: 720, bitrateBitsPerSecond: 2_400_000),
        PlaybackQualityRendition(height: 1080, bitrateBitsPerSecond: 5_000_000),
      ],
      measuredBandwidthBitsPerSecond: 6_000_000,
    );

    // 72% of 6 Mbps is 4.32 Mbps, so 720p is the highest safe rendition.
    expect(selected, 720);
  });

  test(
    'automatic policy chooses the lowest option when bandwidth is too low',
    () {
      expect(
        PlaybackAutoQualityPolicy.chooseHeight(
          renditions: const <PlaybackQualityRendition>[
            PlaybackQualityRendition(height: 480),
            PlaybackQualityRendition(height: 720),
            PlaybackQualityRendition(height: 1080),
          ],
          measuredBandwidthBitsPerSecond: 1_000_000,
        ),
        480,
      );
    },
  );

  test('automatic policy falls back to 720p or the best lower rendition', () {
    expect(
      PlaybackAutoQualityPolicy.chooseHeight(
        renditions: const <PlaybackQualityRendition>[
          PlaybackQualityRendition(height: 480),
          PlaybackQualityRendition(height: 720),
          PlaybackQualityRendition(height: 1080),
        ],
      ),
      720,
    );
    expect(
      PlaybackAutoQualityPolicy.chooseHeight(
        renditions: const <PlaybackQualityRendition>[
          PlaybackQualityRendition(height: 360),
          PlaybackQualityRendition(height: 480),
        ],
      ),
      480,
    );
  });
}
