import 'source_manifest.dart';
import 'source_priority_manager.dart';

/// Shared runtime policy for VOD source discovery and execution.
/// Repository labels (media type, language, status, and provider metadata) are
/// advisory only. Any installed source with a VOD engine in this app may be
/// placed in and attempted from any user's Movies, Series, or Anime list.
class SourcePriorityPolicy {
  const SourcePriorityPolicy._();

  static const Map<
    SourcePriorityCategory,
    List<({String repository, String id})>
  >
  _priorityOrder =
      <SourcePriorityCategory, List<({String repository, String id})>>{
        SourcePriorityCategory.movies: <({String repository, String id})>[
          (repository: 'openstream', id: 'yoru'),
          (repository: 'openstream', id: 'cypher'),
          (repository: 'openstream', id: 'breach'),
          (repository: 'openstream', id: 'neon'),
          (repository: 'openstream', id: 'vyse'),
          (repository: 'openstream', id: 'omen'),
          (repository: 'openstream', id: 'raze'),
          (repository: 'spyou-zangetsu', id: 'fourkhdhub'),
          (repository: 'spyou-zangetsu', id: 'uhdmovies'),
          (repository: 'serenity', id: 'serenity-streamplay'),
          (repository: 'serenity', id: 'serenity-cinestream'),
          (repository: 'spyhell-experiment', id: 'filmzie'),
          (repository: 'spyhell-experiment', id: 'internetarchive'),
        ],
        SourcePriorityCategory.series: <({String repository, String id})>[
          (repository: 'openstream', id: 'yoru'),
          (repository: 'openstream', id: 'cypher'),
          (repository: 'openstream', id: 'breach'),
          (repository: 'openstream', id: 'neon'),
          (repository: 'openstream', id: 'vyse'),
          (repository: 'openstream', id: 'omen'),
          (repository: 'openstream', id: 'raze'),
          (repository: 'serenity', id: 'serenity-streamplay'),
          (repository: 'serenity', id: 'serenity-cinestream'),
        ],
        SourcePriorityCategory.anime: <({String repository, String id})>[
          (repository: 'spyou-zangetsu', id: 'anikoto'),
          (repository: 'spyou-zangetsu', id: 'hianime'),
          (repository: 'spyou-zangetsu', id: 'animecube'),
          (repository: 'serenity', id: 'serenity-anikoto'),
          (repository: 'serenity', id: 'serenity-animekai'),
          (repository: 'serenity', id: 'serenity-aniwave'),
          (repository: 'spyhell-experiment', id: 'animesuge'),
          (repository: 'spyhell-experiment', id: 'animex'),
          (repository: 'spyhell-experiment', id: 'anikage'),
          (repository: 'spyhell-experiment', id: 'wcoflix'),
          (repository: 'spyhell-experiment', id: 'donghuanation'),
        ],
      };

  /// Optional first-run sources installed as backups. User-edited primary and
  /// backup lists are persisted separately after this initial configuration.
  static const Map<String, List<String>> _backupIds = <String, List<String>>{
    'openstream': <String>[
      'hdhub',
      'yastream',
      'anikoto',
      'reanime',
      'animepahe',
      'fouranimo',
      'animegg',
    ],
    'spyhell-experiment': <String>[
      'peertube',
      'prelinger',
      'silentfilms',
      'loc',
      'artetv',
      'animetsu',
      'gogoanime',
      'wikimedia',
    ],
    'spyou-additional': <String>['netprime'],
  };

  static List<SourceManifest> recommended(
    SourcePriorityCategory category,
    Iterable<SourceManifest> catalog, {
    required bool Function(SourceManifest) supportsRuntime,
  }) {
    final sources = catalog.toList(growable: false);
    final result = <SourceManifest>[];
    for (final candidate in _priorityOrder[category] ?? const []) {
      final source = sources.cast<SourceManifest?>().firstWhere(
        (item) =>
            item != null &&
            item.id.toLowerCase() == candidate.id &&
            _repositoryBucket(item.repositoryUrl) == candidate.repository,
        orElse: () => null,
      );
      if (source == null ||
          !source.enabled ||
          !isDirectPriorityCandidate(
            source,
            category,
            supportsRuntime: supportsRuntime,
          )) {
        continue;
      }
      if (!result.any((item) => item.stableKey == source.stableKey)) {
        result.add(source);
      }
      if (result.length >= SourcePriorityManager.maxPrimarySources) break;
    }
    return List<SourceManifest>.unmodifiable(result);
  }

  static List<SourceManifest> autoActivationSet(
    Iterable<SourceManifest> catalog, {
    required bool Function(SourceManifest) supportsRuntime,
  }) {
    final sources = catalog.toList(growable: false);
    final selected = <String, SourceManifest>{};

    void add(SourceManifest source) {
      if (!source.enabled || !isEligible(
        source,
        SourcePriorityCategory.movies,
        supportsRuntime: supportsRuntime,
      )) {
        return;
      }
      selected.putIfAbsent(source.stableKey, () => source);
    }

    for (final category in SourcePriorityCategory.values) {
      for (final source in recommended(
        category,
        sources,
        supportsRuntime: supportsRuntime,
      )) {
        add(source);
      }
    }

    for (final entry in _backupIds.entries) {
      for (final id in entry.value) {
        final source = sources.cast<SourceManifest?>().firstWhere(
          (item) =>
              item != null &&
              item.id.toLowerCase() == id &&
              _repositoryBucket(item.repositoryUrl) == entry.key,
          orElse: () => null,
        );
        if (source != null) add(source);
      }
    }

    return List<SourceManifest>.unmodifiable(selected.values);
  }

  /// Retained for compatibility with old call sites. The old per-repository
  /// activation cap incorrectly hid otherwise valid sources from user lists;
  /// list capacities now apply only to each editable lane (20 + 30).
  static bool canActivateWithinRepositoryCap({
    required Iterable<SourceManifest> activeSources,
    required SourceManifest candidate,
  }) => true;

  static int backupStatusRank(SourceManifest source) {
    if (source.engine.config['statusDeclared'] != true) return 3;
    return switch (source.status) {
      1 => 0,
      2 => 1,
      3 => 2,
      _ => 3,
    };
  }

  static String statusLabel(SourceManifest source) {
    if (source.engine.config['statusDeclared'] == false) return 'Unrated';
    return switch (source.status) {
      0 => 'Unavailable',
      1 => 'Listed OK',
      2 => 'Slow',
      3 => 'Beta',
      _ => 'Unrated',
    };
  }

  /// Every source with a registered VOD engine is allowed in any media lane.
  /// The manifest's media tags, status, language, NSFW labels and `getInfo()`
  /// declarations do not filter attempts. A selected provider is actually
  /// tested by its engine for each item. Live TV-only adapters are the one
  /// separate pipeline; unknown engine kinds cannot run without an adapter.
  static bool isDirectPriorityCandidate(
    SourceManifest source,
    SourcePriorityCategory category, {
    required bool Function(SourceManifest) supportsRuntime,
  }) => isEligible(source, category, supportsRuntime: supportsRuntime);

  static bool isEligible(
    SourceManifest source,
    SourcePriorityCategory category, {
    required bool Function(SourceManifest) supportsRuntime,
  }) {
    return !source.requiresLiveTvAdapter && supportsRuntime(source);
  }

  static String _repositoryBucket(String? repositoryUrl) {
    final uri = Uri.tryParse(repositoryUrl ?? '');
    final value =
        '${uri?.host.toLowerCase() ?? ''}${uri?.path.toLowerCase() ?? ''}';
    if (value.contains('/ivorisnoob/openstream/')) return 'openstream';
    if (value.contains('/spyou/zangetsu-providers/')) return 'spyou-zangetsu';
    if (value.contains('/serenity-mist/zangetsu-sources/')) return 'serenity';
    if (value.contains('/spyhell/zangetsu-experiment-repo/')) {
      return 'spyhell-experiment';
    }
    if (value.contains('/spyou/zangetsu-spyou-provider/')) {
      return 'spyou-additional';
    }
    if (value.contains('/spyhell/spyou-latin-zan/')) return 'spyhell-latin';
    return 'other:${uri?.host ?? 'local'}${uri?.path ?? ''}';
  }
}
