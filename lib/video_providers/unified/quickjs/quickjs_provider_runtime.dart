import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../source_manifest.dart';
import '../source_host_policy.dart';
import '../source_repository_revision.dart';
import 'crypto_ops.dart';
import 'js_bootstrap.dart';
import 'js_engine.dart';
import 'quickjs_exception.dart';
import 'quickjs_extension_settings.dart';

/// Runs Zangetsu-compatible JavaScript video providers in a single serialized
/// QuickJS runtime. Network access is mediated by Dio; scripts never receive
/// Flutter objects or application credentials.
class QuickJsProviderRuntime {
  QuickJsProviderRuntime({
    Dio? dio,
    QuickJsExtensionSettingsStore? settingsStore,
    SourceHostPolicy? hostPolicy,
    SourceRepositoryArtifactStore? artifactStore,
  }) : _dio = dio ?? Dio(),
       _settingsStore = settingsStore ?? QuickJsExtensionSettingsStore.instance,
       _hostPolicy = hostPolicy ?? const SourceHostPolicy(),
       _artifactStore = artifactStore ?? SourceRepositoryArtifactStore();

  static const Duration _maxCallTime = Duration(seconds: 65);
  static const int _maxScriptBytes = 1536 * 1024;
  static const int _maxResponseBytes = 8 * 1024 * 1024;
  static const Map<String, String> _extractorAssets = <String, String>{
    'doodstream': 'assets/video_providers/extractors/doodstream.js',
    'mp4upload': 'assets/video_providers/extractors/mp4upload.js',
    'okru': 'assets/video_providers/extractors/okru.js',
    'streamlare': 'assets/video_providers/extractors/streamlare.js',
    'filemoon': 'assets/video_providers/extractors/filemoon.js',
    'streamwish': 'assets/video_providers/extractors/streamwish.js',
    'voe': 'assets/video_providers/extractors/voe.js',
    'vidmoly': 'assets/video_providers/extractors/vidmoly.js',
    'example_embed': 'assets/video_providers/extractors/example_embed.js',
  };

  final Dio _dio;
  final QuickJsExtensionSettingsStore _settingsStore;
  final SourceHostPolicy _hostPolicy;
  final SourceRepositoryArtifactStore _artifactStore;
  final Map<String, QuickJsSettingsSchema?> _settingsSchemaCache =
      <String, QuickJsSettingsSchema?>{};
  final Map<String, Set<String>> _sensitiveSettingsBySource =
      <String, Set<String>>{};
  late final JsEngine _engine = JsEngine(onChannel: _onChannel);
  Future<void> _tail = Future<void>.value();
  final Set<String> _loadedSources = <String>{};
  bool _extractorsLoaded = false;
  bool _disposed = false;
  CancelToken? _activeCancelToken;

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        if (_disposed) {
          throw const JsRuntimeException('JavaScript runtime is closed.');
        }
        completer.complete(await operation());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<void> ensureProviderLoaded(
    SourceManifest source, {
    CancelToken? cancelToken,
  }) async {
    final sourceId = _runtimeSourceId(source);
    if (_loadedSources.contains(sourceId)) return;
    final scriptUrl = source.engine.endpoint.trim();
    await _validateHttpUrl(scriptUrl);

    final response = await _requestWithSafeRedirects(
      scriptUrl,
      method: 'GET',
      cancelToken: cancelToken,
      headers: const <String, String>{
        'Accept': 'text/javascript, application/javascript, */*',
      },
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      maxResponseBytes: _maxScriptBytes,
    );
    final script = response.data ?? '';
    if (script.trim().isEmpty) {
      throw const FormatException('Provider script is empty.');
    }
    if (utf8.encode(script).length > _maxScriptBytes) {
      throw const FormatException(
        'Provider script exceeds the 1.5 MB safety limit.',
      );
    }
    try {
      await _artifactStore.saveProviderScript(
        sourceStableKey: source.stableKey,
        scriptUrl: response.realUri.toString(),
        script: script,
      );
    } catch (_) {
      // Audit storage must not take down an otherwise valid provider. The
      // script remains hash-checked in memory for this runtime session only.
      debugPrint('[quickjs] provider script revision could not be persisted');
    }

    await _serialized(() async {
      if (_loadedSources.contains(sourceId)) return;
      await _engine.ready;
      await _loadBundledExtractors();
      final result = await _engine.eval(wrapProviderSource(sourceId, script));
      if (result.isError) {
        throw JsRuntimeException(
          'Provider ${source.name} failed to load: ${result.value}',
        );
      }
      _loadedSources.add(sourceId);
    });
  }

  Future<void> _loadBundledExtractors() async {
    if (_extractorsLoaded) return;
    for (final entry in _extractorAssets.entries) {
      try {
        final script = await rootBundle.loadString(entry.value);
        final result = await _engine.eval(
          wrapExtractorSource(entry.key, script),
        );
        if (result.isError) {
          debugPrint(
            '[quickjs] extractor ${entry.key} failed: ${result.value}',
          );
        }
      } catch (error) {
        debugPrint('[quickjs] extractor ${entry.key} unavailable: $error');
      }
    }
    _extractorsLoaded = true;
  }

  Future<dynamic> call(
    SourceManifest source,
    String method,
    List<Object?> arguments, {
    Duration timeout = _maxCallTime,
    CancelToken? cancelToken,
  }) async {
    await ensureProviderLoaded(source, cancelToken: cancelToken);
    final sourceId = _runtimeSourceId(source);
    return _serialized(() async {
      _activeCancelToken = cancelToken;
      try {
        await _engine.ready;

        // Settings are discovered from the provider's own getSettings() contract.
        // A malformed/absent schema never blocks ordinary provider operations.
        if (method != 'getSettings') {
          final schema = await _settingsSchemaFor(sourceId);
          if (schema != null && schema.fields.isNotEmpty) {
            final values = await _settingsStore.load(source, schema);
            final missingRequired = schema.missingRequired(values);
            if (missingRequired.isNotEmpty) {
              throw JsRuntimeException(
                'Configure required extension settings first: ${missingRequired.join(', ')}.',
              );
            }
            _sensitiveSettingsBySource[sourceId] = <String>{
              for (final field in schema.fields)
                if (field.sensitive)
                  ..._sensitiveValueStrings(values[field.key]),
            };
            final settingsJson = jsonEncode(values);
            final injected = await _engine.eval(
              '__setProviderSettingsT(${jsonEncode(sourceId)}, ${jsonEncode(settingsJson)});',
            );
            if (injected.isError) {
              throw JsRuntimeException(
                'Provider settings could not be injected safely.',
              );
            }
          }
        }

        return _invokeProviderInside(sourceId, method, arguments, timeout);
      } finally {
        _activeCancelToken = null;
      }
    });
  }

  Future<QuickJsSettingsSchema?> _settingsSchemaFor(String sourceId) async {
    if (_settingsSchemaCache.containsKey(sourceId)) {
      return _settingsSchemaCache[sourceId];
    }
    QuickJsSettingsSchema? schema;
    try {
      final raw = await _invokeProviderInside(
        sourceId,
        'getSettings',
        const <Object?>[],
        const Duration(seconds: 10),
      );
      schema = QuickJsSettingsSchema.parse(raw);
    } catch (_) {
      schema = null;
    }
    _settingsSchemaCache[sourceId] = schema;
    return schema;
  }

  Future<dynamic> _invokeProviderInside(
    String sourceId,
    String method,
    List<Object?> arguments,
    Duration timeout,
  ) async {
    final argsJson = jsonEncode(arguments);
    final expression =
        '__callProviderT('
        '${jsonEncode(sourceId)}, ${jsonEncode(method)}, '
        '${jsonEncode(argsJson)}, ${timeout.inMilliseconds})';
    final result = await _engine
        .callAsync(expression, timeout + const Duration(seconds: 3))
        .timeout(timeout + const Duration(seconds: 4));
    if (result.isError) throw JsRuntimeException(_unquote(result.value));
    final value = _unquote(result.value);
    if (value.isEmpty || value == 'null') return null;
    try {
      return jsonDecode(value);
    } on FormatException {
      return value;
    }
  }

  /// Extracts a supported hoster embed using the same QuickJS extractor
  /// registry used by Zangetsu provider scripts. Returns raw VideoSource maps.
  Future<dynamic> extractVideo(
    String url, {
    Map<String, dynamic> options = const <String, dynamic>{},
    Duration timeout = const Duration(seconds: 25),
    CancelToken? cancelToken,
  }) async {
    await _validateHttpUrl(url);
    return _serialized(() async {
      _activeCancelToken = cancelToken;
      try {
        await _engine.ready;
        await _loadBundledExtractors();
        final expression =
            '__callExtractorT('
            '${jsonEncode(url)}, ${jsonEncode(jsonEncode(options))}, '
            '${timeout.inMilliseconds})';
        final result = await _engine
            .callAsync(expression, timeout + const Duration(seconds: 3))
            .timeout(timeout + const Duration(seconds: 4));
        if (result.isError) throw JsRuntimeException(_unquote(result.value));
        final value = _unquote(result.value);
        if (value.isEmpty || value == 'null') return const <dynamic>[];
        try {
          return jsonDecode(value);
        } on FormatException {
          throw const FormatException('Host extractor returned invalid JSON.');
        }
      } finally {
        _activeCancelToken = null;
      }
    });
  }

  String _unquote(String value) {
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is String) return decoded;
      } catch (_) {}
    }
    return value;
  }

  void _onChannel(String channel, dynamic raw) {
    switch (channel) {
      case 'fetch':
        unawaited(_onFetch(raw));
      case 'crypto':
        _onCrypto(raw);
      case 'timer':
        _onTimer(raw);
      case 'console':
        _onConsole(raw);
    }
  }

  Map<String, dynamic> _payloadMap(dynamic raw) {
    if (raw is String) return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const FormatException('Invalid JavaScript bridge payload.');
  }

  Future<void> _onFetch(dynamic raw) async {
    String? id;
    try {
      final payload = _payloadMap(raw);
      id = payload['id']?.toString();
      final url = payload['url']?.toString() ?? '';
      final method = (payload['method'] ?? 'GET').toString().toUpperCase();
      if (!const <String>{
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
        'HEAD',
      }.contains(method)) {
        throw const FormatException(
          'Provider requested a disallowed HTTP method.',
        );
      }
      final rawHeaders = payload['headers'];
      final headers = _sanitizeProviderHeaders(rawHeaders);
      final body = payload['body'];
      final requestedTimeout = (payload['timeoutMs'] as num?)?.toInt() ?? 0;
      final timeoutMs = requestedTimeout <= 0
          ? 25000
          : requestedTimeout.clamp(1000, 25000).toInt();
      final response = await _requestWithSafeRedirects(
        url,
        method: method,
        data: body,
        headers: headers,
        cancelToken: _activeCancelToken,
        followRedirects: payload['followRedirects'] != false,
        receiveTimeout: Duration(milliseconds: timeoutMs),
        sendTimeout: Duration(milliseconds: timeoutMs),
        maxResponseBytes: _maxResponseBytes,
      );
      final data = response.data?.toString() ?? '';
      if (utf8.encode(data).length > _maxResponseBytes) {
        throw const FormatException(
          'Provider response exceeds the 8 MB safety limit.',
        );
      }
      final responsePayload = <String, dynamic>{
        'status': response.statusCode ?? 0,
        'statusText': response.statusMessage ?? '',
        'headers': <String, String>{
          for (final entry in response.headers.map.entries)
            entry.key: entry.value.join(', '),
        },
        'url': response.realUri.toString(),
        'body': data,
      };
      _engine.post(
        '__resolveFetch(${jsonEncode(id)}, ${jsonEncode(jsonEncode(responsePayload))});',
      );
    } catch (error) {
      if (id != null) {
        _engine.post(
          '__rejectFetch(${jsonEncode(id)}, ${jsonEncode(error.toString())});',
        );
      }
    }
  }

  void _onCrypto(dynamic raw) {
    String? id;
    try {
      final payload = _payloadMap(raw);
      id = payload['id']?.toString();
      final operation = payload['op']?.toString();
      late final String value;
      if (operation == 'sha256') {
        value = sha256Hex(payload['message']?.toString() ?? '');
      } else if (operation == 'aesCtrDecrypt') {
        value = aesCtrDecryptToString(
          keyHex: payload['keyHex']?.toString() ?? '',
          counterHex: payload['counterHex']?.toString() ?? '',
          data: Uint8List.fromList(
            base64Decode(payload['dataB64']?.toString() ?? ''),
          ),
        );
      } else {
        throw FormatException(
          'Unsupported provider crypto operation: $operation',
        );
      }
      _engine.post('__resolveCrypto(${jsonEncode(id)}, ${jsonEncode(value)});');
    } catch (error) {
      if (id != null) {
        _engine.post(
          '__rejectCrypto(${jsonEncode(id)}, ${jsonEncode(error.toString())});',
        );
      }
    }
  }

  void _onTimer(dynamic raw) {
    try {
      final payload = _payloadMap(raw);
      final id = payload['id']?.toString();
      final ms = (payload['ms'] as num?)?.toInt() ?? 0;
      if (id == null) return;
      Future<void>.delayed(
        Duration(milliseconds: ms.clamp(0, 60000).toInt()),
        () {
          if (!_disposed) _engine.post('__fireTimer(${jsonEncode(id)});');
        },
      );
    } catch (_) {}
  }

  void _onConsole(dynamic raw) {
    try {
      final payload = _payloadMap(raw);
      final source = (payload['__src'] ?? '?').toString();
      final level = (payload['level'] ?? 'log').toString();
      final message = (payload['message'] ?? '').toString();
      debugPrint(
        '[$source/js $level] ${_redactSensitiveSettings(source, message)}',
      );
    } catch (_) {}
  }

  Set<String> _sensitiveValueStrings(Object? value) {
    if (value == null) return const <String>{};
    if (value is List) {
      return <String>{
        for (final item in value) ..._sensitiveValueStrings(item),
      };
    }
    final text = value.toString();
    return text.isEmpty ? const <String>{} : <String>{text};
  }

  String _redactSensitiveSettings(String sourceId, String message) =>
      redactQuickJsSensitiveValues(
        message,
        _sensitiveSettingsBySource[sourceId] ?? const <String>{},
      );

  Future<void> _validateHttpUrl(String value) async {
    await _hostPolicy.validate(value);
  }

  Map<String, String> _sanitizeProviderHeaders(dynamic rawHeaders) {
    if (rawHeaders is! Map) return <String, String>{};
    const blocked = <String>{
      'host',
      'connection',
      'proxy-authorization',
      'proxy-connection',
      'transfer-encoding',
      'upgrade',
      'content-length',
    };
    final result = <String, String>{};
    for (final entry in rawHeaders.entries) {
      final name = entry.key.toString().trim();
      if (name.isEmpty || blocked.contains(name.toLowerCase())) continue;
      if (!RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]{1,80}$").hasMatch(name)) {
        continue;
      }
      final value = entry.value.toString();
      if (value.length > 8192 || value.contains('\r') || value.contains('\n')) {
        continue;
      }
      result[name] = value;
    }
    return result;
  }

  Future<Response<dynamic>> _requestWithSafeRedirects(
    String rawUrl, {
    required String method,
    dynamic data,
    Map<String, String> headers = const <String, String>{},
    CancelToken? cancelToken,
    bool followRedirects = true,
    Duration receiveTimeout = const Duration(seconds: 25),
    Duration sendTimeout = const Duration(seconds: 25),
    int maxResponseBytes = _maxResponseBytes,
  }) async {
    var currentUri = await _hostPolicy.validate(rawUrl);
    final requestToken = cancelToken ?? CancelToken();
    var exceededResponseLimit = false;
    var currentMethod = method;
    var currentData = data;
    var currentHeaders = Map<String, String>.of(headers);
    for (var redirect = 0; ; redirect++) {
      late final Response<dynamic> response;
      try {
        response = await _dio.request<dynamic>(
          currentUri.toString(),
          data: currentData,
          cancelToken: requestToken,
          onReceiveProgress: (received, _) {
            if (received > maxResponseBytes && !requestToken.isCancelled) {
              exceededResponseLimit = true;
              requestToken.cancel('Provider response exceeded its size limit.');
            }
          },
          options: Options(
            method: currentMethod,
            headers: currentHeaders,
            responseType: ResponseType.plain,
            followRedirects: false,
            maxRedirects: 0,
            receiveTimeout: receiveTimeout,
            sendTimeout: sendTimeout,
            validateStatus: (_) => true,
          ),
        );
      } on DioException {
        if (exceededResponseLimit) {
          throw FormatException(
            'Provider response exceeds the ${maxResponseBytes ~/ (1024 * 1024)} MB safety limit.',
          );
        }
        rethrow;
      }
      final status = response.statusCode ?? 0;
      final location = response.headers.value('location');
      final isRedirect = status >= 300 && status < 400 && location != null;
      if (!isRedirect || !followRedirects) return response;
      if (redirect >= _hostPolicy.maxRedirects) {
        throw const FormatException('Provider exceeded the redirect limit.');
      }

      final nextUri = await _hostPolicy.validate(
        currentUri.resolve(location).toString(),
      );
      if (nextUri.scheme != 'https' && currentUri.scheme == 'https') {
        throw const FormatException('HTTPS downgrade redirects are blocked.');
      }
      if (nextUri.host.toLowerCase() != currentUri.host.toLowerCase() ||
          nextUri.port != currentUri.port) {
        currentHeaders.removeWhere((name, _) {
          final lower = name.toLowerCase();
          return lower == 'authorization' ||
              lower == 'cookie' ||
              lower == 'proxy-authorization';
        });
      }
      if (status == 303 ||
          ((status == 301 || status == 302) && currentMethod == 'POST')) {
        currentMethod = 'GET';
        currentData = null;
        currentHeaders.removeWhere((name, _) {
          final lower = name.toLowerCase();
          return lower == 'content-type' || lower == 'content-length';
        });
      }
      currentUri = nextUri;
    }
  }

  String _runtimeSourceId(SourceManifest source) {
    final value = source.id.trim();
    if (value.isEmpty || !RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(value)) {
      throw const FormatException(
        'Provider ID contains unsupported characters.',
      );
    }
    // Zangetsu providers commonly derive platform variants from their IDs
    // (for example *_pv / *_hs). Keep the original ID prefix but namespace
    // each repository entry to prevent collisions between different repos.
    final namespace = sha256Hex(
      '${source.stableKey}|${source.version}|${source.engine.endpoint}',
    ).substring(0, 16);
    return '${value}_$namespace';
  }

  void dispose() {
    _disposed = true;
    _sensitiveSettingsBySource.clear();
    _settingsSchemaCache.clear();
    _engine.dispose();
  }
}
