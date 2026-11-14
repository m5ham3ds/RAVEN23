import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'keiyoushi_extension_repository.dart';

/// A loaded Mihon source exposed by the Android extension runtime.
class MihonSourceInfo {
  const MihonSourceInfo({
    required this.id,
    required this.name,
    required this.lang,
    required this.packageName,
    required this.baseUrl,
    this.version = '',
    this.isNsfw = false,
    this.headers = const <String, String>{},
    this.iconBase64,
  });

  final int id;
  final String name;
  final String lang;
  final String packageName;
  final String baseUrl;
  final String version;
  final bool isNsfw;
  final Map<String, String> headers;
  final String? iconBase64;

  factory MihonSourceInfo.fromJson(Map<String, dynamic> json) =>
      MihonSourceInfo(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: '${json['name'] ?? ''}',
        lang: '${json['lang'] ?? ''}',
        packageName: '${json['pkg'] ?? ''}',
        baseUrl: '${json['baseUrl'] ?? ''}',
        version: '${json['version'] ?? ''}',
        isNsfw: json['nsfw'] == true,
        headers:
            (json['headers'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const <String, String>{},
        iconBase64: (json['iconBase64'] as String?)?.trim().isNotEmpty == true
            ? (json['iconBase64'] as String).trim()
            : null,
      );
}

/// Android Mihon extension runtime. The native half owns extension class loading,
/// source instances, HTTP/cookies and page bytes; Flutter owns the screens/reader.
class MihonRuntimeService {
  MihonRuntimeService({Dio? dio, MethodChannel? channel})
    : _dio = dio ?? Dio(),
      _channel = channel ?? const MethodChannel('raven23/mihon');

  static final MihonRuntimeService instance = MihonRuntimeService();

  final Dio _dio;
  final MethodChannel _channel;
  bool get supportsNativeExtensions => Platform.isAndroid;
  Directory? _extensionDirectory;
  bool _loaded = false;
  Future<void>? _initializing;

  Future<Directory> _directory() async {
    final cached = _extensionDirectory;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/mihon');
    await directory.create(recursive: true);
    _extensionDirectory = directory;
    return directory;
  }

  Future<void> initialize({bool force = false}) async {
    if (_loaded && !force) return;
    final active = _initializing;
    if (active != null) return active;
    final future = _initializeInternal();
    _initializing = future;
    try {
      await future;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    if (!Platform.isAndroid) {
      _loaded = true;
      return;
    }
    final directory = await _directory();
    await _channel.invokeMethod<void>('loadInstalled', <String, Object>{
      'dir': directory.path,
    });
    _loaded = true;
  }

  Future<List<MihonSourceInfo>> listSources({bool reload = false}) async {
    await initialize(force: reload);
    if (!Platform.isAndroid) return const <MihonSourceInfo>[];
    final raw = await _channel.invokeMethod<String>('listSources');
    if (raw == null || raw.isEmpty) return const <MihonSourceInfo>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <MihonSourceInfo>[];
    return decoded
        .whereType<Map>()
        .map(
          (value) => MihonSourceInfo.fromJson(Map<String, dynamic>.from(value)),
        )
        .where((source) => source.id > 0 && source.name.isNotEmpty)
        .toList(growable: false);
  }

  /// Downloads a signed extension into app-private storage, checks it against the
  /// repository's published SHA-256 signer fingerprint natively, then Dex-loads it.
  Future<void> installExtension(MangaExtensionEntry entry) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Mihon extensions are Android-only.');
    }
    if (!entry.canInstall) {
      throw StateError(
        'This repository has no valid SHA-256 signing fingerprint. Installation is disabled.',
      );
    }
    final uri = Uri.tryParse(entry.apkUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException('Extension download URL must use HTTPS.');
    }
    if (!RegExp(
      r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$',
    ).hasMatch(entry.packageName)) {
      throw FormatException('Invalid extension package name.');
    }

    final directory = await _directory();
    final target = File('${directory.path}/${entry.packageName}.apk');
    final temporary = File('${directory.path}/${entry.packageName}.download');
    final backup = File('${directory.path}/${entry.packageName}.backup');
    for (final file in <File>[temporary, backup]) {
      if (await file.exists()) await file.delete();
    }

    try {
      final cancelToken = CancelToken();
      await _dio.download(
        entry.apkUrl,
        temporary.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          // Keiyoushi extension APKs are small. Abort unexpectedly large payloads
          // before they can consume app-private storage on a mobile device.
          if (received > 64 * 1024 * 1024) {
            cancelToken.cancel(
              'Extension APK exceeds the 64 MiB safety limit.',
            );
          }
        },
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(seconds: 30),
          headers: const <String, String>{
            'User-Agent': 'RAVEN23 Mihon extension manager',
          },
        ),
        deleteOnError: true,
      );
      if (!await temporary.exists() ||
          await temporary.length() < 4096 ||
          await temporary.length() > 64 * 1024 * 1024) {
        throw const FormatException(
          'Downloaded extension APK is empty or truncated.',
        );
      }

      // Atomic swap: keep a working installed extension recoverable until the new
      // archive has passed Android's signature and Mihon ABI checks.
      if (await target.exists()) await target.rename(backup.path);
      await temporary.rename(target.path);
      try {
        await _channel.invokeMethod<void>('installExtension', <String, Object>{
          'apkPath': target.path,
          'packageName': entry.packageName,
          'signingKey': entry.signingKey!,
        });
        if (await backup.exists()) await backup.delete();
      } catch (_) {
        if (await target.exists()) await target.delete();
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
      _loaded = true;
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      if (await backup.exists() && !await target.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  Future<void> uninstallExtension(String packageName) async {
    if (!Platform.isAndroid) return;
    final directory = await _directory();
    final removed = await _channel.invokeMethod<bool>(
      'uninstallExtension',
      <String, Object>{'packageName': packageName, 'dir': directory.path},
    );
    if (removed != true) {
      throw StateError('Could not remove the installed extension APK.');
    }
  }

  Future<List<Map<String, dynamic>>> _jsonList(
    String method,
    Map<String, Object?> arguments,
  ) async {
    await initialize();
    final raw = await _channel.invokeMethod<String>(method, arguments);
    if (raw == null || raw.isEmpty) return const <Map<String, dynamic>>[];
    final data = jsonDecode(raw);
    if (data is! List) return const <Map<String, dynamic>>[];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> popular(int sourceId, {int page = 1}) =>
      _jsonList('getPopular', <String, Object?>{
        'sourceId': sourceId,
        'page': page,
      });

  Future<List<Map<String, dynamic>>> latest(int sourceId, {int page = 1}) =>
      _jsonList('getLatest', <String, Object?>{
        'sourceId': sourceId,
        'page': page,
      });

  Future<List<Map<String, dynamic>>> search(
    int sourceId,
    String query, {
    int page = 1,
    String? filtersJson,
  }) => _jsonList('search', <String, Object?>{
    'sourceId': sourceId,
    'query': query,
    'page': page,
    if (filtersJson != null) 'filters': filtersJson,
  });

  Future<List<Map<String, dynamic>>> filterList(int sourceId) async {
    await initialize();
    final raw = await _channel.invokeMethod<String>(
      'getFilterList',
      <String, Object>{'sourceId': sourceId},
    );
    if (raw == null || raw.isEmpty) return const <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> details(int sourceId, String url) async {
    await initialize();
    final raw = await _channel.invokeMethod<String>(
      'getDetails',
      <String, Object>{'sourceId': sourceId, 'url': url},
    );
    return raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<List<Map<String, dynamic>>> chapters(int sourceId, String mangaUrl) =>
      _jsonList('getChapters', <String, Object?>{
        'sourceId': sourceId,
        'url': mangaUrl,
      });

  Future<List<Map<String, dynamic>>> pages(int sourceId, String chapterUrl) =>
      _jsonList('getPages', <String, Object?>{
        'sourceId': sourceId,
        'url': chapterUrl,
      });

  Future<Uint8List> image(
    int sourceId,
    String url, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    await initialize();
    final bytes = await _channel.invokeMethod<Uint8List>(
      'getImage',
      <String, Object>{'sourceId': sourceId, 'url': url, 'headers': headers},
    );
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Image response is empty.');
    }
    return bytes;
  }

  Future<bool> hasSettings(int sourceId) async {
    await initialize();
    return await _channel.invokeMethod<bool>(
          'hasSourceSettings',
          <String, Object>{'sourceId': sourceId},
        ) ??
        false;
  }

  Future<void> openSettings(int sourceId) async {
    await initialize();
    await _channel.invokeMethod<void>('openSourceSettings', <String, Object>{
      'sourceId': sourceId,
    });
  }

  Future<bool> solveCloudflare(String url) async {
    await initialize();
    return await _channel.invokeMethod<bool>(
          'solveCloudflare',
          <String, Object>{'url': url},
        ) ??
        false;
  }

  Future<void> openSourceWebView(String url, {String? title}) async {
    await initialize();
    await _channel.invokeMethod<void>('openSourceWebView', <String, Object?>{
      'url': url,
      if (title != null) 'title': title,
    });
  }

  Future<List<Map<String, dynamic>>> readSourceSettings(int sourceId) async {
    await initialize();
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'readSourceSettings',
      <String, Object>{'sourceId': sourceId},
    );
    return (raw ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<bool> writeSourceSetting(
    int sourceId,
    String key,
    Object? value,
  ) async {
    await initialize();
    return await _channel.invokeMethod<bool>(
          'writeSourceSetting',
          <String, Object?>{'sourceId': sourceId, 'key': key, 'value': value},
        ) ??
        false;
  }

  Future<void> clearCache() async {
    try {
      await _channel.invokeMethod<void>('clearHttpCache');
    } catch (error) {
      debugPrint('[mihon] clear cache ignored: $error');
    }
  }
}
