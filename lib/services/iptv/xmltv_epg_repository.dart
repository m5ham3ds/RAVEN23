import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/xmltv_epg.dart';
import '../../video_providers/unified/source_host_policy.dart';
import 'xmltv_epg_parser.dart';

/// Downloads, parses and caches XMLTV feeds with per-redirect host validation.
class XmlTvEpgRepository {
  XmlTvEpgRepository({
    SharedPreferences? preferences,
    http.Client? client,
    SourceHostPolicy hostPolicy = const SourceHostPolicy(),
    XmlTvEpgParser parser = const XmlTvEpgParser(),
    this.cacheTtl = const Duration(hours: 6),
    this.staleLimit = const Duration(days: 3),
  }) : _preferences = preferences,
       _client = client ?? http.Client(),
       _hostPolicy = hostPolicy,
       _parser = parser;

  static const int maxFeedBytes = 8 * 1024 * 1024;
  static const int maxCachedBytes = 4 * 1024 * 1024;
  static const int maxEncodedCacheChars = ((maxCachedBytes + 2) ~/ 3) * 4 + 8;
  static const int _maxRedirects = 4;

  final SharedPreferences? _preferences;
  final http.Client _client;
  final SourceHostPolicy _hostPolicy;
  final XmlTvEpgParser _parser;
  final Duration cacheTtl;
  final Duration staleLimit;
  SharedPreferences? _resolvedPreferences;
  bool _closed = false;

  Future<SharedPreferences> get _prefs async {
    if (_preferences != null) return _preferences;
    return _resolvedPreferences ??= await SharedPreferences.getInstance();
  }

  String _cacheKey(String namespace, Uri uri) {
    final digest = sha256.convert(utf8.encode('$namespace|${uri.toString()}'));
    return 'xmltv_cache_v1_${digest.toString()}';
  }

  Future<XmlTvLoadResult> load(
    String rawUrl, {
    String namespace = 'iptv_m3u',
    bool refresh = false,
  }) async {
    _ensureOpen();
    final initialUri = await _hostPolicy.validate(rawUrl.trim());
    final key = _cacheKey(namespace, initialUri);
    final cached = await _readCache(key, initialUri);
    final now = DateTime.now().toUtc();
    if (!refresh &&
        cached != null &&
        now.difference(cached.fetchedAt) <= cacheTtl) {
      return cached;
    }

    try {
      return await _fetch(initialUri, key: key, cached: cached);
    } on Object {
      if (cached != null && now.difference(cached.fetchedAt) <= staleLimit) {
        return XmlTvLoadResult(
          guide: cached.guide,
          fetchedAt: cached.fetchedAt,
          sourceUri: initialUri,
          isStale: true,
        );
      }
      rethrow;
    }
  }

  Future<XmlTvLoadResult> _fetch(
    Uri initialUri, {
    required String key,
    required XmlTvLoadResult? cached,
  }) async {
    var current = initialUri;
    var redirects = 0;
    while (true) {
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(<String, String>{
          'Accept': 'application/xml, text/xml;q=0.9, */*;q=0.5',
          'User-Agent': 'RAVEN23-XMLTV/1.0',
        });
      if (cached != null && current == initialUri) {
        final metadata = await _readMetadata(key);
        final etag = metadata['etag']?.toString();
        final modified = metadata['lastModified']?.toString();
        if (etag != null && etag.isNotEmpty) {
          request.headers['If-None-Match'] = etag;
        }
        if (modified != null && modified.isNotEmpty) {
          request.headers['If-Modified-Since'] = modified;
        }
      }

      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 25));
      if (_isRedirect(response.statusCode)) {
        final location = response.headers['location'];
        await response.stream.drain<void>();
        if (location == null ||
            location.isEmpty ||
            redirects >= _maxRedirects) {
          throw const FormatException('XMLTV redirect chain is invalid.');
        }
        current = await _hostPolicy.validate(
          current.resolve(location).toString(),
        );
        redirects++;
        continue;
      }

      if (response.statusCode == 304 && cached != null) {
        await response.stream.drain<void>();
        final refreshedAt = DateTime.now().toUtc();
        final priorMetadata = await _readMetadata(key);
        await _writeCache(
          key,
          cached.guide,
          fetchedAt: refreshedAt,
          etag: response.headers['etag'] ?? priorMetadata['etag']?.toString(),
          lastModified:
              response.headers['last-modified'] ??
              priorMetadata['lastModified']?.toString(),
        );
        return XmlTvLoadResult(
          guide: cached.guide,
          fetchedAt: refreshedAt,
          sourceUri: initialUri,
        );
      }
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw HttpException('XMLTV feed returned HTTP ${response.statusCode}.');
      }
      final declaredLength = int.tryParse(
        response.headers['content-length'] ?? '',
      );
      if (declaredLength != null && declaredLength > maxFeedBytes) {
        await response.stream.drain<void>();
        throw const FormatException('XMLTV feed exceeds the 8 MiB limit.');
      }
      final bytes = await _readBounded(response.stream);
      final text = utf8.decode(bytes, allowMalformed: false);
      final guide = _parser.parse(text);
      final fetchedAt = DateTime.now().toUtc();
      await _writeCache(
        key,
        guide,
        fetchedAt: fetchedAt,
        // Validators belong to the exact requested URI. Do not persist a
        // redirected endpoint's ETag and then send it to the original host.
        etag: redirects == 0 ? response.headers['etag'] : null,
        lastModified: redirects == 0 ? response.headers['last-modified'] : null,
      );
      return XmlTvLoadResult(
        guide: guide,
        fetchedAt: fetchedAt,
        sourceUri: initialUri,
      );
    }
  }

  Future<List<int>> _readBounded(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in stream.timeout(const Duration(seconds: 20))) {
      total += chunk.length;
      if (total > maxFeedBytes) {
        throw const FormatException('XMLTV feed exceeds the 8 MiB limit.');
      }
      builder.add(chunk);
    }
    if (total == 0) throw const FormatException('XMLTV feed is empty.');
    return builder.takeBytes();
  }

  Future<XmlTvLoadResult?> _readCache(String key, Uri sourceUri) async {
    final encoded = (await _prefs).getString(key);
    if (encoded == null ||
        encoded.isEmpty ||
        encoded.length > maxEncodedCacheChars) {
      return null;
    }
    try {
      final compressed = base64.decode(encoded);
      final jsonBytes = gzip.decode(compressed);
      final decoded = jsonDecode(utf8.decode(jsonBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final fetchedAt = DateTime.tryParse(
        decoded['fetchedAt']?.toString() ?? '',
      );
      final guideJson = decoded['guide'];
      if (fetchedAt == null || guideJson is! Map<String, dynamic>) return null;
      return XmlTvLoadResult(
        guide: XmlTvGuide.fromJson(guideJson),
        fetchedAt: fetchedAt.toUtc(),
        sourceUri: sourceUri,
      );
    } on Object {
      return null;
    }
  }

  Future<Map<String, dynamic>> _readMetadata(String key) async {
    final cached = (await _prefs).getString('${key}_meta');
    if (cached == null) return <String, dynamic>{};
    try {
      // Metadata is stored separately from the compressed body.
      final decoded = jsonDecode(cached);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  Future<void> _writeCache(
    String key,
    XmlTvGuide guide, {
    required DateTime fetchedAt,
    String? etag,
    String? lastModified,
  }) async {
    final preferences = await _prefs;
    final body = utf8.encode(
      jsonEncode(<String, dynamic>{
        'fetchedAt': fetchedAt.toIso8601String(),
        'guide': guide.toJson(),
      }),
    );
    final compressed = gzip.encode(body);
    if (compressed.length > maxCachedBytes) {
      await preferences.remove(key);
      return;
    }
    await preferences.setString(key, base64.encode(compressed));
    await preferences.setString(
      '${key}_meta',
      jsonEncode(<String, dynamic>{'etag': etag, 'lastModified': lastModified}),
    );
  }

  bool _isRedirect(int statusCode) =>
      statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;

  void _ensureOpen() {
    if (_closed) throw StateError('XMLTV EPG repository is closed.');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }
}
