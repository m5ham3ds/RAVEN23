import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

import 'media_identity.dart';
import 'embedded_player_option.dart';
import 'source_engine.dart';
import 'source_manifest.dart';
import 'source_host_policy.dart';
import 'stream_option.dart';
import 'quickjs/quickjs_provider_runtime.dart';
import 'quickjs/quickjs_stream_mapper.dart';

/// Android off-screen WebView resolver matching OpenStream's web-embed and
/// vidking-webview engine contracts. Only captured media URLs are returned to
/// Flutter; the embed page is never treated as a playable stream itself.
class OpenStreamWebEmbedSourceEngine extends SourceEngine {
  OpenStreamWebEmbedSourceEngine({
    required this.engineKind,
    required QuickJsProviderRuntime quickJsRuntime,
    Dio? dio,
    SourceHostPolicy? hostPolicy,
  }) : _quickJsRuntime = quickJsRuntime,
       _dio = dio ?? Dio(),
       _hostPolicy = hostPolicy ?? const SourceHostPolicy();

  static const MethodChannel _channel = MethodChannel(
    'raven23/openstream_web_embed',
  );

  final SourceEngineKind engineKind;
  final QuickJsProviderRuntime _quickJsRuntime;
  final Dio _dio;
  final SourceHostPolicy _hostPolicy;
  static const int _maxHtmlBytes = 8 * 1024 * 1024;

  static const Set<String> _hosterDomains = <String>{
    'filemoon',
    'moonplayer',
    'kerapoxy',
    'fmoonembed',
    'cinegrab',
    'streamwish',
    'wishembed',
    'wishfast',
    'sfastwish',
    'strwish',
    'playerwish',
    'hlswish',
    'awish',
    'dwish',
    'embedwish',
    'mwish',
    'flaswish',
    'obeywish',
    'cdnwish',
    'asnwish',
    'jodwish',
    'streamhg',
    'dhcplay',
    'hglink',
    'vidhide',
    'filelions',
    'alions',
    'dlions',
    'mlions',
    'ryderjet',
    'smoothpre',
    'movearnpre',
    'dinisglows',
    'mivalyo',
    'dintezuvio',
    'voe',
    'voe-unblock',
    'voeunblock',
    'tubelessceliolymph',
    'maxfinishseveral',
    'crystaltreatmenteast',
    'graceaddresscommunity',
    'christopheruntilpoint',
    'launchreliantcleaverriver',
    'jennifercertaindevelopment',
    'mp4upload',
    'vidmoly',
    'ok.ru',
    'odnoklassniki',
    'dood',
    'streamlare',
    'slwatch',
  };

  @override
  SourceEngineKind get kind => engineKind;

  @override
  bool supports(SourceManifest source) =>
      Platform.isAndroid && source.engine.kind == kind;

  @override
  Future<UnifiedSourceResult> resolve({
    required SourceManifest source,
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  }) async {
    if (!Platform.isAndroid) {
      return const UnifiedSourceResult(
        errorMessage:
            'OpenStream Web Embed currently requires the Android WebView bridge.',
      );
    }
    final embedUrl = _embedUrl(source, media);
    if (embedUrl == null) {
      return const UnifiedSourceResult(
        errorMessage:
            'This embed template requires an identifier or episode number that is unavailable.',
      );
    }
    final stopwatch = Stopwatch()..start();
    try {
      await _hostPolicy.validate(embedUrl);
      // OpenStream first attempts direct hoster extraction (Filemoon,
      // StreamWish/VidHide, Voe, Mp4Upload, Vidmoly and OK.ru). This is faster
      // and more reliable than loading the full embed whenever the page
      // exposes its hoster iframe in HTML.
      final nativeStreams = await _resolveNativeHosters(
        source,
        embedUrl,
        cancelToken,
      );
      if (nativeStreams.isNotEmpty) {
        stopwatch.stop();
        return UnifiedSourceResult(
          streams: nativeStreams,
          elapsed: stopwatch.elapsed,
        );
      }
      final embedUri = Uri.parse(embedUrl);
      final defaultReferer = '${embedUri.scheme}://${embedUri.host}/';
      final nativeResponse = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'resolveEmbed',
        <String, dynamic>{
          'url': embedUrl,
          'referer': defaultReferer,
          'sourceId': source.id,
          'sourceName': source.name,
          'timeoutMs': 18000,
        },
      );
      final response = nativeResponse ?? const <dynamic, dynamic>{};
      final rawStreams = response['streams'];
      final streams = <UnifiedStreamOption>[];
      var index = 0;
      for (final raw in rawStreams is List ? rawStreams : const <dynamic>[]) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final url = (item['url'] ?? '').toString().trim();
        final uri = Uri.tryParse(url);
        if (uri == null ||
            (uri.scheme != 'https' && uri.scheme != 'http') ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          continue;
        }
        try {
          await _hostPolicy.validate(url);
        } catch (_) {
          continue;
        }
        index++;
        final headers = _stringMap(item['headers']);
        final rawSubtitles = item['subtitles'];
        final subtitles = <UnifiedSubtitleTrack>[];
        if (rawSubtitles is List) {
          for (final track in rawSubtitles.whereType<Map>()) {
            final subtitle = UnifiedSubtitleTrack.fromJson(
              Map<String, dynamic>.from(track),
            );
            if (subtitle.url.isEmpty) continue;
            try {
              await _hostPolicy.validate(subtitle.url);
              subtitles.add(subtitle);
            } catch (_) {
              // Do not expose a subtitle URL targeting a local/private host.
            }
          }
        }
        streams.add(
          UnifiedStreamOption(
            id: '${source.id}-web-$index-${url.hashCode}',
            providerId: source.id,
            providerName: source.name,
            url: url,
            label: item['label']?.toString(),
            quality: item['quality']?.toString(),
            container: _container(url, item['container']?.toString()),
            headers: headers,
            subtitles: subtitles,
            audioKind: _audioKind(item['audioKind']?.toString()),
            audioLanguage: item['audioLanguage']?.toString(),
            expiresAt: parseStreamExpiry(
              item['expiresAt'] ??
                  item['expires_at'] ??
                  item['expiry'] ??
                  item['expiration'],
            ),
          ),
        );
      }
      stopwatch.stop();
      if (streams.isEmpty) {
        final status = response['status']?.toString();
        if (status == 'embedded_player' || status == 'verification_required') {
          return UnifiedSourceResult(
            embeddedPlayer: UnifiedEmbeddedPlayerOption(
              sourceId: source.id,
              sourceName: source.name,
              url: embedUrl,
              headers: <String, String>{
                'Referer': defaultReferer,
                'Origin': '${embedUri.scheme}://${embedUri.host}',
              },
              readiness: status == 'verification_required'
                  ? EmbeddedPlayerReadiness.verificationRequired
                  : EmbeddedPlayerReadiness.interactive,
            ),
            elapsed: stopwatch.elapsed,
          );
        }
        final nativeError = response['error']?.toString();
        return UnifiedSourceResult(
          errorMessage: nativeError?.trim().isNotEmpty == true
              ? '${source.name}: $nativeError'
              : '${source.name} embed could not be opened. The page may be unavailable or navigation was blocked.',
          elapsed: stopwatch.elapsed,
          failureKind: SourceFailureKind.emptyResponse,
        );
      }
      return UnifiedSourceResult(streams: streams, elapsed: stopwatch.elapsed);
    } on PlatformException catch (error) {
      stopwatch.stop();
      return UnifiedSourceResult(
        errorMessage: error.message ?? error.code,
        elapsed: stopwatch.elapsed,
        failureKind: SourceFailureKind.unknown,
      );
    } catch (error) {
      stopwatch.stop();
      return UnifiedSourceResult(
        errorMessage: error.toString(),
        elapsed: stopwatch.elapsed,
        failureKind: sourceFailureKindFromException(error),
        httpStatusCodeClass: sourceHttpStatusClass(error),
      );
    }
  }

  Future<List<UnifiedStreamOption>> _resolveNativeHosters(
    SourceManifest source,
    String embedUrl,
    CancelToken? cancelToken,
  ) async {
    final candidates = <String>{};
    if (_isSupportedHoster(Uri.tryParse(embedUrl)?.host ?? '')) {
      candidates.add(embedUrl);
    }
    try {
      final response = await _safeGet(
        embedUrl,
        cancelToken: cancelToken,
        headers: <String, String>{
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36',
          'Referer': '${Uri.parse(embedUrl).origin}/',
        },
      );
      final html = response.data ?? '';
      // OpenStream scans quoted absolute URLs because hoster links may live in
      // inline JavaScript/JSON instead of src/href attributes.
      final linkPattern = RegExp(
        r"""["'](https?://[^"'\s<>]+)["']""",
        caseSensitive: false,
      );
      for (final match in linkPattern.allMatches(html)) {
        final raw = match.group(1)?.trim() ?? '';
        if (raw.isEmpty) continue;
        final absolute = Uri.tryParse(raw);
        if (absolute == null ||
            (absolute.scheme != 'https' && absolute.scheme != 'http') ||
            absolute.host.isEmpty ||
            absolute.userInfo.isNotEmpty) {
          continue;
        }
        if (_isSupportedHoster(absolute.host)) {
          candidates.add(absolute.toString());
        }
        if (candidates.length >= 10) break;
      }
    } catch (_) {
      // Some embeds deliberately reject a plain HTTP client; the WebView
      // fallback below remains the authoritative dynamic-page path.
    }
    if (candidates.isEmpty) return const <UnifiedStreamOption>[];

    final results = <UnifiedStreamOption>[];
    for (final candidate in candidates.take(10)) {
      try {
        final raw = await _quickJsRuntime.extractVideo(
          candidate,
          options: <String, dynamic>{
            'headers': <String, String>{
              'Referer': embedUrl,
              'Origin': Uri.parse(embedUrl).origin,
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36',
            },
          },
          timeout: const Duration(seconds: 18),
          cancelToken: cancelToken,
        );
        results.addAll(
          mapQuickJsVideoSources(source, raw, idPrefix: 'openstream-hoster'),
        );
      } catch (_) {
        // Unsupported or changed hosters fall back to the WebView sniffer.
      }
    }
    final seen = <String>{};
    return results
        .where((stream) => seen.add('${stream.url}|${stream.headers}'))
        .toList(growable: false);
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
            if (received > _maxHtmlBytes && !requestToken.isCancelled) {
              exceededLimit = true;
              requestToken.cancel('Embed response exceeded 8 MB.');
            }
          },
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 12),
            sendTimeout: const Duration(seconds: 12),
            headers: headers,
            validateStatus: (_) => true,
            followRedirects: false,
            maxRedirects: 0,
          ),
        );
      } on DioException {
        if (exceededLimit) {
          throw const FormatException(
            'Embed page exceeds the 8 MB safety limit.',
          );
        }
        rethrow;
      }
      final status = response.statusCode ?? 0;
      final location = response.headers.value('location');
      if (status >= 300 && status < 400 && location != null) {
        if (redirect >= _hostPolicy.maxRedirects) {
          throw const FormatException(
            'Embed page exceeded the redirect limit.',
          );
        }
        final nextUri = await _hostPolicy.validate(
          currentUri.resolve(location).toString(),
        );
        if (currentUri.scheme == 'https' && nextUri.scheme != 'https') {
          throw const FormatException(
            'Embed HTTPS downgrade redirects are blocked.',
          );
        }
        currentUri = nextUri;
        continue;
      }
      if (utf8.encode(response.data ?? '').length > _maxHtmlBytes) {
        throw const FormatException(
          'Embed page exceeds the 8 MB safety limit.',
        );
      }
      return response;
    }
  }

  bool _isSupportedHoster(String host) {
    final normalized = host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    return _hosterDomains.any(
      (domain) => normalized == domain || normalized.endsWith('.$domain'),
    );
  }

  String? _embedUrl(SourceManifest source, MediaIdentity media) {
    String? template;
    if (source.engine.kind == SourceEngineKind.vidkingWebView) {
      template = media.normalizedType == UnifiedMediaType.movie
          ? 'https://www.vidking.net/embed/movie/{tmdbId}?autoPlay=true'
          : 'https://www.vidking.net/embed/tv/{tmdbId}/{season}/{episode}?autoPlay=true';
    } else {
      template = media.normalizedType == UnifiedMediaType.movie
          ? source.engine.movieUrl
          : source.engine.tvUrl;
    }
    if (template == null || !template.startsWith('https://')) return null;
    if (template.contains('{tmdbId}') && media.tmdbId == null) return null;
    if (template.contains('{imdbId}') && media.imdbId == null) return null;
    if (media.normalizedType != UnifiedMediaType.movie && !media.isEpisode) {
      return null;
    }
    final value = template
        .replaceAll('{tmdbId}', media.tmdbId?.toString() ?? '')
        .replaceAll('{imdbId}', media.imdbId ?? '')
        .replaceAll('{season}', media.seasonNumber?.toString() ?? '')
        .replaceAll('{episode}', media.episodeNumber?.toString() ?? '');
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return value;
  }

  Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const <String, String>{};
    return <String, String>{
      for (final entry in value.entries)
        if (entry.value != null) entry.key.toString(): entry.value.toString(),
    };
  }

  StreamContainer _container(String url, String? value) {
    final text = '${value ?? ''} $url'.toLowerCase();
    if (text.contains('.m3u8') || text.contains('hls')) {
      return StreamContainer.hls;
    }
    if (text.contains('.mpd') || text.contains('dash')) {
      return StreamContainer.dash;
    }
    if (text.contains('.mp4')) return StreamContainer.mp4;
    if (text.contains('.webm')) return StreamContainer.webm;
    return StreamContainer.unknown;
  }

  StreamAudioKind _audioKind(String? value) {
    switch (value?.toLowerCase()) {
      case 'sub':
      case 'subbed':
        return StreamAudioKind.sub;
      case 'dub':
      case 'dubbed':
        return StreamAudioKind.dub;
      case 'raw':
        return StreamAudioKind.raw;
      default:
        return StreamAudioKind.unknown;
    }
  }
}
