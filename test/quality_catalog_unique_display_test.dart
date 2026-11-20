import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/common.dart';
import 'package:raven23/video_providers/quality_catalog.dart';

void main() {
  test('shows one stable server row for each resolution', () {
    final catalog = PlaybackQualityCatalog.collect(
      linksByProvider: <String, List<RegularVideoLinks>>{
        'jett': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://jett.example/1080.mp4',
            quality: '1080p',
            server: 'Jett',
            providerCode: 'jett',
          ),
          RegularVideoLinks(
            url: 'https://jett.example/720.mp4',
            quality: '720p',
            server: 'Jett',
            providerCode: 'jett',
          ),
        ],
        'sova': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://sova.example/1080.mp4',
            quality: '1080p',
            server: 'Sova',
            providerCode: 'sova',
          ),
          RegularVideoLinks(
            url: 'https://sova.example/720.mp4',
            quality: '720p',
            server: 'Sova',
            providerCode: 'sova',
          ),
        ],
      },
      preferredServerOrder: const <String>['Sova', 'Jett'],
    );

    expect(catalog, hasLength(4));
    final visible = PlaybackQualityCatalog.bestPerQuality(
      entries: catalog,
      preferredServerOrder: const <String>['Sova', 'Jett'],
    );

    expect(visible, hasLength(2));
    expect(visible.map((entry) => entry.qualityLabel), <String>[
      '1080p',
      '720p',
    ]);
    expect(visible.map((entry) => entry.link.server), <String>[
      'Sova',
      'Sova',
    ]);
  });

  test('keeps the active exact server for a duplicated resolution', () {
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
        'sova': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://sova.example/1080.mp4',
            quality: '1080p',
            server: 'Sova',
            providerCode: 'sova',
          ),
        ],
      },
      preferredServerOrder: const <String>['Jett', 'Sova'],
    );
    final active = catalog.singleWhere((entry) => entry.link.server == 'Sova');

    final visible = PlaybackQualityCatalog.bestPerQuality(
      entries: catalog,
      activeProviderCode: active.sourceProviderCode,
      activeSourceKey: active.sourceKey,
      activeStreamUrl: active.link.url,
      preferredServerOrder: const <String>['Jett', 'Sova'],
    );

    expect(visible, hasLength(1));
    expect(visible.single.link.server, 'Sova');
  });

  test('keeps distinct unknown resolution labels separate', () {
    final catalog = PlaybackQualityCatalog.collect(
      linksByProvider: <String, List<RegularVideoLinks>>{
        'one': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://one.example/a',
            quality: 'SD source',
            server: 'One',
            providerCode: 'one',
          ),
        ],
        'two': <RegularVideoLinks>[
          RegularVideoLinks(
            url: 'https://two.example/b',
            quality: 'HD source',
            server: 'Two',
            providerCode: 'two',
          ),
        ],
      },
    );

    final visible = PlaybackQualityCatalog.bestPerQuality(entries: catalog);
    expect(visible.map((entry) => entry.qualityLabel), <String>[
      'HD source',
      'SD source',
    ]);
  });
}
