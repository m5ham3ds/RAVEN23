import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'media_identity.dart';
import 'source_manifest.dart';

/// Repository identity is deliberately separate from the legacy source key.
/// [SourceManifest.stableKey] remains unchanged because it is persisted by
/// existing installations and stream attribution.
class SourceRepositoryIdentity {
  const SourceRepositoryIdentity._(this.key, this._originalUrl);

  factory SourceRepositoryIdentity.fromUrl(String? value) {
    final original = value;
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return SourceRepositoryIdentity._('local', original);
    }

    final uri = Uri.tryParse(raw);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      // Preserve opaque/legacy identifiers instead of silently rewriting
      // persisted keys. Validation belongs to SourceRepositoryClient.
      return SourceRepositoryIdentity._(raw, original);
    }

    // URL credentials and query parameters can contain access tokens. Keep
    // them out of the comparable key while retaining a one-way fingerprint so
    // distinct authenticated repository URLs do not collapse to one identity.
    final hasPrivateMaterial = uri.userInfo.isNotEmpty || uri.hasQuery;
    final privateMaterial = jsonEncode(<String>[uri.userInfo, uri.query]);
    final identityUri = uri.replace(
      userInfo: uri.userInfo.isEmpty ? null : '',
      query: uri.hasQuery ? '' : null,
      fragment: uri.hasFragment ? '' : null,
    );
    final normalizedUri = identityUri
        .replace(
          scheme: identityUri.scheme.toLowerCase(),
          host: identityUri.host.toLowerCase(),
        )
        .normalizePath()
        .toString();
    final privateFingerprint = hasPrivateMaterial
        ? sha256.convert(utf8.encode(privateMaterial)).toString()
        : '';
    final normalized = privateFingerprint.isEmpty
        ? normalizedUri
        : '$normalizedUri::private=$privateFingerprint';
    return SourceRepositoryIdentity._(normalized, original);
  }

  /// Canonical comparison key. Private URL components are represented by a
  /// one-way fingerprint and never used to rewrite persisted legacy keys.
  final String key;
  // Kept private because this value may contain private query material.
  final String? _originalUrl;
}

/// Source identity is stable within a repository and independent from its
/// runtime engine or the media item currently being resolved.
class SourceIdentity {
  const SourceIdentity({required this.repository, required this.sourceId});

  final SourceRepositoryIdentity repository;
  final String sourceId;

  String get key => '${repository.key}::$sourceId';

  /// Existing installation/preferences key. Keep this byte-for-byte aligned
  /// with SourceManifest.stableKey until a dedicated migration phase exists.
  String get legacyStableKey =>
      '${repository._originalUrl ?? 'local'}::$sourceId';

  @override
  bool operator ==(Object other) =>
      other is SourceIdentity &&
      other.repository.key == repository.key &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(repository.key, sourceId);
}

/// Engine identity is separate from source identity because multiple sources
/// may run through one engine and one source may change engine on a later
/// manifest revision.
class SourceEngineIdentity {
  const SourceEngineIdentity({required this.kind, required this.rawType});

  final SourceEngineKind kind;
  final String rawType;

  /// Engine adapter identity is independent of a per-source endpoint. This
  /// prevents signed endpoint/query values from entering diagnostics.
  String get key {
    final candidate = rawType.trim().toLowerCase();
    final safeType = RegExp(r'^[a-z0-9._-]{1,48}$').hasMatch(candidate)
        ? candidate
        : 'custom';
    return '${kind.name}::$safeType';
  }
}

/// Content identity is local metadata, never a signed stream URL. It wraps the
/// existing playback cache identity while preserving external identifiers.
class SourceContentIdentity {
  const SourceContentIdentity({
    required this.type,
    required this.title,
    required this.year,
    required this.tmdbId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTmdbId,
    required this.externalIds,
    required this.isAnimeContent,
    required this.classification,
  });

  factory SourceContentIdentity.fromMedia(MediaIdentity media) {
    final externalIds = Map<String, String>.from(media.externalIds);
    return SourceContentIdentity(
      type: media.normalizedType,
      title: media.normalizedTitle,
      year: media.year,
      tmdbId: media.tmdbId,
      seasonNumber: media.seasonNumber,
      episodeNumber: media.episodeNumber,
      episodeTmdbId: media.episodeTmdbId,
      externalIds: Map<String, String>.unmodifiable(externalIds),
      isAnimeContent: media.isAnimeContent,
      classification: media.normalizedClassification,
    );
  }

  final UnifiedMediaType type;
  final String title;
  final int? year;
  final int? tmdbId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? episodeTmdbId;
  final Map<String, String> externalIds;
  final bool isAnimeContent;
  final MediaContentClassification classification;

  String get key {
    final ids = externalIds.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <String>[
      type.name,
      tmdbId?.toString() ?? title,
      year?.toString() ?? '-',
      seasonNumber?.toString() ?? '-',
      episodeNumber?.toString() ?? '-',
      episodeTmdbId?.toString() ?? '-',
      classification.name,
      ids.map((entry) => '${entry.key}=${entry.value}').join('&'),
    ].join('::');
  }
}

/// Normalized capabilities declared by a source manifest. These are claims
/// from metadata, not proof that a source has passed runtime/playback tests.
enum SourceCapability {
  movie,
  series,
  anime,
  liveTv,
  subtitles,
  multipleAudio,
  universal,
}

class SourceCapabilityProfile {
  SourceCapabilityProfile({
    required Set<SourceCapability> declared,
    required this.isExplicit,
  }) : declared = Set<SourceCapability>.unmodifiable(declared);

  final Set<SourceCapability> declared;
  final bool isExplicit;

  bool get isUniversal => declared.contains(SourceCapability.universal);

  bool get hasContentCapabilities => declared.any(
    const <SourceCapability>{
      SourceCapability.movie,
      SourceCapability.series,
      SourceCapability.anime,
      SourceCapability.universal,
    }.contains,
  );

  /// Media capability declarations are retained for diagnostics only.
  /// A provider is considered VOD-eligible unless its declarations identify
  /// it exclusively as a Live TV adapter. Movie/series/anime labels never
  /// prevent a user-selected source from being attempted.
  bool supportsMedia(MediaIdentity _) =>
      !declared.contains(SourceCapability.liveTv) || hasContentCapabilities;

  factory SourceCapabilityProfile.fromManifest(SourceManifest source) {
    final values = <String>{...source.tags.map(_normalizeCapability)}
      ..remove('');

    final providerType = _normalizeCapability(
      source.engine.config['providerType']?.toString() ?? '',
    );
    if (providerType.isNotEmpty) {
      values.add(providerType);
    }

    final capabilities = <SourceCapability>{};
    for (final value in values) {
      switch (value) {
        case 'movie':
        case 'movies':
        case 'film':
        case 'films':
          capabilities.add(SourceCapability.movie);
          break;
        case 'series':
        case 'shows':
        case 'show':
        case 'tv':
          capabilities.add(SourceCapability.series);
          break;
        case 'anime':
        case 'anime-only':
        case 'donghua':
          capabilities.add(SourceCapability.anime);
          break;
        case 'live-tv':
        case 'livetv':
        case 'iptv':
          capabilities.add(SourceCapability.liveTv);
          break;
        case 'subtitle':
        case 'subtitles':
          capabilities.add(SourceCapability.subtitles);
          break;
        case 'multi-audio':
        case 'multiple-audio':
          capabilities.add(SourceCapability.multipleAudio);
          break;
        case 'all':
        case 'multi':
        case 'multi-content':
        case 'universal':
          capabilities.add(SourceCapability.universal);
          break;
        case 'movies-and-series':
          capabilities
            ..add(SourceCapability.movie)
            ..add(SourceCapability.series);
          break;
      }
    }

    if (source.engine.kind == SourceEngineKind.animeSite) {
      capabilities.add(SourceCapability.anime);
    }

    return SourceCapabilityProfile(
      declared: capabilities,
      isExplicit: capabilities.isNotEmpty,
    );
  }
}

String _normalizeCapability(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('_', '-')
    .replaceAll(' ', '-')
    .replaceAll(RegExp(r'-+'), '-');

/// Lifecycle flags are orthogonal: a source can be installed, enabled and
/// experimental at the same time. This avoids collapsing independent facts
/// into a single status enum.
enum SourceLifecycleFlag {
  discovered,
  validated,
  installed,
  enabled,
  disabled,
  experimental,
  incompatible,
  failed,
  duplicate,
}

class SourceLifecycleSnapshot {
  SourceLifecycleSnapshot({
    required Set<SourceLifecycleFlag> flags,
    this.validationMessage,
    this.failureMessage,
  }) : flags = Set<SourceLifecycleFlag>.unmodifiable(flags);

  final Set<SourceLifecycleFlag> flags;
  final String? validationMessage;
  final String? failureMessage;

  bool has(SourceLifecycleFlag flag) => flags.contains(flag);

  factory SourceLifecycleSnapshot.fromManifest(
    SourceManifest source, {
    required bool installed,
    bool? enabled,
    bool validated = false,
    bool duplicate = false,
    String? validationMessage,
    String? failureMessage,
  }) {
    final effectiveEnabled = enabled ?? source.enabled;
    final values = <SourceLifecycleFlag>{SourceLifecycleFlag.discovered};

    if (validated && validationMessage == null) {
      values.add(SourceLifecycleFlag.validated);
    }
    if (installed) {
      values.add(SourceLifecycleFlag.installed);
    }
    if (installed && effectiveEnabled && source.isRunnable) {
      values.add(SourceLifecycleFlag.enabled);
    }
    if (!effectiveEnabled) {
      values.add(SourceLifecycleFlag.disabled);
    }
    if (source.status == 3) {
      values.add(SourceLifecycleFlag.experimental);
    }
    if (source.engine.kind == SourceEngineKind.unsupported ||
        validationMessage != null) {
      values.add(SourceLifecycleFlag.incompatible);
    }
    if (failureMessage != null && failureMessage.trim().isNotEmpty) {
      values.add(SourceLifecycleFlag.failed);
    }
    if (duplicate) {
      values.add(SourceLifecycleFlag.duplicate);
    }

    return SourceLifecycleSnapshot(
      flags: values,
      validationMessage: validationMessage,
      failureMessage: failureMessage,
    );
  }
}

extension SourceRepositoryManifestContracts on SourceRepositoryManifest {
  SourceRepositoryIdentity get identity =>
      SourceRepositoryIdentity.fromUrl(url);
}

extension SourceManifestContracts on SourceManifest {
  SourceRepositoryIdentity get repositoryIdentity =>
      SourceRepositoryIdentity.fromUrl(repositoryUrl);

  SourceIdentity get sourceIdentity =>
      SourceIdentity(repository: repositoryIdentity, sourceId: id);

  SourceEngineIdentity get engineIdentity =>
      SourceEngineIdentity(kind: engine.kind, rawType: engine.rawType);

  SourceCapabilityProfile get capabilityProfile =>
      SourceCapabilityProfile.fromManifest(this);
}
