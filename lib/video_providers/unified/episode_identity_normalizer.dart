/// Normalizes episode coordinates returned by third-party source providers.
///
/// A season is never inferred from an episode number. The only accepted
/// season context is an explicit season field on the episode, an unambiguous
/// SxxEyy-style identifier in provider metadata, or an explicit season field
/// on the parent detail response that contains the episode list.
class EpisodeCoordinate {
  const EpisodeCoordinate({
    required this.seasonNumber,
    required this.episodeNumber,
  });

  final int seasonNumber;
  final int episodeNumber;

  bool matches({required int seasonNumber, required int episodeNumber}) =>
      this.seasonNumber == seasonNumber && this.episodeNumber == episodeNumber;

  @override
  bool operator ==(Object other) =>
      other is EpisodeCoordinate &&
      other.seasonNumber == seasonNumber &&
      other.episodeNumber == episodeNumber;

  @override
  int get hashCode => Object.hash(seasonNumber, episodeNumber);
}

class EpisodeIdentityNormalizer {
  EpisodeIdentityNormalizer._();

  static const List<String> _seasonKeys = <String>[
    'season',
    'seasonNumber',
    'season_number',
  ];
  static const List<String> _episodeKeys = <String>[
    'number',
    'episode',
    'episodeNumber',
    'episode_number',
    'episodeNo',
    'episode_no',
  ];
  static const List<String> _identityTextKeys = <String>[
    'title',
    'name',
    'id',
    'episodeId',
    'episode_id',
    'number',
    'episode',
    'episodeNumber',
    'episode_number',
    'season',
    'seasonNumber',
    'season_number',
    'url',
    'link',
  ];

  /// Whether the parent response contains a non-null season declaration.
  /// This distinguishes an absent season from a present but invalid/conflicting
  /// declaration so callers never fall back through an ambiguous parent.
  static bool hasSeasonDeclaration(Map<dynamic, dynamic> parent) =>
      _seasonKeys.any((key) => parent.containsKey(key) && parent[key] != null);

  /// Returns a season only when the parent response explicitly declares one.
  /// Conflicting aliases (for example `season: 1` and `season_number: 2`)
  /// make the parent context ambiguous and are rejected.
  static int? explicitSeasonFromParent(Map<dynamic, dynamic> parent) {
    final values = _integerValues(parent, _seasonKeys);
    if (values.length != 1 ||
        _hasInvalidNumericValue(parent, _seasonKeys) ||
        _hasMalformedAliasValue(parent, _seasonKeys, isSeason: true)) {
      return null;
    }
    return values.single;
  }

  /// Reads an exact coordinate from a provider episode item.
  ///
  /// Conflicting explicit fields, identifiers, or title/URL metadata are
  /// rejected rather than choosing whichever value happens to be read first.
  static EpisodeCoordinate? fromProviderItem(
    Map<String, dynamic> item, {
    int? inheritedSeasonNumber,
  }) {
    if (_hasInvalidNumericValue(item, _seasonKeys) ||
        _hasInvalidNumericValue(item, _episodeKeys)) {
      return null;
    }

    final explicitSeasons = _integerValues(item, _seasonKeys);
    final explicitEpisodes = _integerValues(item, _episodeKeys);
    final embeddedCoordinates = _embeddedCoordinates(item);
    final titleEpisodeNumbers = _episodeNumbersFromTitle(item);

    if (explicitSeasons.length > 1 ||
        explicitEpisodes.length > 1 ||
        embeddedCoordinates.length > 1 ||
        titleEpisodeNumbers.length > 1 ||
        _hasMalformedAliasValue(item, _seasonKeys, isSeason: true) ||
        _hasMalformedAliasValue(item, _episodeKeys, isSeason: false)) {
      return null;
    }
    final titleEpisodeNumber = titleEpisodeNumbers.isEmpty
        ? null
        : titleEpisodeNumbers.single;
    if (titleEpisodeNumber != null &&
        explicitEpisodes.isNotEmpty &&
        titleEpisodeNumber != explicitEpisodes.single) {
      return null;
    }
    if (titleEpisodeNumber != null &&
        embeddedCoordinates.isNotEmpty &&
        titleEpisodeNumber != embeddedCoordinates.single.episodeNumber) {
      return null;
    }

    final explicitSeason = explicitSeasons.isEmpty
        ? null
        : explicitSeasons.single;
    final explicitEpisode = explicitEpisodes.isEmpty
        ? null
        : explicitEpisodes.single;
    final embedded = embeddedCoordinates.isEmpty
        ? null
        : embeddedCoordinates.single;

    if (inheritedSeasonNumber != null && inheritedSeasonNumber < 0) {
      return null;
    }
    if (embedded != null &&
        explicitSeason != null &&
        embedded.seasonNumber != explicitSeason) {
      return null;
    }
    if (embedded != null &&
        explicitEpisode != null &&
        embedded.episodeNumber != explicitEpisode) {
      return null;
    }
    if (inheritedSeasonNumber != null &&
        explicitSeason != null &&
        inheritedSeasonNumber != explicitSeason) {
      return null;
    }
    if (inheritedSeasonNumber != null &&
        embedded != null &&
        inheritedSeasonNumber != embedded.seasonNumber) {
      return null;
    }

    final seasonNumber =
        explicitSeason ?? embedded?.seasonNumber ?? inheritedSeasonNumber;
    final episodeNumber =
        explicitEpisode ?? embedded?.episodeNumber ?? titleEpisodeNumber;

    if (seasonNumber == null || episodeNumber == null) return null;
    if (seasonNumber < 0 || episodeNumber < 0) return null;

    return EpisodeCoordinate(
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
  }

  /// Finds only an exact season + episode match. Missing season metadata is
  /// not treated as a wildcard.
  static Map<String, dynamic>? findExactEpisode({
    required List<dynamic> episodes,
    required int seasonNumber,
    required int episodeNumber,
    int? inheritedSeasonNumber,
  }) {
    if (seasonNumber < 0 || episodeNumber < 0) return null;

    for (final raw in episodes) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final coordinate = fromProviderItem(
        item,
        inheritedSeasonNumber: inheritedSeasonNumber,
      );
      if (coordinate?.matches(
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
          ) ==
          true) {
        return item;
      }
    }
    return null;
  }

  static Set<int> _integerValues(
    Map<dynamic, dynamic> item,
    List<String> keys,
  ) {
    final values = <int>{};
    for (final key in keys) {
      if (!item.containsKey(key)) continue;
      final value = _exactInteger(item[key]);
      if (value != null) values.add(value);
    }
    return values;
  }

  static int? _exactInteger(dynamic value) {
    if (value is int) return value;
    if (value is num) {
      if (!value.isFinite || value != value.truncateToDouble()) return null;
      return value.toInt();
    }
    if (value is String) {
      final text = value.trim();
      if (!RegExp(r'^\d+$').hasMatch(text)) return null;
      return int.tryParse(text);
    }
    return null;
  }

  static bool _hasInvalidNumericValue(
    Map<dynamic, dynamic> item,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = item[key];
      if (value == null) continue;
      if (value is num) {
        if (!value.isFinite || value < 0 || value != value.truncateToDouble()) {
          return true;
        }
      } else if (value is String) {
        final text = value.trim();
        if (RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(text) &&
            _exactInteger(text) == null) {
          return true;
        }
      }
    }
    return false;
  }

  /// Rejects a populated coordinate alias that cannot be interpreted.
  /// Silently ignoring an invalid alias could make a different alias appear
  /// authoritative even though the provider supplied contradictory data.
  static bool _hasMalformedAliasValue(
    Map<dynamic, dynamic> item,
    List<String> keys, {
    required bool isSeason,
  }) {
    for (final key in keys) {
      if (!item.containsKey(key)) continue;
      final value = item[key];
      if (value == null || _exactInteger(value) != null) continue;
      if (value is! String) return true;
      final text = value.trim();
      if (text.isEmpty) return true;

      final hasFullCoordinate = RegExp(
        r'(?:^|[^A-Za-z0-9])S\d{1,3}[\s._-]*E\d{1,4}(?=$|[^A-Za-z0-9])'
        r'|(?:season|الموسم)\s*\d{1,3}\s*'
        r'(?:episode|ep\.?|الحلقة)\s*\d{1,4}'
        r'|(?:^|[^A-Za-z0-9])\d{1,2}x\d{1,3}(?=$|[^A-Za-z0-9])',
        caseSensitive: false,
      ).hasMatch(text);
      final hasSingleCoordinate = isSeason
          ? RegExp(
              r'^(?:season|الموسم)\s*#?\s*\d+$',
              caseSensitive: false,
            ).hasMatch(text)
          : RegExp(
              r'^(?:episode|ep\.?|الحلقة)\s*#?\s*\d+$',
              caseSensitive: false,
            ).hasMatch(text);
      if (!hasFullCoordinate && !hasSingleCoordinate) return true;
    }
    return false;
  }

  static Set<EpisodeCoordinate> _embeddedCoordinates(
    Map<String, dynamic> item,
  ) {
    final coordinates = <EpisodeCoordinate>{};
    final standardPattern = RegExp(
      r'(?:^|[^A-Za-z0-9])S(\d{1,3})[\s._-]*E(\d{1,4})(?=$|[^A-Za-z0-9])',
      caseSensitive: false,
    );
    final expandedPattern = RegExp(
      r'(?:season|الموسم)\s*(\d{1,3})\s*(?:episode|ep\.?|الحلقة)\s*(\d{1,4})',
      caseSensitive: false,
    );
    final compactPattern = RegExp(
      r'(?:^|[^A-Za-z0-9])(\d{1,2})x(\d{1,3})(?=$|[^A-Za-z0-9])',
      caseSensitive: false,
    );

    for (final key in _identityTextKeys) {
      final text = item[key]?.toString();
      if (text == null || text.isEmpty) continue;
      for (final match in standardPattern.allMatches(text)) {
        coordinates.add(
          EpisodeCoordinate(
            seasonNumber: int.parse(match.group(1)!),
            episodeNumber: int.parse(match.group(2)!),
          ),
        );
      }
      for (final match in expandedPattern.allMatches(text)) {
        coordinates.add(
          EpisodeCoordinate(
            seasonNumber: int.parse(match.group(1)!),
            episodeNumber: int.parse(match.group(2)!),
          ),
        );
      }
      for (final match in compactPattern.allMatches(text)) {
        coordinates.add(
          EpisodeCoordinate(
            seasonNumber: int.parse(match.group(1)!),
            episodeNumber: int.parse(match.group(2)!),
          ),
        );
      }
    }
    return coordinates;
  }

  static Set<int> _episodeNumbersFromTitle(Map<String, dynamic> item) {
    final numbers = <int>{};
    for (final key in <String>['episode', 'title', 'name']) {
      final text = item[key]?.toString();
      if (text == null) continue;
      final matches = RegExp(
        r'(?:episode|ep\.?|الحلقة)\s*(\d+)',
        caseSensitive: false,
      ).allMatches(text);
      for (final match in matches) {
        final number = int.tryParse(match.group(1)!);
        if (number != null) numbers.add(number);
      }
    }
    return numbers;
  }
}
