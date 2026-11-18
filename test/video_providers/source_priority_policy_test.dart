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

  test('Anime PRIMARY LIST matches the requested fourteen-source order', () {
    const openStream =
        'https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json';
    const spyhell =
        'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json';
    const serenity =
        'https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json';
    const spyou =
        'https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json';
    const ids = <(String repositoryUrl, String id)>[
      (openStream, 'anikoto'),
      (openStream, 'reanime'),
      (openStream, 'animegg'),
      (openStream, 'jett'),
      (openStream, 'yastream'),
      (spyhell, 'vidfast'),
      (openStream, 'sage'),
      (openStream, 'phoenix'),
      (serenity, 'serenity-cinestream'),
      (spyhell, 'vidzee'),
      (spyou, 'vegamovies'),
      (openStream, 'sova'),
      (spyhell, 'vidspark'),
    ];
    final catalog = <SourceManifest>[
      for (final entry in ids)
        SourceManifest(
          id: entry.$2,
          name: entry.$2,
          repositoryUrl: entry.$1,
          engine: const SourceEngineDescriptor(
            rawType: 'native',
            kind: SourceEngineKind.native,
          ),
        ),
    ];

    final primary = SourcePriorityPolicy.recommendedPrimaryKeys(
      SourcePriorityCategory.anime,
      catalog,
      supportsRuntime: (_) => true,
    );

    expect(primary, <String>[
      '$openStream::anikoto',
      '$openStream::reanime',
      '$openStream::animegg',
      '$openStream::jett',
      '$openStream::yastream',
      SourcePriorityPolicy.directVixSrcPriorityKey,
      '$spyhell::vidfast',
      '$openStream::sage',
      '$openStream::phoenix',
      '$serenity::serenity-cinestream',
      '$spyhell::vidzee',
      '$spyou::vegamovies',
      '$openStream::sova',
      '$spyhell::vidspark',
    ]);
    expect(SourcePriorityPolicy.directVixSrcManifest.name, 'VixSrc');
    expect(SourcePriorityPolicy.directVixSrcManifest.repositoryUrl, isNull);
  });

  test(
    'VixSrc execution index follows installed PRIMARY predecessors only',
    () {
      const keys = <String>[
        'repo::anikoto',
        'repo::reanime',
        'repo::animegg',
        'repo::jett',
        'repo::yastream',
        SourcePriorityPolicy.directVixSrcPriorityKey,
        'repo::vidfast',
      ];

      expect(
        SourcePriorityPolicy.directVixSrcInsertionIndex(
          primaryKeys: keys,
          installedPrimaryKeys: keys,
        ),
        5,
      );
      expect(
        SourcePriorityPolicy.directVixSrcInsertionIndex(
          primaryKeys: keys,
          installedPrimaryKeys: <String>[
            'repo::anikoto',
            'repo::reanime',
            'repo::jett',
            'repo::yastream',
          ],
        ),
        4,
      );
      expect(
        SourcePriorityPolicy.directVixSrcInsertionIndex(
          primaryKeys: <String>['repo::anikoto'],
          installedPrimaryKeys: <String>['repo::anikoto'],
        ),
        isNull,
      );
      expect(
        SourcePriorityPolicy.directVixSrcInsertionIndex(
          primaryKeys: <String>[
            'repo::yastream',
            'repo::jett',
            'repo::hdhub',
            SourcePriorityPolicy.directVixSrcPriorityKey,
            'repo::vidspark',
          ],
          installedPrimaryKeys: <String>[
            'repo::yastream',
            'repo::jett',
            'repo::hdhub',
            'repo::vidspark',
          ],
        ),
        3,
      );
      expect(
        SourcePriorityPolicy.directVixSrcInsertionIndex(
          primaryKeys: <String>[
            'repo::yastream',
            'repo::jett',
            'repo::hdhub',
            SourcePriorityPolicy.directVixSrcPriorityKey,
            'repo::vidspark',
          ],
          installedPrimaryKeys: <String>[
            'repo::yastream',
            'repo::jett',
            'repo::vidspark',
          ],
        ),
        2,
      );
    },
  );

  test('Movies and Series PRIMARY LIST match the requested shared order', () {
    const openStream =
        'https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json';
    const spyhell =
        'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json';
    const serenity =
        'https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json';
    const spyou =
        'https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json';
    const orderedSources = <(String repositoryUrl, String id)>[
      (openStream, 'yastream'),
      (openStream, 'jett'),
      (openStream, 'hdhub'),
      (spyhell, 'vidspark'),
      (spyhell, 'vidfast'),
      (openStream, 'sova'),
      (openStream, 'sage'),
      (openStream, 'phoenix'),
      (serenity, 'serenity-cinestream'),
      (spyhell, 'vidzee'),
      (spyou, 'vegamovies'),
    ];
    final catalog = <SourceManifest>[
      for (final entry in orderedSources)
        SourceManifest(
          id: entry.$2,
          name: entry.$2,
          repositoryUrl: entry.$1,
          engine: const SourceEngineDescriptor(
            rawType: 'native',
            kind: SourceEngineKind.native,
          ),
        ),
    ];
    final expected = <String>[
      '$openStream::yastream',
      '$openStream::jett',
      '$openStream::hdhub',
      SourcePriorityPolicy.directVixSrcPriorityKey,
      '$spyhell::vidspark',
      '$spyhell::vidfast',
      '$openStream::sova',
      '$openStream::sage',
      '$openStream::phoenix',
      '$serenity::serenity-cinestream',
      '$spyhell::vidzee',
      '$spyou::vegamovies',
    ];

    for (final category in <SourcePriorityCategory>[
      SourcePriorityCategory.movies,
      SourcePriorityCategory.series,
    ]) {
      expect(
        SourcePriorityPolicy.recommendedPrimaryKeys(
          category,
          catalog,
          supportsRuntime: (_) => true,
        ),
        expected,
        reason: '${category.name} must use the same first-search order.',
      );
    }
  });

  test('previous Movies/Series defaults are recognized for migration', () {
    const openStream =
        'https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json';
    const spyhell =
        'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json';
    const serenity =
        'https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json';
    const spyou =
        'https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json';
    const oldIds = <(String, String)>[
      (openStream, 'jett'),
      (openStream, 'yastream'),
      (spyhell, 'vidfast'),
      (spyhell, 'vidspark'),
      (openStream, 'hdhub'),
      (openStream, 'sova'),
      (openStream, 'sage'),
      (openStream, 'phoenix'),
      (serenity, 'serenity-cinestream'),
      (spyhell, 'vidzee'),
      (spyou, 'vegamovies'),
    ];
    final catalog = <SourceManifest>[
      for (final entry in oldIds)
        SourceManifest(
          id: entry.$2,
          name: entry.$2,
          repositoryUrl: entry.$1,
          engine: const SourceEngineDescriptor(
            rawType: 'native',
            kind: SourceEngineKind.native,
          ),
        ),
    ];
    final expected = <String>[
      SourcePriorityPolicy.directVixSrcPriorityKey,
      for (final entry in oldIds) '${entry.$1}::${entry.$2}',
    ];

    for (final category in <SourcePriorityCategory>[
      SourcePriorityCategory.movies,
      SourcePriorityCategory.series,
    ]) {
      expect(
        SourcePriorityPolicy.previousMoviesSeriesPrimaryKeys(
          category,
          catalog,
          supportsRuntime: (_) => true,
        ),
        expected,
      );
    }
    expect(
      SourcePriorityPolicy.previousMoviesSeriesPrimaryKeys(
        SourcePriorityCategory.anime,
        catalog,
        supportsRuntime: (_) => true,
      ),
      isEmpty,
    );
  });

  test('legacy Anime defaults remain available for safe migration checks', () {
    const oldIds = <String>[
      'anikoto',
      'hianime',
      'animecube',
      'serenity-anikoto',
      'serenity-animekai',
      'serenity-aniwave',
      'animesuge',
      'animex',
      'anikage',
      'wcoflix',
      'donghuanation',
    ];
    final catalog = <SourceManifest>[
      for (final id in oldIds)
        SourceManifest(
          id: id,
          name: id,
          repositoryUrl: switch (id) {
            'anikoto' || 'hianime' || 'animecube' =>
              'https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json',
            'serenity-anikoto' || 'serenity-animekai' || 'serenity-aniwave' =>
              'https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json',
            _ =>
              'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json',
          },
          engine: const SourceEngineDescriptor(
            rawType: 'native',
            kind: SourceEngineKind.native,
          ),
        ),
    ];
    expect(
      SourcePriorityPolicy.legacyAnimeRecommended(
        catalog,
        supportsRuntime: (_) => true,
      ).map((source) => source.id).toList(),
      oldIds,
    );
  });

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

  test('manually selected fallback sources stay in the user priority tier', () {
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
  });

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
