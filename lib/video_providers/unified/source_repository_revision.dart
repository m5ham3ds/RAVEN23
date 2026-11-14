import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'source_contracts.dart';
import 'source_manifest.dart';

/// An HTTP document captured while a repository index is being resolved.
/// Bodies are stored in the app-private revision directory, never in logs.
class RepositoryDocumentCapture {
  RepositoryDocumentCapture({
    required this.requestedUrl,
    required this.finalUrl,
    required this.statusCode,
    required this.body,
    this.contentType,
    this.etag,
    this.lastModified,
  }) : contentHash = sha256.convert(utf8.encode(body)).toString();

  final String requestedUrl;
  final String finalUrl;
  final int statusCode;
  final String body;
  final String? contentType;
  final String? etag;
  final String? lastModified;
  final String contentHash;
}

class RepositoryDocumentRevision {
  const RepositoryDocumentRevision({
    required this.requestedUrl,
    required this.finalUrl,
    required this.statusCode,
    required this.contentHash,
    required this.bodyFile,
    this.contentType,
    this.etag,
    this.lastModified,
  });

  final String requestedUrl;
  final String finalUrl;
  final int statusCode;
  final String contentHash;
  final String bodyFile;
  final String? contentType;
  final String? etag;
  final String? lastModified;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'requestedUrl': _safeUrl(requestedUrl),
    'finalUrl': _safeUrl(finalUrl),
    'statusCode': statusCode,
    'contentHash': contentHash,
    'bodyFile': bodyFile,
    if (contentType != null) 'contentType': contentType,
    if (etag != null) 'etag': etag,
    if (lastModified != null) 'lastModified': lastModified,
  };

  factory RepositoryDocumentRevision.fromJson(Map<String, dynamic> json) =>
      RepositoryDocumentRevision(
        requestedUrl: json['requestedUrl']?.toString() ?? '',
        finalUrl: json['finalUrl']?.toString() ?? '',
        statusCode: (json['statusCode'] as num?)?.toInt() ?? 0,
        contentHash: json['contentHash']?.toString() ?? '',
        bodyFile: json['bodyFile']?.toString() ?? '',
        contentType: json['contentType']?.toString(),
        etag: json['etag']?.toString(),
        lastModified: json['lastModified']?.toString(),
      );
}

class SourceRepositoryRevision {
  const SourceRepositoryRevision({
    required this.id,
    required this.repositoryKey,
    required this.repositoryUrl,
    required this.fetchedAt,
    DateTime? lastValidatedAt,
    required this.statusCode,
    required this.contentHash,
    this.manifestHash,
    required this.documents,
    required this.manifest,
    this.versionRef,
    this.commitHash,
    this.etag,
    this.lastModified,
    this.previousContentHash,
  }) : lastValidatedAt = lastValidatedAt ?? fetchedAt;

  final String id;
  final String repositoryKey;
  final String repositoryUrl;

  /// Time the revision was first captured.
  final DateTime fetchedAt;

  /// Most recent successful validation of the same indexed content.
  final DateTime lastValidatedAt;
  final int statusCode;
  final String contentHash;

  /// SHA-256 of the sanitized manifest snapshot serialized in metadata.
  final String? manifestHash;
  final String? versionRef;
  final String? commitHash;
  final String? etag;
  final String? lastModified;
  final String? previousContentHash;
  final List<RepositoryDocumentRevision> documents;
  final SourceRepositoryManifest manifest;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'repositoryKey': repositoryKey,
    'repositoryUrl': _safeUrl(repositoryUrl),
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'lastValidatedAt': lastValidatedAt.toUtc().toIso8601String(),
    'statusCode': statusCode,
    'contentHash': contentHash,
    if (manifestHash != null) 'manifestHash': manifestHash,
    if (versionRef != null) 'versionRef': versionRef,
    if (commitHash != null) 'commitHash': commitHash,
    if (etag != null) 'etag': etag,
    if (lastModified != null) 'lastModified': lastModified,
    if (previousContentHash != null) 'previousContentHash': previousContentHash,
    'documents': documents.map((value) => value.toJson()).toList(),
    'manifest': _manifestToJson(manifest),
  };

  factory SourceRepositoryRevision.fromJson(Map<String, dynamic> json) {
    final rawDocuments = json['documents'];
    final rawManifest = json['manifest'];
    if (rawManifest is! Map) {
      throw const FormatException('Repository revision has no manifest.');
    }
    return SourceRepositoryRevision(
      id: json['id']?.toString() ?? '',
      repositoryKey: json['repositoryKey']?.toString() ?? '',
      repositoryUrl: json['repositoryUrl']?.toString() ?? '',
      fetchedAt:
          DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastValidatedAt:
          DateTime.tryParse(json['lastValidatedAt']?.toString() ?? '') ??
          DateTime.tryParse(json['fetchedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      statusCode: (json['statusCode'] as num?)?.toInt() ?? 0,
      contentHash: json['contentHash']?.toString() ?? '',
      manifestHash: json['manifestHash']?.toString(),
      versionRef: json['versionRef']?.toString(),
      commitHash: json['commitHash']?.toString(),
      etag: json['etag']?.toString(),
      lastModified: json['lastModified']?.toString(),
      previousContentHash: json['previousContentHash']?.toString(),
      documents: rawDocuments is List
          ? rawDocuments
                .whereType<Map>()
                .map(
                  (value) => RepositoryDocumentRevision.fromJson(
                    Map<String, dynamic>.from(value),
                  ),
                )
                .toList(growable: false)
          : const <RepositoryDocumentRevision>[],
      manifest: _manifestFromJson(Map<String, dynamic>.from(rawManifest)),
    );
  }
}

class RepositoryUpdatePreview {
  const RepositoryUpdatePreview({
    required this.repositoryUrl,
    required this.currentHash,
    required this.candidateHash,
    required this.hasChanges,
    required this.addedSourceIds,
    required this.removedSourceIds,
    required this.changedSourceIds,
    required this.changedDocumentCount,
    required this.candidateManifest,
  });

  final String repositoryUrl;
  final String? currentHash;
  final String candidateHash;
  final bool hasChanges;
  final List<String> addedSourceIds;
  final List<String> removedSourceIds;
  final List<String> changedSourceIds;
  final int changedDocumentCount;
  final SourceRepositoryManifest candidateManifest;
}

class SourceDuplicateCandidate {
  const SourceDuplicateCandidate({
    required this.first,
    required this.second,
    required this.reasons,
  });

  final SourceManifest first;
  final SourceManifest second;
  final Set<String> reasons;
}

class SourceProvenance {
  const SourceProvenance({
    required this.sourceId,
    required this.sourceName,
    required this.version,
    required this.authors,
    required this.repositoryUrl,
    required this.engineType,
    required this.scriptUrl,
    this.scriptHash,
    this.commitHash,
  });

  final String sourceId;
  final String sourceName;
  final String version;
  final List<String> authors;
  final String? repositoryUrl;
  final String engineType;
  final String? scriptUrl;
  final String? scriptHash;
  final String? commitHash;
}

/// App-private, append-only storage for repository revisions and provider
/// scripts. A SHA-256 detects byte changes; it is not a trust/signature check.
class SourceRepositoryArtifactStore {
  SourceRepositoryArtifactStore({
    Directory? rootDirectory,
    this.maxRevisionsPerRepository = 20,
    this.maxScriptsPerSource = 20,
  }) : _providedRoot = rootDirectory;

  /// Keep enough local history for practical rollback without unbounded cache
  /// growth. The newest [maxRevisionsPerRepository] snapshots are retained.
  final int maxRevisionsPerRepository;
  final int maxScriptsPerSource;

  final Directory? _providedRoot;
  Directory? _resolvedRoot;
  final Map<String, List<SourceRepositoryRevision>> _memoryRevisions = {};
  final Map<String, String> _memoryScripts = {};
  final Map<String, String> _memoryDocumentBodies = {};

  Future<Directory> _root() async {
    final provided = _providedRoot;
    if (provided != null) {
      await provided.create(recursive: true);
      return provided;
    }
    final existing = _resolvedRoot;
    if (existing != null) return existing;
    try {
      final base = await getApplicationSupportDirectory();
      final directory = Directory(
        p.join(base.path, 'source_repository_artifacts'),
      );
      await directory.create(recursive: true);
      return _resolvedRoot = directory;
    } on MissingPluginException {
      // Unit tests and unsupported hosts use process-memory storage only.
      return _resolvedRoot = Directory.systemTemp;
    } on PlatformException {
      // Some test hosts report a PlatformException instead of a
      // MissingPluginException when path_provider is not registered.
      return _resolvedRoot = Directory.systemTemp;
    }
  }

  String repositoryKey(String repositoryUrl) => sha256
      .convert(utf8.encode(SourceRepositoryIdentity.fromUrl(repositoryUrl).key))
      .toString();

  static String contentHashForDocuments(
    List<RepositoryDocumentCapture> documents,
  ) {
    final fingerprints =
        documents
            .map((doc) => '${_safeUrl(doc.requestedUrl)}:${doc.contentHash}')
            .toList()
          ..sort();
    return sha256.convert(utf8.encode(fingerprints.join('\n'))).toString();
  }

  Future<SourceRepositoryRevision> saveRevision({
    required String repositoryUrl,
    required SourceRepositoryManifest manifest,
    required List<RepositoryDocumentCapture> documents,
    String? versionRef,
    String? commitHash,
  }) async {
    final key = repositoryKey(repositoryUrl);
    final previous = await latestRevision(repositoryUrl);
    final contentHash = contentHashForDocuments(documents);
    final manifestHash = _manifestContentHash(manifest);
    final root = await _root();
    final memoryOnly =
        _providedRoot == null && root.path == Directory.systemTemp.path;
    final now = DateTime.now().toUtc();
    if (previous != null && previous.contentHash == contentHash) {
      final primary = documents.isEmpty ? null : documents.first;
      final previousDocuments = <String, RepositoryDocumentRevision>{
        for (final value in previous.documents) value.requestedUrl: value,
      };
      final revalidatedDocuments = <RepositoryDocumentRevision>[
        for (final document in documents)
          RepositoryDocumentRevision(
            requestedUrl: document.requestedUrl,
            finalUrl: document.finalUrl,
            statusCode: document.statusCode,
            contentHash: document.contentHash,
            bodyFile:
                previousDocuments[document.requestedUrl]?.bodyFile ??
                'document_${documents.indexOf(document).toString().padLeft(2, '0')}_${document.contentHash.substring(0, 12)}.txt',
            contentType: document.contentType,
            etag: document.etag,
            lastModified: document.lastModified,
          ),
      ];
      final revalidated = SourceRepositoryRevision(
        id: previous.id,
        repositoryKey: previous.repositoryKey,
        repositoryUrl: previous.repositoryUrl,
        fetchedAt: previous.fetchedAt,
        lastValidatedAt: now,
        statusCode: primary?.statusCode ?? previous.statusCode,
        contentHash: previous.contentHash,
        manifestHash: manifestHash,
        versionRef: versionRef ?? previous.versionRef,
        commitHash: _validCommit(commitHash) ?? previous.commitHash,
        etag: primary?.etag ?? previous.etag,
        lastModified: primary?.lastModified ?? previous.lastModified,
        previousContentHash: previous.previousContentHash,
        documents: revalidatedDocuments,
        manifest: manifest,
      );
      if (!memoryOnly) {
        final metadata = File(
          p.join(root.path, 'repositories', key, previous.id, 'revision.json'),
        );
        await metadata.writeAsString(
          jsonEncode(revalidated.toJson()),
          flush: true,
        );
      }
      final history = _memoryRevisions.putIfAbsent(key, () => []);
      final existingIndex = history.indexWhere(
        (revision) => revision.id == previous.id,
      );
      if (existingIndex >= 0) {
        history[existingIndex] = revalidated;
      } else {
        history.add(revalidated);
      }
      return revalidated;
    }
    final revisionId =
        '${now.microsecondsSinceEpoch}-${contentHash.substring(0, 12)}';
    final revisionDirectory = Directory(
      p.join(root.path, 'repositories', key, revisionId),
    );
    if (!memoryOnly) await revisionDirectory.create(recursive: true);

    final documentRevisions = <RepositoryDocumentRevision>[];
    for (var index = 0; index < documents.length; index++) {
      final document = documents[index];
      final fileName =
          'document_${index.toString().padLeft(2, '0')}_${document.contentHash.substring(0, 12)}.txt';
      if (memoryOnly) {
        _memoryDocumentBodies['$key/$revisionId/$fileName'] = document.body;
      } else {
        final file = File(p.join(revisionDirectory.path, fileName));
        await file.writeAsString(document.body, flush: true);
      }
      documentRevisions.add(
        RepositoryDocumentRevision(
          requestedUrl: document.requestedUrl,
          finalUrl: document.finalUrl,
          statusCode: document.statusCode,
          contentHash: document.contentHash,
          bodyFile: fileName,
          contentType: document.contentType,
          etag: document.etag,
          lastModified: document.lastModified,
        ),
      );
    }

    final primary = documents.isEmpty ? null : documents.first;
    final revision = SourceRepositoryRevision(
      id: revisionId,
      repositoryKey: key,
      repositoryUrl: _safeUrl(repositoryUrl),
      fetchedAt: now,
      lastValidatedAt: now,
      statusCode: primary?.statusCode ?? 0,
      contentHash: contentHash,
      manifestHash: manifestHash,
      versionRef: versionRef,
      commitHash: _validCommit(commitHash),
      etag: primary?.etag,
      lastModified: primary?.lastModified,
      previousContentHash: previous?.contentHash,
      documents: documentRevisions,
      manifest: manifest,
    );
    if (!memoryOnly) {
      final temporary = File(p.join(revisionDirectory.path, 'revision.tmp'));
      await temporary.writeAsString(jsonEncode(revision.toJson()), flush: true);
      await temporary.rename(p.join(revisionDirectory.path, 'revision.json'));
    }

    final inMemory = _memoryRevisions.putIfAbsent(key, () => []);
    inMemory.add(revision);
    final revisionLimit = maxRevisionsPerRepository.clamp(1, 100).toInt();
    if (!memoryOnly) {
      await _pruneRevisionHistory(key, revisionLimit);
    } else if (inMemory.length > revisionLimit) {
      inMemory.removeRange(0, inMemory.length - revisionLimit);
    }
    return revision;
  }

  Future<void> _pruneRevisionHistory(
    String repositoryKey,
    int revisionLimit,
  ) async {
    final root = await _root();
    final directory = Directory(
      p.join(root.path, 'repositories', repositoryKey),
    );
    if (!await directory.exists()) return;
    final entries = <Directory>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final metadata = File(p.join(entity.path, 'revision.json'));
      if (await metadata.exists()) entries.add(entity);
    }
    // Revision IDs begin with UTC microseconds, so lexical order is stable even
    // on filesystems whose lastModified precision is only one second.
    entries.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final entry in entries.skip(revisionLimit)) {
      await entry.delete(recursive: true);
    }
  }

  Future<List<SourceRepositoryRevision>> revisions(String repositoryUrl) async {
    final key = repositoryKey(repositoryUrl);
    final inMemory = _memoryRevisions[key];
    final root = await _root();
    if (_providedRoot == null && root.path == Directory.systemTemp.path) {
      return List<SourceRepositoryRevision>.unmodifiable(
        (inMemory ?? const <SourceRepositoryRevision>[]).reversed,
      );
    }
    final directory = Directory(p.join(root.path, 'repositories', key));
    if (!await directory.exists()) return const <SourceRepositoryRevision>[];
    final values = <SourceRepositoryRevision>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final file = File(p.join(entity.path, 'revision.json'));
      if (!await file.exists()) continue;
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          values.add(
            SourceRepositoryRevision.fromJson(
              Map<String, dynamic>.from(decoded),
            ),
          );
        }
      } catch (_) {
        // A corrupt older revision must not prevent the remaining history
        // from being listed or used.
      }
    }
    values.sort((a, b) => a.fetchedAt.compareTo(b.fetchedAt));
    return List<SourceRepositoryRevision>.unmodifiable(values.reversed);
  }

  Future<SourceRepositoryRevision?> latestRevision(String repositoryUrl) async {
    final values = await revisions(repositoryUrl);
    return values.isEmpty ? null : values.first;
  }

  Future<SourceRepositoryRevision?> loadRevision(
    String repositoryUrl,
    String revisionId,
  ) async {
    final values = await revisions(repositoryUrl);
    for (final value in values) {
      if (value.id != revisionId) continue;
      if (value.manifestHash != null &&
          value.manifestHash != _manifestContentHash(value.manifest)) {
        throw const FileSystemException(
          'Repository revision manifest integrity check failed.',
        );
      }
      final documents = <RepositoryDocumentCapture>[];
      for (final document in value.documents) {
        final body = await readDocumentBody(repositoryUrl, value, document);
        documents.add(
          RepositoryDocumentCapture(
            requestedUrl: document.requestedUrl,
            finalUrl: document.finalUrl,
            statusCode: document.statusCode,
            body: body,
            contentType: document.contentType,
            etag: document.etag,
            lastModified: document.lastModified,
          ),
        );
      }
      if (contentHashForDocuments(documents) != value.contentHash) {
        throw const FileSystemException(
          'Repository revision document index integrity check failed.',
        );
      }
      return value;
    }
    return null;
  }

  Future<String> readDocumentBody(
    String repositoryUrl,
    SourceRepositoryRevision revision,
    RepositoryDocumentRevision document,
  ) async {
    final root = await _root();
    final key = repositoryKey(repositoryUrl);
    final memoryOnly =
        _providedRoot == null && root.path == Directory.systemTemp.path;
    final memoryKey = '$key/${revision.id}/${document.bodyFile}';
    if (!RegExp(
      r'^document_\d{2,}_[a-f0-9]{12}\.txt$',
    ).hasMatch(document.bodyFile)) {
      throw const FileSystemException(
        'Repository revision contains an invalid body path.',
      );
    }
    final file = File(
      p.join(root.path, 'repositories', key, revision.id, document.bodyFile),
    );
    final body = memoryOnly
        ? _memoryDocumentBodies[memoryKey]
        : (await file.exists() ? await file.readAsString() : null);
    if (body == null) {
      throw const FileSystemException('Repository revision body is missing.');
    }
    final digest = sha256.convert(utf8.encode(body)).toString();
    if (digest != document.contentHash) {
      throw const FileSystemException(
        'Repository revision integrity check failed.',
      );
    }
    return body;
  }

  Future<String> saveProviderScript({
    required String sourceStableKey,
    required String scriptUrl,
    required String script,
  }) async {
    final hash = sha256.convert(utf8.encode(script)).toString();
    final sourceKey = sha256.convert(utf8.encode(sourceStableKey)).toString();
    final root = await _root();
    final memoryOnly =
        _providedRoot == null && root.path == Directory.systemTemp.path;
    final directory = Directory(p.join(root.path, 'scripts', sourceKey));
    if (!memoryOnly) {
      await directory.create(recursive: true);
      final scriptFile = File(p.join(directory.path, '$hash.js'));
      if (!await scriptFile.exists()) {
        await scriptFile.writeAsString(script, flush: true);
      } else {
        // Reusing an unchanged script must keep it at the head of retention;
        // otherwise a frequently reused older hash could be pruned as stale.
        await scriptFile.setLastModified(DateTime.now());
      }
      await _pruneScriptHistory(directory);
    }
    final metadata = <String, dynamic>{
      'sourceKey': sourceKey,
      'scriptUrl': _safeUrl(scriptUrl),
      'sha256': hash,
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (!memoryOnly) {
      await File(
        p.join(directory.path, 'latest.json'),
      ).writeAsString(jsonEncode(metadata), flush: true);
    }
    _memoryScripts[sourceKey] = hash;
    return hash;
  }

  Future<void> _pruneScriptHistory(Directory directory) async {
    final files = <({File file, DateTime modified})>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.js')) continue;
      files.add((file: entity, modified: await entity.lastModified()));
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    for (final entry in files.skip(maxScriptsPerSource.clamp(1, 100).toInt())) {
      await entry.file.delete();
    }
  }

  Future<String?> latestProviderScriptHash(String sourceStableKey) async {
    final sourceKey = sha256.convert(utf8.encode(sourceStableKey)).toString();
    final memory = _memoryScripts[sourceKey];
    if (memory != null) return memory;
    final root = await _root();
    final file = File(p.join(root.path, 'scripts', sourceKey, 'latest.json'));
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? decoded['sha256']?.toString() : null;
    } catch (_) {
      return null;
    }
  }
}

String _manifestContentHash(SourceRepositoryManifest manifest) => sha256
    .convert(utf8.encode(jsonEncode(_manifestToJson(manifest))))
    .toString();

String? _validCommit(String? value) {
  final commit = value?.trim().toLowerCase();
  if (commit == null || !RegExp(r'^[a-f0-9]{40}$').hasMatch(commit)) {
    return null;
  }
  return commit;
}

String _safeUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || (uri.hasScheme && uri.host.isEmpty)) {
    return 'redacted-url';
  }
  const sensitiveQueryKeys = <String>{
    'token',
    'accesstoken',
    'authtoken',
    'refreshtoken',
    'apikey',
    'xapikey',
    'authorization',
    'auth',
    'authkey',
    'password',
    'passwd',
    'secret',
    'signature',
    'sig',
    'credential',
    'clientsecret',
    'bearer',
    'jwt',
    'session',
    'sessionid',
    'cookie',
    'key',
  };
  final safeQuery = <String, dynamic>{};
  for (final entry in uri.queryParametersAll.entries) {
    final key = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (sensitiveQueryKeys.contains(key)) continue;
    safeQuery[entry.key] = entry.value.length == 1
        ? entry.value.single
        : entry.value;
  }
  if (uri.host.isEmpty) {
    if (uri.userInfo.isNotEmpty) return 'redacted-url';
    return uri.replace(queryParameters: safeQuery, fragment: '').toString();
  }
  return uri
      .replace(userInfo: '', queryParameters: safeQuery, fragment: '')
      .toString();
}

dynamic _sanitizeStoredConfig(dynamic value) {
  const sensitiveKeys = <String>{
    'token',
    'accesstoken',
    'authtoken',
    'refreshtoken',
    'apikey',
    'xapikey',
    'authorization',
    'auth',
    'authkey',
    'password',
    'passwd',
    'secret',
    'signature',
    'credential',
    'clientsecret',
    'bearer',
    'jwt',
    'session',
    'sessionid',
    'cookie',
  };
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        if (entry.key is String)
          entry.key as String:
              sensitiveKeys.contains(
                (entry.key as String).toLowerCase().replaceAll(
                  RegExp(r'[^a-z0-9]'),
                  '',
                ),
              )
              ? '[redacted]'
              : _sanitizeStoredConfig(entry.value),
    };
  }
  if (value is List) {
    return value.map(_sanitizeStoredConfig).toList(growable: false);
  }
  return value;
}

Map<String, dynamic> _manifestToJson(SourceRepositoryManifest manifest) =>
    <String, dynamic>{
      'url': _safeUrl(manifest.url),
      'name': manifest.name,
      'description': manifest.description,
      if (manifest.website != null) 'website': _safeUrl(manifest.website!),
      if (manifest.iconUrl != null) 'iconUrl': _safeUrl(manifest.iconUrl!),
      'extensionLists': manifest.extensionLists
          .map((value) {
            final uri = Uri.tryParse(value);
            return uri != null && uri.hasScheme && uri.host.isNotEmpty
                ? _safeUrl(value)
                : value;
          })
          .toList(growable: false),
      'isStremioAddon': manifest.isStremioAddon,
      'extensions': manifest.extensions.map(_sourceToJson).toList(),
    };

Map<String, dynamic> _sourceToJson(SourceManifest source) => <String, dynamic>{
  'id': source.id,
  'name': source.name,
  'description': source.description,
  'version': source.version,
  'versionCode': source.versionCode,
  'apiVersion': source.apiVersion,
  'language': source.language,
  'authors': source.authors,
  'tags': source.tags,
  if (source.homepage != null) 'homepage': _safeUrl(source.homepage!),
  if (source.iconUrl != null) 'iconUrl': _safeUrl(source.iconUrl!),
  if (source.repositoryUrl != null)
    'repositoryUrl': _safeUrl(source.repositoryUrl!),
  'enabled': source.enabled,
  'installedByDefault': source.installedByDefault,
  'isFallback': source.isFallback,
  'isNsfw': source.isNsfw,
  if (source.declaredNsfw != null) 'declaredNsfw': source.declaredNsfw,
  'status': source.status,
  if (source.updatedAt != null)
    'updatedAt': source.updatedAt!.toIso8601String(),
  'engine': <String, dynamic>{
    'rawType': source.engine.rawType,
    'kind': source.engine.kind.name,
    'endpoint': _safeUrl(source.engine.endpoint),
    'priority': source.engine.priority,
    if (source.engine.language != null) 'language': source.engine.language,
    if (source.engine.audioLanguage != null)
      'audioLanguage': source.engine.audioLanguage,
    if (source.engine.qualityFilter != null)
      'qualityFilter': source.engine.qualityFilter,
    if (source.engine.movieUrl != null)
      'movieUrl': _safeUrl(source.engine.movieUrl!),
    if (source.engine.tvUrl != null) 'tvUrl': _safeUrl(source.engine.tvUrl!),
    'config': _sanitizeStoredConfig(source.engine.config),
  },
};

SourceRepositoryManifest _manifestFromJson(Map<String, dynamic> json) {
  final rawExtensions = json['extensions'];
  return SourceRepositoryManifest(
    url: json['url']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Repository snapshot',
    description: json['description']?.toString() ?? '',
    website: json['website']?.toString(),
    iconUrl: json['iconUrl']?.toString(),
    extensionLists: json['extensionLists'] is List
        ? (json['extensionLists'] as List).whereType<String>().toList()
        : const <String>[],
    isStremioAddon: json['isStremioAddon'] == true,
    extensions: rawExtensions is List
        ? rawExtensions
              .whereType<Map>()
              .map((value) => _sourceFromJson(Map<String, dynamic>.from(value)))
              .toList(growable: false)
        : const <SourceManifest>[],
  );
}

SourceManifest _sourceFromJson(Map<String, dynamic> json) {
  final engineMap = json['engine'] is Map
      ? Map<String, dynamic>.from(json['engine'] as Map)
      : <String, dynamic>{};
  final rawType = engineMap['rawType']?.toString() ?? '';
  final config = engineMap['config'] is Map
      ? Map<String, dynamic>.from(engineMap['config'] as Map)
      : <String, dynamic>{};
  return SourceManifest(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    version: json['version']?.toString() ?? '1.0.0',
    versionCode: (json['versionCode'] as num?)?.toInt() ?? 1,
    apiVersion: (json['apiVersion'] as num?)?.toInt() ?? 1,
    language: json['language']?.toString() ?? 'Multi',
    authors: json['authors'] is List
        ? (json['authors'] as List).whereType<String>().toList()
        : const <String>[],
    tags: json['tags'] is List
        ? (json['tags'] as List).whereType<String>().toList()
        : const <String>[],
    homepage: json['homepage']?.toString(),
    iconUrl: json['iconUrl']?.toString(),
    repositoryUrl: json['repositoryUrl']?.toString(),
    enabled: json['enabled'] != false,
    installedByDefault: json['installedByDefault'] == true,
    isFallback: json['isFallback'] == true,
    isNsfw: json['isNsfw'] == true,
    declaredNsfw: json['declaredNsfw'] is bool
        ? json['declaredNsfw'] as bool
        : (json['isNsfw'] == true ? true : null),
    status: (json['status'] as num?)?.toInt() ?? 1,
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    engine: SourceEngineDescriptor(
      rawType: rawType,
      kind: sourceEngineKindFrom(rawType),
      endpoint: engineMap['endpoint']?.toString() ?? '',
      priority: (engineMap['priority'] as num?)?.toInt() ?? 50,
      language: engineMap['language']?.toString(),
      audioLanguage: engineMap['audioLanguage']?.toString(),
      qualityFilter: engineMap['qualityFilter']?.toString(),
      movieUrl: engineMap['movieUrl']?.toString(),
      tvUrl: engineMap['tvUrl']?.toString(),
      config: config,
    ),
  );
}
