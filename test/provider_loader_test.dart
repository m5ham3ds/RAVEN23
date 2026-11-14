import 'dart:async';

import 'package:raven23/video_providers/common.dart';
import 'package:raven23/video_providers/names.dart';
import 'package:raven23/video_providers/provider_loader.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderLoadResult playableResult() => ProviderLoadResult(
  success: true,
  videoLinks: [RegularVideoLinks(url: 'https://example.com/video.m3u8')],
);

void main() {
  final providers = List.generate(
    5,
    (index) => VideoProvider.scraper(id: '$index', name: 'Provider $index'),
  );

  test('recognizes QuickJS metadata that marks a provider anime-only', () {
    expect(
      ProviderLoader.isAnimeOnlyMismatch(
        'Provider ReAnime declares type "anime" and cannot resolve movie.',
      ),
      isTrue,
    );
    expect(
      ProviderLoader.isAnimeOnlyMismatch(
        'Provider Demo declares type "anime-only" and cannot resolve series.',
      ),
      isTrue,
    );
    expect(
      ProviderLoader.isAnimeOnlyMismatch(
        'Provider Demo declares type "donghua" and cannot resolve movie.',
      ),
      isTrue,
    );
    expect(
      ProviderLoader.isAnimeOnlyMismatch('No matching title was found.'),
      isFalse,
    );
  });

  test('universal manifest tags override a generic anime tag', () {
    const provider = SourceManifest(
      id: 'universal',
      name: 'Universal source',
      tags: ['anime', 'all'],
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
      ),
    );
    expect(provider.isAnimeOnly, isFalse);
  });

  test('attempts anime-tagged providers for live-action movies in supplied order', () async {
    final animeOnly = VideoProvider.unifiedSource(
      const SourceManifest(
        id: 'anikoto',
        name: 'Anikoto',
        tags: ['anime'],
        engine: SourceEngineDescriptor(
          rawType: 'anikoto',
          kind: SourceEngineKind.animeSite,
        ),
      ),
    );
    final multiContent = VideoProvider.unifiedSource(
      const SourceManifest(
        id: 'multi',
        name: 'Multi provider',
        tags: ['anime', 'movies', 'series'],
        engine: SourceEngineDescriptor(
          rawType: 'web-embed',
          kind: SourceEngineKind.webEmbed,
          movieUrl: 'https://example.com/movie/{tmdbId}',
          tvUrl: 'https://example.com/tv/{tmdbId}/{season}/{episode}',
        ),
      ),
    );
    final started = <String>[];
    final selection = await ProviderLoader.loadFirstSuccessful(
      providers: [animeOnly, multiContent],
      unifiedMediaIdentity: const MediaIdentity(
        type: UnifiedMediaType.movie,
        title: 'A Live Action Film',
      ),
      load: (provider) async {
        started.add(provider.codeName);
        return provider == animeOnly
            ? ProviderLoadResult(errorMessage: 'No matching title.')
            : playableResult();
      },
    );

    expect(started, [animeOnly.codeName, multiContent.codeName]);
    expect(selection?.provider, multiContent);
  });

  test(
    'anime feature films keep movie identity while enabling anime-only providers',
    () async {
      final animeOnly = VideoProvider.unifiedSource(
        const SourceManifest(
          id: 'anime-movie-source',
          name: 'Anime Movie Source',
          tags: ['anime'],
          engine: SourceEngineDescriptor(
            rawType: 'anikoto',
            kind: SourceEngineKind.animeSite,
          ),
        ),
      );
      final started = <String>[];
      final identity = ProviderLoader.movieIdentity(
        tmdbId: 42,
        title: 'Anime Feature Film',
        isAnime: true,
      );
      final selection = await ProviderLoader.loadFirstSuccessful(
        providers: [animeOnly],
        unifiedMediaIdentity: identity,
        load: (provider) async {
          started.add(provider.codeName);
          return playableResult();
        },
      );

      expect(identity.type, UnifiedMediaType.movie);
      expect(identity.isAnimeContent, isTrue);
      expect(started, [animeOnly.codeName]);
      expect(selection?.provider, animeOnly);
    },
  );

  test('normalizes Anime and Donghua episodes to the existing series kind', () {
    final anime = ProviderLoader.episodeIdentity(
      tmdbId: 100,
      title: 'Anime series',
      seasonNumber: 2,
      episodeNumber: 8,
      isAnime: true,
    );
    final donghua = ProviderLoader.episodeIdentity(
      tmdbId: 200,
      title: 'Donghua series',
      seasonNumber: 1,
      episodeNumber: 3,
      classification: MediaContentClassification.donghua,
    );

    expect(anime.type, UnifiedMediaType.series);
    expect(anime.isAnimeContent, isTrue);
    expect(anime.stremioType, 'series');
    expect(donghua.type, UnifiedMediaType.series);
    expect(donghua.isAnimeContent, isTrue);
    expect(donghua.contentClassification, MediaContentClassification.donghua);
  });

  test('keeps anime-exclusive providers eligible for anime episodes', () async {
    final animeOnly = VideoProvider.unifiedSource(
      const SourceManifest(
        id: 'reanime',
        name: 'Re:Anime',
        tags: ['anime'],
        engine: SourceEngineDescriptor(
          rawType: 'reanime',
          kind: SourceEngineKind.animeSite,
        ),
      ),
    );
    final started = <String>[];
    final selection = await ProviderLoader.loadFirstSuccessful(
      providers: [animeOnly],
      unifiedMediaIdentity: const MediaIdentity(
        type: UnifiedMediaType.anime,
        title: 'Anime Title',
        seasonNumber: 1,
        episodeNumber: 1,
      ),
      load: (provider) async {
        started.add(provider.codeName);
        return playableResult();
      },
    );

    expect(started, [animeOnly.codeName]);
    expect(selection?.provider, animeOnly);
  });

  test('first provider success never starts backup requests', () async {
    final firstResult = Completer<ProviderLoadResult>();
    final startedProviders = <String>[];
    final completedProviders = <String>[];
    final result = playableResult();

    final selectionFuture = ProviderLoader.loadFirstSuccessful(
      providers: providers,
      load: (provider) {
        startedProviders.add(provider.apiId!);
        return firstResult.future;
      },
      onResult: (_, provider, __) => completedProviders.add(provider.apiId!),
    );

    await Future<void>.delayed(Duration.zero);
    expect(startedProviders, ['0']);
    expect(completedProviders, isEmpty);

    firstResult.complete(result);
    final selection = await selectionFuture;

    expect(selection?.index, 0);
    expect(selection?.provider, providers.first);
    expect(selection?.result, same(result));
    expect(startedProviders, ['0']);
    expect(completedProviders, ['0']);
  });

  test('each fallback waits for the previous provider to fail', () async {
    final results = List.generate(5, (_) => Completer<ProviderLoadResult>());
    final startedProviders = <String>[];
    final completedIndexes = <int>[];

    final selectionFuture = ProviderLoader.loadFirstSuccessful(
      providers: providers,
      load: (provider) {
        startedProviders.add(provider.apiId!);
        return results[int.parse(provider.apiId!)].future;
      },
      onResult: (index, _, __) => completedIndexes.add(index),
    );

    await Future<void>.delayed(Duration.zero);
    expect(startedProviders, ['0']);

    for (var index = 0; index < 3; index++) {
      results[index].complete(const ProviderLoadResult(errorMessage: 'Failed'));
      await Future<void>.delayed(Duration.zero);
      expect(startedProviders, [for (var i = 0; i <= index + 1; i++) '$i']);
      expect(completedIndexes, [for (var i = 0; i <= index; i++) i]);
    }

    results[3].complete(playableResult());
    final selection = await selectionFuture;
    expect(selection?.index, 3);
    expect(selection?.provider, providers[3]);
    expect(startedProviders, ['0', '1', '2', '3']);
    expect(completedIndexes, [0, 1, 2, 3]);
  });

  test(
    'exceptions and empty successful results fall through in order',
    () async {
      final attempts = <int>[];
      final reportedResults = <ProviderLoadResult>[];

      final selection = await ProviderLoader.loadFirstSuccessful(
        providers: providers,
        load: (provider) {
          final index = int.parse(provider.apiId!);
          attempts.add(index);
          switch (index) {
            case 0:
              throw StateError('Synchronous failure');
            case 1:
              return Future.error(StateError('Asynchronous failure'));
            case 2:
              return Future.value(const ProviderLoadResult(success: true));
            case 3:
              return Future.value(
                const ProviderLoadResult(success: true, videoLinks: []),
              );
            default:
              return Future.value(playableResult());
          }
        },
        onResult: (_, __, result) => reportedResults.add(result),
      );

      expect(selection?.index, 4);
      expect(attempts, [0, 1, 2, 3, 4]);
      expect(reportedResults, hasLength(5));
      expect(reportedResults[0].errorMessage, contains('Synchronous failure'));
      expect(reportedResults[1].errorMessage, contains('Asynchronous failure'));
    },
  );

  test('returns null after every provider fails', () async {
    final attempts = <String>[];
    final completedProviders = <String>[];

    final selection = await ProviderLoader.loadFirstSuccessful(
      providers: providers,
      load: (provider) async {
        attempts.add(provider.codeName);
        return const ProviderLoadResult(errorMessage: 'No sources');
      },
      onResult: (_, provider, __) => completedProviders.add(provider.codeName),
    );

    expect(selection, isNull);
    expect(attempts, providers.map((provider) => provider.codeName));
    expect(completedProviders, attempts);
  });

  test('empty provider list makes no requests', () async {
    final selection = await ProviderLoader.loadFirstSuccessful(
      providers: [],
      load: (_) => throw StateError('No provider should be loaded'),
      onResult: (_, __, ___) => fail('No result should be reported'),
    );

    expect(selection, isNull);
  });
}
