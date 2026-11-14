import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/names.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_priority_manager.dart';
import 'package:raven23/video_providers/unified/source_priority_policy.dart';

void main() {
  const animeTaggedJapaneseProvider = SourceManifest(
    id: 'anime-provider',
    name: 'Anime Provider',
    repositoryUrl: 'https://example.com/index.json',
    language: 'Japanese',
    tags: <String>['anime-only'],
    engine: SourceEngineDescriptor(
      rawType: 'javascript',
      kind: SourceEngineKind.javascript,
      config: <String, dynamic>{'providerType': 'anime-only'},
    ),
  );

  test('declared anime type and language do not block other media lanes', () {
    for (final category in SourcePriorityCategory.values) {
      expect(
        SourcePriorityPolicy.isDirectPriorityCandidate(
          animeTaggedJapaneseProvider,
          category,
          supportsRuntime: (_) => true,
        ),
        isTrue,
        reason: 'The user may place any VOD source in ${category.name}.',
      );
    }
  });


  test('VideoProvider does not filter by anime/movie/series media labels', () {
    final provider = VideoProvider.unifiedSource(animeTaggedJapaneseProvider);
    expect(
      provider.supportsMedia(
        const MediaIdentity(type: UnifiedMediaType.movie, title: 'Live Action'),
      ),
      isTrue,
    );
    expect(
      provider.supportsMedia(
        const MediaIdentity(type: UnifiedMediaType.series, title: 'Series'),
      ),
      isTrue,
    );
    expect(provider.supportsMediaType(UnifiedMediaType.movie), isTrue);
    expect(provider.supportsMediaType(UnifiedMediaType.series), isTrue);
    expect(provider.supportsMediaType(UnifiedMediaType.anime), isTrue);
  });

  test('declared movie type is not required for the series or anime lane', () {
    const movieTaggedProvider = SourceManifest(
      id: 'movie-provider',
      name: 'Movie Provider',
      repositoryUrl: 'https://example.com/index.json',
      language: 'English',
      tags: <String>['movie-only'],
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
      ),
    );

    expect(
      SourcePriorityPolicy.isEligible(
        movieTaggedProvider,
        SourcePriorityCategory.series,
        supportsRuntime: (_) => true,
      ),
      isTrue,
    );
    expect(
      SourcePriorityPolicy.isEligible(
        movieTaggedProvider,
        SourcePriorityCategory.anime,
        supportsRuntime: (_) => true,
      ),
      isTrue,
    );
  });


  test(
    'manually selected fallback sources stay in the user priority tier',
    () {
      const fallbackSource = SourceManifest(
        id: 'fallback-source',
        name: 'Fallback Source',
        repositoryUrl: 'https://example.com/index.json',
        isFallback: true,
        engine: SourceEngineDescriptor(
          rawType: 'stremio',
          kind: SourceEngineKind.stremio,
        ),
      );

      final ordinary = VideoProvider.unifiedSource(fallbackSource);
      final selected = VideoProvider.unifiedSource(
        fallbackSource,
        forcePrimary: true,
      );

      expect(ordinary.isFallback, isTrue);
      expect(selected.isFallback, isFalse);
    },
  );

  test('unsupported runtime and Live TV-only adapters remain non-VOD', () {
    const unsupported = SourceManifest(
      id: 'unsupported',
      name: 'Unsupported Engine',
      engine: SourceEngineDescriptor(
        rawType: 'unknown-engine',
        kind: SourceEngineKind.unsupported,
      ),
    );
    const liveTv = SourceManifest(
      id: 'live-only',
      name: 'Live TV only',
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
        config: <String, dynamic>{'requiresLiveTvAdapter': true},
      ),
    );

    expect(
      SourcePriorityPolicy.isEligible(
        unsupported,
        SourcePriorityCategory.movies,
        supportsRuntime: (_) => false,
      ),
      isFalse,
    );
    expect(
      SourcePriorityPolicy.isEligible(
        liveTv,
        SourcePriorityCategory.movies,
        supportsRuntime: (_) => true,
      ),
      isFalse,
    );
  });
}
