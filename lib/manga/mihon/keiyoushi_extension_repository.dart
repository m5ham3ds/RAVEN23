import 'dart:convert';

import 'package:dio/dio.dart';

import 'mihon_pb_index.dart';

/// The Keiyoushi repository is a Mihon protobuf index, not a video-provider
/// JSON manifest. Keep its data model and fetch pipeline isolated from the
/// six existing RAVEN video repositories.
class MangaExtensionSource {
  const MangaExtensionSource({
    required this.name,
    required this.language,
    required this.homeUrl,
  });

  final String name;
  final String language;
  final String homeUrl;
}

class MangaExtensionEntry {
  const MangaExtensionEntry({
    required this.name,
    required this.packageName,
    required this.version,
    required this.versionCode,
    required this.apkUrl,
    required this.sources,
    required this.isNsfw,
    this.signingKey,
  });

  final String name;
  final String packageName;
  final String version;
  final int versionCode;
  final String apkUrl;
  final List<MangaExtensionSource> sources;
  final bool isNsfw;

  /// SHA-256 certificate fingerprint published by this repository.
  final String? signingKey;
  bool get canInstall {
    final key = signingKey?.trim().replaceAll(':', '');
    final validPackage = RegExp(
      r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$',
    ).hasMatch(packageName);
    final uri = Uri.tryParse(apkUrl);
    return validPackage &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        key != null &&
        RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(key);
  }

  List<String> get languages => sources
      .map((source) => source.language)
      .where((language) => language.isNotEmpty)
      .toSet()
      .toList(growable: false);

  factory MangaExtensionEntry.fromIndex(
    Map<String, dynamic> json, {
    String? signingKey,
  }) {
    final resources = json['resources'] is Map
        ? Map<String, dynamic>.from(json['resources'] as Map)
        : const <String, dynamic>{};
    final rawSources = json['sources'] as List? ?? const <dynamic>[];
    final sources = <MangaExtensionSource>[];
    for (final raw in rawSources) {
      if (raw is! Map) continue;
      final source = Map<String, dynamic>.from(raw);
      final name = '${source['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      sources.add(
        MangaExtensionSource(
          name: name,
          language: '${source['language'] ?? ''}'.trim(),
          homeUrl: '${source['homeUrl'] ?? ''}'.trim(),
        ),
      );
    }
    final warning = json['contentWarning'];
    final apkUrl = '${resources['apkUrl'] ?? ''}'.trim();
    return MangaExtensionEntry(
      name: '${json['name'] ?? ''}'.trim(),
      packageName: '${json['packageName'] ?? ''}'.trim(),
      version: '${json['versionName'] ?? ''}'.trim(),
      versionCode: _intValue(json['versionCode']),
      apkUrl: apkUrl,
      sources: List<MangaExtensionSource>.unmodifiable(sources),
      isNsfw: warning == 'CONTENT_WARNING_NSFW' || warning == 3,
      signingKey: signingKey,
    );
  }

  static int _intValue(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

String? parseMihonRepositorySigningFingerprint(Object? payload) {
  Object? decoded = payload;
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      return null;
    }
  }
  if (decoded is! Map) return null;
  final meta = decoded['meta'];
  if (meta is! Map) return null;
  // This exact field is the repository's documented trust anchor. Do not
  // accept protobuf fields, legacy aliases, or similarly named root values.
  final raw = '${meta['signingKeyFingerprint'] ?? ''}'
      .trim()
      .replaceAll(':', '');
  return RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(raw) ? raw.toLowerCase() : null;
}

class KeiyoushiExtensionRepository {
  KeiyoushiExtensionRepository({Dio? dio}) : _dio = dio ?? _newDio();

  static const String indexUrl =
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb';
  static const String projectUrl = 'https://github.com/keiyoushi/extensions';

  final Dio _dio;
  static Dio _newDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const <String, String>{
        'Accept': 'application/octet-stream',
        'User-Agent': 'RAVEN23/4.x manga repository catalogue',
      },
    ),
  );

  Future<List<MangaExtensionEntry>> fetchExtensions({
    String repositoryUrl = indexUrl,
  }) async {
    final response = await _dio.get<List<int>>(
      repositoryUrl,
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.statusCode == 429) {
      throw StateError('Mihon repository rate limit reached: $repositoryUrl');
    }
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw StateError(
        'Mihon index could not be fetched from $repositoryUrl (${response.statusCode}).',
      );
    }
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw FormatException(
        'Mihon repository returned an empty index: $repositoryUrl',
      );
    }
    final decoded = decodeMihonPbRepositoryIndex(bytes);
    String? signingKey;
    // The protobuf field 3 is deliberately not trusted as signer metadata.
    // Keiyoushi publishes the canonical SHA-256 fingerprint in repo.json:
    // { "index_v2": ".../index.pb", "meta": { "signingKeyFingerprint": "..." } }.
    // If that sidecar is unavailable or invalid, listing remains possible but
    // every extension remains non-installable.
    try {
      final sidecarUrl = Uri.parse(
        repositoryUrl,
      ).resolve('repo.json').toString();
      // GitHub's raw-content endpoint may serve valid JSON with a
      // text/plain content type. Decode the body ourselves instead of relying
      // on Dio's content-type-gated ResponseType.json transformer.
      final metadata = await _dio.get<String>(
        sidecarUrl,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      signingKey = parseMihonRepositorySigningFingerprint(metadata.data);
    } catch (_) {
      signingKey = null;
    }
    final entries = decoded.extensions
        .map(
          (item) => MangaExtensionEntry.fromIndex(item, signingKey: signingKey),
        )
        .where(
          (entry) =>
              entry.name.isNotEmpty &&
              entry.packageName.isNotEmpty &&
              entry.apkUrl.startsWith('https://'),
        )
        .toList(growable: false);
    if (entries.isEmpty) {
      throw FormatException(
        'Mihon index decoded, but contained no valid extensions: $repositoryUrl',
      );
    }
    return entries;
  }
}
