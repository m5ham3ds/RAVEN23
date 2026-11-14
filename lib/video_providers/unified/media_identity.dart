/// Stable identity passed to every source engine.
///
/// TMDB remains the catalogue authority in RAVEN23. External identifiers are
/// carried separately because source ecosystems (notably Stremio) often need an
/// IMDb/AniList/MAL identifier rather than a TMDB integer.
/// `anime` is retained as a legacy input value. Runtime routing normalizes it
/// to `series`; editorial distinctions live in [MediaContentClassification].
enum UnifiedMediaType { movie, series, anime }

/// Editorial classification is separate from the playback/content kind.
/// Anime and Donghua are episodic television content; Animation and
/// Documentary are classifications, not independent playback engines.
enum MediaContentClassification {
  general,
  anime,
  donghua,
  animation,
  documentary,
}

class MediaIdentity {
  const MediaIdentity({
    required this.type,
    required this.title,
    this.originalTitle,
    this.year,
    this.tmdbId,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeTmdbId,
    this.episodeAirDate,
    this.externalIds = const <String, String>{},
    bool isAnimeContent = false,
    this.contentClassification = MediaContentClassification.general,
  }) : _legacyAnimeFlag = isAnimeContent;

  final UnifiedMediaType type;
  final String title;
  final String? originalTitle;
  final int? year;
  final int? tmdbId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? episodeTmdbId;
  final String? episodeAirDate;
  final Map<String, String> externalIds;

  /// Classification does not create a separate playback engine.
  final MediaContentClassification contentClassification;

  final bool _legacyAnimeFlag;

  /// Normalizes the legacy `anime` media type to episodic `series` while
  /// preserving movie routing for anime feature films.
  UnifiedMediaType get normalizedType =>
      type == UnifiedMediaType.anime ? UnifiedMediaType.series : type;

  MediaContentClassification get normalizedClassification {
    if (contentClassification != MediaContentClassification.general) {
      return contentClassification;
    }
    if (_legacyAnimeFlag || type == UnifiedMediaType.anime) {
      return MediaContentClassification.anime;
    }
    return MediaContentClassification.general;
  }

  /// True for Anime and Donghua content. Retained as a compatibility getter
  /// for existing source engines and adapters.
  bool get isAnimeContent =>
      normalizedClassification == MediaContentClassification.anime ||
      normalizedClassification == MediaContentClassification.donghua;

  bool get isAnimationContent =>
      normalizedClassification == MediaContentClassification.anime ||
      normalizedClassification == MediaContentClassification.donghua ||
      normalizedClassification == MediaContentClassification.animation;

  bool get isEpisode =>
      normalizedType != UnifiedMediaType.movie &&
      seasonNumber != null &&
      seasonNumber! >= 0 &&
      episodeNumber != null &&
      episodeNumber! >= 0;

  /// Stremio's public stream protocol accepts `movie` and `series` types.
  String get stremioType =>
      normalizedType == UnifiedMediaType.movie ? 'movie' : 'series';

  /// A source-specific ID explicitly supplied by the catalogue/mapping layer.
  /// It may use any identifier prefix that a Stremio add-on advertises.
  String? get explicitStremioId =>
      _firstNonEmpty(<String?>[externalIds['stremio']]);

  /// Returns a validated IMDb ID, not an arbitrary external identifier.
  String? get imdbId {
    final value = _firstNonEmpty(<String?>[
      externalIds['imdb'],
      externalIds['imdbId'],
    ]);
    return value != null && RegExp(r'^tt\d+$').hasMatch(value) ? value : null;
  }

  /// Returns an explicit Stremio ID, or an IMDb-compatible ID when available.
  /// TMDB IDs are never guessed here; the add-on's `idPrefixes` must opt in.
  String? get stremioId {
    final explicit = explicitStremioId ?? imdbId;
    if (explicit == null) return null;
    if (normalizedType == UnifiedMediaType.movie || !isEpisode) return explicit;
    final episodeSuffix = ':$seasonNumber:$episodeNumber';
    return explicit.endsWith(episodeSuffix)
        ? explicit
        : '$explicit$episodeSuffix';
  }

  /// Returns a copy with merged external provider identifiers. Existing
  /// values are preserved unless the caller supplies a replacement.
  MediaIdentity copyWithExternalIds(Map<String, String> values) =>
      MediaIdentity(
        type: type,
        title: title,
        originalTitle: originalTitle,
        year: year,
        tmdbId: tmdbId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeTmdbId: episodeTmdbId,
        episodeAirDate: episodeAirDate,
        externalIds: Map<String, String>.unmodifiable(values),
        isAnimeContent: _legacyAnimeFlag,
        contentClassification: contentClassification,
      );

  String get normalizedTitle => title.trim().toLowerCase();

  /// Stable local-only key for playback history/cache. It separates movies,
  /// seasons, episodes, and anime classification without putting the title or
  /// any signed stream URL in a storage key.
  String get playbackCacheKey => <String>[
    normalizedType.name,
    tmdbId?.toString() ?? normalizedTitle,
    seasonNumber?.toString() ?? '-',
    episodeNumber?.toString() ?? '-',
    normalizedClassification.name,
  ].join(':');

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
