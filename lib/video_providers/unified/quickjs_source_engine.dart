import 'package:dio/dio.dart';

import 'episode_identity_normalizer.dart';
import 'media_identity.dart';
import 'quickjs/quickjs_provider_runtime.dart';
import 'quickjs/quickjs_stream_mapper.dart';
import 'source_engine.dart';
import 'source_manifest.dart';

/// Executes Zangetsu-compatible JavaScript sources. Each provider's search,
/// episode matching and getVideoSources call follow Zangetsu's public JS
/// contract; source scripts are downloaded from the repository URL and run in
/// a sandboxed QuickJS runtime with a mediated HTTP bridge.
class QuickJsSourceEngine extends SourceEngine {
  QuickJsSourceEngine({QuickJsProviderRuntime? runtime, Dio? dio})
    : _runtime = runtime ?? QuickJsProviderRuntime(dio: dio);

  final QuickJsProviderRuntime _runtime;

  @override
  SourceEngineKind get kind => SourceEngineKind.javascript;

  @override
  Future<UnifiedSourceResult> resolve({
    required SourceManifest source,
    required MediaIdentity media,
    String? preferredAudioLanguage,
    CancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (media.normalizedType != UnifiedMediaType.movie && !media.isEpisode) {
        throw const FormatException(
          'An exact season and episode number are required for series sources.',
        );
      }
      final info = await _runtime.call(
        source,
        'getInfo',
        const <Object?>[],
        timeout: const Duration(seconds: 15),
        cancelToken: cancelToken,
      );
      if (info is! Map) {
        throw const FormatException(
          'Provider getInfo() did not return a metadata object.',
        );
      }
      // `getInfo().type` and repository media tags are not reliable execution
      // capabilities (many upstream providers under-declare support). Keep
      // the metadata read for contract validation, but always attempt the
      // requested lookup and let search/episode/stream extraction prove it.
      final searchResults = await _search(
        source,
        media,
        cancelToken,
        category: media.normalizedType == UnifiedMediaType.movie
            ? 'movie'
            : 'sub',
      );
      final match = _bestMatch(searchResults, media);
      if (match == null) {
        stopwatch.stop();
        return UnifiedSourceResult(
          errorMessage: 'No matching title was found by ${source.name}.',
          elapsed: stopwatch.elapsed,
          failureKind: SourceFailureKind.emptyResponse,
        );
      }

      String targetUrl = _readString(match, const <String>[
        'url',
        'link',
        'id',
      ]);
      if (targetUrl.isEmpty) {
        throw const FormatException(
          'Provider search result does not contain a playable title URL.',
        );
      }
      if (media.normalizedType != UnifiedMediaType.movie) {
        targetUrl = await _resolveEpisodeUrl(
          source,
          media,
          targetUrl,
          cancelToken,
        );
      }
      final rawStreams = await _runtime.call(
        source,
        'getVideoSources',
        <Object?>[targetUrl, false],
        timeout: const Duration(seconds: 60),
        cancelToken: cancelToken,
      );
      final streams = mapQuickJsVideoSources(source, rawStreams);
      stopwatch.stop();
      if (streams.isEmpty) {
        return UnifiedSourceResult(
          errorMessage:
              '${source.name} getVideoSources() returned no playable HTTP(S) streams. '
              'Check the provider result shape, host extractor, and required request headers.',
          elapsed: stopwatch.elapsed,
          failureKind: SourceFailureKind.emptyResponse,
        );
      }
      return UnifiedSourceResult(streams: streams, elapsed: stopwatch.elapsed);
    } on DioException catch (error) {
      stopwatch.stop();
      return UnifiedSourceResult(
        errorMessage:
            error.message ?? 'JavaScript provider network request failed.',
        elapsed: stopwatch.elapsed,
        failureKind: sourceFailureKindFromException(error),
        httpStatusCodeClass: sourceHttpStatusClass(error),
      );
    } catch (error) {
      stopwatch.stop();
      return UnifiedSourceResult(
        errorMessage: error.toString(),
        elapsed: stopwatch.elapsed,
        failureKind: sourceFailureKindFromException(error),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _search(
    SourceManifest source,
    MediaIdentity media,
    CancelToken? cancelToken, {
    required String category,
  }) async {
    final terms = <String>{
      media.title.trim(),
      if ((media.originalTitle ?? '').trim().isNotEmpty)
        media.originalTitle!.trim(),
    }.where((value) => value.isNotEmpty).toList(growable: false);
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final term in terms) {
      final result = await _runtime.call(
        source,
        'search',
        <Object?>[
          term,
          1,
          <String, dynamic>{'category': category},
        ],
        timeout: const Duration(seconds: 30),
        cancelToken: cancelToken,
      );
      if (result is! List) continue;
      for (final item in result.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final key = _readString(map, const <String>['url', 'link', 'id']);
        if (key.isNotEmpty && seen.add(key)) out.add(map);
      }
      if (out.length >= 40) break;
    }
    return out;
  }

  Map<String, dynamic>? _bestMatch(
    List<Map<String, dynamic>> items,
    MediaIdentity media,
  ) {
    Map<String, dynamic>? best;
    var bestScore = 0.0;
    for (final item in items) {
      final candidates = <String>[
        for (final key in const <String>[
          'title',
          'name',
          'englishTitle',
          'originalTitle',
        ])
          if (item[key] != null) item[key].toString(),
      ];
      var score = 0.0;
      for (final candidate in candidates) {
        score = score > _titleScore(media.title, candidate)
            ? score
            : _titleScore(media.title, candidate);
        if ((media.originalTitle ?? '').trim().isNotEmpty) {
          final originalScore = _titleScore(media.originalTitle!, candidate);
          if (originalScore > score) score = originalScore;
        }
      }
      final itemYear = int.tryParse(
        '${item['year'] ?? item['releaseYear'] ?? ''}',
      );
      if (media.year != null && itemYear != null && media.year != itemYear) {
        score -= 0.2;
      }
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore >= 0.78 ? best : null;
  }

  double _titleScore(String first, String second) {
    final a = _normalizeTitle(first);
    final b = _normalizeTitle(second);
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    if (a.startsWith(b) || b.startsWith(a)) return 0.86;
    final aTokens = a.split(' ').toSet();
    final bTokens = b.split(' ').toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    final common = aTokens.intersection(bTokens).length;
    return common / aTokens.union(bTokens).length;
  }

  // Keep all writing systems. The previous ASCII/Arabic-only filter erased
  // Japanese, Korean, Chinese and Cyrillic titles before fuzzy matching.
  String _normalizeTitle(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<String> _resolveEpisodeUrl(
    SourceManifest source,
    MediaIdentity media,
    String seriesUrl,
    CancelToken? cancelToken,
  ) async {
    if (!media.isEpisode) {
      throw const FormatException(
        'An exact season and episode number are required for series sources.',
      );
    }

    // Zangetsu allows getEpisodes() to be omitted when getDetail() already
    // returns an `episodes` array. A parent season is inherited only when
    // that response explicitly declares its season number.
    List<dynamic> episodeItems = const <dynamic>[];
    int? inheritedSeasonNumber;
    try {
      final detail = await _runtime.call(
        source,
        'getDetail',
        <Object?>[seriesUrl],
        timeout: const Duration(seconds: 30),
        cancelToken: cancelToken,
      );
      if (detail is Map) {
        inheritedSeasonNumber =
            EpisodeIdentityNormalizer.explicitSeasonFromParent(detail);
        if (detail['episodes'] is List) {
          episodeItems = detail['episodes'] as List<dynamic>;
        }
      }
    } catch (_) {
      // getDetail is optional in the Zangetsu contract. Providers that only
      // implement getEpisodes() must remain usable.
    }
    if (episodeItems.isEmpty) {
      final episodes = await _runtime.call(
        source,
        'getEpisodes',
        <Object?>[
          seriesUrl,
          <String, dynamic>{'category': 'sub'},
        ],
        timeout: const Duration(seconds: 30),
        cancelToken: cancelToken,
      );
      if (episodes is List) {
        episodeItems = episodes;
      } else if (episodes is Map && episodes['episodes'] is List) {
        if (EpisodeIdentityNormalizer.hasSeasonDeclaration(episodes)) {
          // A present but conflicting/invalid declaration is not equivalent
          // to an absent field and must not fall back to an older parent.
          inheritedSeasonNumber =
              EpisodeIdentityNormalizer.explicitSeasonFromParent(episodes);
        }
        episodeItems = episodes['episodes'] as List<dynamic>;
      }
    }
    if (episodeItems.isEmpty) {
      throw const FormatException(
        'Provider did not return an episode list from getDetail() or getEpisodes().',
      );
    }

    final match = EpisodeIdentityNormalizer.findExactEpisode(
      episodes: episodeItems,
      seasonNumber: media.seasonNumber!,
      episodeNumber: media.episodeNumber!,
      inheritedSeasonNumber: inheritedSeasonNumber,
    );
    if (match == null) {
      throw FormatException(
        'No exact S${media.seasonNumber!.toString().padLeft(2, '0')}'
        'E${media.episodeNumber!.toString().padLeft(2, '0')} match was found '
        'on ${source.name}. Provider entries without an explicit or '
        'unambiguous season identity are not used.',
      );
    }

    final episodeUrl = _readString(match, const <String>['url', 'link', 'id']);
    if (episodeUrl.isEmpty) {
      throw const FormatException(
        'Matched episode does not contain a source URL.',
      );
    }
    return episodeUrl;
  }

  String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }
}
