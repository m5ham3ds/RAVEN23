import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/source_catalog_safety_policy.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

void main() {
  test('excludes a provider whose name contains Hentai', () {
    const source = SourceManifest(
      id: 'adult-streams',
      name: 'Hentai Streams',
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
      ),
    );

    expect(SourceCatalogSafetyPolicy.isExcludedHentai(source), isTrue);
  });

  test('explicitly excludes HentaiMama by source id', () {
    const source = SourceManifest(
      id: 'hentaimama',
      name: 'Adult Video Provider',
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
      ),
    );

    expect(SourceCatalogSafetyPolicy.isExcludedHentai(source), isTrue);
  });

  test('excludes Arabic spelling of Hentai in provider names', () {
    const source = SourceManifest(
      id: 'arabic-adult-provider',
      name: 'مزود هنتاي',
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
      ),
    );

    expect(SourceCatalogSafetyPolicy.isExcludedHentai(source), isTrue);
  });

  test('explicitly excludes Hanime even without Hentai in its name', () {
    const source = SourceManifest(
      id: 'hanime',
      name: 'Anime Provider',
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
      ),
    );

    expect(SourceCatalogSafetyPolicy.isExcludedHentai(source), isTrue);
  });

  test('excludes Hentai identified by source category metadata', () {
    const source = SourceManifest(
      id: 'adult-provider',
      name: 'Adult Provider',
      tags: <String>['hentai', 'anime'],
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
      ),
    );

    expect(SourceCatalogSafetyPolicy.isExcludedHentai(source), isTrue);
  });

  test('does not exclude ordinary anime providers', () {
    const source = SourceManifest(
      id: 'anime-provider',
      name: 'Anime Provider',
      tags: <String>['anime', 'donghua'],
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
      ),
    );

    expect(SourceCatalogSafetyPolicy.isExcludedHentai(source), isFalse);
  });

  test('stable-key filtering ignores Hentai in the repository URL', () {
    expect(
      SourceCatalogSafetyPolicy.isExcludedStableKey(
        'https://example.com/hentai-repository/index.json::normal-anime',
      ),
      isFalse,
    );
    expect(
      SourceCatalogSafetyPolicy.isExcludedStableKey(
        'https://example.com/index.json::HentaiMama',
      ),
      isTrue,
    );
  });

  test('stable-key filtering catches Arabic Hentai provider ids', () {
    expect(
      SourceCatalogSafetyPolicy.isExcludedStableKey(
        'https://example.com/index.json::مزود-هنتاي',
      ),
      isTrue,
    );
  });

  test('does not exclude a repository because its URL mentions Hentai', () {
    const source = SourceManifest(
      id: 'general-provider',
      name: 'General Provider',
      repositoryUrl: 'https://example.com/hentai-repository/index.json',
      tags: <String>['movies', 'series'],
      engine: SourceEngineDescriptor(
        rawType: 'javascript',
        kind: SourceEngineKind.javascript,
      ),
    );

    expect(SourceCatalogSafetyPolicy.isExcludedHentai(source), isFalse);
  });
}
