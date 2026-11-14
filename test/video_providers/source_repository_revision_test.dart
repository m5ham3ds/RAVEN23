import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';
import 'package:raven23/video_providers/unified/source_repository_revision.dart';

void main() {
  late Directory root;
  late SourceRepositoryArtifactStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'raven23-repository-revisions-',
    );
    store = SourceRepositoryArtifactStore(rootDirectory: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  SourceRepositoryManifest manifest(String version) => SourceRepositoryManifest(
    url: 'https://repo.example/index.json',
    name: 'Fixture Repository',
    extensions: <SourceManifest>[
      SourceManifest(
        id: 'fixture-provider',
        name: 'Fixture Provider',
        version: version,
        authors: const <String>['Fixture Author'],
        repositoryUrl: 'https://repo.example/index.json',
        engine: const SourceEngineDescriptor(
          rawType: 'javascript',
          kind: SourceEngineKind.javascript,
          endpoint: 'https://repo.example/provider.js',
        ),
      ),
    ],
  );

  RepositoryDocumentCapture document(String body) => RepositoryDocumentCapture(
    requestedUrl: 'https://repo.example/index.json?token=private',
    finalUrl: 'https://repo.example/index.json?token=private',
    statusCode: 200,
    body: body,
    contentType: 'application/json',
    etag: 'fixture-etag',
    lastModified: 'Sat, 07 Nov 2026 00:00:00 GMT',
  );

  test(
    'persists immutable revisions, hashes, and previous-version links',
    () async {
      final first = await store.saveRevision(
        repositoryUrl: 'https://repo.example/index.json?token=private',
        manifest: manifest('1.0.0'),
        documents: <RepositoryDocumentCapture>[document('{"version":1}')],
        versionRef: 'main',
      );
      final second = await store.saveRevision(
        repositoryUrl: 'https://repo.example/index.json?token=private',
        manifest: manifest('2.0.0'),
        documents: <RepositoryDocumentCapture>[document('{"version":2}')],
        versionRef: 'main',
        commitHash: '0123456789abcdef0123456789abcdef01234567',
      );

      final history = await store.revisions(
        'https://repo.example/index.json?token=private',
      );
      expect(history.map((value) => value.id), <String>[second.id, first.id]);
      expect(second.previousContentHash, first.contentHash);
      expect(second.commitHash, '0123456789abcdef0123456789abcdef01234567');
      expect(history.first.manifest.extensions.single.version, '2.0.0');
      expect(history.last.manifest.extensions.single.version, '1.0.0');
    },
  );

  test('verifies saved document bytes before allowing snapshot use', () async {
    final revision = await store.saveRevision(
      repositoryUrl: 'https://repo.example/index.json',
      manifest: manifest('1.0.0'),
      documents: <RepositoryDocumentCapture>[document('{"healthy":true}')],
    );
    final body = await store.readDocumentBody(
      'https://repo.example/index.json',
      revision,
      revision.documents.single,
    );
    expect(body, '{"healthy":true}');
  });

  test('rejects tampering with the saved manifest snapshot metadata', () async {
    final revision = await store.saveRevision(
      repositoryUrl: 'https://repo.example/tamper.json',
      manifest: manifest('1.0.0'),
      documents: <RepositoryDocumentCapture>[document('{"safe":true}')],
    );
    final repositoryKey = store.repositoryKey(
      'https://repo.example/tamper.json',
    );
    final metadata = File(
      '${root.path}/repositories/$repositoryKey/${revision.id}/revision.json',
    );
    final decoded =
        jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
    final manifestJson = decoded['manifest'] as Map<String, dynamic>;
    final extensions = manifestJson['extensions'] as List<dynamic>;
    (extensions.single as Map<String, dynamic>)['name'] = 'Tampered Provider';
    await metadata.writeAsString(jsonEncode(decoded), flush: true);

    await expectLater(
      store.loadRevision('https://repo.example/tamper.json', revision.id),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'keeps query credentials out of revision metadata and filenames',
    () async {
      final revision = await store.saveRevision(
        repositoryUrl: 'https://repo.example/index.json?token=do-not-store',
        manifest: manifest('1.0.0'),
        documents: <RepositoryDocumentCapture>[document('{"safe":true}')],
      );
      final serialized = revision.toJson().toString();
      expect(serialized, isNot(contains('do-not-store')));
      expect(serialized, isNot(contains('?token=')));
    },
  );

  test(
    'redacts URL credentials and secret configuration in snapshots',
    () async {
      final privateManifest = SourceRepositoryManifest(
        url: 'https://repo.example/index.json?api_key=index-secret',
        name: 'Private Fixture',
        extensions: <SourceManifest>[
          SourceManifest(
            id: 'private-provider',
            name: 'Private Provider',
            repositoryUrl: 'https://repo.example/index.json?token=repo-secret',
            engine: const SourceEngineDescriptor(
              rawType: 'javascript',
              kind: SourceEngineKind.javascript,
              endpoint: 'cdn/provider.js?token=script-secret&mode=fast',
              config: <String, dynamic>{
                'apiKey': 'config-secret',
                'mode': 'safe',
              },
            ),
          ),
        ],
      );
      final revision = await store.saveRevision(
        repositoryUrl: 'https://repo.example/index.json?token=repo-secret',
        manifest: privateManifest,
        documents: <RepositoryDocumentCapture>[document('{"safe":true}')],
      );
      final serialized = revision.toJson().toString();
      for (final secret in <String>[
        'index-secret',
        'repo-secret',
        'script-secret',
        'config-secret',
      ]) {
        expect(serialized, isNot(contains(secret)));
      }
      expect(serialized, contains('cdn/provider.js?mode=fast'));
      expect(serialized, contains('[redacted]'));
    },
  );

  test(
    'rejects snapshot body paths outside the artifact filename scheme',
    () async {
      final revision = await store.saveRevision(
        repositoryUrl: 'https://repo.example/index.json',
        manifest: manifest('1.0.0'),
        documents: <RepositoryDocumentCapture>[document('{"safe":true}')],
      );
      final unsafeDocument = RepositoryDocumentRevision(
        requestedUrl: revision.documents.single.requestedUrl,
        finalUrl: revision.documents.single.finalUrl,
        statusCode: 200,
        contentHash: revision.documents.single.contentHash,
        bodyFile: '../outside.txt',
      );
      await expectLater(
        store.readDocumentBody(
          'https://repo.example/index.json',
          revision,
          unsafeDocument,
        ),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'revalidating unchanged content does not consume history slots',
    () async {
      final first = await store.saveRevision(
        repositoryUrl: 'https://repo.example/unchanged.json',
        manifest: manifest('1.0.0'),
        documents: <RepositoryDocumentCapture>[document('{"same":true}')],
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await store.saveRevision(
        repositoryUrl: 'https://repo.example/unchanged.json',
        manifest: manifest('1.0.0'),
        documents: <RepositoryDocumentCapture>[document('{"same":true}')],
      );
      final history = await store.revisions(
        'https://repo.example/unchanged.json',
      );
      expect(second.id, first.id);
      expect(second.lastValidatedAt.isAfter(first.lastValidatedAt), isTrue);
      expect(history, hasLength(1));
    },
  );

  test('retains only the configured number of repository revisions', () async {
    final boundedStore = SourceRepositoryArtifactStore(
      rootDirectory: root,
      maxRevisionsPerRepository: 2,
    );
    for (var version = 1; version <= 3; version++) {
      await boundedStore.saveRevision(
        repositoryUrl: 'https://repo.example/bounded.json',
        manifest: manifest('$version.0.0'),
        documents: <RepositoryDocumentCapture>[
          document('{"version":$version}'),
        ],
      );
    }
    final history = await boundedStore.revisions(
      'https://repo.example/bounded.json',
    );
    expect(history, hasLength(2));
    expect(
      history.map((revision) => revision.manifest.extensions.single.version),
      <String>['3.0.0', '2.0.0'],
    );
  });

  test('captures provider script content by hash for provenance', () async {
    const script = 'function search(){ return []; }';
    final hash = await store.saveProviderScript(
      sourceStableKey: 'https://repo.example/index.json::fixture-provider',
      scriptUrl: 'https://repo.example/provider.js?cache=1',
      script: script,
    );
    expect(hash, isNotEmpty);
    expect(
      await store.latestProviderScriptHash(
        'https://repo.example/index.json::fixture-provider',
      ),
      hash,
    );
  });
}
