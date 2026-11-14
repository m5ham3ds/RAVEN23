import 'package:dio/dio.dart';

/// AniList country-based catalogue groups.
enum MangaContentKind { all, manga, manhwa, manhua }

extension MangaContentKindX on MangaContentKind {
  String? get countryCode => switch (this) {
    MangaContentKind.all => null,
    MangaContentKind.manga => 'JP',
    MangaContentKind.manhwa => 'KR',
    MangaContentKind.manhua => 'CN',
  };
}

/// A character or creator credited on an AniList manga work.
class MangaPersonCredit {
  const MangaPersonCredit({
    required this.id,
    required this.name,
    required this.role,
    this.imageUrl,
    this.isStaff = false,
  });

  final int id;
  final String name;
  final String role;
  final String? imageUrl;
  final bool isStaff;

  factory MangaPersonCredit.fromEdge(
    Map<String, dynamic> edge, {
    required bool isStaff,
  }) {
    final node = edge['node'] is Map
        ? Map<String, dynamic>.from(edge['node'] as Map)
        : const <String, dynamic>{};
    final name = node['name'] is Map
        ? Map<String, dynamic>.from(node['name'] as Map)
        : const <String, dynamic>{};
    final image = node['image'] is Map
        ? Map<String, dynamic>.from(node['image'] as Map)
        : const <String, dynamic>{};
    return MangaPersonCredit(
      id: (node['id'] as num?)?.toInt() ?? 0,
      name: '${name['full'] ?? name['native'] ?? ''}'.trim(),
      role: '${edge['role'] ?? ''}'.trim(),
      imageUrl: _cleanString(image['large']) ?? _cleanString(image['medium']),
      isStaff: isStaff,
    );
  }
}

/// A related manga title. Anime adaptations are intentionally excluded from
/// Manga/Manhwa/Manhua detail navigation.
class MangaRelatedWork {
  const MangaRelatedWork({
    required this.id,
    required this.title,
    required this.relationType,
    this.englishTitle,
    this.nativeTitle,
    this.coverUrl,
    this.format,
    this.countryOfOrigin,
  });

  final int id;
  final String title;
  final String? englishTitle;
  final String? nativeTitle;
  final String? coverUrl;
  final String relationType;
  final String? format;
  final String? countryOfOrigin;

  factory MangaRelatedWork.fromEdge(Map<String, dynamic> edge) {
    final node = edge['node'] is Map
        ? Map<String, dynamic>.from(edge['node'] as Map)
        : const <String, dynamic>{};
    return MangaRelatedWork.fromNode(
      node,
      relationType: '${edge['relationType'] ?? ''}',
    );
  }

  factory MangaRelatedWork.fromNode(
    Map<String, dynamic> node, {
    required String relationType,
  }) {
    final titles = node['title'] is Map
        ? Map<String, dynamic>.from(node['title'] as Map)
        : const <String, dynamic>{};
    final cover = node['coverImage'] is Map
        ? Map<String, dynamic>.from(node['coverImage'] as Map)
        : const <String, dynamic>{};
    return MangaRelatedWork(
      id: (node['id'] as num?)?.toInt() ?? 0,
      title:
          '${titles['romaji'] ?? titles['english'] ?? titles['native'] ?? 'Untitled'}',
      englishTitle: _cleanString(titles['english']),
      nativeTitle: _cleanString(titles['native']),
      coverUrl: _cleanString(cover['large']),
      relationType: relationType,
      format: _cleanString(node['format']),
      countryOfOrigin: _cleanString(node['countryOfOrigin']),
    );
  }
}

String? _cleanString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// AniList content tag, including spoiler metadata used by the reference
/// detail screen to keep spoiler tags hidden until the reader opts in.
class MangaTag {
  const MangaTag({required this.name, this.rank, this.isSpoiler = false});

  final String name;
  final int? rank;
  final bool isSpoiler;

  factory MangaTag.fromJson(Map<String, dynamic> json) => MangaTag(
    name: '${json['name'] ?? ''}'.trim(),
    rank: (json['rank'] as num?)?.toInt(),
    isSpoiler: json['isMediaSpoiler'] == true,
  );
}

/// An AniList manga/one-shot record used by RAVEN23's discovery catalogue.
/// Light novels are excluded from the manga catalogue by the GraphQL query.
class MangaTitle {
  const MangaTitle({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.englishTitle,
    this.nativeTitle,
    this.bannerUrl,
    this.description,
    this.averageScore,
    this.popularity,
    this.trending,
    this.chapters,
    this.volumes,
    this.status,
    this.format,
    this.genres = const <String>[],
    this.startDate,
    this.endDate,
    this.favourites,
    this.sourceMaterial,
    this.countryOfOrigin,
    this.synonyms = const <String>[],
    this.tags = const <MangaTag>[],
    this.characters = const <MangaPersonCredit>[],
    this.staff = const <MangaPersonCredit>[],
    this.relations = const <MangaRelatedWork>[],
  });

  final int id;
  final String title;
  final String? englishTitle;
  final String? nativeTitle;
  final String? coverUrl;
  final String? bannerUrl;
  final String? description;
  final int? averageScore;
  final int? popularity;
  final int? trending;
  final int? chapters;
  final int? volumes;
  final String? status;
  final String? format;
  final List<String> genres;
  final String? startDate;
  final String? endDate;
  final int? favourites;
  final String? sourceMaterial;
  final String? countryOfOrigin;
  final List<String> synonyms;
  final List<MangaTag> tags;
  final List<MangaPersonCredit> characters;
  final List<MangaPersonCredit> staff;
  final List<MangaRelatedWork> relations;

  factory MangaTitle.fromJson(Map<String, dynamic> json) {
    final title = json['title'] is Map
        ? Map<String, dynamic>.from(json['title'] as Map)
        : const <String, dynamic>{};
    final cover = json['coverImage'] is Map
        ? Map<String, dynamic>.from(json['coverImage'] as Map)
        : const <String, dynamic>{};
    String dateValue(Object? raw) {
      final value = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      return <String>[
        if (value['year'] != null) '${value['year']}',
        if (value['month'] != null) '${value['month']}'.padLeft(2, '0'),
        if (value['day'] != null) '${value['day']}'.padLeft(2, '0'),
      ].join('-');
    }

    final start = dateValue(json['startDate']);
    final end = dateValue(json['endDate']);
    final characterEdges = _edgeList(json['characters']);
    final staffEdges = _edgeList(json['staff']);
    final relationEdges = _edgeList(json['relations']);
    final tags = (json['tags'] as List? ?? const <dynamic>[])
        .whereType<Map>()
        .map((tag) => MangaTag.fromJson(Map<String, dynamic>.from(tag)))
        .where((tag) => tag.name.isNotEmpty)
        .toList(growable: false);
    final characters = characterEdges
        .map((edge) => MangaPersonCredit.fromEdge(edge, isStaff: false))
        .where((person) => person.id > 0 && person.name.isNotEmpty)
        .toList(growable: false);
    final staff = staffEdges
        .map((edge) => MangaPersonCredit.fromEdge(edge, isStaff: true))
        .where((person) => person.id > 0 && person.name.isNotEmpty)
        .toList(growable: false);
    final relations = relationEdges
        .where((edge) {
          final node = edge['node'];
          if (node is! Map) return false;
          final type = '${node['type'] ?? ''}';
          final format = '${node['format'] ?? ''}';
          return type == 'MANGA' && format != 'NOVEL';
        })
        .map(MangaRelatedWork.fromEdge)
        .where((work) => work.id > 0)
        .toList(growable: false);
    return MangaTitle(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title:
          _nonEmpty(title['romaji']) ??
          _nonEmpty(title['english']) ??
          _nonEmpty(title['native']) ??
          'Untitled manga',
      englishTitle: _nonEmpty(title['english']),
      nativeTitle: _nonEmpty(title['native']),
      coverUrl: _nonEmpty(cover['extraLarge']) ?? _nonEmpty(cover['large']),
      bannerUrl: _nonEmpty(json['bannerImage']),
      description: _nonEmpty(json['description']),
      averageScore: (json['averageScore'] as num?)?.toInt(),
      popularity: (json['popularity'] as num?)?.toInt(),
      trending: (json['trending'] as num?)?.toInt(),
      chapters: (json['chapters'] as num?)?.toInt(),
      volumes: (json['volumes'] as num?)?.toInt(),
      status: _nonEmpty(json['status']),
      format: _nonEmpty(json['format']),
      genres: (json['genres'] as List? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      startDate: start.isEmpty ? null : start,
      endDate: end.isEmpty ? null : end,
      favourites: (json['favourites'] as num?)?.toInt(),
      sourceMaterial: _nonEmpty(json['source']),
      countryOfOrigin: _nonEmpty(json['countryOfOrigin']),
      synonyms: (json['synonyms'] as List? ?? const <dynamic>[])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      tags: tags,
      characters: characters,
      staff: staff,
      relations: relations,
    );
  }

  static List<Map<String, dynamic>> _edgeList(Object? value) {
    if (value is! Map || value['edges'] is! List) {
      return const <Map<String, dynamic>>[];
    }
    return (value['edges'] as List)
        .whereType<Map>()
        .map((edge) => Map<String, dynamic>.from(edge))
        .toList(growable: false);
  }

  static String? _nonEmpty(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class MangaHomeShelf {
  const MangaHomeShelf(
    this.translationKey,
    this.items, {
    this.isTopTen = false,
  });

  final String translationKey;
  final List<MangaTitle> items;
  final bool isTopTen;
}

class MangaCatalogue {
  const MangaCatalogue({
    required this.recentlyReleased,
    required this.trending,
    required this.popular,
    required this.topRated,
    required this.action,
    required this.romance,
    this.top10 = const <MangaTitle>[],
    this.upcoming = const <MangaTitle>[],
    this.completed = const <MangaTitle>[],
    this.adventure = const <MangaTitle>[],
    this.comedy = const <MangaTitle>[],
    this.drama = const <MangaTitle>[],
    this.fantasy = const <MangaTitle>[],
    this.horror = const <MangaTitle>[],
    this.mystery = const <MangaTitle>[],
    this.sciFi = const <MangaTitle>[],
    this.supernatural = const <MangaTitle>[],
    this.sliceOfLife = const <MangaTitle>[],
  });

  final List<MangaTitle> recentlyReleased;
  final List<MangaTitle> trending;
  final List<MangaTitle> popular;
  final List<MangaTitle> topRated;
  final List<MangaTitle> action;
  final List<MangaTitle> romance;
  final List<MangaTitle> top10;
  final List<MangaTitle> upcoming;
  final List<MangaTitle> completed;
  final List<MangaTitle> adventure;
  final List<MangaTitle> comedy;
  final List<MangaTitle> drama;
  final List<MangaTitle> fantasy;
  final List<MangaTitle> horror;
  final List<MangaTitle> mystery;
  final List<MangaTitle> sciFi;
  final List<MangaTitle> supernatural;
  final List<MangaTitle> sliceOfLife;

  /// Canonical Home shelf order used by All, Japanese Manga, Manhwa and
  /// Manhua. Keeping the mapping here prevents a UI refactor from silently
  /// dropping or reordering one of the catalogue sections. Empty shelves are
  /// retained in this definition and hidden only by the normal Home row
  /// renderer when the service has no items for that shelf.
  List<MangaHomeShelf> get homeShelves => <MangaHomeShelf>[
    MangaHomeShelf(
      'manga_top_10',
      top10.isNotEmpty ? top10 : popular.take(10).toList(growable: false),
      isTopTen: true,
    ),
    MangaHomeShelf('manga_recently_released', recentlyReleased),
    MangaHomeShelf('trending', trending),
    MangaHomeShelf('popular', popular),
    MangaHomeShelf('top_rated', topRated),
    MangaHomeShelf('manga_upcoming', upcoming),
    MangaHomeShelf('manga_completed', completed),
    MangaHomeShelf('action', action),
    MangaHomeShelf('adventure', adventure),
    MangaHomeShelf('comedy', comedy),
    MangaHomeShelf('drama', drama),
    MangaHomeShelf('fantasy', fantasy),
    MangaHomeShelf('horror', horror),
    MangaHomeShelf('mystery', mystery),
    MangaHomeShelf('romance', romance),
    MangaHomeShelf('sci_fi', sciFi),
    MangaHomeShelf('supernatural', supernatural),
    MangaHomeShelf('slice_of_life', sliceOfLife),
  ];

  /// Combines already country-filtered catalogues into the All view.
  ///
  /// This intentionally avoids a second, unfiltered AniList request: each
  /// region can load independently, and one failed region must not blank the
  /// entire catalogue. IDs are deduplicated before shelves are sorted.
  static MangaCatalogue combine(Iterable<MangaCatalogue> catalogues) {
    final values = catalogues.toList(growable: false);

    List<MangaTitle> collect(
      List<MangaTitle> Function(MangaCatalogue catalogue) select,
    ) {
      final byId = <int, MangaTitle>{};
      for (final catalogue in values) {
        for (final title in select(catalogue)) {
          byId.putIfAbsent(title.id, () => title);
        }
      }
      return byId.values.toList(growable: false);
    }

    int descendingNullable(int? left, int? right) {
      if (left == null) return right == null ? 0 : 1;
      if (right == null) return -1;
      return right.compareTo(left);
    }

    int compareDateDescending(MangaTitle left, MangaTitle right) {
      final a = left.startDate;
      final b = right.startDate;
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return b.compareTo(a);
    }

    int compareDateAscending(MangaTitle left, MangaTitle right) {
      final a = left.startDate;
      final b = right.startDate;
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return a.compareTo(b);
    }

    List<MangaTitle> sorted(
      List<MangaTitle> items,
      int Function(MangaTitle left, MangaTitle right) compare,
    ) => items..sort(compare);

    final popularItems = sorted(
      collect((catalogue) => catalogue.popular),
      (left, right) => descendingNullable(left.popularity, right.popularity),
    );
    final topTenItems = collect((catalogue) => catalogue.top10);

    return MangaCatalogue(
      top10: sorted(
        topTenItems.isEmpty ? List<MangaTitle>.of(popularItems) : topTenItems,
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ).take(10).toList(growable: false),
      recentlyReleased: sorted(
        collect((catalogue) => catalogue.recentlyReleased),
        compareDateDescending,
      ),
      trending: sorted(collect((catalogue) => catalogue.trending), (
        left,
        right,
      ) {
        final trend = descendingNullable(left.trending, right.trending);
        return trend != 0
            ? trend
            : descendingNullable(left.popularity, right.popularity);
      }),
      popular: popularItems,
      topRated: sorted(
        collect((catalogue) => catalogue.topRated),
        (left, right) =>
            descendingNullable(left.averageScore, right.averageScore),
      ),
      upcoming: sorted(
        collect((catalogue) => catalogue.upcoming),
        compareDateAscending,
      ),
      completed: sorted(
        collect((catalogue) => catalogue.completed),
        compareDateDescending,
      ),
      action: sorted(
        collect((catalogue) => catalogue.action),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      adventure: sorted(
        collect((catalogue) => catalogue.adventure),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      comedy: sorted(
        collect((catalogue) => catalogue.comedy),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      drama: sorted(
        collect((catalogue) => catalogue.drama),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      fantasy: sorted(
        collect((catalogue) => catalogue.fantasy),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      horror: sorted(
        collect((catalogue) => catalogue.horror),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      mystery: sorted(
        collect((catalogue) => catalogue.mystery),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      romance: sorted(
        collect((catalogue) => catalogue.romance),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      sciFi: sorted(
        collect((catalogue) => catalogue.sciFi),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      supernatural: sorted(
        collect((catalogue) => catalogue.supernatural),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
      sliceOfLife: sorted(
        collect((catalogue) => catalogue.sliceOfLife),
        (left, right) => descendingNullable(left.popularity, right.popularity),
      ),
    );
  }

  bool get isEmpty => <List<MangaTitle>>[
    recentlyReleased,
    trending,
    popular,
    topRated,
    action,
    romance,
    top10,
    upcoming,
    completed,
    adventure,
    comedy,
    drama,
    fantasy,
    horror,
    mystery,
    sciFi,
    supernatural,
    sliceOfLife,
  ].every((items) => items.isEmpty);
}

/// Thin public AniList GraphQL client. Public manga metadata is queried
/// anonymously; account sync and mutations are deliberately out of scope.
class AniListMangaService {
  AniListMangaService({Dio? dio}) : _dio = dio ?? _newDio();

  static const String endpoint = 'https://graphql.anilist.co';
  final Dio _dio;

  static Dio _newDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 18),
      sendTimeout: const Duration(seconds: 12),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'RAVEN23/4.x (AniList public manga catalogue)',
      },
    ),
  );

  static const String _fields =
      'id idMal chapters volumes format status countryOfOrigin '
      'averageScore popularity trending genres description(asHtml:false) '
      'title{romaji english native} synonyms coverImage{large extraLarge} bannerImage '
      'startDate{year month day}';

  static const String _detailFields =
      '$_fields '
      'characters(sort:[ROLE,RELEVANCE],perPage:24){edges{role node{id name{full} image{medium}}}} '
      'staff(sort:[RELEVANCE],perPage:6){edges{role node{id name{full} image{medium}}}} '
      'relations{edges{relationType(version:2) node{id type format countryOfOrigin title{romaji english native} coverImage{large}}}} '
      'endDate{year month day} favourites source tags{name rank isMediaSpoiler}';

  Future<Map<String, dynamic>> _query(
    String query, [
    Map<String, dynamic> variables = const <String, dynamic>{},
  ]) async {
    final response = await _dio.post<dynamic>(
      endpoint,
      data: <String, dynamic>{'query': query, 'variables': variables},
      options: Options(
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final payload = response.data;
    if (response.statusCode == 429) {
      throw StateError('AniList rate limit reached. Try again shortly.');
    }
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw StateError('AniList request failed (${response.statusCode}).');
    }
    if (payload is! Map) {
      throw const FormatException('Invalid AniList response.');
    }
    final errors = payload['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map ? first['message'] : null;
      throw StateError(message?.toString() ?? 'AniList GraphQL error.');
    }
    final data = payload['data'];
    if (data is! Map) {
      throw const FormatException('AniList response has no data.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<MangaCatalogue> home({MangaContentKind? kind, DateTime? now}) async {
    final query =
        r'''      query($countryOfOrigin: CountryCode) {
        top10: Page(page: 1, perPage: 10) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, sort: POPULARITY_DESC) { FIELDS }
        }
        recentlyReleased: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, status_in: [RELEASING, FINISHED], sort: START_DATE_DESC) { FIELDS }
        }
        trending: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, sort: TRENDING_DESC) { FIELDS }
        }
        popular: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, sort: POPULARITY_DESC) { FIELDS }
        }
        topRated: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, sort: SCORE_DESC, averageScore_greater: 65) { FIELDS }
        }
        upcoming: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, status: NOT_YET_RELEASED, sort: START_DATE) { FIELDS }
        }
        completed: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, status: FINISHED, sort: END_DATE_DESC) { FIELDS }
        }
        action: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Action"], sort: POPULARITY_DESC) { FIELDS }
        }
        adventure: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Adventure"], sort: POPULARITY_DESC) { FIELDS }
        }
        comedy: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Comedy"], sort: POPULARITY_DESC) { FIELDS }
        }
        drama: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Drama"], sort: POPULARITY_DESC) { FIELDS }
        }
        fantasy: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Fantasy"], sort: POPULARITY_DESC) { FIELDS }
        }
        horror: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Horror"], sort: POPULARITY_DESC) { FIELDS }
        }
        mystery: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Mystery"], sort: POPULARITY_DESC) { FIELDS }
        }
        romance: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Romance"], sort: POPULARITY_DESC) { FIELDS }
        }
        sciFi: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Sci-Fi"], sort: POPULARITY_DESC) { FIELDS }
        }
        supernatural: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Supernatural"], sort: POPULARITY_DESC) { FIELDS }
        }
        sliceOfLife: Page(page: 1, perPage: 24) {
          media(type: MANGA, isAdult: false, format_not_in: [NOVEL], countryOfOrigin: $countryOfOrigin, genre_in: ["Slice of Life"], sort: POPULARITY_DESC) { FIELDS }
        }
      }
    '''
            .replaceAll('FIELDS', _fields);
    final data = await _query(query, <String, dynamic>{
      'countryOfOrigin': kind?.countryCode,
    });
    return MangaCatalogue(
      top10: _items(data['top10']),
      recentlyReleased: _items(data['recentlyReleased']),
      trending: _items(data['trending']),
      popular: _items(data['popular']),
      topRated: _items(data['topRated']),
      upcoming: _items(data['upcoming']),
      completed: _items(data['completed']),
      action: _items(data['action']),
      adventure: _items(data['adventure']),
      comedy: _items(data['comedy']),
      drama: _items(data['drama']),
      fantasy: _items(data['fantasy']),
      horror: _items(data['horror']),
      mystery: _items(data['mystery']),
      romance: _items(data['romance']),
      sciFi: _items(data['sciFi']),
      supernatural: _items(data['supernatural']),
      sliceOfLife: _items(data['sliceOfLife']),
    );
  }

  Future<List<MangaTitle>> search(
    String query, {
    int page = 1,
    MangaContentKind? kind,
  }) async {
    final value = query.trim();
    if (value.isEmpty) return const <MangaTitle>[];
    final data = await _query(
      'query(\$search:String!,\$page:Int!,\$countryOfOrigin:CountryCode){ '
      'Page(page:\$page,perPage:30){ media(search:\$search,type:MANGA,'
      'isAdult:false,format_not_in:[NOVEL],countryOfOrigin:\$countryOfOrigin,'
      'sort:SEARCH_MATCH){ $_fields } } }',
      <String, dynamic>{
        'search': value,
        'page': page,
        'countryOfOrigin': kind?.countryCode,
      },
    );
    return _items(data['Page']);
  }

  Future<MangaTitle> detail(int id) async {
    final data = await _query(
      'query(\$id:Int!){ Media(id:\$id,type:MANGA){ $_detailFields } }',
      <String, dynamic>{'id': id},
    );
    final media = data['Media'];
    if (media is! Map) throw StateError('Manga title was not found.');
    return MangaTitle.fromJson(Map<String, dynamic>.from(media));
  }

  List<MangaTitle> _items(Object? page) {
    if (page is! Map || page['media'] is! List) {
      return const <MangaTitle>[];
    }
    return (page['media'] as List)
        .whereType<Map>()
        .map((item) => MangaTitle.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id > 0)
        .toList(growable: false);
  }
}
