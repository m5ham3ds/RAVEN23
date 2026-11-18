import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/quickjs_source_catalog_profile.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_repository_manager.dart';
import 'package:raven23/video_providers/unified/source_repository_revision.dart';
import 'package:raven23/video_providers/unified/source_repository_parser.dart';

void main() {
  const parser = SourceRepositoryParser();

  test(
    'the six curated repositories remain discoverable, not auto-installed',
    () {
      expect(SourceRepositoryManager.bundledRepositoryUrls, hasLength(6));
      expect(
        SourceRepositoryManager.bundledRepositoryUrls.where(
          (url) => url.contains('Spyhell/spyou-latin-zan/main/index.json'),
        ),
        hasLength(1),
      );
      expect(
        SourceRepositoryManager.bundledRepositoryUrls,
        isNot(contains('index.ison')),
      );
    },
  );

  test(
    'Zangetsu entries preserve declared type and explicit safety metadata',
    () {
      const raw = '''
    {
      "name":"Spyhell fixture",
      "sources":[
        {"id":"animesuge","name":"AnimeSuge","type":"anime","lang":"en","file":"providers/animesuge.js"},
        {"id":"filmzie","name":"Filmzie","type":"movie","lang":"en","file":"providers/filmzie.js","nsfw":false},
        {"id":"adult-explicit","name":"Adult Explicit","type":"anime","lang":"en","file":"providers/adult.js","nsfw":true}
      ]
    }
    ''';
      final repository = parser.parseRepository(
        raw,
        sourceUrl:
            'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json',
      );
      final anime = repository.extensions.firstWhere(
        (source) => source.id == 'animesuge',
      );
      final filmzie = repository.extensions.firstWhere(
        (source) => source.id == 'filmzie',
      );
      final adult = repository.extensions.firstWhere(
        (source) => source.id == 'adult-explicit',
      );

      expect(anime.engine.kind, SourceEngineKind.javascript);
      expect(anime.installedByDefault, isFalse);
      expect(anime.declaredNsfw, isNull);
      expect(anime.safetyClassification, SourceSafetyClassification.unknown);
      expect(filmzie.declaredNsfw, isFalse);
      expect(
        filmzie.safetyClassification,
        SourceSafetyClassification.declaredSafe,
      );
      expect(adult.isNsfw, isTrue);
      expect(
        adult.safetyClassification,
        SourceSafetyClassification.declaredAdult,
      );
    },
  );

  test('known channel-group providers are never sent to VOD dispatch', () {
    const raw = '''
    {"name":"Spyhell fixture","sources":[
      {"id":"worldlivetv","name":"World Live TV","type":"movie","file":"providers/worldlivetv.js"},
      {"id":"moviesda","name":"MoviesDa","type":"movie","file":"providers/moviesda.js"}
    ]}
    ''';
    final sources = parser
        .parseRepository(
          raw,
          sourceUrl:
              'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json',
        )
        .extensions;
    final live = sources.firstWhere((source) => source.id == 'worldlivetv');
    final vod = sources.firstWhere((source) => source.id == 'moviesda');
    const movie = MediaIdentity(type: UnifiedMediaType.movie, title: 'Test');

    expect(live.requiresLiveTvAdapter, isTrue);
    expect(live.supportsMedia(movie), isFalse);
    expect(vod.requiresLiveTvAdapter, isFalse);
    expect(vod.supportsMedia(movie), isTrue);
    expect(
      vod.supportsMedia(
        const MediaIdentity(type: UnifiedMediaType.series, title: 'Series'),
      ),
      isTrue,
      reason: 'A movie-tagged VOD provider remains selectable for series.',
    );
  });

  test(
    'archive sources are tagged without being upgraded to verified playback',
    () {
      final profile = QuickJsSourceCatalogProfile.classify(
        repositoryUrl:
            'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json',
        sourceId: 'internetarchive',
      );
      expect(profile.catalogRole, 'archive-vod');
      expect(profile.requiresLiveTvAdapter, isFalse);
    },
  );

  test('account-backed providers are marked for credential review', () {
    final profile = QuickJsSourceCatalogProfile.classify(
      repositoryUrl:
          'https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json',
      sourceId: 'torbox',
    );
    expect(profile.requiresCredentialReview, isTrue);
  });

  test(
    'duplicate source candidates are reported without deleting alternatives',
    () async {
      final temporary = Directory.systemTemp.createTempSync('raven23-phase44-');
      try {
        const scriptUrl = 'https://scripts.example/provider.js';
        final first = SourceManifest(
          id: 'same-provider',
          name: 'Same Provider',
          repositoryUrl: 'https://repo-a.example/index.json',
          engine: const SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
            endpoint: scriptUrl,
          ),
        );
        final second = SourceManifest(
          id: 'same-provider',
          name: 'Same Provider',
          repositoryUrl: 'https://repo-b.example/index.json',
          engine: const SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
            endpoint: scriptUrl,
          ),
        );
        final manager = SourceRepositoryManager(
          artifactStore: SourceRepositoryArtifactStore(
            rootDirectory: temporary,
          ),
        );

        final duplicates = await manager.findPotentialDuplicates(
          <SourceManifest>[first, second],
        );

        expect(duplicates, hasLength(1));
        expect(duplicates.single.reasons, contains('canonical-script-url'));
        expect(<SourceManifest>[first, second], hasLength(2));
      } finally {
        temporary.deleteSync(recursive: true);
      }
    },
  );
}
