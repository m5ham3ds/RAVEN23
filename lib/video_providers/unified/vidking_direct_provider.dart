import 'dart:convert';

import 'package:dio/dio.dart';

import '../../functions/video_utils.dart';

import 'media_identity.dart';
import 'source_manifest.dart';
import 'stream_option.dart';
import 'vidking_audio_quality_normalizer.dart';
import 'vidking_payload_cipher.dart';
import 'source_host_policy.dart';

/// Vidking direct API adapter based on OpenStream's MIT-licensed implementation.
/// The API host is intentionally fixed: repository entries may select a route,
/// but cannot redirect this engine to an arbitrary host.
class VidkingDirectProvider {
  VidkingDirectProvider({Dio? dio, SourceHostPolicy? hostPolicy})
    : _dio = dio ?? _createDio(),
      _hostPolicy = hostPolicy ?? const SourceHostPolicy();

  static const String apiBaseUrl = 'https://api.speedracelight.com';
  static const String origin = 'https://www.vidking.net';
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  final Dio _dio;
  final SourceHostPolicy _hostPolicy;
  static const int _maxResponseBytes = 8 * 1024 * 1024;
  final Map<int, _SeedCacheEntry> _seedCache = <int, _SeedCacheEntry>{};
  final Map<int, Future<_SeedCacheEntry>> _seedRequests =
      <int, Future<_SeedCacheEntry>>{};

  static Dio _createDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 12),
      followRedirects: false,
      maxRedirects: 0,
      responseType: ResponseType.plain,
      headers: const <String, String>{
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': userAgent,
      },
    ),
  );

  Future<List<UnifiedStreamOption>> resolve({
    required SourceManifest source,
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  }) async {
    final tmdbId = media.tmdbId;
    if (tmdbId == null || tmdbId <= 0) {
      throw const FormatException('Vidking requires a valid TMDB identifier.');
    }
    if (media.normalizedType != UnifiedMediaType.movie && !media.isEpisode) {
      throw const FormatException(
        'Vidking series streams require an exact season and episode number.',
      );
    }
    final route = _validatedRoute(source.engine.endpoint);
    final normalizedEngine = VidkingAudioQualityNormalizer.normalizeDescriptor(
      source.engine,
    );
    final normalizedUserPreference =
        VidkingAudioQualityNormalizer.normalizeAudioLanguage(
          preferredAudioLanguage,
        );
    final sourceAudioLanguage =
        VidkingAudioQualityNormalizer.normalizeAudioLanguage(
          normalizedEngine.audioLanguage,
        );
    final resolvedAudioLanguage =
        VidkingAudioQualityNormalizer.resolveAudioLanguage(
          preferredAudioLanguage: preferredAudioLanguage,
          engine: normalizedEngine,
        );
    // Keep the exact legacy engine selector on the wire when it is the only
    // available source value. Its canonical form is still used for stream
    // metadata, while explicit/user-selected audio values use canonical names.
    final legacyRequestLanguage = source.engine.language?.trim();
    final requestLanguage =
        normalizedUserPreference ??
        sourceAudioLanguage ??
        (legacyRequestLanguage?.isNotEmpty == true
            ? legacyRequestLanguage
            : resolvedAudioLanguage);
    final seed = await _seed(tmdbId, cancelToken: cancelToken);
    var response = await _requestSources(
      route: route,
      media: media,
      seed: seed,
      requestLanguage: requestLanguage,
      cancelToken: cancelToken,
    );

    if (response.statusCode == 401) {
      final refreshedSeed = await _seed(
        tmdbId,
        forceRefresh: true,
        cancelToken: cancelToken,
      );
      response = await _requestSources(
        route: route,
        media: media,
        seed: refreshedSeed,
        requestLanguage: requestLanguage,
        cancelToken: cancelToken,
      );
      return _decodeResponse(
        response,
        refreshedSeed.value,
        tmdbId,
        source,
        preferredAudioLanguage: preferredAudioLanguage,
      );
    }
    return _decodeResponse(
      response,
      seed.value,
      tmdbId,
      source,
      preferredAudioLanguage: preferredAudioLanguage,
    );
  }

  Future<Response<String>> _requestSources({
    required String route,
    required MediaIdentity media,
    required _SeedCacheEntry seed,
    String? requestLanguage,
    CancelToken? cancelToken,
  }) {
    final uri = Uri.parse('$apiBaseUrl/$route').replace(
      queryParameters: <String, String>{
        'title': media.title,
        'mediaType': media.normalizedType == UnifiedMediaType.movie
            ? 'movie'
            : 'tv',
        'year': media.year?.toString() ?? '',
        // The VidKing movie endpoint historically accepts these placeholders;
        // series requests are validated above and always send exact values.
        'episodeId': media.normalizedType == UnifiedMediaType.movie
            ? '1'
            : media.episodeNumber!.toString(),
        'seasonId': media.normalizedType == UnifiedMediaType.movie
            ? '1'
            : media.seasonNumber!.toString(),
        'tmdbId': media.tmdbId.toString(),
        'imdbId': media.imdbId ?? '',
        'enc': '2',
        'seed': seed.value,
        '_t': DateTime.now().millisecondsSinceEpoch.toString(),
        if (requestLanguage != null) 'language': requestLanguage,
      },
    );
    return _safeGet(
      uri.toString(),
      cancelToken: cancelToken,
      headers: <String, String>{
        'User-Agent': userAgent,
        'Referer': '$origin/',
        'Origin': origin,
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      },
    );
  }

  Future<Response<String>> _safeGet(
    String url, {
    CancelToken? cancelToken,
    Map<String, String> headers = const <String, String>{},
  }) async {
    var currentUri = await _hostPolicy.validate(url);
    final requestToken = cancelToken ?? CancelToken();
    for (var redirect = 0; ; redirect++) {
      var exceededLimit = false;
      late Response<String> response;
      try {
        response = await _dio.get<String>(
          currentUri.toString(),
          cancelToken: requestToken,
          onReceiveProgress: (received, _) {
            if (received > _maxResponseBytes && !requestToken.isCancelled) {
              exceededLimit = true;
              requestToken.cancel('VidKing response exceeded 8 MB.');
            }
          },
          options: Options(
            headers: headers,
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 20),
            followRedirects: false,
            maxRedirects: 0,
            validateStatus: (_) => true,
          ),
        );
      } on DioException {
        if (exceededLimit) {
          throw const FormatException(
            'VidKing response exceeds the 8 MB safety limit.',
          );
        }
        rethrow;
      }
      final status = response.statusCode ?? 0;
      final location = response.headers.value('location');
      if (status >= 300 && status < 400 && location != null) {
        if (redirect >= _hostPolicy.maxRedirects) {
          throw const FormatException('VidKing exceeded the redirect limit.');
        }
        final nextUri = await _hostPolicy.validate(
          currentUri.resolve(location).toString(),
        );
        if (currentUri.scheme == 'https' && nextUri.scheme != 'https') {
          throw const FormatException(
            'VidKing HTTPS downgrade redirects are blocked.',
          );
        }
        currentUri = nextUri;
        continue;
      }
      if (utf8.encode(response.data ?? '').length > _maxResponseBytes) {
        throw const FormatException(
          'VidKing response exceeds the 8 MB safety limit.',
        );
      }
      return response;
    }
  }

  Future<_SeedCacheEntry> _seed(
    int mediaId, {
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    // Every direct route for one title shares a seed. If several endpoints
    // answer 401 together, only one refreshed seed request may be in flight;
    // parallel refreshes can otherwise invalidate one another at the API.
    final inFlight = _seedRequests[mediaId];
    if (inFlight != null) return inFlight;
    final now = DateTime.now();
    final cached = _seedCache[mediaId];
    if (!forceRefresh &&
        cached != null &&
        cached.expiresAt.isAfter(now.add(const Duration(seconds: 5)))) {
      return cached;
    }

    final request = () async {
      final uri = Uri.parse('$apiBaseUrl/seed').replace(
        queryParameters: <String, String>{'mediaId': mediaId.toString()},
      );
      final response = await _safeGet(uri.toString(), cancelToken: cancelToken);
      if ((response.statusCode ?? 500) < 200 ||
          (response.statusCode ?? 500) >= 300) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message:
              'Vidking seed endpoint returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(response.data ?? '') as Map<String, dynamic>;
      final value = (decoded['seed'] ?? '').toString();
      if (value.isEmpty) throw const FormatException('Vidking seed is empty.');
      final ttlMs = (decoded['ttlMs'] as num?)?.toInt() ?? 30000;
      final entry = _SeedCacheEntry(
        value: value,
        expiresAt: DateTime.now().add(
          Duration(milliseconds: ttlMs.clamp(1000, 300000).toInt()),
        ),
      );
      _seedCache[mediaId] = entry;
      return entry;
    }();
    _seedRequests[mediaId] = request;
    try {
      return await request;
    } finally {
      if (identical(_seedRequests[mediaId], request)) {
        _seedRequests.remove(mediaId);
      }
    }
  }

  List<UnifiedStreamOption> _decodeResponse(
    Response<String> response,
    String seed,
    int mediaId,
    SourceManifest source, {
    String? preferredAudioLanguage,
  }) {
    final status = response.statusCode ?? 500;
    if (status < 200 || status >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: '${source.name} returned HTTP $status.',
      );
    }
    final body = response.data ?? '';
    if (body.trim().isEmpty) {
      throw const FormatException('Vidking payload is empty.');
    }
    final decoded = jsonDecode(
      VidkingPayloadCipher.decrypt(body, seed, mediaId),
    );
    if (decoded is! Map) {
      throw FormatException(
        '${source.name} returned HTTP $status, but the decrypted payload was not a JSON object.',
      );
    }
    final payload = Map<String, dynamic>.from(decoded);
    final streams = _toStreams(
      payload,
      source,
      preferredAudioLanguage: preferredAudioLanguage,
    );
    if (streams.isEmpty) {
      final rawSources = payload['sources'];
      final sourceCount = rawSources is List ? rawSources.length : 0;
      final playlist = (payload['playlist'] ?? '').toString();
      final hasPlaylist = _isPublicHttpUrl(playlist);
      final qualityFilter = VidkingAudioQualityNormalizer.normalizeDescriptor(
        source.engine,
      ).qualityFilter;
      throw FormatException(
        '${source.name} returned HTTP $status but no usable stream. '
        'sourceEntries=$sourceCount, masterPlaylist=${hasPlaylist ? 'present' : 'absent'}'
        '${qualityFilter == null || qualityFilter.isEmpty ? '' : ', qualityFilter=$qualityFilter'}.',
      );
    }
    return streams;
  }

  List<UnifiedStreamOption> _toStreams(
    Map<String, dynamic> payload,
    SourceManifest source, {
    String? preferredAudioLanguage,
  }) {
    final rawSources = payload['sources'];
    final rawSubtitles = payload['subtitles'];
    final sources = rawSources is List
        ? rawSources
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList()
        : <Map<String, dynamic>>[];
    final subtitles = <UnifiedSubtitleTrack>[
      if (rawSubtitles is List)
        for (final raw in rawSubtitles.whereType<Map>())
          if ((raw['url'] ?? '').toString().startsWith('http'))
            UnifiedSubtitleTrack(
              url: (raw['url']).toString(),
              language: (raw['lang'] ?? 'und').toString(),
              label: (raw['label'] ?? raw['lang'] ?? 'Subtitle').toString(),
              headers: _requestHeaders,
            ),
    ];

    final engine = VidkingAudioQualityNormalizer.normalizeDescriptor(
      source.engine,
    );
    final qualityFilter = engine.qualityFilter;
    final hasSpecificQuality =
        VidkingAudioQualityNormalizer.qualityFilterHeight(qualityFilter) !=
        null;
    final selectedAudioLanguage =
        VidkingAudioQualityNormalizer.resolveAudioLanguage(
          preferredAudioLanguage: preferredAudioLanguage,
          engine: engine,
        );
    final playlist = (payload['playlist'] ?? '').toString();
    if ((Uri.tryParse(playlist)?.scheme == 'https' ||
            Uri.tryParse(playlist)?.scheme == 'http') &&
        Uri.tryParse(playlist)?.host.isNotEmpty == true &&
        !hasSpecificQuality &&
        sources.isNotEmpty) {
      final qualities = sources
          .map((entry) => (entry['quality'] ?? '').toString())
          .where((value) => value.isNotEmpty)
          .toList();
      final best = qualities.isEmpty ? 'Auto' : _bestQuality(qualities);
      return <UnifiedStreamOption>[
        UnifiedStreamOption(
          id: 'vidking-${source.id}-master',
          providerId: 'vidking-${source.id}',
          providerName: source.name,
          url: playlist,
          label: '${source.name} · Adaptive',
          quality: best,
          container: StreamContainer.hls,
          headers: _requestHeaders,
          audioKind: StreamAudioKind.unknown,
          audioLanguage: selectedAudioLanguage,
          subtitles: subtitles,
          expiresAt: parseStreamExpiry(
            payload['expiresAt'] ??
                payload['expires_at'] ??
                payload['expiry'] ??
                payload['expiration'],
          ),
          metadata: <String, dynamic>{
            'adaptiveMaster': true,
            'availableHeights': qualities
                .map(_qualityHeight)
                .whereType<int>()
                .toSet()
                .toList(growable: false),
          },
        ),
      ];
    }

    final output = <UnifiedStreamOption>[];
    for (var index = 0; index < sources.length; index++) {
      final entry = sources[index];
      final url = (entry['url'] ?? '').toString().trim();
      final uri = Uri.tryParse(url);
      if (uri == null ||
          (uri.scheme != 'https' && uri.scheme != 'http') ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        continue;
      }
      final rawQuality = (entry['quality'] ?? 'Auto').toString();
      if (!VidkingAudioQualityNormalizer.matchesQualityFilter(
        filter: qualityFilter,
        streamQuality: rawQuality,
      )) {
        continue;
      }
      final sourceType = (entry['type'] ?? '').toString().toLowerCase();
      final container = _container(url, sourceType);
      final audioDescription = <String>[
        entry['audioKind']?.toString() ?? '',
        entry['audioType']?.toString() ?? '',
        entry['label']?.toString() ?? '',
      ].where((value) => value.isNotEmpty).join(' ');
      final streamAudioLanguage =
          VidkingAudioQualityNormalizer.normalizeAudioLanguage(
            entry['audioLanguage'] ?? entry['language'] ?? entry['lang'],
          );
      output.add(
        UnifiedStreamOption(
          id: 'vidking-${source.id}-$index-${url.hashCode}',
          providerId: 'vidking-${source.id}',
          providerName: source.name,
          url: url,
          label: '${source.name} · $rawQuality',
          quality: rawQuality,
          height: _qualityHeight(rawQuality),
          container: container,
          headers: _requestHeaders,
          audioKind: _audioKind(audioDescription),
          audioLanguage: streamAudioLanguage ?? selectedAudioLanguage,
          subtitles: subtitles,
          expiresAt: parseStreamExpiry(
            entry['expiresAt'] ??
                entry['expires_at'] ??
                entry['expiry'] ??
                entry['expiration'] ??
                payload['expiresAt'] ??
                payload['expires_at'] ??
                payload['expiry'] ??
                payload['expiration'],
          ),
          metadata: <String, dynamic>{
            'sourceType': sourceType,
            'isDownloadable': !url
                .split('?')
                .first
                .toLowerCase()
                .endsWith('.mpd'),
          },
        ),
      );
    }
    return output;
  }

  static const Map<String, String> _requestHeaders = <String, String>{
    'User-Agent': userAgent,
    'Referer': '$origin/',
    'Origin': origin,
  };

  static String _validatedRoute(String endpoint) {
    final value = endpoint.trim().replaceAll('\\', '/');
    final uri = Uri.tryParse(value);
    if (value.isEmpty ||
        uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        value.startsWith('/') ||
        uri.pathSegments.any((segment) => segment == '..' || segment == '.')) {
      throw const FormatException('Vidking route is invalid.');
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) {
      throw const FormatException('Vidking route is empty.');
    }
    return segments.join('/');
  }

  static bool _isPublicHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static StreamContainer _container(String url, String sourceType) {
    final lower = url.toLowerCase().split('?').first;
    if (sourceType.contains('m3u8') || lower.endsWith('.m3u8')) {
      return StreamContainer.hls;
    }
    if (sourceType.contains('mpd') || lower.endsWith('.mpd')) {
      return StreamContainer.dash;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) {
      return StreamContainer.mp4;
    }
    if (lower.endsWith('.webm')) return StreamContainer.webm;
    return StreamContainer.unknown;
  }

  static StreamAudioKind _audioKind(String? value) {
    final lower = (value ?? '').toLowerCase();
    if (lower.contains('dub')) return StreamAudioKind.dub;
    if (lower.contains('sub')) return StreamAudioKind.sub;
    if (lower.contains('raw')) return StreamAudioKind.raw;
    return StreamAudioKind.unknown;
  }

  static String _bestQuality(List<String> values) {
    int rank(String value) => _qualityHeight(value) ?? 0;
    return values.reduce((a, b) => rank(a) >= rank(b) ? a : b);
  }

  static int? _qualityHeight(String value) =>
      VideoUtils.videoQualityHeight(value);
}

class _SeedCacheEntry {
  const _SeedCacheEntry({required this.value, required this.expiresAt});

  final String value;
  final DateTime expiresAt;
}
