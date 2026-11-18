import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'source_host_policy.dart';

import 'source_manifest.dart';
import 'source_repository_parser.dart';
import 'source_repository_revision.dart';

class _RepositoryCaptureLimitException implements Exception {
  const _RepositoryCaptureLimitException();
}

/// Downloads and resolves declarative source repositories on the device.
///
/// The client is intentionally independent of Flutter UI and storage so it can
/// be used by mobile and Android TV flows and tested with a fake Dio adapter.
class SourceRepositoryClient {
  SourceRepositoryClient({
    Dio? dio,
    SourceRepositoryParser? parser,
    SourceHostPolicy? hostPolicy,
  }) : _dio = dio ?? _createDio(),
       _parser = parser ?? const SourceRepositoryParser(),
       _hostPolicy = hostPolicy ?? const SourceHostPolicy();

  final Dio _dio;
  final SourceRepositoryParser _parser;
  final SourceHostPolicy _hostPolicy;
  static const int _maxResponseBytes = 8 * 1024 * 1024;
  static const int _maxRepositoryCaptureBytes = 32 * 1024 * 1024;

  static Dio _createDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 18),
      sendTimeout: const Duration(seconds: 12),
      followRedirects: true,
      maxRedirects: 5,
      responseType: ResponseType.plain,
      headers: const <String, String>{
        'Accept': 'application/json, text/plain;q=0.9, */*;q=0.8',
        'User-Agent': 'RAVEN23-SourceEngine/1.0',
      },
    ),
  );

  Future<SourceRepositoryManifest> fetchRepository(
    String repositoryUrl, {
    CancelToken? cancelToken,
    int maxLinkedLists = 8,
    String? repositoryIdentityUrl,
    void Function(RepositoryDocumentCapture document)? onDocument,
  }) async {
    final normalizedUrl = normalizeRepositoryUrl(repositoryUrl);
    final identityUrl = normalizeRepositoryUrl(
      repositoryIdentityUrl ?? repositoryUrl,
    );
    var capturedBytes = 0;
    void captureDocument(RepositoryDocumentCapture document) {
      capturedBytes += utf8.encode(document.body).length;
      if (capturedBytes > _maxRepositoryCaptureBytes) {
        throw const _RepositoryCaptureLimitException();
      }
      onDocument?.call(document);
    }

    final raw = await _fetchText(
      normalizedUrl,
      cancelToken: cancelToken,
      onDocument: captureDocument,
    );
    if (_isM3uDocument(raw)) {
      throw const FormatException(
        'This URL serves an M3U/HLS media playlist, not a source repository index. '
        'Add channel playlists from Live TV > IPTV / M3U > Manage IPTV playlists.',
      );
    }
    final repository = _parser.parseRepository(raw, sourceUrl: identityUrl);
    if (repository.isStremioAddon) return repository;

    final linkedExtensions = <SourceManifest>[];
    final seenIds = repository.extensions.map((entry) => entry.id).toSet();
    final links = repository.extensionLists.take(maxLinkedLists);
    for (final link in links) {
      final resolved = Uri.parse(normalizedUrl).resolve(link).toString();
      try {
        final linkedRaw = await _fetchText(
          resolved,
          cancelToken: cancelToken,
          onDocument: captureDocument,
        );
        final items = _parser.parseExtensionList(
          linkedRaw,
          repositoryUrl: identityUrl,
        );
        for (final item in items) {
          if (seenIds.add(item.id)) linkedExtensions.add(item);
        }
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) rethrow;
        // One broken linked list must not empty a partially valid repository.
        continue;
      } on FormatException {
        continue;
      }
    }

    final combined = <SourceManifest>[
      ...repository.extensions,
      ...linkedExtensions,
    ];
    final enriched = <SourceManifest>[];
    // Add-on manifests expose the content types and ID prefixes required to
    // choose the correct Stremio stream URL. Limit concurrent metadata lookups
    // so a large index does not open an unbounded burst of network requests.
    for (var start = 0; start < combined.length; start += 3) {
      final batch = combined.skip(start).take(3);
      enriched.addAll(
        await Future.wait(
          batch.map(
            (source) => _enrichStremioSource(
              source,
              cancelToken: cancelToken,
              onDocument: captureDocument,
            ),
          ),
        ),
      );
    }

    return SourceRepositoryManifest(
      url: repository.url,
      name: repository.name,
      description: repository.description,
      website: repository.website,
      iconUrl: repository.iconUrl,
      extensions: enriched,
      extensionLists: repository.extensionLists,
    );
  }

  Future<SourceManifest> _enrichStremioSource(
    SourceManifest source, {
    CancelToken? cancelToken,
    void Function(RepositoryDocumentCapture document)? onDocument,
  }) async {
    if (source.engine.kind != SourceEngineKind.stremio ||
        source.engine.endpoint.trim().isEmpty) {
      return source;
    }

    try {
      final endpoint = Uri.parse(source.engine.endpoint);
      if ((endpoint.scheme != 'https' && endpoint.scheme != 'http') ||
          endpoint.host.isEmpty ||
          endpoint.userInfo.isNotEmpty) {
        return source;
      }
      final endpointSegments = endpoint.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList();
      if (endpointSegments.isNotEmpty &&
          endpointSegments.last == 'manifest.json') {
        endpointSegments.removeLast();
      }
      final baseEndpoint = endpoint
          .replace(pathSegments: endpointSegments)
          .removeFragment()
          .toString();
      final manifestUrl = endpoint
          .replace(pathSegments: <String>[...endpointSegments, 'manifest.json'])
          .removeFragment()
          .toString();
      final rawManifest = await _fetchText(
        manifestUrl,
        cancelToken: cancelToken,
        onDocument: onDocument,
      );
      final parsed = _parser.parseRepository(
        rawManifest,
        sourceUrl: manifestUrl,
      );
      if (!parsed.isStremioAddon || parsed.extensions.isEmpty) return source;
      final manifestSource = parsed.extensions.first;
      final engine = SourceEngineDescriptor(
        rawType: 'stremio',
        kind: manifestSource.engine.kind,
        endpoint: baseEndpoint,
        priority: source.engine.priority,
        language: source.engine.language ?? manifestSource.engine.language,
        audioLanguage:
            source.engine.audioLanguage ?? manifestSource.engine.audioLanguage,
        qualityFilter:
            source.engine.qualityFilter ?? manifestSource.engine.qualityFilter,
        movieUrl: source.engine.movieUrl ?? manifestSource.engine.movieUrl,
        tvUrl: source.engine.tvUrl ?? manifestSource.engine.tvUrl,
        config: <String, dynamic>{
          ...source.engine.config,
          ...manifestSource.engine.config,
        },
      );
      return SourceManifest(
        id: source.id,
        name: source.name,
        description: source.description,
        version: source.version,
        versionCode: source.versionCode,
        apiVersion: source.apiVersion,
        language: source.language,
        authors: source.authors,
        tags: source.tags,
        homepage: source.homepage ?? manifestSource.homepage,
        iconUrl: source.iconUrl ?? manifestSource.iconUrl,
        repositoryUrl: source.repositoryUrl,
        enabled: source.enabled && manifestSource.enabled,
        installedByDefault: source.installedByDefault,
        isFallback: source.isFallback,
        isNsfw: source.isNsfw,
        declaredNsfw: source.declaredNsfw,
        status: source.status,
        updatedAt: source.updatedAt,
        engine: engine,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      // Keep an indexed Stremio source visible if its metadata host is down.
      return source;
    } on _RepositoryCaptureLimitException {
      rethrow;
    } catch (_) {
      // Runtime fallback can still try its documented default ID convention.
      return source;
    }
  }

  Future<String> _fetchText(
    String url, {
    CancelToken? cancelToken,
    void Function(RepositoryDocumentCapture document)? onDocument,
  }) async {
    var currentUri = await _hostPolicy.validate(url);
    final requestToken = cancelToken ?? CancelToken();
    var exceededResponseLimit = false;
    late Response<String> response;
    for (var redirect = 0; ; redirect++) {
      try {
        response = await _dio.get<String>(
          currentUri.toString(),
          cancelToken: requestToken,
          onReceiveProgress: (received, _) {
            if (received > _maxResponseBytes && !requestToken.isCancelled) {
              exceededResponseLimit = true;
              requestToken.cancel('Repository response exceeded 8 MB.');
            }
          },
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 18),
            followRedirects: false,
            maxRedirects: 0,
            validateStatus: (_) => true,
          ),
        );
      } on DioException {
        if (exceededResponseLimit) {
          throw const FormatException(
            'The source repository response exceeds the 8 MB safety limit.',
          );
        }
        rethrow;
      }
      final status = response.statusCode ?? 0;
      final location = response.headers.value('location');
      if (status >= 300 && status < 400 && location != null) {
        if (redirect >= _hostPolicy.maxRedirects) {
          throw const FormatException(
            'Repository exceeded the redirect limit.',
          );
        }
        final nextUri = await _hostPolicy.validate(
          currentUri.resolve(location).toString(),
        );
        if (currentUri.scheme == 'https' && nextUri.scheme != 'https') {
          throw const FormatException(
            'Repository HTTPS downgrade redirects are blocked.',
          );
        }
        currentUri = nextUri;
        continue;
      }
      if (status < 200 || status >= 300) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
      break;
    }
    final body = response.data;
    if (body == null || body.trim().isEmpty) {
      throw const FormatException(
        'The source repository returned an empty response.',
      );
    }
    if (utf8.encode(body).length > _maxResponseBytes) {
      throw const FormatException(
        'The source repository response exceeds the 8 MB safety limit.',
      );
    }
    onDocument?.call(
      RepositoryDocumentCapture(
        requestedUrl: url,
        finalUrl: response.realUri.toString().isNotEmpty
            ? response.realUri.toString()
            : currentUri.toString(),
        statusCode: response.statusCode ?? 0,
        body: body,
        contentType: response.headers.value(Headers.contentTypeHeader),
        etag: response.headers.value('etag'),
        lastModified: response.headers.value('last-modified'),
      ),
    );
    return body;
  }

  /// Replaces the mutable ref segment of a raw.githubusercontent.com URL with
  /// an immutable 40-character commit SHA. Other URL formats are rejected so
  /// a caller cannot believe a pin was applied when it was not.
  static String pinGitHubRawUrlToCommit(String repositoryUrl, String commit) {
    final normalized = normalizeRepositoryUrl(repositoryUrl);
    final sha = commit.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(sha)) {
      throw const FormatException(
        'Commit pin must be a full 40-character SHA.',
      );
    }
    final uri = Uri.parse(normalized);
    if (uri.host.toLowerCase() != 'raw.githubusercontent.com' ||
        uri.pathSegments.length < 4) {
      throw const FormatException(
        'Commit pinning currently supports raw.githubusercontent.com repository indexes only.',
      );
    }
    final segments = List<String>.of(uri.pathSegments);
    segments[2] = sha;
    return uri.replace(pathSegments: segments).toString();
  }

  static String? commitHashFromUrl(String repositoryUrl) {
    final uri = Uri.tryParse(repositoryUrl);
    if (uri == null || uri.host.toLowerCase() != 'raw.githubusercontent.com') {
      return null;
    }
    if (uri.pathSegments.length < 4) return null;
    final ref = uri.pathSegments[2].toLowerCase();
    return RegExp(r'^[a-f0-9]{40}$').hasMatch(ref) ? ref : null;
  }

  static bool _isM3uDocument(String body) {
    final withoutBom = body.startsWith('\uFEFF') ? body.substring(1) : body;
    final normalized = withoutBom.trimLeft().toUpperCase();
    return normalized.startsWith('#EXTM3U');
  }

  /// Accepts only explicit HTTP(S) URLs. Relative linked-list paths are resolved
  /// against the repository URL by [fetchRepository]. Media playlist/manifest
  /// paths are rejected early so they cannot be mistaken for JSON indexes.
  static String normalizeRepositoryUrl(String input) {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.host == 'localhost' ||
        uri.host.endsWith('.localhost') ||
        uri.host.endsWith('.local') ||
        uri.host.endsWith('.internal')) {
      throw const FormatException(
        'Repository URL must be a valid HTTP or HTTPS address.',
      );
    }
    final mediaPath = uri.path.toLowerCase();
    if (mediaPath.endsWith('.m3u') ||
        mediaPath.endsWith('.m3u8') ||
        mediaPath.endsWith('.mpd')) {
      throw const FormatException(
        'This is a media playlist or stream URL, not a source repository index. '
        'Add M3U/M3U8 channel lists in Live TV > IPTV / M3U > Manage IPTV playlists. '
        'Direct HLS/DASH stream URLs belong inside an M3U playlist, not in Source Repositories.',
      );
    }
    final literal = InternetAddress.tryParse(uri.host);
    if (literal != null) {
      final parts = literal.address.split('.').map(int.tryParse).toList();
      final privateV4 =
          literal.type == InternetAddressType.IPv4 &&
          parts.length == 4 &&
          parts.every((part) => part != null) &&
          (parts[0] == 0 ||
              parts[0] == 10 ||
              parts[0] == 127 ||
              (parts[0] == 169 && parts[1] == 254) ||
              (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31) ||
              (parts[0] == 192 && parts[1] == 168));
      final privateV6 =
          literal.type == InternetAddressType.IPv6 &&
          (literal.address == '::' ||
              literal.address.toLowerCase().startsWith('fc') ||
              literal.address.toLowerCase().startsWith('fd'));
      if (literal.isLoopback ||
          literal.isLinkLocal ||
          literal.isMulticast ||
          privateV4 ||
          privateV6) {
        throw const FormatException(
          'Private repository hosts are not allowed.',
        );
      }
    }
    return uri.toString();
  }
}
