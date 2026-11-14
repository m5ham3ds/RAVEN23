import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/media_identity.dart';
import 'package:raven23/video_providers/unified/source_contracts.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

void main() {
  group('Unified source identities', () {
    test('canonical repository identity does not rewrite legacy stableKey', () {
      const source = SourceManifest(
        id: 'provider-a',
        name: 'Provider A',
        repositoryUrl: 'HTTPS://Example.COM/repo/../index.json',
        engine: SourceEngineDescriptor(
          rawType: 'QuickJS',
          kind: SourceEngineKind.javascript,
          endpoint: 'providers/a.js',
        ),
      );

      expect(
        source.stableKey,
        'HTTPS://Example.COM/repo/../index.json::provider-a',
      );
      expect(source.repositoryIdentity.key, 'https://example.com/index.json');
      expect(
        source.sourceIdentity.key,
        'https://example.com/index.json::provider-a',
      );
      expect(source.sourceIdentity.legacyStableKey, source.stableKey);
      expect(source.engineIdentity.key, 'javascript::quickjs');
    });

    test(
      'legacy identity preserves the original repository string verbatim',
      () {
        const source = SourceManifest(
          id: 'provider-spaces',
          name: 'Provider With Spaces',
          repositoryUrl: '  https://repo.example/index.json  ',
          engine: SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
          ),
        );

        expect(source.sourceIdentity.legacyStableKey, source.stableKey);
        expect(
          source.repositoryIdentity.key,
          'https://repo.example/index.json',
        );
      },
    );

    test('canonical comparison identity omits repository URL credentials', () {
      const source = SourceManifest(
        id: 'private-provider',
        name: 'Private Provider',
        repositoryUrl: 'https://user:password@repo.example/index.json',
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      expect(
        source.repositoryIdentity.key,
        startsWith('https://repo.example/index.json::private='),
      );
      expect(source.repositoryIdentity.key, isNot(contains('user')));
      expect(source.repositoryIdentity.key, isNot(contains('password')));
      expect(source.sourceIdentity.legacyStableKey, source.stableKey);
    });

    test('private query material is fingerprinted rather than exposed', () {
      const first = SourceManifest(
        id: 'private-provider',
        name: 'Private Provider',
        repositoryUrl: 'https://repo.example/index.json?token=secret-one',
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );
      const second = SourceManifest(
        id: 'private-provider',
        name: 'Private Provider',
        repositoryUrl: 'https://repo.example/index.json?token=secret-two',
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      expect(first.repositoryIdentity.key, isNot(contains('secret-one')));
      expect(second.repositoryIdentity.key, isNot(contains('secret-two')));
      expect(
        first.repositoryIdentity.key,
        isNot(second.repositoryIdentity.key),
      );
      expect(first.sourceIdentity.legacyStableKey, first.stableKey);
    });

    test('unsafe engine raw types do not enter diagnostic identity', () {
      const source = SourceManifest(
        id: 'custom-engine',
        name: 'Custom Engine',
        engine: SourceEngineDescriptor(
          rawType: 'javascript?token=do-not-log',
          kind: SourceEngineKind.javascript,
        ),
      );

      expect(source.engineIdentity.key, 'javascript::custom');
      expect(source.engineIdentity.key, isNot(contains('do-not-log')));
    });

    test('local sources receive a stable local repository identity', () {
      const source = SourceManifest(
        id: 'local-source',
        name: 'Local Source',
        engine: SourceEngineDescriptor(
          rawType: 'native',
          kind: SourceEngineKind.native,
        ),
      );

      expect(source.repositoryIdentity.key, 'local');
      expect(source.sourceIdentity.key, 'local::local-source');
    });
  });

  test(
    'content identity retains anime episode identity independently from source identity',
    () {
      const media = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Bleach',
        year: 2004,
        tmdbId: 30984,
        seasonNumber: 2,
        episodeNumber: 8,
        episodeTmdbId: 101,
        externalIds: <String, String>{'anilist': '269'},
        isAnimeContent: true,
      );

      final identity = SourceContentIdentity.fromMedia(media);
      expect(identity.type, UnifiedMediaType.series);
      expect(identity.isAnimeContent, isTrue);
      expect(identity.seasonNumber, 2);
      expect(identity.episodeNumber, 8);
      expect(identity.episodeTmdbId, 101);
      expect(identity.externalIds['anilist'], '269');
      expect(identity.key, contains('series::30984::2004::2::8::101::anime'));
    },
  );

  group('Source capability profiles', () {
    test('normalizes movie, series, anime and audio capability tags', () {
      const source = SourceManifest(
        id: 'multi-provider',
        name: 'Multi Provider',
        tags: <String>['Movies', 'series', 'anime', 'multi_audio'],
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      final profile = source.capabilityProfile;
      expect(profile.isExplicit, isTrue);
      expect(profile.declared, contains(SourceCapability.movie));
      expect(profile.declared, contains(SourceCapability.series));
      expect(profile.declared, contains(SourceCapability.anime));
      expect(profile.declared, contains(SourceCapability.multipleAudio));
    });

    test('movies-and-series is not broadened to universal content', () {
      const source = SourceManifest(
        id: 'movie-series-provider',
        name: 'Movie and Series Provider',
        tags: <String>['movies-and-series'],
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      final profile = source.capabilityProfile;
      expect(profile.isUniversal, isFalse);
      expect(profile.declared, contains(SourceCapability.movie));
      expect(profile.declared, contains(SourceCapability.series));
      expect(
        profile.supportsMedia(
          const MediaIdentity(type: UnifiedMediaType.movie, title: 'Movie'),
        ),
        isTrue,
      );
      expect(
        profile.supportsMedia(
          const MediaIdentity(type: UnifiedMediaType.series, title: 'Series'),
        ),
        isTrue,
      );
    });

    test('metadata-only capabilities do not block VOD eligibility', () {
      const source = SourceManifest(
        id: 'subtitle-metadata-provider',
        name: 'Subtitle Metadata Provider',
        tags: <String>['subtitles', 'multi-audio'],
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      final profile = source.capabilityProfile;
      expect(profile.isExplicit, isTrue);
      expect(profile.hasContentCapabilities, isFalse);
      expect(
        profile.supportsMedia(
          const MediaIdentity(type: UnifiedMediaType.movie, title: 'Movie'),
        ),
        isTrue,
      );
    });

    test('Live TV-only capability is not eligible for VOD', () {
      const source = SourceManifest(
        id: 'live-only-provider',
        name: 'Live Only Provider',
        tags: <String>['iptv'],
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      final profile = source.capabilityProfile;
      expect(profile.declared, contains(SourceCapability.liveTv));
      expect(
        profile.supportsMedia(
          const MediaIdentity(type: UnifiedMediaType.movie, title: 'Movie'),
        ),
        isFalse,
      );
    });

    test('keeps older manifests with no capability tags permissive', () {
      const source = SourceManifest(
        id: 'legacy-provider',
        name: 'Legacy Provider',
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );
      final profile = source.capabilityProfile;

      expect(profile.isExplicit, isFalse);
      expect(
        profile.supportsMedia(
          const MediaIdentity(type: UnifiedMediaType.movie, title: 'Movie'),
        ),
        isTrue,
      );
      expect(
        profile.supportsMedia(
          const MediaIdentity(type: UnifiedMediaType.series, title: 'Series'),
        ),
        isTrue,
      );
    });

    test('anime capability accepts anime feature films on the movie route', () {
      const source = SourceManifest(
        id: 'anime-only-provider',
        name: 'Anime Only Provider',
        tags: <String>['anime'],
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      final profile = source.capabilityProfile;
      expect(
        profile.supportsMedia(
          const MediaIdentity(
            type: UnifiedMediaType.movie,
            title: 'Anime Feature Film',
            isAnimeContent: true,
          ),
        ),
        isTrue,
      );
      expect(
        profile.supportsMedia(
          const MediaIdentity(
            type: UnifiedMediaType.movie,
            title: 'Live Action Film',
          ),
        ),
        isTrue,
        reason: 'Anime tags are advisory and never block a media lane.',
      );
    });

    test('Donghua is an anime capability on the series playback route', () {
      const source = SourceManifest(
        id: 'donghua-provider',
        name: 'Donghua Provider',
        tags: <String>['donghua'],
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );
      const media = MediaIdentity(
        type: UnifiedMediaType.series,
        title: 'Donghua Series',
        seasonNumber: 1,
        episodeNumber: 3,
        contentClassification: MediaContentClassification.donghua,
      );

      expect(source.isAnimeOnly, isTrue);
      expect(
        source.capabilityProfile.declared,
        contains(SourceCapability.anime),
      );
      expect(source.supportsMedia(media), isTrue);
      expect(
        source.supportsMedia(
          const MediaIdentity(type: UnifiedMediaType.movie, title: 'Film'),
        ),
        isTrue,
      );
      expect(media.normalizedType, UnifiedMediaType.series);
    });

    test(
      'anime engine declares anime capability without creating a new app media kind',
      () {
        const source = SourceManifest(
          id: 'anime-provider',
          name: 'Anime Provider',
          engine: SourceEngineDescriptor(
            rawType: 'reanime',
            kind: SourceEngineKind.animeSite,
          ),
        );
        final profile = source.capabilityProfile;

        expect(profile.declared, contains(SourceCapability.anime));
        expect(
          profile.supportsMedia(
            const MediaIdentity(
              type: UnifiedMediaType.series,
              title: 'Anime Series',
              isAnimeContent: true,
            ),
          ),
          isTrue,
        );
        expect(UnifiedMediaType.series.name, 'series');
      },
    );
  });

  group('Source lifecycle snapshots', () {
    test(
      'represents installed, enabled and experimental as separate flags',
      () {
        const source = SourceManifest(
          id: 'beta-provider',
          name: 'Beta Provider',
          status: 3,
          engine: SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
          ),
        );

        final lifecycle = SourceLifecycleSnapshot.fromManifest(
          source,
          installed: true,
        );

        expect(lifecycle.has(SourceLifecycleFlag.discovered), isTrue);
        expect(lifecycle.has(SourceLifecycleFlag.validated), isFalse);
        expect(lifecycle.has(SourceLifecycleFlag.installed), isTrue);
        expect(lifecycle.has(SourceLifecycleFlag.enabled), isTrue);
        expect(lifecycle.has(SourceLifecycleFlag.experimental), isTrue);
        expect(lifecycle.has(SourceLifecycleFlag.disabled), isFalse);
      },
    );

    test('marks a source validated only when validation is explicit', () {
      const source = SourceManifest(
        id: 'validated-provider',
        name: 'Validated Provider',
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      final pending = SourceLifecycleSnapshot.fromManifest(
        source,
        installed: false,
      );
      final validated = SourceLifecycleSnapshot.fromManifest(
        source,
        installed: false,
        validated: true,
      );

      expect(pending.has(SourceLifecycleFlag.validated), isFalse);
      expect(validated.has(SourceLifecycleFlag.validated), isTrue);
    });

    test('a user-disabled compatible source is not marked incompatible', () {
      const source = SourceManifest(
        id: 'disabled-provider',
        name: 'Disabled Provider',
        enabled: false,
        engine: SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
        ),
      );

      final lifecycle = SourceLifecycleSnapshot.fromManifest(
        source,
        installed: true,
      );

      expect(lifecycle.has(SourceLifecycleFlag.disabled), isTrue);
      expect(lifecycle.has(SourceLifecycleFlag.installed), isTrue);
      expect(lifecycle.has(SourceLifecycleFlag.incompatible), isFalse);
    });

    test(
      'marks unsupported sources incompatible and duplicate sources explicitly',
      () {
        const source = SourceManifest(
          id: 'unknown-provider',
          name: 'Unknown Provider',
          engine: SourceEngineDescriptor(
            rawType: 'unknown-engine',
            kind: SourceEngineKind.unsupported,
          ),
        );

        final lifecycle = SourceLifecycleSnapshot.fromManifest(
          source,
          installed: false,
          duplicate: true,
          validationMessage: 'No registered source engine.',
        );

        expect(lifecycle.has(SourceLifecycleFlag.discovered), isTrue);
        expect(lifecycle.has(SourceLifecycleFlag.incompatible), isTrue);
        expect(lifecycle.has(SourceLifecycleFlag.duplicate), isTrue);
        expect(lifecycle.has(SourceLifecycleFlag.installed), isFalse);
      },
    );
  });
}
