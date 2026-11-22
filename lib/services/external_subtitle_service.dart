import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/external_subtitles.dart';
import 'subtitle_provider_orchestrator.dart';
import '../video_providers/scraper_api.dart';
import '../video_providers/unified/media_identity.dart';
import '../video_providers/unified/media_identity_resolver.dart';
import 'subtitle_file_normalizer.dart';

/// Aggregates the subtitle sources used by OpenStream (OpenSubtitles and
/// SubSource) while retaining RAVEN23's existing Scraper API as an
/// additional provider/fallback.
///
/// OpenSubtitles uses its current API v1 when an application key is configured
/// and keeps a compatibility fallback for older installations. SubSource uses
/// its documented API v1 endpoints and X-API-Key authentication. ArabicSubs
/// is accessed only through an optional protected server-side proxy. Every
/// provider is isolated so one outage never hides the results returned by
/// other providers.
class ExternalSubtitleService {
  ExternalSubtitleService(
    this.scraperApiUrl, {
    http.Client? client,
    MediaIdentityResolver? identityResolver,
    String? openSubtitlesApiKey,
    String? subSourceApiKey,
    String? arabicSubsProxyUrl,
  }) : _client = client ?? _sharedClient,
       _identityResolver = identityResolver ?? _sharedIdentityResolver,
       _openSubtitlesApiKey =
           (openSubtitlesApiKey ?? dotenv.env['OPENSUBTITLES_API_KEY'] ?? '')
               .trim(),
       _subSourceApiKey =
           (subSourceApiKey ?? dotenv.env['SUBSOURCE_API_KEY'] ?? '').trim(),
       _arabicSubsProxyUrl =
           (arabicSubsProxyUrl ?? dotenv.env['ARABICSUBS_PROXY_URL'] ?? '')
               .trim()
               .replaceAll(RegExp(r'/+$'), '');

  final String scraperApiUrl;
  final http.Client _client;
  final MediaIdentityResolver _identityResolver;
  final String _openSubtitlesApiKey;
  final String _subSourceApiKey;
  final String _arabicSubsProxyUrl;

  static final http.Client _sharedClient = http.Client();
  static final MediaIdentityResolver _sharedIdentityResolver =
      MediaIdentityResolver();

  static const String _openSubtitlesV1Base =
      'https://api.opensubtitles.com/api/v1';
  static const String _openSubtitlesUserAgent = 'RAVEN23 PRO v1.0';
  static const String _subSourceBase = 'https://api.subsource.net/api/v1';
  static const Duration _searchTimeout = Duration(seconds: 18);
  static const Duration _downloadTimeout = Duration(seconds: 25);
  static const int _maxSubtitleDownloadBytes = 24 * 1024 * 1024;

  /// Search movie subtitles by TMDB id. The IMDb id is resolved through the
  /// same TMDB `external_ids` mapping used by OpenStream's IdMappingService.
  Future<List<ExternalSubtitle>> fetchMovieSubtitles(
    int tmdbId, {
    String? title,
    int? year,
    String? preferredLanguageCode,
  }) => _search(
    tmdbId: tmdbId,
    title: title,
    year: year,
    isMovie: true,
    preferredLanguageCode: preferredLanguageCode,
  );

  /// Search subtitles for one exact TV episode (not the whole season).
  Future<List<ExternalSubtitle>> fetchTVSubtitles(
    int tmdbId,
    int seasonNumber,
    int episodeNumber, {
    String? title,
    int? year,
    String? preferredLanguageCode,
  }) => _search(
    tmdbId: tmdbId,
    title: title,
    year: year,
    season: seasonNumber,
    episode: episodeNumber,
    isMovie: false,
    preferredLanguageCode: preferredLanguageCode,
  );

  Future<List<ExternalSubtitle>> _search({
    required int tmdbId,
    required bool isMovie,
    String? title,
    int? year,
    int? season,
    int? episode,
    String? preferredLanguageCode,
  }) async {
    if (tmdbId <= 0) return const <ExternalSubtitle>[];

    final identity = MediaIdentity(
      type: isMovie ? UnifiedMediaType.movie : UnifiedMediaType.series,
      tmdbId: tmdbId,
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'TMDB $tmdbId',
      year: year,
      seasonNumber: season,
      episodeNumber: episode,
    );

    // Start the existing scraper request and the IMDb mapping concurrently.
    // A failed mapping only disables the two IMDb-based sources; the current
    // RAVEN23 scraper remains available by TMDB id.
    final scraperFuture = _searchScraper(
      tmdbId: tmdbId,
      season: season,
      episode: episode,
    );
    final enrichedFuture = _identityResolver
        .enrich(identity)
        .timeout(const Duration(seconds: 9), onTimeout: () => identity)
        .catchError((Object _) => identity);

    final enriched = await enrichedFuture;
    final imdbId = enriched.imdbId;
    final providerFutures = <Future<List<ExternalSubtitle>>>[
      // OpenSubtitles free-provider searches use the documented API v1 only.
      // Never silently fall back to the legacy VIP-only REST endpoint when the
      // application key is missing or rejected.
      if (_openSubtitlesApiKey.isNotEmpty)
        _searchOpenSubtitlesV1(
          tmdbId: tmdbId,
          isMovie: isMovie,
          season: season,
          episode: episode,
          preferredLanguageCode: preferredLanguageCode,
        ).catchError((Object error) {
          debugPrint('[Subtitle][OpenSubtitlesV1] Search failed: $error');
          return const <ExternalSubtitle>[];
        }),
      if (imdbId != null)
        _searchSubSource(
          imdbId: imdbId,
          isMovie: isMovie,
          season: season,
          episode: episode,
          preferredLanguageCode: preferredLanguageCode,
        ).catchError((Object error) {
          debugPrint('[Subtitle][SubSource] Search failed: $error');
          return const <ExternalSubtitle>[];
        }),
      if (_arabicSubsProxyUrl.isNotEmpty)
        _searchArabicSubsProxy(
          tmdbId: tmdbId,
          title: title,
          year: year,
          isMovie: isMovie,
          season: season,
          episode: episode,
        ).catchError((Object error) {
          debugPrint('[Subtitle][ArabicSubs] Search failed: $error');
          return const <ExternalSubtitle>[];
        }),
      scraperFuture.catchError((Object error) {
        debugPrint('[Subtitle][ScraperAPI] Search failed: $error');
        return const <ExternalSubtitle>[];
      }),
    ];

    // Keep results from providers that have already completed if another
    // provider stalls beyond the batch deadline. Future.wait's timeout handler
    // used to replace the entire result with an empty list.
    final results = await SubtitleProviderOrchestrator.collectPartialResults(
      requests: providerFutures,
      timeout: const Duration(seconds: 48),
    );
    return _mergeAndSort(results, preferredLanguageCode);
  }

  Future<List<ExternalSubtitle>> _searchScraper({
    required int tmdbId,
    int? season,
    int? episode,
  }) async {
    if (scraperApiUrl.trim().isEmpty) return const <ExternalSubtitle>[];
    final results = await ScraperApi(
      scraperApiUrl,
    ).searchSubtitles(tmdbId: tmdbId, season: season, episode: episode);
    return results
        .map(
          (subtitle) => ExternalSubtitle(
            id: subtitle.id,
            url: subtitle.url,
            flagUrl: subtitle.flagUrl,
            format: subtitle.format,
            encoding: subtitle.encoding,
            display: subtitle.display,
            language: subtitle.language,
            media: subtitle.media,
            isHearingImpaired: subtitle.isHearingImpaired,
            release: subtitle.release,
            source: subtitle.source,
          ),
        )
        .toList(growable: false);
  }

  Future<List<ExternalSubtitle>> _searchOpenSubtitlesV1({
    required int tmdbId,
    required bool isMovie,
    required String? preferredLanguageCode,
    int? season,
    int? episode,
  }) async {
    final languages = <String>{
      _normaliseLanguageCode(preferredLanguageCode),
      'en',
    }..remove('');
    final params = <String, String>{
      'languages': (languages.toList()..sort()).join(','),
      'type': isMovie ? 'movie' : 'episode',
      if (isMovie) 'tmdb_id': '$tmdbId',
      if (!isMovie) 'parent_tmdb_id': '$tmdbId',
      if (!isMovie && season != null) 'season_number': '$season',
      if (!isMovie && episode != null) 'episode_number': '$episode',
      'order_by': 'download_count',
      'order_direction': 'desc',
    };
    // Query parameters are encoded by Uri; the OpenSubtitles API requires a
    // stable lower-case app User-Agent and an application Api-Key.
    final uri = Uri.parse(
      '$_openSubtitlesV1Base/subtitles',
    ).replace(queryParameters: params);
    final response = await _client
        .get(
          uri,
          headers: <String, String>{
            'Api-Key': _openSubtitlesApiKey,
            'User-Agent': 'RAVEN23 PRO v1.0',
            'Accept': 'application/json',
          },
        )
        .timeout(_searchTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'OpenSubtitles v1 returned HTTP ${response.statusCode}.',
        uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      return const <ExternalSubtitle>[];
    }

    final results = <ExternalSubtitle>[];
    for (final item in (decoded['data'] as List).whereType<Map>()) {
      final attributes = item['attributes'];
      if (attributes is! Map) continue;
      final language = _normaliseLanguageCode(
        attributes['language']?.toString(),
      );
      final files = attributes['files'];
      if (files is! List) continue;
      for (final file in files.whereType<Map>()) {
        final fileId = int.tryParse(file['file_id']?.toString() ?? '');
        if (fileId == null || fileId <= 0) continue;
        final fileName = file['file_name']?.toString() ?? '';
        final extension = fileName.split('.').last.toLowerCase();
        results.add(
          ExternalSubtitle(
            id: 'opensubtitles_v1_$fileId',
            url: 'opensubtitles-v1://file/$fileId',
            flagUrl: '',
            format:
                const <String>{'srt', 'vtt', 'ass', 'ssa'}.contains(extension)
                ? extension
                : 'srt',
            encoding: 'UTF-8/auto',
            display: _languageName(language),
            language: language,
            media: isMovie ? 'movie' : 'tv',
            isHearingImpaired: attributes['hearing_impaired'] == true,
            release: attributes['release']?.toString() ?? fileName,
            source: 'OpenSubtitles',
          ),
        );
      }
    }
    return results;
  }

  /// ArabicSubs keys must stay server-side. This optional adapter talks only
  /// to a user's own proxy, which forwards the documented ArabicSubs API and
  /// keeps its Authorization bearer key out of the APK.
  Future<List<ExternalSubtitle>> _searchArabicSubsProxy({
    required int tmdbId,
    required String? title,
    required int? year,
    required bool isMovie,
    int? season,
    int? episode,
  }) async {
    if (title?.trim().isNotEmpty != true) return const <ExternalSubtitle>[];
    final searchUri = Uri.parse('$_arabicSubsProxyUrl/search').replace(
      queryParameters: <String, String>{'q': title!.trim(), 'limit': '25'},
    );
    final searchResponse = await _client
        .get(searchUri, headers: const {'Accept': 'application/json'})
        .timeout(_searchTimeout);
    if (searchResponse.statusCode < 200 || searchResponse.statusCode >= 300) {
      throw http.ClientException('ArabicSubs proxy search failed.', searchUri);
    }
    final searchBody = jsonDecode(searchResponse.body);
    if (searchBody is! Map || searchBody['items'] is! List) {
      return const <ExternalSubtitle>[];
    }
    final titles = (searchBody['items'] as List).whereType<Map>().toList();
    Map? match;
    for (final candidate in titles) {
      final providerId = candidate['providerId']?.toString();
      final candidateType = candidate['type']?.toString().toLowerCase();
      final typeMatches = isMovie
          ? candidateType == 'movie'
          : candidateType == 'series' || candidateType == 'tv';
      if (providerId == '$tmdbId' && typeMatches) {
        match = candidate;
        break;
      }
    }
    match ??= titles.cast<Map?>().firstWhere((candidate) {
      if (candidate == null) return false;
      final candidateType = candidate['type']?.toString().toLowerCase();
      final typeMatches = isMovie
          ? candidateType == 'movie'
          : candidateType == 'series' || candidateType == 'tv';
      final candidateYear = int.tryParse(candidate['year']?.toString() ?? '');
      return typeMatches &&
          (year == null || candidateYear == null || candidateYear == year);
    }, orElse: () => null);
    final titleId = match?['id']?.toString();
    if (titleId == null || titleId.isEmpty) return const <ExternalSubtitle>[];

    final subtitlesUri =
        Uri.parse(
          '$_arabicSubsProxyUrl/titles/${Uri.encodeComponent(titleId)}/subtitles',
        ).replace(
          queryParameters: <String, String>{
            if (!isMovie && season != null) 'season': '$season',
            if (!isMovie && episode != null) 'episode': '$episode',
            'limit': '100',
          },
        );
    final subtitlesResponse = await _client
        .get(subtitlesUri, headers: const {'Accept': 'application/json'})
        .timeout(_searchTimeout);
    if (subtitlesResponse.statusCode < 200 ||
        subtitlesResponse.statusCode >= 300) {
      throw http.ClientException(
        'ArabicSubs subtitle lookup failed.',
        subtitlesUri,
      );
    }
    final subtitlesBody = jsonDecode(subtitlesResponse.body);
    final rawItems = subtitlesBody is Map
        ? (subtitlesBody['items'] ?? subtitlesBody['subtitles'])
        : null;
    if (rawItems is! List) return const <ExternalSubtitle>[];
    return rawItems
        .whereType<Map>()
        .map((row) {
          final id = row['id']?.toString() ?? '';
          final fileName = row['originalFilename']?.toString() ?? '';
          final release = row['releaseLabel']?.toString() ?? fileName;
          final ext = fileName.split('.').last.toLowerCase();
          return ExternalSubtitle(
            id: 'arabicsubs_$id',
            url: 'arabicsubs-proxy://subtitle/$id',
            flagUrl: '',
            format: const <String>{'srt', 'vtt', 'ass', 'ssa'}.contains(ext)
                ? ext
                : 'srt',
            encoding: 'UTF-8',
            display: 'Arabic',
            language: 'ar',
            media: isMovie ? 'movie' : 'tv',
            isHearingImpaired:
                row['hearingImpaired'] == true || row['hi'] == true,
            release: release,
            source: 'ArabicSubs',
          );
        })
        .where((subtitle) => subtitle.id != 'arabicsubs_')
        .toList(growable: false);
  }

  static String _normaliseLanguageCode(String? value) {
    final input = (value ?? '').trim().toLowerCase();
    if (input.isEmpty) return '';
    final first = input.split(RegExp(r'[-_]')).first;
    if (first == 'ara' || first == 'arabic') return 'ar';
    if (first == 'eng' || first == 'english') return 'en';
    return first;
  }

  static List<ExternalSubtitle> _mergeAndSort(
    Iterable<ExternalSubtitle> items,
    String? preferredLanguageCode,
  ) {
    final preferred = _normaliseLanguageCode(preferredLanguageCode);
    final ordered = items
        .where((item) {
          final url = item.url.trim();
          final isInternalDownload =
              (item.source == 'OpenSubtitles' &&
                  url.startsWith('opensubtitles-v1://')) ||
              (item.source == 'ArabicSubs' &&
                  url.startsWith('arabicsubs-proxy://')) ||
              (item.source == 'SubSource' &&
                  url.startsWith('subsource-v2://'));
          return url.isNotEmpty &&
              (url.startsWith('http') || isInternalDownload);
        })
        .toList(growable: true);

    // Apply language and provider priority before BOTH URL and release
    // de-duplication. This makes SubSource win even when two adapters expose
    // the same download URL or the same release record.
    ordered.sort((a, b) {
      int languageRank(ExternalSubtitle subtitle) {
        final language = _normaliseLanguageCode(subtitle.language);
        if (preferred.isNotEmpty && language == preferred) return 0;
        if (language == 'en') return 1;
        return 2;
      }

      final languageOrder = languageRank(a).compareTo(languageRank(b));
      if (languageOrder != 0) return languageOrder;
      final sourceOrder =
          _sourceRank(
            a.source,
            languageCode: _normaliseLanguageCode(a.language),
          ).compareTo(
            _sourceRank(
              b.source,
              languageCode: _normaliseLanguageCode(b.language),
            ),
          );
      if (sourceOrder != 0) return sourceOrder;
      return a.display.toLowerCase().compareTo(b.display.toLowerCase());
    });

    final seenUrls = <String>{};
    final seenReleases = <String>{};
    final merged = <ExternalSubtitle>[];
    for (final item in ordered) {
      if (!seenUrls.add(item.url.trim())) continue;
      final release = item.release.trim().toLowerCase();
      final language = _normaliseLanguageCode(item.language);
      if (release.isNotEmpty) {
        final key = '$language|$release|${item.isHearingImpaired}';
        if (!seenReleases.add(key)) continue;
      }
      merged.add(item);
    }
    return List<ExternalSubtitle>.unmodifiable(merged);
  }

  static int _sourceRank(String source, {required String languageCode}) {
    if (languageCode == 'ar') {
      return switch (source) {
        // Arabic subtitle selection must prefer SubSource whenever it has a
        // usable result; the other Arabic providers are deterministic fallbacks.
        'SubSource' => 0,
        'OpenSubtitles' => 1,
        'ArabicSubs' => 2,
        _ => 4,
      };
    }
    return switch (source) {
      'OpenSubtitles' => 0,
      'SubSource' => 1,
      'ArabicSubs' => 2,
      _ => 4,
    };
  }

  @visibleForTesting
  static List<ExternalSubtitle> mergeSearchResultsForTesting(
    Iterable<ExternalSubtitle> items,
    String? preferredLanguageCode,
  ) => _mergeAndSort(items, preferredLanguageCode);

  @visibleForTesting
  static String? subSourceLanguageNameForTesting(String code) =>
      _subSourceLanguageNames[code.toLowerCase()];

  @visibleForTesting
  static RegExp episodePatternForTesting(int season, int episode) =>
      _episodePattern(season, episode);

  @visibleForTesting
  static String normaliseLanguageCodeForTesting(String? value) =>
      _normaliseLanguageCode(value);
}

class _SubSourceLanguage {
  const _SubSourceLanguage(this.name, this.code);
  final String name;
  final String code;
}

