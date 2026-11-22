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
      // OpenSubtitles searches use the documented API v1 only. Do not
      // silently fall back to the legacy REST service when the key is missing.
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
      // OpenSubtitles includes AI-translated subtitles by default. This app
      // must use pre-existing non-AI/non-machine-translated community tracks.
      'ai_translated': 'exclude',
      'machine_translated': 'exclude',
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
      final uploader = attributes['uploader'] is Map
          ? Map<String, dynamic>.from(attributes['uploader'] as Map)
          : const <String, dynamic>{};
      final language = _normaliseLanguageCode(
        attributes['language']?.toString(),
      );
      // Enforce the policy locally as well as in the API query, so a provider
      // regression or ignored filter cannot promote generated translations.
      if (attributes['ai_translated'] == true ||
          attributes['machine_translated'] == true ||
          attributes['ai_translated']?.toString() == '1' ||
          attributes['machine_translated']?.toString() == '1') {
        continue;
      }
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
            downloadCount: _asInt(attributes['download_count']),
            newDownloadCount: _asInt(attributes['new_download_count']),
            providerRating: _asDouble(attributes['ratings']),
            providerVotes: _asInt(attributes['votes']),
            frameRate: _asDouble(attributes['fps']),
            uploaderName: uploader['name']?.toString(),
            uploaderRank: uploader['rank']?.toString(),
            isTrustedUploader: _asBool(attributes['from_trusted']),
            foreignParts: _asBool(attributes['foreign_parts_only']),
            createdAt: attributes['upload_date']?.toString(),
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
    // The protected proxy must enrich search items with providerId by
    // resolving the official /titles/{id} record. A title/year-only fallback
    // can confuse remakes or same-name works and is not safe for auto-match.
    Map? match;
    for (final candidate in titles) {
      final providerId = candidate['providerId']?.toString();
      final candidateType = candidate['type']?.toString().toLowerCase();
      final typeMatches = isMovie
          ? candidateType == 'movie'
          : candidateType == 'series' || candidateType == 'tv';
      final candidateYear = int.tryParse(candidate['year']?.toString() ?? '');
      final yearMatches =
          year == null || candidateYear == null || candidateYear == year;
      if (providerId == '$tmdbId' && typeMatches && yearMatches) {
        match = candidate;
        break;
      }
    }
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

  Future<List<ExternalSubtitle>> _searchSubSource({
    required String imdbId,
    required bool isMovie,
    int? season,
    int? episode,
    String? preferredLanguageCode,
  }) async {
    if (_subSourceApiKey.isEmpty) return const <ExternalSubtitle>[];

    final movieId = await _findSubSourceMovieId(
      imdbId,
      isMovie: isMovie,
      season: season,
    );
    if (movieId == null) return const <ExternalSubtitle>[];

    final languagePairs = _subSourceLanguages(preferredLanguageCode);
    final episodePattern = !isMovie ? _episodePattern(season!, episode!) : null;
    final languageResults = await Future.wait(
      languagePairs.map((language) async {
        try {
          final uri = Uri.parse('$_subSourceBase/subtitles').replace(
            queryParameters: <String, String>{
              'movieId': '$movieId',
              'language': language.name,
              'page': '1',
              'limit': '100',
            },
          );
          final response = await _client
              .get(uri, headers: _subSourceHeaders)
              .timeout(_searchTimeout);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            return <ExternalSubtitle>[];
          }
          final body = jsonDecode(response.body);
          if (body is! Map ||
              body['data'] is! List ||
              body['success'] == false) {
            return <ExternalSubtitle>[];
          }

          final candidates = <ExternalSubtitle>[];
          final seenIds = <String>{};
          for (final raw in (body['data'] as List).whereType<Map>()) {
            final row = Map<String, dynamic>.from(raw);
            final id = row['subtitleId']?.toString().trim() ?? '';
            final rowLanguage = row['language']?.toString().trim() ?? '';
            final release = _subSourceReleaseInfo(row['releaseInfo']);
            final releaseType = row['releaseType']
                ?.toString()
                .trim()
                .toLowerCase();
            if (rowLanguage.toLowerCase() != language.name.toLowerCase()) {
              continue;
            }
            if (id.isEmpty || int.tryParse(id) == null || !seenIds.add(id)) {
              continue;
            }
            if (releaseType == 'trailer') continue;
            // The API list is scoped by movie/series id, not individual
            // episode. Never surface a season pack or different episode as
            // a candidate for the requested episode.
            if (episodePattern != null &&
                (!episodePattern.hasMatch(release) ||
                    _episodeRange.hasMatch(release))) {
              continue;
            }

            final rating = row['rating'] is Map
                ? Map<String, dynamic>.from(row['rating'] as Map)
                : const <String, dynamic>{};
            final contributors = row['contributors'] is List
                ? (row['contributors'] as List).whereType<Map>().toList()
                : const <Map>[];
            final contributorNames = contributors
                .map((item) => item['displayname']?.toString().trim() ?? '')
                .where((name) => name.isNotEmpty)
                .toSet()
                .join(', ');
            candidates.add(
              ExternalSubtitle(
                id: 'subsource_v2_$id',
                url: 'subsource-v2://subtitle/$id',
                flagUrl: '',
                format: 'auto',
                encoding: 'zip/auto',
                display: _languageName(language.code, fallback: rowLanguage),
                language: language.code,
                media: isMovie ? 'movie' : 'tv',
                isHearingImpaired: _asBool(row['hearingImpaired']),
                release: release,
                source: 'SubSource',
                productionType: row['productionType']?.toString(),
                releaseType: row['releaseType']?.toString(),
                downloadCount: _asInt(row['downloads']),
                ratingGood: _asInt(rating['good']),
                ratingBad: _asInt(rating['bad']),
                providerVotes: _asInt(rating['total']),
                frameRate: _asDouble(row['framerate']),
                uploaderName: contributorNames,
                foreignParts: _asBool(row['foreignParts']),
                createdAt: row['createdAt']?.toString(),
              ),
            );
          }
          return candidates;
        } catch (error) {
          debugPrint('[Subtitle][SubSource] Search failed safely: $error');
          return <ExternalSubtitle>[];
        }
      }),
    );
    return languageResults.expand((items) => items).toList(growable: false);
  }

  Future<int?> _findSubSourceMovieId(
    String imdbId, {
    required bool isMovie,
    int? season,
  }) async {
    final uri = Uri.parse('$_subSourceBase/movies/search').replace(
      queryParameters: <String, String>{
        'searchType': 'imdb',
        'imdb': imdbId,
        'type': isMovie ? 'movie' : 'series',
        if (!isMovie && season != null) 'season': '$season',
      },
    );
    final response = await _client
        .get(uri, headers: _subSourceHeaders)
        .timeout(_searchTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final body = jsonDecode(response.body);
    if (body is! Map || body['data'] is! List || body['success'] == false) {
      return null;
    }

    for (final raw in (body['data'] as List).whereType<Map>()) {
      final row = Map<String, dynamic>.from(raw);
      final returnedImdb = row['imdbId']?.toString().trim().toLowerCase() ?? '';
      final rowType = row['type']?.toString().trim().toLowerCase() ?? '';
      final id = _asInt(row['movieId']);
      final typeMatches = isMovie
          ? rowType == 'movie'
          : rowType == 'series' || rowType == 'tv';
      if (id != null &&
          id > 0 &&
          returnedImdb == imdbId.trim().toLowerCase() &&
          typeMatches) {
        return id;
      }
    }
    return null;
  }

  static String _subSourceReleaseInfo(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .join(' | ');
    }
    return value?.toString().trim() ?? '';
  }

  static bool _asBool(dynamic value) =>
      value == true || value?.toString() == '1' || value?.toString() == 'true';

  static int? _asInt(dynamic value) => int.tryParse(value?.toString() ?? '');
  static double? _asDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '');

  static const Map<String, String> _subSourceLanguageNames = <String, String>{
    'ar': 'arabic',
    'bg': 'bulgarian',
    'zh': 'chinese',
    'hr': 'croatian',
    'cs': 'czech',
    'da': 'danish',
    'nl': 'dutch',
    'en': 'english',
    'et': 'estonian',
    'fi': 'finnish',
    'fr': 'french',
    'de': 'german',
    'el': 'greek',
    'he': 'hebrew',
    'hi': 'hindi',
    'hu': 'hungarian',
    'id': 'indonesian',
    'it': 'italian',
    'ja': 'japanese',
    'ko': 'korean',
    'lv': 'latvian',
    'lt': 'lithuanian',
    'ms': 'malay',
    'no': 'norwegian',
    'pl': 'polish',
    'pt': 'portuguese',
    'ro': 'romanian',
    'ru': 'russian',
    'sr': 'serbian',
    'sk': 'slovak',
    'sl': 'slovenian',
    'es': 'spanish',
    'sv': 'swedish',
    'th': 'thai',
    'tr': 'turkish',
    'uk': 'ukrainian',
  };

  static List<_SubSourceLanguage> _subSourceLanguages(String? preferred) {
    String normalizeCode(String? value) =>
        (value ?? '').trim().toLowerCase().split(RegExp(r'[-_]')).first;

    // OpenStream checks English and the device language. RAVEN23 also
    // honors the currently selected app language; when that differs from the
    // Android locale, search both so changing the UI language never hides the
    // subtitles normally offered for the device language.
    final codes = <String>{
      normalizeCode(preferred),
      'ar',
      'en',
      normalizeCode(PlatformDispatcher.instance.locale.languageCode),
    }..remove('');
    final result = <_SubSourceLanguage>[];
    for (final code in codes) {
      final name = _subSourceLanguageNames[code];
      if (name != null) result.add(_SubSourceLanguage(name, code));
    }
    return result;
  }

  static String _languageName(String? code, {String fallback = 'Unknown'}) {
    final normalized = (code ?? '')
        .trim()
        .toLowerCase()
        .split(RegExp(r'[-_]'))
        .first;
    return _subSourceLanguageNames[normalized] ?? fallback;
  }

  static final RegExp _episodeRange = RegExp(
    r'e\d+\s*-\s*e?\d+',
    caseSensitive: false,
  );

  static RegExp _episodePattern(int season, int episode) => RegExp(
    '(s0*$season[ ._-]*e0*$episode(?!\\d))|'
    '((?<![a-z0-9])${season}x0*$episode(?!\\d))|'
    '((?<![a-z0-9])e0*$episode(?!\\d))',
    caseSensitive: false,
  );

  /// Downloads and normalizes an external track into a WebVTT memory source.
  /// For SubSource the public search result is a detail URL, not a file URL;
  /// the detail response must be exchanged for its short-lived download token.
  Future<BetterPlayerSubtitlesSource> convertToBetterPlayerSource(
    ExternalSubtitle subtitle, {
    int? subtitleNumber,
  }) async {
    final text = await _downloadAndNormalize(subtitle);
    var name = subtitle.display.trim().isEmpty
        ? subtitle.language
        : subtitle.display;
    if (subtitleNumber != null) name = '$name #$subtitleNumber';
    if (subtitle.isHearingImpaired && !name.toLowerCase().contains('(hi)')) {
      name = '$name (HI)';
    }
    if (subtitle.source.trim().isNotEmpty) name = '$name · ${subtitle.source}';
    return BetterPlayerSubtitlesSource(
      type: BetterPlayerSubtitlesSourceType.memory,
      name: name,
      content: text,
      selectedByDefault: false,
    );
  }

  Future<String> downloadAndNormalizeForPlayback(ExternalSubtitle subtitle) =>
      _downloadAndNormalize(subtitle);

  Future<String> _downloadAndNormalize(ExternalSubtitle subtitle) async {
    final client = _client;
    var downloadUrl = subtitle.url;
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36',
      'Accept': '*/*',
    };

    if (subtitle.source == 'OpenSubtitles' &&
        subtitle.url.startsWith('opensubtitles-v1://')) {
      if (_openSubtitlesApiKey.isEmpty) {
        throw StateError('OpenSubtitles API key is not configured.');
      }
      final fileId = int.tryParse(Uri.parse(subtitle.url).pathSegments.last);
      if (fileId == null || fileId <= 0) {
        throw const FormatException('Invalid OpenSubtitles file id.');
      }
      final downloadUri = Uri.parse('$_openSubtitlesV1Base/download');
      final tokenResponse = await client
          .post(
            downloadUri,
            headers: <String, String>{
              'Api-Key': _openSubtitlesApiKey,
              'User-Agent': 'RAVEN23 PRO v1.0',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{'file_id': fileId}),
          )
          .timeout(_downloadTimeout);
      if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
        throw http.ClientException(
          'OpenSubtitles download request returned HTTP ${tokenResponse.statusCode}.',
          downloadUri,
        );
      }
      final tokenBody = jsonDecode(tokenResponse.body);
      downloadUrl = tokenBody is Map ? tokenBody['link']?.toString() ?? '' : '';
      if (!downloadUrl.startsWith('http')) {
        throw const FormatException('OpenSubtitles returned no download link.');
      }
    } else if (subtitle.source == 'SubSource' &&
        subtitle.url.startsWith('subsource-v2://')) {
      if (_subSourceApiKey.isEmpty) {
        throw StateError('SubSource API key is not configured.');
      }
      final id = Uri.parse(subtitle.url).pathSegments.last;
      final parsedId = int.tryParse(id);
      if (parsedId == null || parsedId <= 0) {
        throw const FormatException('Invalid SubSource subtitle id.');
      }
      final downloadUri =
          Uri.parse('$_subSourceBase/subtitles/$parsedId/download');
      final response = await client
          .get(downloadUri, headers: _subSourceHeaders)
          .timeout(_downloadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'SubSource download returned HTTP ${response.statusCode}.',
          downloadUri,
        );
      }
      if (response.bodyBytes.length > _maxSubtitleDownloadBytes) {
        throw const FormatException('Subtitle download exceeds the size limit.');
      }
      return SubtitleFileNormalizer.normalizeBytes(response.bodyBytes);
    } else if (subtitle.source == 'ArabicSubs' &&
        subtitle.url.startsWith('arabicsubs-proxy://')) {
      final id = Uri.parse(subtitle.url).pathSegments.last;
      final proxyUri = Uri.parse(
        '$_arabicSubsProxyUrl/subtitles/${Uri.encodeComponent(id)}/download',
      );
      final response = await client
          .get(proxyUri, headers: const {'Accept': '*/*'})
          .timeout(_downloadTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'ArabicSubs proxy download failed.',
          proxyUri,
        );
      }
      if (response.bodyBytes.length > _maxSubtitleDownloadBytes) {
        throw const FormatException(
          'Subtitle download exceeds the size limit.',
        );
      }
      return SubtitleFileNormalizer.normalizeBytes(response.bodyBytes);
    } else if (subtitle.source == 'OpenSubtitles' &&
        subtitle.url.startsWith('http')) {
      headers.addAll(const <String, String>{
        'User-Agent': _openSubtitlesUserAgent,
        'X-User-Agent': _openSubtitlesUserAgent,
      });
    }

    final uri = Uri.parse(downloadUrl);
    final response = await client
        .get(uri, headers: headers)
        .timeout(_downloadTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Subtitle download returned HTTP ${response.statusCode}.',
        uri,
      );
    }
    if (response.bodyBytes.length > _maxSubtitleDownloadBytes) {
      throw const FormatException('Subtitle download exceeds the size limit.');
    }
    return SubtitleFileNormalizer.normalizeBytes(response.bodyBytes);
  }

  Map<String, String> get _subSourceHeaders => <String, String>{
    'X-API-Key': _subSourceApiKey,
    'Accept': 'application/json, application/zip, */*',
  };

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

