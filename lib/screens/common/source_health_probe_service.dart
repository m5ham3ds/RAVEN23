import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../manga/mihon/mihon_runtime.dart';
import '../../video_providers/unified/quickjs/quickjs_provider_runtime.dart';
import '../../video_providers/unified/quickjs/quickjs_stream_mapper.dart';
import '../../video_providers/unified/source_host_policy.dart';
import '../../video_providers/unified/source_manifest.dart';
import '../../video_providers/unified/stream_option.dart';

/// The result describes what the probe actually proved. `reachable` is used
/// when an engine exposes no content-independent search operation; it must not
/// be presented as a successful stream extraction.
enum SourceHealthStatus {
  checking,
  healthy,
  reachable,
  attention,
  failed,
  unsupported,
}

enum SourceHealthReason {
  searchResponded,
  streamsExtracted,
  streamExtractionFailed,
  endpointResponded,
  apiRequiresMedia,
  cloudflare,
  configurationRequired,
  networkUnavailable,
  dnsFailure,
  timeout,
  tlsFailure,
  unauthorized,
  forbidden,
  rateLimited,
  pathNotFound,
  serverError,
  invalidResponse,
  invalidEndpoint,
  sourceMissing,
  extensionFailure,
  unsupportedEngine,
  unknown,
}

class SourceHealthCategoryEvidence {
  const SourceHealthCategoryEvidence({
    required this.category,
    required this.resultCount,
    required this.streamCount,
    required this.elapsedMs,
    this.qualityLabels = const <String>[],
    this.containerLabels = const <String>[],
    this.audioKinds = const <String>[],
    this.subtitleTrackCount = 0,
  });

  final String category;
  final int resultCount;
  final int streamCount;
  final int elapsedMs;
  final List<String> qualityLabels;
  final List<String> containerLabels;
  final List<String> audioKinds;
  final int subtitleTrackCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'category': category,
    'resultCount': resultCount,
    'streamCount': streamCount,
    'elapsedMs': elapsedMs,
    'qualityLabels': qualityLabels,
    'containerLabels': containerLabels,
    'audioKinds': audioKinds,
    'subtitleTrackCount': subtitleTrackCount,
  };

  factory SourceHealthCategoryEvidence.fromJson(Map<String, dynamic> json) =>
      SourceHealthCategoryEvidence(
        category: '${json['category'] ?? ''}',
        resultCount: (json['resultCount'] as num?)?.toInt() ?? 0,
        streamCount: (json['streamCount'] as num?)?.toInt() ?? 0,
        elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
        qualityLabels: _stringList(json['qualityLabels']),
        containerLabels: _stringList(json['containerLabels']),
        audioKinds: _stringList(json['audioKinds']),
        subtitleTrackCount: (json['subtitleTrackCount'] as num?)?.toInt() ?? 0,
      );
}

class SourceHealthCheckResult {
  const SourceHealthCheckResult({
    required this.id,
    required this.name,
    required this.engineLabel,
    required this.status,
    required this.reason,
    required this.elapsed,
    this.resultCount,
    this.httpStatusCode,
    this.extractedStreamCount = 0,
    this.qualityLabels = const <String>[],
    this.containerLabels = const <String>[],
    this.audioKinds = const <String>[],
    this.subtitleTrackCount = 0,
    this.categoryEvidence = const <String, SourceHealthCategoryEvidence>{},
    this.videoSource,
    this.mihonSource,
  });

  final String id;
  final String name;
  final String engineLabel;
  final SourceHealthStatus status;
  final SourceHealthReason reason;
  final Duration elapsed;
  final int? resultCount;
  final int? httpStatusCode;
  final int extractedStreamCount;
  final List<String> qualityLabels;
  final List<String> containerLabels;
  final List<String> audioKinds;
  final int subtitleTrackCount;
  final Map<String, SourceHealthCategoryEvidence> categoryEvidence;
  final SourceManifest? videoSource;
  final MihonSourceInfo? mihonSource;

  bool get isChecking => status == SourceHealthStatus.checking;

  bool get isOnline =>
      status == SourceHealthStatus.healthy ||
      status == SourceHealthStatus.reachable;

  bool get needsAttention =>
      status == SourceHealthStatus.failed ||
      status == SourceHealthStatus.attention;

  String get selectionKey => videoSource != null
      ? 'video:${videoSource!.stableKey}'
      : 'mihon:${mihonSource?.packageName ?? ''}:${mihonSource?.id ?? id}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'engineLabel': engineLabel,
    'status': status.name,
    'reason': reason.name,
    'elapsedMs': elapsed.inMilliseconds,
    'resultCount': resultCount,
    'httpStatusCode': httpStatusCode,
    'extractedStreamCount': extractedStreamCount,
    'qualityLabels': qualityLabels,
    'containerLabels': containerLabels,
    'audioKinds': audioKinds,
    'subtitleTrackCount': subtitleTrackCount,
    'categoryEvidence': categoryEvidence.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'videoSource': videoSource == null
        ? null
        : _sourceManifestToJson(videoSource!),
    'mihonSource': mihonSource == null
        ? null
        : <String, dynamic>{
            'id': mihonSource!.id,
            'name': mihonSource!.name,
            'lang': mihonSource!.lang,
            'pkg': mihonSource!.packageName,
            'baseUrl': mihonSource!.baseUrl,
            'version': mihonSource!.version,
            'nsfw': mihonSource!.isNsfw,
            'headers': mihonSource!.headers,
          },
  };

  factory SourceHealthCheckResult.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      return values.firstWhere(
        (value) => value.name == raw,
        orElse: () => fallback,
      );
    }

    final rawMihon = json['mihonSource'];
    final mihon = rawMihon is Map
        ? MihonSourceInfo.fromJson(Map<String, dynamic>.from(rawMihon))
        : null;
    final rawVideo = json['videoSource'];
    final rawEvidence = json['categoryEvidence'];
    final evidence = <String, SourceHealthCategoryEvidence>{};
    if (rawEvidence is Map) {
      for (final entry in rawEvidence.entries) {
        if (entry.value is Map) {
          evidence[entry.key
              .toString()] = SourceHealthCategoryEvidence.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    return SourceHealthCheckResult(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      engineLabel: '${json['engineLabel'] ?? ''}',
      status: enumValue(
        SourceHealthStatus.values,
        json['status'],
        SourceHealthStatus.checking,
      ),
      reason: enumValue(
        SourceHealthReason.values,
        json['reason'],
        SourceHealthReason.unknown,
      ),
      elapsed: Duration(
        milliseconds: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      ),
      resultCount: (json['resultCount'] as num?)?.toInt(),
      httpStatusCode: (json['httpStatusCode'] as num?)?.toInt(),
      extractedStreamCount:
          (json['extractedStreamCount'] as num?)?.toInt() ?? 0,
      qualityLabels: _stringList(json['qualityLabels']),
      containerLabels: _stringList(json['containerLabels']),
      audioKinds: _stringList(json['audioKinds']),
      subtitleTrackCount: (json['subtitleTrackCount'] as num?)?.toInt() ?? 0,
      categoryEvidence: Map<String, SourceHealthCategoryEvidence>.unmodifiable(
        evidence,
      ),
      videoSource: rawVideo is Map
          ? _sourceManifestFromJson(Map<String, dynamic>.from(rawVideo))
          : null,
      mihonSource: mihon,
    );
  }
}

String _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
  }
  return '';
}

List<String> _stringList(Object? raw) => raw is List
    ? raw.whereType<String>().toList(growable: false)
    : const <String>[];

Map<String, dynamic> _sourceManifestToJson(SourceManifest source) =>
    <String, dynamic>{
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
      'repositoryUrl': source.repositoryUrl,
      'enabled': source.enabled,
      'installedByDefault': source.installedByDefault,
      'isFallback': source.isFallback,
      'isNsfw': source.isNsfw,
      'declaredNsfw': source.declaredNsfw,
      'status': source.status,
      'updatedAt': source.updatedAt?.toIso8601String(),
      'engine': <String, dynamic>{
        'rawType': source.engine.rawType,
        'endpoint': source.engine.endpoint,
        'priority': source.engine.priority,
        'language': source.engine.language,
        'audioLanguage': source.engine.audioLanguage,
        'qualityFilter': source.engine.qualityFilter,
        'movieUrl': source.engine.movieUrl,
        'tvUrl': source.engine.tvUrl,
        'config': source.engine.config,
      },
    };

SourceManifest _sourceManifestFromJson(Map<String, dynamic> json) {
  final rawEngine = json['engine'];
  final engine = rawEngine is Map
      ? Map<String, dynamic>.from(rawEngine)
      : <String, dynamic>{};
  final rawConfig = engine['config'];
  return SourceManifest(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    description: '${json['description'] ?? ''}',
    version: '${json['version'] ?? '1.0.0'}',
    versionCode: (json['versionCode'] as num?)?.toInt() ?? 1,
    apiVersion: (json['apiVersion'] as num?)?.toInt() ?? 1,
    language: '${json['language'] ?? 'Multi'}',
    authors: (json['authors'] as List? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    tags: (json['tags'] as List? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    homepage: json['homepage'] as String?,
    iconUrl: json['iconUrl'] as String?,
    repositoryUrl: json['repositoryUrl'] as String?,
    enabled: json['enabled'] != false,
    installedByDefault: json['installedByDefault'] == true,
    isFallback: json['isFallback'] == true,
    isNsfw: json['isNsfw'] == true,
    declaredNsfw: json['declaredNsfw'] as bool?,
    status: (json['status'] as num?)?.toInt() ?? 1,
    updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
    engine: SourceEngineDescriptor(
      rawType: '${engine['rawType'] ?? ''}',
      kind: sourceEngineKindFrom('${engine['rawType'] ?? ''}'),
      endpoint: '${engine['endpoint'] ?? ''}',
      priority: (engine['priority'] as num?)?.toInt() ?? 50,
      language: engine['language'] as String?,
      audioLanguage: engine['audioLanguage'] as String?,
      qualityFilter: engine['qualityFilter'] as String?,
      movieUrl: engine['movieUrl'] as String?,
      tvUrl: engine['tvUrl'] as String?,
      config: rawConfig is Map
          ? Map<String, dynamic>.from(rawConfig)
          : const <String, dynamic>{},
    ),
  );
}

/// Performs local checks against the providers installed in RAVEN23.
/// No external scraper-health service is required.
class SourceHealthProbeService {
  static const int _maxProbeResponseBytes = 512 * 1024;

  SourceHealthProbeService({
    Dio? dio,
    QuickJsProviderRuntime? quickJsRuntime,
    MihonRuntimeService? mihonRuntime,
    SourceHostPolicy? hostPolicy,
  }) : _dio = dio ?? _createDio(),
       _quickJsRuntime = quickJsRuntime ?? QuickJsProviderRuntime(),
       _mihonRuntime = mihonRuntime ?? MihonRuntimeService.instance,
       _hostPolicy = hostPolicy ?? const SourceHostPolicy();

  final Dio _dio;
  final QuickJsProviderRuntime _quickJsRuntime;
  final MihonRuntimeService _mihonRuntime;
  final SourceHostPolicy _hostPolicy;

  /// Releases the dedicated QuickJS engine and HTTP client owned by this probe.
  void dispose() {
    _quickJsRuntime.dispose();
    _dio.close(force: true);
  }

  static Dio _createDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 12),
      responseType: ResponseType.plain,
      headers: const <String, String>{
        'Accept': 'application/json, text/html, */*',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      },
    ),
  );

  Future<List<SourceHealthCheckResult>> checkVideoSources(
    List<SourceManifest> sources, {
    void Function(int completed, int total)? onProgress,
    void Function(SourceManifest source, SourceHealthCheckResult result)?
    onResult,
  }) async {
    if (sources.isEmpty) return const <SourceHealthCheckResult>[];
    final results = List<SourceHealthCheckResult?>.filled(sources.length, null);
    var next = 0;
    var completed = 0;
    final workerCount = math.min(3, sources.length).toInt();

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= sources.length) return;
        final source = sources[index];
        final result = await checkVideoSource(source);
        results[index] = result;
        onResult?.call(source, result);
        completed++;
        onProgress?.call(completed, sources.length);
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return results.whereType<SourceHealthCheckResult>().toList(growable: false);
  }

  Future<SourceHealthCheckResult> checkVideoSource(
    SourceManifest source,
  ) async {
    final watch = Stopwatch()..start();
    try {
      if (source.requiresLiveTvAdapter) {
        return _result(
          source,
          status: SourceHealthStatus.unsupported,
          reason: SourceHealthReason.unsupportedEngine,
          watch: watch,
        );
      }
      if (source.engine.kind == SourceEngineKind.unsupported ||
          source.engine.kind == SourceEngineKind.httpJson ||
          source.engine.kind == SourceEngineKind.legacyScraperApi ||
          source.engine.kind == SourceEngineKind.native) {
        return _result(
          source,
          status: SourceHealthStatus.unsupported,
          reason: SourceHealthReason.unsupportedEngine,
          watch: watch,
        );
      }

      switch (source.engine.kind) {
        case SourceEngineKind.javascript:
          return await _checkQuickJs(source, watch);
        case SourceEngineKind.stremio:
          return await _checkStremio(source, watch);
        case SourceEngineKind.vidkingDirect:
          return await _checkVidkingDirect(source, watch);
        case SourceEngineKind.vidkingWebView:
          return await _checkWebsite(source, 'https://www.vidking.net/', watch);
        case SourceEngineKind.webEmbed:
          return await _checkWebEmbed(source, watch);
        case SourceEngineKind.animeSite:
          return await _checkWebsite(
            source,
            _originUrl(source.homepage ?? source.engine.endpoint),
            watch,
          );
        case SourceEngineKind.httpJson:
        case SourceEngineKind.legacyScraperApi:
        case SourceEngineKind.native:
        case SourceEngineKind.unsupported:
          return _result(
            source,
            status: SourceHealthStatus.unsupported,
            reason: SourceHealthReason.unsupportedEngine,
            watch: watch,
          );
      }
    } catch (error) {
      final failure = _classifyError(error);
      return _result(
        source,
        status: failure.status,
        reason: failure.reason,
        httpStatusCode: failure.httpStatusCode,
        watch: watch,
      );
    }
  }

  Future<SourceHealthCheckResult> _checkQuickJs(
    SourceManifest source,
    Stopwatch watch,
  ) async {
    final info = await _quickJsRuntime.call(
      source,
      'getInfo',
      const <Object?>[],
      timeout: const Duration(seconds: 15),
    );
    if (info is! Map) {
      return _result(
        source,
        status: SourceHealthStatus.failed,
        reason: SourceHealthReason.invalidResponse,
        watch: watch,
      );
    }

    Object? lastSearchError;
    var hasSearchResponse = false;
    var totalResults = 0;
    var totalStreams = 0;
    var totalSubtitles = 0;
    final allQualities = <String>{};
    final allContainers = <String>{};
    final allAudioKinds = <String>{};
    final evidence = <String, SourceHealthCategoryEvidence>{};

    for (final providerCategory in _quickJsSearchCategories(source)) {
      final categoryWatch = Stopwatch()..start();
      try {
        final response = await _quickJsRuntime.call(source, 'search', <Object?>[
          'M',
          1,
          <String, dynamic>{'category': providerCategory},
        ], timeout: const Duration(seconds: 20));
        if (response is! List) {
          lastSearchError = const FormatException(
            'Provider search() did not return a list.',
          );
          continue;
        }

        hasSearchResponse = true;
        totalResults += response.length;
        final streams = response.isEmpty
            ? const <UnifiedStreamOption>[]
            : await _extractQuickJsSample(
                source,
                response,
                providerCategory: providerCategory,
              );
        final qualities = streams
            .map((stream) => stream.quality?.trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet();
        final containers = streams
            .map((stream) => stream.container.name)
            .toSet();
        final audioKinds = streams
            .map((stream) => stream.audioKind.name)
            .toSet();
        final subtitleCount = streams.fold<int>(
          0,
          (total, stream) => total + stream.subtitles.length,
        );

        totalStreams += streams.length;
        totalSubtitles += subtitleCount;
        allQualities.addAll(qualities);
        allContainers.addAll(containers);
        allAudioKinds.addAll(audioKinds);

        final categoryNames = _priorityCategoryNames(source, providerCategory);
        for (final categoryName in categoryNames) {
          evidence[categoryName] = SourceHealthCategoryEvidence(
            category: categoryName,
            resultCount: response.length,
            streamCount: streams.length,
            elapsedMs: categoryWatch.elapsed.inMilliseconds,
            qualityLabels: qualities.toList()..sort(),
            containerLabels: containers.toList()..sort(),
            audioKinds: audioKinds.toList()..sort(),
            subtitleTrackCount: subtitleCount,
          );
        }
      } catch (error) {
        // A mixed provider may implement only one category contract. Keep
        // testing the other declared contract before marking the source down.
        lastSearchError = error;
      }
    }

    if (!hasSearchResponse) {
      if (lastSearchError != null) throw lastSearchError;
      return _result(
        source,
        status: SourceHealthStatus.failed,
        reason: SourceHealthReason.invalidResponse,
        watch: watch,
      );
    }

    return _result(
      source,
      status: totalResults > 0 && totalStreams == 0
          ? SourceHealthStatus.attention
          : SourceHealthStatus.healthy,
      reason: totalStreams > 0
          ? SourceHealthReason.streamsExtracted
          : totalResults > 0
          ? SourceHealthReason.streamExtractionFailed
          : SourceHealthReason.searchResponded,
      resultCount: totalResults,
      extractedStreamCount: totalStreams,
      qualityLabels: allQualities.toList()..sort(),
      containerLabels: allContainers.toList()..sort(),
      audioKinds: allAudioKinds.toList()..sort(),
      subtitleTrackCount: totalSubtitles,
      categoryEvidence: evidence,
      watch: watch,
    );
  }

  Future<List<UnifiedStreamOption>> _extractQuickJsSample(
    SourceManifest source,
    List<dynamic> response, {
    required String providerCategory,
  }) async {
    final candidates = response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) =>
              _readString(item, const <String>['url', 'link', 'id']).isNotEmpty,
        )
        .take(2);

    for (final candidate in candidates) {
      final listingUrl = _readString(candidate, const <String>[
        'url',
        'link',
        'id',
      ]);
      var targetUrl = listingUrl;
      if (providerCategory == 'sub') {
        targetUrl =
            await _firstQuickJsEpisodeUrl(source, listingUrl) ?? listingUrl;
      }

      try {
        final rawStreams = await _quickJsRuntime.call(
          source,
          'getVideoSources',
          <Object?>[targetUrl, false],
          timeout: const Duration(seconds: 25),
        );
        final streams = mapQuickJsVideoSources(source, rawStreams);
        if (streams.isNotEmpty) return streams;
      } catch (_) {
        // A failed sample extraction is recorded as search-only evidence; the
        // provider remains visible for diagnosis but is not priority-ranked.
      }
    }
    return const <UnifiedStreamOption>[];
  }

  Future<String?> _firstQuickJsEpisodeUrl(
    SourceManifest source,
    String seriesUrl,
  ) async {
    List<dynamic> episodes = const <dynamic>[];
    try {
      final detail = await _quickJsRuntime.call(source, 'getDetail', <Object?>[
        seriesUrl,
      ], timeout: const Duration(seconds: 12));
      if (detail is Map && detail['episodes'] is List) {
        episodes = detail['episodes'] as List<dynamic>;
      }
    } catch (_) {
      // getDetail is optional in the source contract.
    }

    if (episodes.isEmpty) {
      try {
        final rawEpisodes = await _quickJsRuntime.call(
          source,
          'getEpisodes',
          <Object?>[
            seriesUrl,
            <String, dynamic>{'category': 'sub'},
          ],
          timeout: const Duration(seconds: 15),
        );
        if (rawEpisodes is List) {
          episodes = rawEpisodes;
        } else if (rawEpisodes is Map && rawEpisodes['episodes'] is List) {
          episodes = rawEpisodes['episodes'] as List<dynamic>;
        }
      } catch (_) {
        // Some providers expose streams directly on the series URL.
      }
    }

    for (final raw in episodes) {
      if (raw is! Map) continue;
      final url = _readString(Map<String, dynamic>.from(raw), const <String>[
        'url',
        'link',
        'id',
      ]);
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  List<String> _priorityCategoryNames(
    SourceManifest source,
    String providerCategory,
  ) {
    if (providerCategory == 'movie') return const <String>['movies'];
    final tags = source.tags
        .map((tag) => tag.trim().toLowerCase().replaceAll('_', '-'))
        .toSet();
    final providerType = (source.engine.config['providerType'] ?? '')
        .toString()
        .toLowerCase();
    final hasAnime =
        source.isAnimeOnly ||
        providerType.contains('anime') ||
        providerType.contains('donghua') ||
        tags.contains('anime') ||
        tags.contains('donghua');
    final hasSeries = tags.any(
      const <String>{'series', 'tv', 'show', 'shows'}.contains,
    );
    if (hasAnime && hasSeries) return const <String>['anime', 'series'];
    if (hasAnime) return const <String>['anime'];
    return const <String>['series'];
  }

  List<String> _quickJsSearchCategories(SourceManifest source) {
    final providerType = (source.engine.config['providerType'] ?? '')
        .toString()
        .toLowerCase();
    final tags = source.tags
        .map((tag) => tag.toLowerCase().replaceAll('_', '-'))
        .toSet();
    final hasMovies = tags.any(
      const <String>{'movie', 'movies', 'film', 'films'}.contains,
    );
    final hasSeries = tags.any(
      const <String>{'series', 'tv', 'show', 'shows'}.contains,
    );
    final advertisesAnime =
        source.isAnimeOnly ||
        providerType.contains('anime') ||
        providerType.contains('donghua') ||
        tags.contains('anime') ||
        tags.contains('donghua');
    if ((advertisesAnime && !hasMovies) || (hasSeries && !hasMovies)) {
      return const <String>['sub'];
    }
    if (hasMovies && !hasSeries && !advertisesAnime) {
      return const <String>['movie'];
    }
    // For mixed or undeclared sources, test both movie and sub contracts so
    // one successful category cannot hide a broken second category.
    return const <String>['movie', 'sub'];
  }

  Future<SourceHealthCheckResult> _checkStremio(
    SourceManifest source,
    Stopwatch watch,
  ) async {
    if (source.engine.config['configurationRequired'] == true ||
        source.engine.config['needsConfiguration'] == true) {
      return _result(
        source,
        status: SourceHealthStatus.attention,
        reason: SourceHealthReason.configurationRequired,
        watch: watch,
      );
    }
    final uri = _stremioManifestUri(source.engine.endpoint);
    final response = await _safeGet(uri);
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      final failure = _classifyResponse(response);
      return _result(
        source,
        status: failure.status,
        reason: failure.reason,
        httpStatusCode: statusCode,
        watch: watch,
      );
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(response.data ?? '');
    } on FormatException {
      final failure =
          _looksLikeCloudflare(
            response.data,
            response.headers,
            statusCode: statusCode,
          )
          ? const _HealthFailure(
              SourceHealthStatus.attention,
              SourceHealthReason.cloudflare,
            )
          : const _HealthFailure(
              SourceHealthStatus.failed,
              SourceHealthReason.invalidResponse,
            );
      return _result(
        source,
        status: failure.status,
        reason: failure.reason,
        httpStatusCode: statusCode,
        watch: watch,
      );
    }
    if (decoded is! Map ||
        decoded['id'] is! String ||
        (decoded['id'] as String).trim().isEmpty ||
        decoded['resources'] is! List) {
      return _result(
        source,
        status: SourceHealthStatus.failed,
        reason: SourceHealthReason.invalidResponse,
        httpStatusCode: statusCode,
        watch: watch,
      );
    }
    return _result(
      source,
      status: SourceHealthStatus.reachable,
      reason: SourceHealthReason.endpointResponded,
      httpStatusCode: statusCode,
      watch: watch,
    );
  }

  Future<SourceHealthCheckResult> _checkVidkingDirect(
    SourceManifest source,
    Stopwatch watch,
  ) async {
    final route = source.engine.endpoint.trim().replaceAll('\\', '/');
    final routeUri = Uri.tryParse(route);
    if (route.isEmpty ||
        routeUri == null ||
        routeUri.hasScheme ||
        routeUri.hasAuthority ||
        route.startsWith('/') ||
        routeUri.pathSegments.any(
          (segment) => segment == '.' || segment == '..',
        )) {
      return _result(
        source,
        status: SourceHealthStatus.failed,
        reason: SourceHealthReason.invalidEndpoint,
        watch: watch,
      );
    }
    // VidKing resolves streams only after receiving a TMDB media ID and seed.
    // Its seed endpoint can still confirm API reachability without selecting
    // any particular film or series. A 400/422 is expected without mediaId.
    final response = await _safeGet(
      Uri.parse('https://api.speedracelight.com/seed'),
      headers: const <String, String>{
        'Referer': 'https://www.vidking.net/',
        'Origin': 'https://www.vidking.net',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      },
    );
    final statusCode = response.statusCode ?? 0;
    if (_looksLikeCloudflare(
      response.data,
      response.headers,
      statusCode: statusCode,
    )) {
      return _result(
        source,
        status: SourceHealthStatus.attention,
        reason: SourceHealthReason.cloudflare,
        httpStatusCode: statusCode,
        watch: watch,
      );
    }
    if (statusCode >= 200 && statusCode < 300) {
      return _result(
        source,
        status: SourceHealthStatus.reachable,
        reason: SourceHealthReason.endpointResponded,
        httpStatusCode: statusCode,
        watch: watch,
      );
    }
    if (statusCode == 400 || statusCode == 422) {
      return _result(
        source,
        status: SourceHealthStatus.reachable,
        reason: SourceHealthReason.apiRequiresMedia,
        httpStatusCode: statusCode,
        watch: watch,
      );
    }
    final failure = _classifyResponse(response);
    return _result(
      source,
      status: failure.status,
      reason: failure.reason,
      httpStatusCode: statusCode,
      watch: watch,
    );
  }

  Future<SourceHealthCheckResult> _checkWebEmbed(
    SourceManifest source,
    Stopwatch watch,
  ) async {
    final candidate =
        source.homepage ?? source.engine.movieUrl ?? source.engine.tvUrl ?? '';
    final parsed = Uri.tryParse(candidate);
    if (parsed == null || parsed.host.isEmpty || parsed.userInfo.isNotEmpty) {
      return _result(
        source,
        status: SourceHealthStatus.failed,
        reason: SourceHealthReason.invalidEndpoint,
        watch: watch,
      );
    }
    final uri = Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
    );
    return _checkWebsite(source, uri.toString(), watch);
  }

  String _originUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return rawUrl;
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  Future<SourceHealthCheckResult> _checkWebsite(
    SourceManifest source,
    String rawUrl,
    Stopwatch watch,
  ) async {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null ||
        (parsed.scheme != 'https' && parsed.scheme != 'http') ||
        parsed.host.isEmpty) {
      return _result(
        source,
        status: SourceHealthStatus.failed,
        reason: SourceHealthReason.invalidEndpoint,
        watch: watch,
      );
    }
    var response = await _safeHead(parsed);
    var statusCode = response.statusCode ?? 0;
    // Some origins intentionally do not implement HEAD. Fall back to a bounded
    // GET only for those explicit method-not-supported responses.
    if (statusCode == 405 || statusCode == 501) {
      response = await _safeGet(parsed);
      statusCode = response.statusCode ?? 0;
    }
    if (_looksLikeCloudflare(
      response.data,
      response.headers,
      statusCode: statusCode,
    )) {
      return _result(
        source,
        status: SourceHealthStatus.attention,
        reason: SourceHealthReason.cloudflare,
        httpStatusCode: statusCode,
        watch: watch,
      );
    }
    if (statusCode >= 200 && statusCode < 400) {
      return _result(
        source,
        status: SourceHealthStatus.reachable,
        reason: SourceHealthReason.endpointResponded,
        httpStatusCode: statusCode,
        watch: watch,
      );
    }
    final failure = _classifyResponse(response);
    return _result(
      source,
      status: failure.status,
      reason: failure.reason,
      httpStatusCode: statusCode,
      watch: watch,
    );
  }

  Future<Response<String>> _safeGet(
    Uri initialUri, {
    Map<String, String> headers = const <String, String>{},
  }) => _safeRequest(initialUri, method: 'GET', headers: headers);

  Future<Response<String>> _safeHead(Uri initialUri) =>
      _safeRequest(initialUri, method: 'HEAD');

  Future<Response<String>> _safeRequest(
    Uri initialUri, {
    required String method,
    Map<String, String> headers = const <String, String>{},
  }) async {
    var currentUri = await _hostPolicy.validate(initialUri.toString());
    for (var redirect = 0; ; redirect++) {
      // Stream every response and enforce the limit while reading it. Dio 5.x
      // does not expose BaseOptions.maxContentLength; a streamed cap prevents
      // a misconfigured provider from allocating an unbounded response body.
      final streamedResponse = await _dio.request<ResponseBody>(
        currentUri.toString(),
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
          followRedirects: false,
          maxRedirects: 0,
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      final statusCode = streamedResponse.statusCode ?? 0;
      final location = streamedResponse.headers.value('location');
      if (statusCode >= 300 && statusCode < 400 && location != null) {
        // Redirect bodies are not needed. Cancel the stream before following
        // the next, separately validated URL.
        await _cancelResponseBody(streamedResponse.data);
        if (redirect >= _hostPolicy.maxRedirects) {
          throw const FormatException('Provider exceeded the redirect limit.');
        }
        final nextUri = await _hostPolicy.validate(
          currentUri.resolve(location).toString(),
        );
        if (currentUri.scheme == 'https' && nextUri.scheme != 'https') {
          throw const FormatException('Provider attempted an HTTPS downgrade.');
        }
        currentUri = nextUri;
        continue;
      }

      final declaredLength = int.tryParse(
        streamedResponse.headers.value('content-length') ?? '',
      );
      if (declaredLength != null && declaredLength > _maxProbeResponseBytes) {
        await _cancelResponseBody(streamedResponse.data);
        throw const FormatException(
          'maxContentLength exceeded (512 KiB health-check response limit).',
        );
      }

      final responseBytes = <int>[];
      final responseBody = streamedResponse.data;
      if (responseBody != null) {
        await for (final chunk in responseBody.stream.timeout(
          const Duration(seconds: 12),
        )) {
          if (responseBytes.length + chunk.length > _maxProbeResponseBytes) {
            throw const FormatException(
              'maxContentLength exceeded (512 KiB health-check response limit).',
            );
          }
          responseBytes.addAll(chunk);
        }
      }

      return Response<String>(
        data: utf8.decode(responseBytes, allowMalformed: true),
        headers: streamedResponse.headers,
        requestOptions: streamedResponse.requestOptions,
        statusCode: streamedResponse.statusCode,
        statusMessage: streamedResponse.statusMessage,
      );
    }
  }

  Future<void> _cancelResponseBody(ResponseBody? body) async {
    if (body == null) return;
    await body.stream.listen(null).cancel();
  }

  Uri _stremioManifestUri(String endpoint) {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Stremio manifest endpoint is invalid.');
    }
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isNotEmpty && segments.last.toLowerCase() == 'manifest.json') {
      segments.removeLast();
    }
    return uri.replace(
      pathSegments: <String>[...segments, 'manifest.json'],
      fragment: '',
    );
  }

  Future<List<SourceHealthCheckResult>> checkMihonSources({
    List<MihonSourceInfo>? sources,
    void Function(int completed, int total)? onProgress,
    void Function(MihonSourceInfo source, SourceHealthCheckResult result)?
    onResult,
  }) async {
    final installedSources = sources ?? await _mihonRuntime.listSources();
    if (installedSources.isEmpty) return const <SourceHealthCheckResult>[];
    final results = List<SourceHealthCheckResult?>.filled(
      installedSources.length,
      null,
    );
    var next = 0;
    var completed = 0;
    final workerCount = math.min(3, installedSources.length).toInt();

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= installedSources.length) return;
        final source = installedSources[index];
        final result = await checkMihonSource(source);
        results[index] = result;
        onResult?.call(source, result);
        completed++;
        onProgress?.call(completed, installedSources.length);
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );
    return results.whereType<SourceHealthCheckResult>().toList(growable: false);
  }

  Future<SourceHealthCheckResult> checkMihonSource(
    MihonSourceInfo source,
  ) async {
    final watch = Stopwatch()..start();
    try {
      final matches = await _mihonRuntime
          .search(source.id, 'M', page: 1)
          .timeout(const Duration(seconds: 20));
      watch.stop();
      return SourceHealthCheckResult(
        id: source.id.toString(),
        name: source.name,
        engineLabel: 'Mihon · ${source.lang}',
        status: SourceHealthStatus.healthy,
        reason: SourceHealthReason.searchResponded,
        elapsed: watch.elapsed,
        resultCount: matches.length,
        mihonSource: source,
      );
    } catch (error) {
      watch.stop();
      final failure = _classifyError(error);
      return SourceHealthCheckResult(
        id: source.id.toString(),
        name: source.name,
        engineLabel: 'Mihon · ${source.lang}',
        status: failure.status,
        reason: failure.reason,
        elapsed: watch.elapsed,
        httpStatusCode: failure.httpStatusCode,
        mihonSource: source,
      );
    }
  }

  SourceHealthCheckResult _result(
    SourceManifest source, {
    required SourceHealthStatus status,
    required SourceHealthReason reason,
    required Stopwatch watch,
    int? resultCount,
    int? httpStatusCode,
    int extractedStreamCount = 0,
    List<String> qualityLabels = const <String>[],
    List<String> containerLabels = const <String>[],
    List<String> audioKinds = const <String>[],
    int subtitleTrackCount = 0,
    Map<String, SourceHealthCategoryEvidence> categoryEvidence =
        const <String, SourceHealthCategoryEvidence>{},
  }) {
    watch.stop();
    return SourceHealthCheckResult(
      id: source.stableKey,
      name: source.name,
      engineLabel: source.engine.rawType,
      status: status,
      reason: reason,
      elapsed: watch.elapsed,
      resultCount: resultCount,
      httpStatusCode: httpStatusCode,
      extractedStreamCount: extractedStreamCount,
      qualityLabels: qualityLabels,
      containerLabels: containerLabels,
      audioKinds: audioKinds,
      subtitleTrackCount: subtitleTrackCount,
      categoryEvidence: categoryEvidence,
      videoSource: source,
    );
  }

  _HealthFailure _classifyResponse(Response<String> response) {
    final statusCode = response.statusCode ?? 0;
    if (_looksLikeCloudflare(
      response.data,
      response.headers,
      statusCode: statusCode,
    )) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.cloudflare,
      );
    }
    return _classifyHttpStatus(statusCode);
  }

  bool _looksLikeCloudflare(
    Object? body,
    Headers? headers, {
    required int statusCode,
  }) {
    final text = body is String
        ? body.toLowerCase()
        : body?.toString().toLowerCase() ?? '';
    final server = headers?.value('server')?.toLowerCase() ?? '';
    final mitigation = headers?.value('cf-mitigated')?.toLowerCase() ?? '';
    if (mitigation.contains('challenge')) return true;
    if ((statusCode == 403 || statusCode == 429 || statusCode == 503) &&
        (server.contains('cloudflare') || headers?.value('cf-ray') != null)) {
      return true;
    }
    return text.contains('cf-browser-verification') ||
        text.contains('cf-challenge') ||
        text.contains('cloudflare ray id') ||
        text.contains('checking your browser') ||
        text.contains('attention required! | cloudflare') ||
        text.contains('cf_chl_') ||
        text.contains('just a moment...');
  }

  _HealthFailure _classifyError(Object error) {
    if (error is PlatformException) {
      if (error.code.toUpperCase() == 'CLOUDFLARE') {
        return const _HealthFailure(
          SourceHealthStatus.attention,
          SourceHealthReason.cloudflare,
        );
      }
      if (error.code.toUpperCase() == 'NO_SOURCE') {
        return const _HealthFailure(
          SourceHealthStatus.failed,
          SourceHealthReason.sourceMissing,
        );
      }
    }

    if (error is DioException) {
      if (_looksLikeCloudflare(
        error.response?.data,
        error.response?.headers,
        statusCode: error.response?.statusCode ?? 0,
      )) {
        return const _HealthFailure(
          SourceHealthStatus.attention,
          SourceHealthReason.cloudflare,
        );
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const _HealthFailure(
            SourceHealthStatus.failed,
            SourceHealthReason.timeout,
          );
        case DioExceptionType.badCertificate:
          return const _HealthFailure(
            SourceHealthStatus.failed,
            SourceHealthReason.tlsFailure,
          );
        case DioExceptionType.connectionError:
          return _networkFailure(error.message ?? '');
        case DioExceptionType.unknown:
          if (error.error is SocketException) {
            return _networkFailure(error.toString());
          }
          return _messageFailure(error.toString());
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode ?? 0;
          return _classifyHttpStatus(status);
        case DioExceptionType.cancel:
          return const _HealthFailure(
            SourceHealthStatus.failed,
            SourceHealthReason.unknown,
          );
      }
    }
    if (error is SocketException) return _networkFailure(error.message);
    if (error is TimeoutException) {
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.timeout,
      );
    }
    if (error is FormatException) {
      final message = error.message.toLowerCase();
      if (message.contains('maxcontentlength') ||
          message.contains('maximum content length') ||
          message.contains('content-length exceeded')) {
        return const _HealthFailure(
          SourceHealthStatus.attention,
          SourceHealthReason.invalidResponse,
        );
      }
      if (message.contains('timeout') || message.contains('timed out')) {
        return const _HealthFailure(
          SourceHealthStatus.failed,
          SourceHealthReason.timeout,
        );
      }
      if (message.contains('dns')) {
        return const _HealthFailure(
          SourceHealthStatus.failed,
          SourceHealthReason.dnsFailure,
        );
      }
      if (message.contains('url') ||
          message.contains('endpoint') ||
          message.contains('private') ||
          message.contains('reserved network') ||
          message.contains('redirect') ||
          message.contains('https downgrade') ||
          message.contains('host must') ||
          message.contains('scheme')) {
        return const _HealthFailure(
          SourceHealthStatus.failed,
          SourceHealthReason.invalidEndpoint,
        );
      }
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.invalidResponse,
      );
    }
    return _messageFailure(error.toString());
  }

  _HealthFailure _messageFailure(String raw) {
    final message = raw.toLowerCase();
    if (message.contains('unknownhostexception') ||
        message.contains('failed host lookup') ||
        message.contains('name or service not known') ||
        message.contains('no address associated with hostname')) {
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.dnsFailure,
      );
    }
    if (message.contains('sockettimeoutexception') ||
        message.contains('timed out') ||
        message.contains('timeout')) {
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.timeout,
      );
    }
    if (message.contains('sslhandshakeexception') ||
        message.contains('certificate') ||
        message.contains('certpath') ||
        message.contains('trust anchor') ||
        message.contains('certificate verify failed') ||
        message.contains('handshake exception')) {
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.tlsFailure,
      );
    }
    if (message.contains('http error 401') || message.contains('401')) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.unauthorized,
        httpStatusCode: 401,
      );
    }
    if (message.contains('http error 403') || message.contains('403')) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.forbidden,
        httpStatusCode: 403,
      );
    }
    if (message.contains('http error 404') || message.contains('404')) {
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.pathNotFound,
        httpStatusCode: 404,
      );
    }
    if (message.contains('http error 429') || message.contains('429')) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.rateLimited,
        httpStatusCode: 429,
      );
    }
    if (message.contains('http error 5') ||
        message.contains('internal server error') ||
        message.contains('bad gateway') ||
        message.contains('service unavailable')) {
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.serverError,
      );
    }
    if (message.contains('maxcontentlength') ||
        message.contains('maximum content length') ||
        message.contains('content-length exceeded')) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.invalidResponse,
      );
    }
    if (message.contains('cloudflare')) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.cloudflare,
      );
    }
    if (message.contains('configure required') ||
        message.contains('requires setup') ||
        message.contains('configuration required')) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.configurationRequired,
      );
    }
    if (message.contains('no_source') ||
        (message.contains('source ') && message.contains(' not found'))) {
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.sourceMissing,
      );
    }
    if (message.contains('unsupportedoperationexception') ||
        message.contains('nosuchmethoderror') ||
        message.contains('abstractmethoderror') ||
        message.contains('noclassdeffounderror') ||
        message.contains('classnotfoundexception')) {
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.extensionFailure,
      );
    }
    if (message.contains('connectexception') ||
        message.contains('connection refused') ||
        message.contains('no route to host') ||
        message.contains('network is unreachable') ||
        message.contains('failed to connect')) {
      return _networkFailure(message);
    }
    return const _HealthFailure(
      SourceHealthStatus.attention,
      SourceHealthReason.unknown,
    );
  }

  _HealthFailure _networkFailure(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('name or service not known') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('unknownhost')) {
      return const _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.dnsFailure,
      );
    }
    return const _HealthFailure(
      SourceHealthStatus.failed,
      SourceHealthReason.networkUnavailable,
    );
  }

  _HealthFailure _classifyHttpStatus(int statusCode) {
    if (statusCode == 401) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.unauthorized,
        httpStatusCode: 401,
      );
    }
    if (statusCode == 403) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.forbidden,
        httpStatusCode: 403,
      );
    }
    if (statusCode == 429) {
      return const _HealthFailure(
        SourceHealthStatus.attention,
        SourceHealthReason.rateLimited,
        httpStatusCode: 429,
      );
    }
    if (statusCode == 404 || statusCode == 410) {
      return _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.pathNotFound,
        httpStatusCode: statusCode,
      );
    }
    if (statusCode >= 500) {
      return _HealthFailure(
        SourceHealthStatus.failed,
        SourceHealthReason.serverError,
        httpStatusCode: statusCode,
      );
    }
    return _HealthFailure(
      SourceHealthStatus.failed,
      SourceHealthReason.invalidResponse,
      httpStatusCode: statusCode > 0 ? statusCode : null,
    );
  }
}

class _HealthFailure {
  const _HealthFailure(this.status, this.reason, {this.httpStatusCode});

  final SourceHealthStatus status;
  final SourceHealthReason reason;
  final int? httpStatusCode;
}
