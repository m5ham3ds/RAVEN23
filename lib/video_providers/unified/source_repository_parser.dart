import 'dart:convert';

import 'source_manifest.dart';
import 'vidking_audio_quality_normalizer.dart';
import 'quickjs_source_catalog_profile.dart';

/// Tolerant parser for declarative source repositories.
///
/// Accepted shapes:
/// - OpenStream-style `{ manifestVersion, extensions: [...] }`;
/// - Zangetsu-style `{ name, description, sources: [...] }` JavaScript repos;
/// - a raw array of extension entries;
/// - `{ extensions: [...] }` linked-list documents;
/// - a plain Stremio add-on `manifest.json`.
///
/// Invalid individual entries are skipped so one bad extension does not hide
/// the rest of a repository.
class SourceRepositoryParser {
  const SourceRepositoryParser();

  SourceRepositoryManifest parseRepository(
    String raw, {
    required String sourceUrl,
  }) {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return SourceRepositoryManifest(
        url: sourceUrl,
        name: _repositoryName(sourceUrl),
        extensions: _parseEntries(decoded, sourceUrl),
      );
    }
    if (decoded is! Map) {
      throw const FormatException(
        'A source repository must be a JSON object or array.',
      );
    }

    final root = Map<String, dynamic>.from(decoded);
    if (_isStremioManifest(root)) {
      return _parseStremioManifest(root, sourceUrl);
    }

    final entries = root['extensions'];
    final extensionLists = root['extensionLists'];
    final parsedExtensions = _parseEntries(
      entries is List ? entries : const [],
      sourceUrl,
    );
    final parsedJsSources = _parseZangetsuSources(
      root['sources'] is List ? root['sources'] as List : const <dynamic>[],
      sourceUrl,
    );
    final combined = <SourceManifest>[];
    final seen = <String>{};
    for (final source in <SourceManifest>[
      ...parsedExtensions,
      ...parsedJsSources,
    ]) {
      if (seen.add(source.id)) combined.add(source);
    }
    return SourceRepositoryManifest(
      url: sourceUrl,
      name: _text(root['name']) ?? _repositoryName(sourceUrl),
      description: _text(root['description']) ?? '',
      website: _text(root['website']),
      iconUrl: _text(root['iconUrl']),
      extensions: combined,
      extensionLists: extensionLists is List
          ? extensionLists
                .map(_text)
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }

  List<SourceManifest> parseExtensionList(
    String raw, {
    required String repositoryUrl,
  }) {
    final decoded = jsonDecode(raw);
    final entries = decoded is List
        ? decoded
        : decoded is Map && decoded['extensions'] is List
        ? decoded['extensions'] as List
        : const <dynamic>[];
    return _parseEntries(entries, repositoryUrl);
  }

  List<SourceManifest> _parseEntries(
    List<dynamic> entries,
    String repositoryUrl,
  ) {
    final parsed = <SourceManifest>[];
    final seen = <String>{};
    for (final rawEntry in entries) {
      if (rawEntry is! Map) continue;
      final entry = Map<String, dynamic>.from(rawEntry);
      final id = _text(entry['id']);
      final name = _text(entry['name']);
      final rawEngine = entry['engine'];
      if (id == null || name == null || rawEngine is! Map) continue;
      if (!seen.add(id)) continue;

      final engineMap = Map<String, dynamic>.from(rawEngine);
      final rawType = _text(engineMap['type']) ?? '';
      final engineKind = sourceEngineKindFrom(rawType);
      final endpoint = _text(engineMap['endpoint']) ?? '';
      final movieUrl = _text(engineMap['movieUrl']);
      final tvUrl = _text(engineMap['tvUrl']);
      final isValidEngine = switch (engineKind) {
        SourceEngineKind.stremio => _isHttpEndpoint(endpoint),
        SourceEngineKind.vidkingDirect => _isVidkingRoute(endpoint),
        SourceEngineKind.vidkingWebView => true,
        SourceEngineKind.webEmbed =>
          _isHttpsTemplate(movieUrl ?? '') || _isHttpsTemplate(tvUrl ?? ''),
        SourceEngineKind.animeSite => _isHttpsEndpoint(endpoint),
        SourceEngineKind.javascript => _isHttpEndpoint(endpoint),
        _ => false,
      };
      final resolvedEngineKind = isValidEngine
          ? engineKind
          : SourceEngineKind.unsupported;
      final config = Map<String, dynamic>.from(engineMap)
        ..['languageDeclared'] =
            _text(engineMap['language']) != null ||
            _text(entry['language']) != null
        ..['statusDeclared'] =
            entry.containsKey('status') &&
            _integer(entry['status'], fallback: -1) >= 0 &&
            _integer(entry['status'], fallback: -1) <= 3
        ..remove('type')
        ..remove('endpoint')
        ..remove('priority')
        ..remove('language')
        ..remove('audioLanguage')
        ..remove('qualityFilter')
        ..remove('movieUrl')
        ..remove('tvUrl');
      final parsedEngine = SourceEngineDescriptor(
        rawType: rawType,
        kind: resolvedEngineKind,
        endpoint: endpoint,
        priority: _integer(engineMap['priority'], fallback: 50),
        language: _text(engineMap['language']),
        audioLanguage: _text(engineMap['audioLanguage']),
        qualityFilter: _text(engineMap['qualityFilter']),
        movieUrl: movieUrl,
        tvUrl: tvUrl,
        config: config,
      );
      final normalizedEngine =
          VidkingAudioQualityNormalizer.normalizeDescriptor(parsedEngine);
      parsed.add(
        SourceManifest(
          id: id,
          name: name,
          description: _text(entry['description']) ?? '',
          version: _text(entry['version']) ?? '1.0.0',
          versionCode: _integer(entry['versionCode'], fallback: 1),
          apiVersion: _integer(entry['apiVersion'], fallback: 1),
          language: _text(entry['language']) ?? 'Multi',
          authors: _stringList(entry['authors']),
          tags: _stringList(
            entry['tags'],
          ).map((tag) => tag.toLowerCase()).toList(growable: false),
          homepage: _text(entry['homepage']),
          iconUrl: _text(entry['iconUrl']),
          repositoryUrl: repositoryUrl,
          enabled: entry['enabled'] != false,
          installedByDefault: entry['installedByDefault'] == true,
          isFallback:
              entry['fallback'] == true ||
              _stringList(
                entry['tags'],
              ).any((tag) => tag.trim().toLowerCase() == 'fallback') ||
              engineKind == SourceEngineKind.vidkingWebView,
          isNsfw: entry['nsfw'] == true,
          declaredNsfw: entry['nsfw'] is bool ? entry['nsfw'] as bool : null,
          status: _integer(entry['status'], fallback: 1).clamp(0, 3).toInt(),
          updatedAt: _dateTime(entry['updatedAt']),
          engine: normalizedEngine,
        ),
      );
    }
    return parsed;
  }

  List<SourceManifest> _parseZangetsuSources(
    List<dynamic> entries,
    String repositoryUrl,
  ) {
    final parsed = <SourceManifest>[];
    final seen = <String>{};
    for (final rawEntry in entries) {
      if (rawEntry is! Map) continue;
      final entry = Map<String, dynamic>.from(rawEntry);
      final id = _text(entry['id']);
      final name = _text(entry['name']);
      final file = _text(entry['file']);
      if (id == null || name == null || file == null || !seen.add(id)) {
        continue;
      }
      final resolvedFile = Uri.tryParse(file);
      final scriptUrl =
          resolvedFile != null &&
              (resolvedFile.scheme == 'https' ||
                  resolvedFile.scheme == 'http') &&
              resolvedFile.host.isNotEmpty &&
              resolvedFile.userInfo.isEmpty
          ? resolvedFile.toString()
          : Uri.parse(repositoryUrl).resolve(file).toString();
      final validScriptUrl =
          _isHttpEndpoint(scriptUrl) &&
          (scriptUrl.toLowerCase().split('?').first.endsWith('.js') ||
              scriptUrl.toLowerCase().split('?').first.endsWith('.mjs'));
      final logoValue = _text(entry['logo']);
      final logoUrl = logoValue == null
          ? null
          : _resolveRepositoryAsset(repositoryUrl, logoValue);
      final language = _text(entry['lang']) ?? 'Multi';
      final providerType = (_text(entry['type']) ?? 'all').toLowerCase();
      final declaredTags = _stringList(entry['tags'])
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty)
          .toSet();
      final profile = QuickJsSourceCatalogProfile.classify(
        repositoryUrl: repositoryUrl,
        sourceId: id,
      );

      parsed.add(
        SourceManifest(
          id: id,
          name: name,
          description:
              _text(entry['description']) ??
              'JavaScript provider from a Zangetsu-compatible repository.',
          version: _text(entry['version']) ?? '1.0.0',
          language: language,
          authors: _stringList(entry['authors']),
          tags: <String>{
            'javascript',
            if (providerType != 'all') providerType,
            if (profile.seriesCapabilityVerified) 'series',
            if (_boolean(entry['nsfw'])) 'nsfw',
            if (profile.requiresLiveTvAdapter) 'live-only',
            if (profile.catalogRole == 'archive-vod') 'archive-vod',
            ...declaredTags,
          }.toList(growable: false),
          homepage: _text(entry['homepage']),
          iconUrl: logoUrl,
          repositoryUrl: repositoryUrl,
          enabled: validScriptUrl,
          installedByDefault: false,
          isFallback:
              entry['fallback'] == true || declaredTags.contains('fallback'),
          isNsfw: entry['nsfw'] == true,
          declaredNsfw: entry['nsfw'] is bool ? entry['nsfw'] as bool : null,
          status: _integer(entry['status'], fallback: 1).clamp(0, 3).toInt(),
          updatedAt: _dateTime(entry['updatedAt']),
          engine: SourceEngineDescriptor(
            rawType: 'javascript',
            kind: validScriptUrl
                ? SourceEngineKind.javascript
                : SourceEngineKind.unsupported,
            endpoint: validScriptUrl ? scriptUrl : '',
            priority: _integer(entry['priority'], fallback: 50),
            language: language,
            config: <String, dynamic>{
              'providerType': providerType,
              'version': _text(entry['version']) ?? '1.0.0',
              'sourceFile': file,
              'runtimeContract': 'zangetsu-js-v1',
              'statusDeclared':
                  entry.containsKey('status') &&
                  _integer(entry['status'], fallback: -1) >= 0 &&
                  _integer(entry['status'], fallback: -1) <= 3,
              'languageDeclared': _text(entry['lang']) != null,
              'catalogRole': profile.catalogRole,
              'requiresLiveTvAdapter': profile.requiresLiveTvAdapter,
              'requiresCredentialReview': profile.requiresCredentialReview,
              'seriesCapabilityReview': profile.seriesCapabilityReview,
              'seriesCapabilityVerified': profile.seriesCapabilityVerified,
            },
          ),
        ),
      );
    }
    return parsed;
  }

  String _resolveRepositoryAsset(String repositoryUrl, String path) {
    final supplied = Uri.tryParse(path);
    if (supplied != null &&
        (supplied.scheme == 'https' || supplied.scheme == 'http') &&
        supplied.host.isNotEmpty &&
        supplied.userInfo.isEmpty) {
      return supplied.toString();
    }
    return Uri.parse(repositoryUrl).resolve(path).toString();
  }

  static bool _boolean(dynamic value) => value == true || value == 1;

  bool _isHttpEndpoint(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool _isHttpsEndpoint(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool _isHttpsTemplate(String value) {
    final normalized = value.replaceAll(
      RegExp(r'\{[A-Za-z][A-Za-z0-9]*\}'),
      'placeholder',
    );
    return _isHttpsEndpoint(normalized);
  }

  bool _isVidkingRoute(String value) {
    final route = value.trim().replaceAll('\\', '/');
    final uri = Uri.tryParse(route);
    return route.isNotEmpty &&
        uri != null &&
        !uri.hasScheme &&
        !uri.hasAuthority &&
        !route.startsWith('/') &&
        uri.pathSegments.isNotEmpty &&
        !uri.pathSegments.any((segment) => segment == '.' || segment == '..');
  }

  bool _isStremioManifest(Map<String, dynamic> root) {
    if (!root.containsKey('id')) return false;
    const stremioFields = <String>{
      'resources',
      'types',
      'idPrefixes',
      'catalogs',
      'behaviorHints',
      'config',
    };
    return stremioFields.any((field) => root.containsKey(field));
  }

  SourceRepositoryManifest _parseStremioManifest(
    Map<String, dynamic> root,
    String sourceUrl,
  ) {
    final addonId = _text(root['id']);
    if (addonId == null) {
      throw const FormatException('Stremio manifest is missing its id.');
    }

    final rawResources = root['resources'];
    if (rawResources is! List || rawResources.isEmpty) {
      throw const FormatException(
        'Stremio manifest must declare at least one resource.',
      );
    }
    if (rawResources.length > 64) {
      throw const FormatException(
        'Stremio manifest declares too many resources.',
      );
    }

    if (root.containsKey('types') && root['types'] is! List) {
      throw const FormatException('Stremio manifest types must be an array.');
    }
    if (root.containsKey('idPrefixes') && root['idPrefixes'] is! List) {
      throw const FormatException(
        'Stremio manifest idPrefixes must be an array when provided.',
      );
    }
    final rootTypes = _stremioTokens(root['types'], maxItems: 64);
    final hasRootPrefixes = root['idPrefixes'] is List;
    final rootPrefixes = _stremioTokens(
      root['idPrefixes'],
      maxItems: 64,
      maxLength: 128,
      lowercase: false,
    );
    final normalizedResources = <dynamic>[];
    final streamProfiles = <Map<String, dynamic>>[];

    for (final rawResource in rawResources) {
      if (rawResource is String) {
        final name = rawResource.trim();
        if (name.isEmpty || name.length > 64) continue;
        normalizedResources.add(name);
        if (name.toLowerCase() == 'stream') {
          // The manifest specification makes idPrefixes optional. When it is
          // omitted, the resource accepts all IDs; do not silently narrow it
          // to IMDb-only identifiers.
          streamProfiles.add(<String, dynamic>{
            'types': rootTypes,
            'prefixMode': !hasRootPrefixes || rootPrefixes.isEmpty
                ? 'any'
                : 'explicit',
            if (hasRootPrefixes) 'idPrefixes': rootPrefixes,
          });
        }
        continue;
      }

      if (rawResource is! Map) continue;
      final resource = Map<String, dynamic>.from(rawResource);
      final name = _text(resource['name']);
      if (name == null || name.length > 64) continue;
      if (resource.containsKey('types') && resource['types'] is! List) {
        continue;
      }
      if (resource.containsKey('idPrefixes') &&
          resource['idPrefixes'] is! List) {
        continue;
      }
      final resourceTypes = resource['types'] is List
          ? _stremioTokens(resource['types'], maxItems: 64)
          : rootTypes;
      final hasResourcePrefixes = resource['idPrefixes'] is List;
      final resourcePrefixes = _stremioTokens(
        resource['idPrefixes'],
        maxItems: 64,
        maxLength: 128,
        lowercase: false,
      );
      normalizedResources.add(<String, dynamic>{
        'name': name,
        if (resourceTypes.isNotEmpty) 'types': resourceTypes,
        if (hasResourcePrefixes) 'idPrefixes': resourcePrefixes,
      });
      if (name.toLowerCase() == 'stream') {
        // Object resources define their own filtering scope. An omitted or
        // empty idPrefixes on an object means that this resource accepts any
        // explicitly available identifier; it does not inherit root filters.
        streamProfiles.add(<String, dynamic>{
          'types': resourceTypes,
          'prefixMode': !hasResourcePrefixes || resourcePrefixes.isEmpty
              ? 'any'
              : 'explicit',
          if (hasResourcePrefixes) 'idPrefixes': resourcePrefixes,
        });
      }
    }

    final streamTypes = <String>{
      for (final profile in streamProfiles)
        ...(profile['types'] as List<String>),
    }.toList(growable: false);
    final supportsPlayableType = streamProfiles.any((profile) {
      final profileTypes = profile['types'] as List<String>;
      return profileTypes.contains('movie') || profileTypes.contains('series');
    });
    final legacyPrefixes = hasRootPrefixes
        ? rootPrefixes
        : <String>{
            for (final profile in streamProfiles)
              if (profile['prefixMode'] == 'explicit' &&
                  profile['idPrefixes'] is List)
                ...(profile['idPrefixes'] as List<String>),
          }.toList(growable: false);
    final supportsStreams = streamProfiles.isNotEmpty;
    final baseUrl = _stremioBaseUrl(sourceUrl);

    final rawCatalogs = root['catalogs'];
    if (root.containsKey('catalogs') && rawCatalogs is! List) {
      throw const FormatException(
        'Stremio manifest catalogs must be an array.',
      );
    }
    final catalogs = _parseStremioCatalogs(rawCatalogs);
    if (root.containsKey('behaviorHints') && root['behaviorHints'] is! Map) {
      throw const FormatException(
        'Stremio manifest behaviorHints must be an object when provided.',
      );
    }
    final behaviorHints = root['behaviorHints'] is Map
        ? Map<String, dynamic>.from(root['behaviorHints'] as Map)
        : const <String, dynamic>{};
    for (final key in const <String>['configurable', 'configurationRequired']) {
      if (behaviorHints.containsKey(key) && behaviorHints[key] is! bool) {
        throw FormatException('Stremio behaviorHints.$key must be a boolean.');
      }
    }
    final configurable = behaviorHints['configurable'] == true;
    final configurationRequired =
        behaviorHints['configurationRequired'] == true;
    final configurationSchema = _parseStremioConfig(root['config']);
    final configurationUrl =
        (configurable || configurationRequired) && baseUrl != null
        ? _stremioConfigurationUrl(baseUrl)
        : null;
    final playable = supportsStreams && supportsPlayableType && baseUrl != null;

    final manifest = SourceManifest(
      id: addonId,
      name: _text(root['name']) ?? addonId,
      description: _text(root['description']) ?? '',
      version: _text(root['version']) ?? '1.0.0',
      language: 'Multi',
      authors: <String>[
        _hostOf(sourceUrl),
      ].where((value) => value.isNotEmpty).toList(growable: false),
      tags: <String>[
        'stremio',
        'addon',
        if (streamTypes.contains('movie')) 'movies',
        if (streamTypes.contains('series')) 'series',
      ],
      homepage: _text(root['homepage']),
      iconUrl: _text(root['logo']),
      repositoryUrl: sourceUrl,
      enabled: playable,
      // A direct manifest URL was explicitly added by the user. Treat it as
      // installed by default, unlike entries merely discovered in a catalog.
      installedByDefault: true,
      engine: SourceEngineDescriptor(
        rawType: 'stremio',
        kind: playable
            ? SourceEngineKind.stremio
            : SourceEngineKind.unsupported,
        endpoint: baseUrl ?? sourceUrl,
        priority: 40,
        config: <String, dynamic>{
          if (streamTypes.isNotEmpty) 'types': streamTypes,
          if (hasRootPrefixes || legacyPrefixes.isNotEmpty)
            'idPrefixes': legacyPrefixes,
          'streamResourceProfiles': streamProfiles,
          'resources': normalizedResources,
          'catalogs': catalogs,
          'configurable': configurable,
          'configurationRequired': configurationRequired,
          'needsConfiguration': configurationRequired,
          'configurationSchema': configurationSchema,
          if (configurationUrl != null) 'configurationUrl': configurationUrl,
        },
      ),
    );

    return SourceRepositoryManifest(
      url: sourceUrl,
      name: manifest.name,
      description: manifest.description,
      website: manifest.homepage,
      iconUrl: manifest.iconUrl,
      extensions: <SourceManifest>[manifest],
      isStremioAddon: true,
    );
  }

  List<Map<String, dynamic>> _parseStremioConfig(dynamic rawConfig) {
    if (rawConfig == null) return const <Map<String, dynamic>>[];
    if (rawConfig is! List) {
      throw const FormatException('Stremio manifest config must be an array.');
    }
    if (rawConfig.length > 64) {
      throw const FormatException(
        'Stremio manifest declares too many config fields.',
      );
    }

    const supportedTypes = <String>{
      'text',
      'number',
      'password',
      'checkbox',
      'select',
    };
    const requiredTypes = <String>{'text', 'number', 'password'};
    final parsed = <Map<String, dynamic>>[];
    final seenKeys = <String>{};
    for (final rawField in rawConfig) {
      if (rawField is! Map) continue;
      final field = Map<String, dynamic>.from(rawField);
      final key = _text(field['key']);
      final type = _text(field['type'])?.toLowerCase();
      if (key == null ||
          key.length > 128 ||
          type == null ||
          !supportedTypes.contains(type) ||
          !seenKeys.add(key)) {
        continue;
      }

      final title = _text(field['title']);
      final rawDefault = field['default'];
      final defaultValue = rawDefault is String && rawDefault.length <= 512
          ? rawDefault
          : null;
      final options = type == 'select'
          ? _boundedStremioStrings(
              field['options'],
              maxItems: 100,
              maxLength: 128,
            )
          : const <String>[];
      if (type == 'select' && options.isEmpty) continue;
      if (field.containsKey('required') && field['required'] is! bool) {
        continue;
      }

      parsed.add(<String, dynamic>{
        'key': key,
        'type': type,
        'title': title != null && title.length <= 128 ? title : key,
        'required': requiredTypes.contains(type) && field['required'] == true,
        if (type == 'select') 'options': options,
        // A password default is not useful to RAVEN23's external configure
        // flow and should not be persisted in its local source descriptor.
        if (type != 'password' && defaultValue != null) 'default': defaultValue,
      });
    }
    return parsed;
  }

  List<Map<String, dynamic>> _parseStremioCatalogs(dynamic rawCatalogs) {
    if (rawCatalogs is! List) return const <Map<String, dynamic>>[];
    if (rawCatalogs.length > 128) {
      throw const FormatException(
        'Stremio manifest declares too many catalogs.',
      );
    }
    final parsed = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final rawCatalog in rawCatalogs) {
      if (rawCatalog is! Map) continue;
      final catalog = Map<String, dynamic>.from(rawCatalog);
      final type = _text(catalog['type'])?.toLowerCase();
      final id = _text(catalog['id']);
      final name = _text(catalog['name']);
      if (type == null ||
          id == null ||
          name == null ||
          type.length > 32 ||
          id.length > 128 ||
          name.length > 128) {
        continue;
      }
      if (!seen.add('$type::$id')) continue;
      final rawExtra = catalog['extra'];
      final extra = <Map<String, dynamic>>[];
      if (rawExtra is List) {
        for (final rawField in rawExtra.take(32)) {
          if (rawField is! Map) continue;
          final field = Map<String, dynamic>.from(rawField);
          final fieldName = _text(field['name']);
          if (fieldName == null || fieldName.length > 64) continue;
          final options = _boundedStremioStrings(
            field['options'],
            maxItems: 100,
            maxLength: 128,
          );
          extra.add(<String, dynamic>{
            'name': fieldName,
            'isRequired': field['isRequired'] == true,
            if (options.isNotEmpty) 'options': options,
            if (field['optionsLimit'] is num)
              'optionsLimit': (field['optionsLimit'] as num)
                  .toInt()
                  .clamp(0, 100)
                  .toInt(),
          });
        }
      }
      parsed.add(<String, dynamic>{
        'type': type,
        'id': id,
        'name': name,
        if (extra.isNotEmpty) 'extra': extra,
      });
    }
    return parsed;
  }

  static List<String> _boundedStremioStrings(
    dynamic raw, {
    required int maxItems,
    required int maxLength,
  }) {
    if (raw is! List) return const <String>[];
    final values = <String>[];
    final seen = <String>{};
    for (final value in raw.take(maxItems)) {
      if (value is! String) continue;
      final item = value.trim();
      if (item.isEmpty || item.length > maxLength || !seen.add(item)) {
        continue;
      }
      values.add(item);
    }
    return values;
  }

  static List<String> _stremioTokens(
    dynamic raw, {
    required int maxItems,
    int maxLength = 64,
    bool lowercase = true,
  }) {
    if (raw is! List) return const <String>[];
    final tokens = <String>[];
    final seen = <String>{};
    for (final value in raw.take(maxItems)) {
      if (value is! String) continue;
      final token = value.trim();
      if (token.isEmpty || token.length > maxLength) continue;
      final normalized = lowercase ? token.toLowerCase() : token;
      if (seen.add(normalized)) tokens.add(normalized);
    }
    return tokens;
  }

  String? _stremioBaseUrl(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    var path = uri.path;
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('/manifest.json')) {
      path = path.substring(0, path.length - '/manifest.json'.length);
    } else if (lowerPath == 'manifest.json') {
      path = '';
    }
    // Keep configured path/query data because add-ons commonly encode their
    // per-user configuration in the manifest URL. Fragments are not sent over
    // HTTP and must not become part of the runtime endpoint. An explicitly
    // empty query marker is also discarded; Uri serialization otherwise keeps
    // a trailing '?' even when no query parameters exist.
    final baseUri = uri
        .replace(path: path.replaceFirst(RegExp(r'/+$'), ''))
        .removeFragment();
    final baseUrl = baseUri.toString();
    if (baseUri.hasQuery && baseUri.query.isEmpty && baseUrl.endsWith('?')) {
      return baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  String _stremioConfigurationUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return '';
    // The Stremio add-on convention exposes its setup page at /configure.
    // Preserve a base-path deployment while ensuring that private manifest
    // query parameters (often account credentials) are never sent to the
    // browser configuration route.
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    segments.add('configure');
    // Build the browser URL from the origin and path only. Passing query: ''
    // to Uri.replace creates an empty query component and serializes as a
    // trailing '?', which breaks canonical URLs and may leak URL shape details.
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: segments,
    ).toString();
  }

  String _hostOf(String url) => Uri.tryParse(url)?.host ?? '';

  String _repositoryName(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'Source repository';
    return uri.host.isEmpty ? 'Source repository' : uri.host;
  }

  static String? _text(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _integer(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map(_text)
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is num) {
      final millis = value > 1000000000000
          ? value.toInt()
          : (value * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
