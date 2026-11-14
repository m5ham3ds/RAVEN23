import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/functions/video_utils.dart';
import 'package:raven23/video_providers/common.dart';
import 'package:raven23/video_providers/names.dart';
import 'package:raven23/video_providers/provider_loader.dart';
import 'package:raven23/video_providers/unified/embedded_player_option.dart';
import 'package:raven23/video_providers/unified/legacy_provider_adapter.dart';
import 'package:raven23/video_providers/unified/source_engine.dart';

void main() {
  group('Phase 50 embedded playback contract', () {
    test('embedded page metadata survives serialization and copying', () {
      final original = RegularVideoLinks(
        url: 'https://embed.example/watch/123',
        quality: 'Embedded Player · Verification required',
        server: 'Example Embed',
        providerCode: 'example-embed',
        isEmbeddedPlayer: true,
        embedRequiresVerification: true,
      );

      final restored = RegularVideoLinks.fromJson(original.toJson());
      final copied = restored.copyWith(providerCode: 'copied-provider');

      expect(restored.isEmbeddedPlayer, isTrue);
      expect(restored.embedRequiresVerification, isTrue);
      expect(copied.isEmbeddedPlayer, isTrue);
      expect(copied.embedRequiresVerification, isTrue);
      expect(copied.providerCode, 'copied-provider');
    });

    test(
      'embedded-only unified results are candidates but not direct streams',
      () {
        const result = UnifiedSourceResult(
          embeddedPlayer: UnifiedEmbeddedPlayerOption(
            sourceId: 'source',
            sourceName: 'Source',
            url: 'https://embed.example/watch/1',
          ),
        );

        expect(result.success, isFalse);
        expect(result.hasPlaybackCandidate, isTrue);
      },
    );

    test(
      'legacy embedded links stay out of the unified direct stream list',
      () {
        final result =
            ProviderLoadResult(
              success: true,
              videoLinks: <RegularVideoLinks>[
                RegularVideoLinks(
                  url: 'https://embed.example/watch/123',
                  server: 'Legacy embed',
                  providerCode: 'legacy-embed',
                  isEmbeddedPlayer: true,
                  embedRequiresVerification: true,
                  headers: const <String, String>{
                    'Referer': 'https://embed.example/',
                    'Origin': 'https://embed.example',
                  },
                ),
                RegularVideoLinks(
                  url: 'https://cdn.example/video.mp4',
                  server: 'Direct mirror',
                ),
              ],
            ).toUnifiedSourceResult(
              providerId: 'legacy-provider',
              providerName: 'Legacy provider',
            );

        expect(result.streams, hasLength(1));
        expect(result.streams.single.url, 'https://cdn.example/video.mp4');
        expect(result.embeddedPlayer?.url, 'https://embed.example/watch/123');
        expect(result.embeddedPlayer?.requiresManualVerification, isTrue);
        expect(
          result.embeddedPlayer?.headers['Referer'],
          'https://embed.example/',
        );
      },
    );

    test('HTML embed pages never enter native video or format maps', () {
      final links = <RegularVideoLinks>[
        RegularVideoLinks(
          url: 'https://embed.example/watch/123',
          quality: 'Embedded Player',
          server: 'Embed source',
          isEmbeddedPlayer: true,
        ),
        RegularVideoLinks(
          url: 'https://cdn.example/video.m3u8',
          quality: '1080p',
          server: 'Direct source',
          isM3U8: true,
          headers: const <String, String>{'Referer': 'https://source.example/'},
        ),
      ];

      final videos = VideoUtils.convertVideoLinksToMap(links);
      final formats = VideoUtils.convertVideoFormatsToMap(links);
      final headers = VideoUtils.convertVideoHeadersToMap(links);

      expect(videos.values, ['https://cdn.example/video.m3u8']);
      expect(formats.values.single, isNotNull);
      expect(
        headers.values.single,
        containsPair('Referer', 'https://source.example/'),
      );
      expect(videos.values, isNot(contains('https://embed.example/watch/123')));
    });

    test(
      'direct provider result is preferred over an earlier embedded page',
      () async {
        final embeddedProvider = VideoProvider.scraper(
          id: 'embedded',
          name: 'Embedded provider',
        );
        final directProvider = VideoProvider.scraper(
          id: 'direct',
          name: 'Direct provider',
        );
        final attempted = <String>[];

        final selection = await ProviderLoader.loadFirstSuccessful(
          providers: [embeddedProvider, directProvider],
          load: (provider) async {
            attempted.add(provider.codeName);
            if (provider == embeddedProvider) {
              return ProviderLoadResult(
                success: true,
                videoLinks: [
                  RegularVideoLinks(
                    url: 'https://embed.example/watch/123',
                    isEmbeddedPlayer: true,
                    server: 'Embedded provider',
                  ),
                ],
              );
            }
            return ProviderLoadResult(
              success: true,
              videoLinks: [
                RegularVideoLinks(url: 'https://cdn.example/video.mp4'),
              ],
            );
          },
        );

        expect(attempted, [embeddedProvider.codeName, directProvider.codeName]);
        expect(selection?.provider, directProvider);
        expect(
          selection?.result.videoLinks?.every((link) => !link.isEmbeddedPlayer),
          isTrue,
        );
      },
    );

    test(
      'first embedded result is used only after all providers lack direct links',
      () async {
        final first = VideoProvider.scraper(id: 'embed-a', name: 'Embed A');
        final second = VideoProvider.scraper(id: 'embed-b', name: 'Embed B');
        final attempted = <String>[];

        final selection = await ProviderLoader.loadFirstSuccessful(
          providers: [first, second],
          load: (provider) async {
            attempted.add(provider.codeName);
            return ProviderLoadResult(
              success: true,
              videoLinks: [
                RegularVideoLinks(
                  url: 'https://embed.example/${provider.codeName}',
                  isEmbeddedPlayer: true,
                  server: provider.displayName,
                ),
              ],
            );
          },
        );

        expect(attempted, [first.codeName, second.codeName]);
        expect(selection?.provider, first);
        expect(selection?.result.videoLinks?.single.isEmbeddedPlayer, isTrue);
      },
    );
  });
}
