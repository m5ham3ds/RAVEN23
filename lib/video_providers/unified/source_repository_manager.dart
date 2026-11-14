import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'source_contracts.dart';
import 'source_manifest.dart';
import 'source_repository_client.dart';
import 'source_repository_revision.dart';

class SourceRepositorySyncResult {
  const SourceRepositorySyncResult({
    required this.repositories,
    required this.sources,
    required this.errors,
    this.catalog = const <SourceManifest>[],
  });

  final List<SourceRepositoryManifest> repositories;

  /// Installed and enabled sources that are eligible for resolution.
  final List<SourceManifest> sources;

  /// Every source discovered in the repositories, including uninstalled ones.
  final List<SourceManifest> catalog;
  final Map<String, String> errors;
}

class _PendingRepositoryPreview {
  const _PendingRepositoryPreview({
    required this.preview,
    required this.documents,
  });

  final RepositoryUpdatePreview preview;
  final List<RepositoryDocumentCapture> documents;
}

/// Persists user-added repository URLs and refreshes their manifests.
///
/// Repository entries are metadata only: an engine is executed only when its
/// type has a registered implementation and its manifest passes validation.
class SourceRepositoryManager {
  SourceRepositoryManager({
    SourceRepositoryClient? client,
    SharedPreferences? preferences,
    SourceRepositoryArtifactStore? artifactStore,
  }) : _client = client ?? SourceRepositoryClient(),
       _preferences = preferences,
       _artifactStore = artifactStore ?? SourceRepositoryArtifactStore();

  static const String defaultOpenStreamRepository =
      'https://raw.githubusercontent.com/Ivorisnoob/OpenStream/main/extensions/index.json';

  /// Repository index URLs packaged with RAVEN23. The list includes the
  /// OpenStream index and community-maintained Zangetsu/Spyhell indexes.
  /// Discovering a provider never installs or executes it.
  static const List<String> bundledRepositoryUrls = <String>[
    defaultOpenStreamRepository,
    'https://raw.githubusercontent.com/Spyou/zangetsu-providers/main/index.json',
    'https://raw.githubusercontent.com/Serenity-MIST/zangetsu-sources/main/index.json',
    'https://raw.githubusercontent.com/Spyhell/zangetsu-experiment-repo/main/index.json',
    'https://raw.githubusercontent.com/Spyou/Zangetsu-spyou-provider/main/index.json',
    'https://raw.githubusercontent.com/Spyhell/spyou-latin-zan/main/index.json',
  ];

  static const String _defaultRepositorySeededKey =
      'unified_source_default_repository_seeded_v1';
  static const String _defaultRepositorySeedVersionKey =
      'unified_source_default_repository_seed_version_v2';
  static const int _defaultRepositorySeedVersion = 2;
  static const String _repositoriesKey = 'unified_source_repository_urls_v1';
  static const String _installedSourcesKey = 'unified_installed_source_keys_v1';
  static const String _disabledDefaultsKey =
      'unified_disabled_default_source_keys_v1';
  static const String _repositoryPinsKey = 'unified_source_repository_pins_v1';
  static const String _repositoryRollbackKey =
      'unified_source_repository_rollback_v1';
  static const Duration catalogCacheTtl = Duration(minutes: 5);
  static const int _maxPendingPreviewCount = 2;
  static const int _maxPendingPreviewBytes = 16 * 1024 * 1024;

  final Map<String, _PendingRepositoryPreview> _pendingPreviews =
      <String, _PendingRepositoryPreview>{};
  SourceRepositorySyncResult? _catalogCache;
  DateTime? _catalogCachedAt;
  Future<SourceRepositorySyncResult>? _catalogRefresh;

  final SourceRepositoryClient _client;
  final SourceRepositoryArtifactStore _artifactStore;
  final SharedPreferences? _preferences;
  SharedPreferences? _resolvedPreferences;

  Future<SharedPreferences> get _prefs async {
    if (_preferences != null) return _preferences;
    return _resolvedPreferences ??= await SharedPreferences.getInstance();
  }

  Future<List<String>> repositoryUrls() async {
    final preferences = await _prefs;
    final raw = preferences.getStringList(_repositoriesKey) ?? const <String>[];
    return raw
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<void> addRepository(String url) async {
    final normalized = SourceRepositoryClient.normalizeRepositoryUrl(url);
    final current = await repositoryUrls();
    if (current.contains(normalized)) return;
    final preferences = await _prefs;
    await preferences.setStringList(_repositoriesKey, <String>[
      ...current,
      normalized,
    ]);
    _invalidateCatalogCache();
  }

  /// Restores every repository index bundled with the app without
  /// replacing custom repositories or duplicating existing entries.
  /// Returns the number of repositories newly added.
  Future<int> addDefaultRepositories() async {
    return _appendRepositories(bundledRepositoryUrls);
  }

  Future<int> _appendRepositories(Iterable<String> urls) async {
    final current = await repositoryUrls();
    final known = current
        .map(SourceRepositoryClient.normalizeRepositoryUrl)
        .toSet();
    final merged = List<String>.of(current);
    var added = 0;
    for (final value in urls) {
      final normalized = SourceRepositoryClient.normalizeRepositoryUrl(value);
      if (known.add(normalized)) {
        merged.add(normalized);
        added++;
      }
    }
    if (added == 0) return 0;
    final preferences = await _prefs;
    await preferences.setStringList(_repositoriesKey, merged);
    _invalidateCatalogCache();
    return added;
  }

  Future<void> removeRepository(String url) async {
    final normalized = SourceRepositoryClient.normalizeRepositoryUrl(url);
    final current = List<String>.of(await repositoryUrls());
    current.remove(normalized);
    final preferences = await _prefs;
    await preferences.setStringList(_repositoriesKey, current);

    // Remove orphaned installation preferences tied to this repository. The
    // source catalog itself is still fetched on the next sync, so re-adding
    // the repository starts with a clean install state.
    final sourcePrefix = '$normalized::';
    final installed = await installedSourceKeys();
    installed.removeWhere((key) => key.startsWith(sourcePrefix));
    await preferences.setStringList(
      _installedSourcesKey,
      installed.toList(growable: false),
    );
    final disabledDefaults = await disabledDefaultSourceKeys();
    disabledDefaults.removeWhere((key) => key.startsWith(sourcePrefix));
    await preferences.setStringList(
      _disabledDefaultsKey,
      disabledDefaults.toList(growable: false),
    );
    final pins = await _storedStringMap(_repositoryPinsKey);
    pins.remove(_repositoryIdentityKey(normalized));
    await _saveStringMap(_repositoryPinsKey, pins);
    final rollbackOverrides = await _storedStringMap(_repositoryRollbackKey);
    rollbackOverrides.remove(_repositoryIdentityKey(normalized));
    await _saveStringMap(_repositoryRollbackKey, rollbackOverrides);
    _invalidateCatalogCache();
  }

  String _repositoryIdentityKey(String url) =>
      SourceRepositoryIdentity.fromUrl(url).key;

  Future<Map<String, String>> _storedStringMap(String key) async {
    final preferences = await _prefs;
    final raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return <String, String>{
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return <String, String>{};
    }
  }

  Future<void> _saveStringMap(String key, Map<String, String> value) async {
    final preferences = await _prefs;
    await preferences.setString(key, jsonEncode(value));
  }

  /// The immutable commit pin currently applied to a GitHub raw repository.
  Future<String?> pinnedCommit(String repositoryUrl) async {
    return (await _storedStringMap(_repositoryPinsKey))[_repositoryIdentityKey(
      repositoryUrl,
    )];
  }

  /// Pins a raw GitHub index to a full commit SHA. Branch names and short SHAs
  /// are rejected; ordinary repository URLs remain untouched until pinned.
  Future<void> pinRepositoryToCommit(
    String repositoryUrl,
    String commitHash,
  ) async {
    final normalized = SourceRepositoryClient.normalizeRepositoryUrl(
      repositoryUrl,
    );
    // Validate that this URL shape supports immutable ref replacement.
    SourceRepositoryClient.pinGitHubRawUrlToCommit(normalized, commitHash);
    final pins = await _storedStringMap(_repositoryPinsKey);
    pins[_repositoryIdentityKey(normalized)] = commitHash.toLowerCase();
    await _saveStringMap(_repositoryPinsKey, pins);
    await resumeRepositoryUpdates(normalized);
    _invalidateCatalogCache();
  }

  Future<void> clearRepositoryPin(String repositoryUrl) async {
    final pins = await _storedStringMap(_repositoryPinsKey);
    pins.remove(_repositoryIdentityKey(repositoryUrl));
    await _saveStringMap(_repositoryPinsKey, pins);
    _invalidateCatalogCache();
  }

  Future<List<SourceRepositoryRevision>> repositoryRevisions(
    String repositoryUrl,
  ) => _artifactStore.revisions(repositoryUrl);

  /// Downloads and parses a candidate update without making it active. The
  /// caller reviews this diff before [applyPreviewedRepositoryUpdate] commits it.
  Future<RepositoryUpdatePreview> previewRepositoryUpdate(
    String repositoryUrl,
  ) async {
    final normalized = SourceRepositoryClient.normalizeRepositoryUrl(
      repositoryUrl,
    );
    final pin = await pinnedCommit(normalized);
    final fetchUrl = pin == null
        ? normalized
        : SourceRepositoryClient.pinGitHubRawUrlToCommit(normalized, pin);
    final documents = <RepositoryDocumentCapture>[];
    final candidate = await _client.fetchRepository(
      fetchUrl,
      repositoryIdentityUrl: normalized,
      onDocument: documents.add,
    );
    if (documents.isEmpty) {
      throw const FormatException(
        'Repository returned no versioned documents.',
      );
    }
    final previous = await _artifactStore.latestRevision(normalized);
    final oldById = <String, SourceManifest>{
      for (final source
          in previous?.manifest.extensions ?? const <SourceManifest>[])
        source.id: source,
    };
    final newById = <String, SourceManifest>{
      for (final source in candidate.extensions) source.id: source,
    };
    final added = newById.keys.where((id) => !oldById.containsKey(id)).toList()
      ..sort();
    final removed =
        oldById.keys.where((id) => !newById.containsKey(id)).toList()..sort();
    final changed = <String>[];
    for (final id in oldById.keys.toSet().intersection(newById.keys.toSet())) {
      final oldSource = oldById[id]!;
      final newSource = newById[id]!;
      if (_sourceFingerprint(oldSource) != _sourceFingerprint(newSource)) {
        changed.add(id);
      }
    }
    changed.sort();
    final candidateHash = SourceRepositoryArtifactStore.contentHashForDocuments(
      documents,
    );
    final previousDocuments = <String, String>{
      for (final document
          in previous?.documents ?? const <RepositoryDocumentRevision>[])
        _documentIdentity(document.requestedUrl): document.contentHash,
    };
    final candidateDocuments = <String, String>{
      for (final document in documents)
        _documentIdentity(document.requestedUrl): document.contentHash,
    };
    final allDocumentUrls = <String>{
      ...previousDocuments.keys,
      ...candidateDocuments.keys,
    };
    final changedDocumentCount = allDocumentUrls
        .where((url) => previousDocuments[url] != candidateDocuments[url])
        .length;
    final preview = RepositoryUpdatePreview(
      repositoryUrl: normalized,
      currentHash: previous?.contentHash,
      candidateHash: candidateHash,
      hasChanges: previous == null || previous.contentHash != candidateHash,
      addedSourceIds: List<String>.unmodifiable(added),
      removedSourceIds: List<String>.unmodifiable(removed),
      changedSourceIds: List<String>.unmodifiable(changed),
      changedDocumentCount: changedDocumentCount,
      candidateManifest: candidate,
    );
    final capturedBytes = documents.fold<int>(
      0,
      (total, document) => total + utf8.encode(document.body).length,
    );
    if (capturedBytes > _maxPendingPreviewBytes) {
      _pendingPreviews.remove(_repositoryIdentityKey(normalized));
      throw const FormatException(
        'Repository preview exceeds the 16 MB staged-update safety limit.',
      );
    }
    final identityKey = _repositoryIdentityKey(normalized);
    _pendingPreviews[identityKey] = _PendingRepositoryPreview(
      preview: preview,
      documents: List<RepositoryDocumentCapture>.unmodifiable(documents),
    );
    while (_pendingPreviews.length > _maxPendingPreviewCount) {
      _pendingPreviews.remove(_pendingPreviews.keys.first);
    }
    return preview;
  }

  /// Applies exactly the documents and manifest that the user previewed. The
  /// saved revision is selected temporarily while the full catalog is rebuilt;
  /// no second network fetch can silently replace the approved candidate.
  Future<SourceRepositorySyncResult> applyPreviewedRepositoryUpdate(
    RepositoryUpdatePreview preview,
  ) async {
    if (!preview.hasChanges) {
      throw const FormatException(
        'The preview contains no repository changes.',
      );
    }
    final normalized = SourceRepositoryClient.normalizeRepositoryUrl(
      preview.repositoryUrl,
    );
    // Serialize catalog application with any in-flight refresh. The staged
    // candidate remains authoritative; waiting prevents a competing refresh
    // from racing the catalog cache while the approved revision is activated.
    final inFlightRefresh = _catalogRefresh;
    if (inFlightRefresh != null) {
      try {
        await inFlightRefresh;
      } catch (_) {
        // Applying the explicitly previewed snapshot gets its own attempt.
      }
    }
    final identityKey = _repositoryIdentityKey(normalized);
    final pending = _pendingPreviews[identityKey];
    if (pending == null || !identical(pending.preview, preview)) {
      throw StateError(
        'This repository preview is no longer current. Preview the update again.',
      );
    }
    final pin = await pinnedCommit(normalized);
    final fetchUrl = pin == null
        ? normalized
        : SourceRepositoryClient.pinGitHubRawUrlToCommit(normalized, pin);
    final stagedHash = SourceRepositoryArtifactStore.contentHashForDocuments(
      pending.documents,
    );
    if (stagedHash != preview.candidateHash) {
      _pendingPreviews.remove(identityKey);
      throw StateError(
        'The staged repository bytes no longer match the approved preview.',
      );
    }
    final revision = await _artifactStore.saveRevision(
      repositoryUrl: normalized,
      manifest: preview.candidateManifest,
      documents: pending.documents,
      versionRef: pin ?? _versionRefFromUrl(fetchUrl),
      commitHash: pin ?? SourceRepositoryClient.commitHashFromUrl(fetchUrl),
    );
    if (revision.contentHash != preview.candidateHash) {
      _pendingPreviews.remove(identityKey);
      throw StateError(
        'The saved repository revision does not match the approved preview.',
      );
    }

    // Re-read the persisted revision so both its manifest metadata and every
    // captured document body pass the artifact store's integrity checks. Then
    // activate the in-memory manifest the user actually reviewed; stored
    // metadata may redact private URL material and is not the runtime payload.
    // Do not route a transient preview through the persistent rollback map.
    final verifiedRevision = await _artifactStore.loadRevision(
      normalized,
      revision.id,
    );
    if (verifiedRevision == null) {
      throw StateError(
        'The approved repository snapshot could not be reloaded.',
      );
    }
    final activatedStagedKeys = <String>{};
    final refreshed = await _fetchCatalog(
      stagedRepositorySnapshots: <String, SourceRepositoryManifest>{
        identityKey: preview.candidateManifest,
      },
      activatedStagedRepositoryKeys: activatedStagedKeys,
    );
    if (!activatedStagedKeys.contains(identityKey) ||
        refreshed.errors.containsKey(normalized)) {
      throw StateError(
        refreshed.errors[normalized] ??
            'The approved repository snapshot could not be activated.',
      );
    }
    _catalogCache = refreshed;
    _catalogCachedAt = DateTime.now();
    _pendingPreviews.remove(identityKey);
    return sync();
  }

  /// Selects the previous locally saved repository revision. The override is
  /// used by sync until [resumeRepositoryUpdates] is called.
  Future<SourceRepositoryRevision?> rollbackRepository(
    String repositoryUrl,
  ) async {
    final normalized = SourceRepositoryClient.normalizeRepositoryUrl(
      repositoryUrl,
    );
    final revisions = await _artifactStore.revisions(normalized);
    if (revisions.length < 2) return null;
    final overrides = await _storedStringMap(_repositoryRollbackKey);
    final currentId =
        overrides[_repositoryIdentityKey(normalized)] ?? revisions.first.id;
    final currentIndex = revisions.indexWhere(
      (revision) => revision.id == currentId,
    );
    final previousIndex = currentIndex < 0 ? 1 : currentIndex + 1;
    if (previousIndex >= revisions.length) return null;
    final target = revisions[previousIndex];
    overrides[_repositoryIdentityKey(normalized)] = target.id;
    await _saveStringMap(_repositoryRollbackKey, overrides);
    _invalidateCatalogCache();
    return target;
  }

  /// Clears a local rollback override and resumes fetching the configured
  /// branch or commit pin on the next sync.
  Future<void> resumeRepositoryUpdates(String repositoryUrl) async {
    final overrides = await _storedStringMap(_repositoryRollbackKey);
    overrides.remove(_repositoryIdentityKey(repositoryUrl));
    await _saveStringMap(_repositoryRollbackKey, overrides);
    _invalidateCatalogCache();
  }

  /// Reports likely duplicate providers for review; no source is removed or
  /// disabled automatically. Reasons include source identity, script URL,
  /// name+domain and matching locally captured script hashes.
  Future<List<SourceDuplicateCandidate>> findPotentialDuplicates(
    Iterable<SourceManifest> sources,
  ) async {
    final values = sources.toList(growable: false);
    final result = <SourceDuplicateCandidate>[];
    final scriptHashes = <String, String?>{};
    for (final source in values) {
      scriptHashes[source.stableKey] = await _artifactStore
          .latestProviderScriptHash(source.stableKey);
    }
    for (var i = 0; i < values.length; i++) {
      for (var j = i + 1; j < values.length; j++) {
        final first = values[i];
        final second = values[j];
        final reasons = <String>{};
        if (first.stableKey == second.stableKey) {
          reasons.add('source-identity');
        }
        final firstUrl = _canonicalSourceUrl(first.engine.endpoint);
        final secondUrl = _canonicalSourceUrl(second.engine.endpoint);
        if (firstUrl != null && firstUrl == secondUrl) {
          reasons.add('canonical-script-url');
        }
        final firstDomain = Uri.tryParse(
          first.engine.endpoint,
        )?.host.toLowerCase();
        final secondDomain = Uri.tryParse(
          second.engine.endpoint,
        )?.host.toLowerCase();
        if (first.name.trim().toLowerCase() ==
                second.name.trim().toLowerCase() &&
            firstDomain != null &&
            firstDomain.isNotEmpty &&
            firstDomain == secondDomain) {
          reasons.add('name-and-domain');
        }
        final firstHash = scriptHashes[first.stableKey];
        final secondHash = scriptHashes[second.stableKey];
        if (firstHash != null && firstHash == secondHash) {
          reasons.add('script-content-hash');
        }
        if (reasons.isNotEmpty) {
          result.add(
            SourceDuplicateCandidate(
              first: first,
              second: second,
              reasons: Set<String>.unmodifiable(reasons),
            ),
          );
        }
      }
    }
    return List<SourceDuplicateCandidate>.unmodifiable(result);
  }

  Future<SourceProvenance> provenanceOf(SourceManifest source) async {
    final revisions = source.repositoryUrl == null
        ? const <SourceRepositoryRevision>[]
        : await _artifactStore.revisions(source.repositoryUrl!);
    final revision = revisions.isEmpty ? null : revisions.first;
    return SourceProvenance(
      sourceId: source.id,
      sourceName: source.name,
      version: source.version,
      authors: List<String>.unmodifiable(source.authors),
      repositoryUrl: source.repositoryUrl == null
          ? null
          : _safeDisplayUrl(source.repositoryUrl!),
      engineType: source.engine.rawType,
      scriptUrl: source.engine.kind == SourceEngineKind.javascript
          ? _safeDisplayUrl(source.engine.endpoint)
          : null,
      scriptHash: await _artifactStore.latestProviderScriptHash(
        source.stableKey,
      ),
      commitHash: revision?.commitHash,
    );
  }

  String _sourceFingerprint(SourceManifest source) =>
      jsonEncode(<String, dynamic>{
        'id': source.id,
        'name': source.name,
        'description': source.description,
        'version': source.version,
        'versionCode': source.versionCode,
        'apiVersion': source.apiVersion,
        'language': source.language,
        'authors': source.authors,
        'tags': source.tags,
        'homepage': source.homepage,
        'iconUrl': source.iconUrl,
        'enabled': source.enabled,
        'installedByDefault': source.installedByDefault,
        'isFallback': source.isFallback,
        'isNsfw': source.isNsfw,
        'declaredNsfw': source.declaredNsfw,
        'status': source.status,
        'updatedAt': source.updatedAt?.toUtc().toIso8601String(),
        'engine': <String, dynamic>{
          'rawType': source.engine.rawType,
          'kind': source.engine.kind.name,
          'endpoint': source.engine.endpoint,
          'priority': source.engine.priority,
          'language': source.engine.language,
          'audioLanguage': source.engine.audioLanguage,
          'qualityFilter': source.engine.qualityFilter,
          'movieUrl': source.engine.movieUrl,
          'tvUrl': source.engine.tvUrl,
          'config': source.engine.config,
        },
      });

  String? _versionRefFromUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.host.toLowerCase() != 'raw.githubusercontent.com' ||
        uri.pathSegments.length < 4) {
      return null;
    }
    return uri.pathSegments[2];
  }

  String _documentIdentity(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return raw.trim();
    const sensitiveQueryKeys = <String>{
      'token',
      'accesstoken',
      'refreshtoken',
      'apikey',
      'authorization',
      'auth',
      'password',
      'passwd',
      'secret',
      'signature',
      'sig',
      'credential',
      'clientsecret',
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
    return uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          userInfo: '',
          host: uri.host.toLowerCase(),
          queryParameters: safeQuery,
          fragment: '',
        )
        .normalizePath()
        .toString();
  }

  String? _safeDisplayUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return uri.replace(userInfo: '', query: '', fragment: '').toString();
  }

  String? _canonicalSourceUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    return uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          fragment: '',
        )
        .normalizePath()
        .toString();
  }

  /// Describes the current lifecycle flags without changing installation or
  /// enablement behavior. Flags are intentionally orthogonal (for example,
  /// an installed source may also be experimental).
  Future<SourceLifecycleSnapshot> lifecycleOf(
    SourceManifest source, {
    bool validated = false,
    bool duplicate = false,
    String? validationMessage,
    String? failureMessage,
  }) async {
    final installed = await installedSourceKeys();
    final disabledDefaults = await disabledDefaultSourceKeys();
    final isInstalled =
        installed.contains(source.stableKey) ||
        (source.installedByDefault &&
            !disabledDefaults.contains(source.stableKey));
    final isEnabled =
        source.enabled && !disabledDefaults.contains(source.stableKey);
    return SourceLifecycleSnapshot.fromManifest(
      source,
      installed: isInstalled,
      enabled: isEnabled,
      validated: validated,
      duplicate: duplicate,
      validationMessage: validationMessage,
      failureMessage: failureMessage,
    );
  }

  Future<Set<String>> installedSourceKeys() async {
    final preferences = await _prefs;
    return (preferences.getStringList(_installedSourcesKey) ?? const <String>[])
        .toSet();
  }

  Future<void> installSource(SourceManifest source) async {
    final preferences = await _prefs;
    final installed = await installedSourceKeys();
    installed.add(source.stableKey);
    await preferences.setStringList(
      _installedSourcesKey,
      installed.toList(growable: false),
    );
    final disabledDefaults = await disabledDefaultSourceKeys();
    disabledDefaults.remove(source.stableKey);
    await preferences.setStringList(
      _disabledDefaultsKey,
      disabledDefaults.toList(growable: false),
    );
  }

  Future<void> uninstallSource(SourceManifest source) async {
    final preferences = await _prefs;
    final installed = await installedSourceKeys();
    installed.remove(source.stableKey);
    await preferences.setStringList(
      _installedSourcesKey,
      installed.toList(growable: false),
    );
    if (source.installedByDefault) {
      final disabledDefaults = await disabledDefaultSourceKeys();
      disabledDefaults.add(source.stableKey);
      await preferences.setStringList(
        _disabledDefaultsKey,
        disabledDefaults.toList(growable: false),
      );
    }
  }

  Future<Set<String>> disabledDefaultSourceKeys() async {
    final preferences = await _prefs;
    return (preferences.getStringList(_disabledDefaultsKey) ?? const <String>[])
        .toSet();
  }

  Future<void> _seedDefaultRepositoriesIfNeeded() async {
    final preferences = await _prefs;
    final seededVersion =
        preferences.getInt(_defaultRepositorySeedVersionKey) ?? 0;
    if (seededVersion >= _defaultRepositorySeedVersion) return;

    // Existing installations already passed the v1 OpenStream bootstrap.
    // Add only the five newly bundled repositories so a user who deliberately
    // removed OpenStream is not forced to add it back during this migration.
    final legacyOpenStreamSeeded =
        preferences.getBool(_defaultRepositorySeededKey) == true;
    final repositoriesToSeed = legacyOpenStreamSeeded
        ? bundledRepositoryUrls.skip(1)
        : bundledRepositoryUrls;
    await _appendRepositories(repositoriesToSeed);

    await preferences.setBool(_defaultRepositorySeededKey, true);
    await preferences.setInt(
      _defaultRepositorySeedVersionKey,
      _defaultRepositorySeedVersion,
    );
  }

  Future<SourceRepositorySyncResult> sync({bool forceRefresh = false}) async {
    await _seedDefaultRepositoriesIfNeeded();
    var catalogSnapshot = _catalogCache;
    final cachedAt = _catalogCachedAt;
    final isFresh =
        catalogSnapshot != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < catalogCacheTtl;

    if (forceRefresh || !isFresh) {
      final pending = _catalogRefresh;
      if (pending != null && !forceRefresh) {
        catalogSnapshot = await pending;
      } else {
        if (pending != null && forceRefresh) {
          // Do not launch two full repository refreshes at the same time.
          // Wait for the in-flight one, then perform the requested refresh.
          try {
            catalogSnapshot = await pending;
          } catch (_) {
            // The explicit refresh below gets its own attempt.
          }
        }
        final refresh = _fetchCatalog();
        _catalogRefresh = refresh;
        try {
          final refreshed = await refresh;
          final previous = catalogSnapshot;
          catalogSnapshot =
              refreshed.catalog.isEmpty &&
                  refreshed.errors.isNotEmpty &&
                  previous?.catalog.isNotEmpty == true
              ? SourceRepositorySyncResult(
                  repositories: previous!.repositories,
                  sources: const <SourceManifest>[],
                  catalog: previous.catalog,
                  errors: refreshed.errors,
                )
              : refreshed;
          _catalogCache = catalogSnapshot;
          _catalogCachedAt = DateTime.now();
        } catch (_) {
          // Retain the last known catalogue if a refresh fails. The caller
          // still receives the previous snapshot, preserving offline playback.
          if (catalogSnapshot == null) rethrow;
        } finally {
          if (identical(_catalogRefresh, refresh)) _catalogRefresh = null;
        }
      }
    }

    final base = catalogSnapshot;
    final installed = await installedSourceKeys();
    final disabledDefaults = await disabledDefaultSourceKeys();
    final activeSources = base.catalog
        .where((source) {
          final explicitlyInstalled = installed.contains(source.stableKey);
          final isInstalled =
              explicitlyInstalled ||
              (source.installedByDefault &&
                  !disabledDefaults.contains(source.stableKey));
          // Explicit user installation overrides an upstream `enabled:false`
          // hint. Default-only disabled entries remain inactive until the user
          // explicitly adds them.
          return isInstalled && (source.enabled || explicitlyInstalled);
        })
        .toList(growable: false);

    return SourceRepositorySyncResult(
      repositories: base.repositories,
      sources: activeSources,
      catalog: base.catalog,
      errors: base.errors,
    );
  }

  Future<SourceRepositorySyncResult> _fetchCatalog({
    Map<String, SourceRepositoryManifest> stagedRepositorySnapshots =
        const <String, SourceRepositoryManifest>{},
    Set<String>? activatedStagedRepositoryKeys,
  }) async {
    final urls = await repositoryUrls();
    final repositories = <SourceRepositoryManifest>[];
    final catalog = <SourceManifest>[];
    final errors = <String, String>{};
    final seenSources = <String>{};
    final pins = await _storedStringMap(_repositoryPinsKey);
    final rollbackOverrides = await _storedStringMap(_repositoryRollbackKey);

    for (final url in urls) {
      try {
        final key = _repositoryIdentityKey(url);
        final stagedSnapshot = stagedRepositorySnapshots[key];
        final rollbackId = rollbackOverrides[key];
        late final SourceRepositoryManifest repository;
        if (stagedSnapshot != null) {
          repository = stagedSnapshot;
          activatedStagedRepositoryKeys?.add(key);
        } else if (rollbackId != null) {
          final snapshot = await _artifactStore.loadRevision(url, rollbackId);
          if (snapshot == null) {
            throw const FileSystemException(
              'The selected repository rollback snapshot is unavailable.',
            );
          }
          repository = snapshot.manifest;
        } else {
          final pin = pins[key];
          final fetchUrl = pin == null
              ? url
              : SourceRepositoryClient.pinGitHubRawUrlToCommit(url, pin);
          final documents = <RepositoryDocumentCapture>[];
          repository = await _client.fetchRepository(
            fetchUrl,
            repositoryIdentityUrl: url,
            onDocument: documents.add,
          );
          if (documents.isNotEmpty) {
            await _artifactStore.saveRevision(
              repositoryUrl: url,
              manifest: repository,
              documents: documents,
              versionRef: pin ?? _versionRefFromUrl(fetchUrl),
              commitHash:
                  pin ?? SourceRepositoryClient.commitHashFromUrl(fetchUrl),
            );
          }
        }
        repositories.add(repository);
        for (final source in repository.extensions) {
          if (seenSources.add(source.stableKey)) catalog.add(source);
        }
      } catch (error) {
        errors[url] = error.toString();
      }
    }

    return SourceRepositorySyncResult(
      repositories: repositories,
      sources: const <SourceManifest>[],
      catalog: catalog,
      errors: errors,
    );
  }

  void _invalidateCatalogCache() {
    _catalogCache = null;
    _catalogCachedAt = null;
  }

  /// Export/import helpers make repository and install configuration portable.
  Future<String> exportConfiguration() async => jsonEncode(<String, dynamic>{
    'schemaVersion': 3,
    'repositories': await repositoryUrls(),
    'installedSources': (await installedSourceKeys()).toList(),
    'disabledDefaultSources': (await disabledDefaultSourceKeys()).toList(),
    'repositoryPins': await _storedStringMap(_repositoryPinsKey),
  });

  Future<void> importConfiguration(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['repositories'] is! List) {
      throw const FormatException('Invalid source repository configuration.');
    }
    final normalized = <String>{};
    for (final value in decoded['repositories'] as List) {
      if (value is! String) continue;
      normalized.add(SourceRepositoryClient.normalizeRepositoryUrl(value));
    }
    final installed = _stringSet(decoded['installedSources']);
    final disabledDefaults = _stringSet(decoded['disabledDefaultSources']);
    final rawPins = decoded['repositoryPins'];
    final pins = <String, String>{};
    if (rawPins is Map) {
      for (final entry in rawPins.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final value = (entry.value as String).trim().toLowerCase();
        if (RegExp(r'^[a-f0-9]{40}$').hasMatch(value)) {
          pins[entry.key as String] = value;
        }
      }
    }
    final preferences = await _prefs;
    await preferences.setStringList(
      _repositoriesKey,
      normalized.toList(growable: false),
    );
    await preferences.setStringList(
      _installedSourcesKey,
      installed.toList(growable: false),
    );
    await preferences.setStringList(
      _disabledDefaultsKey,
      disabledDefaults.toList(growable: false),
    );
    await preferences.setString(_repositoryPinsKey, jsonEncode(pins));
    await preferences.remove(_repositoryRollbackKey);
    _invalidateCatalogCache();
  }

  Set<String> _stringSet(dynamic value) {
    if (value is! List) return <String>{};
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }
}
