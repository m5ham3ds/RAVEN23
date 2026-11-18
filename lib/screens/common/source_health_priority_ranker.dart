import '../../video_providers/unified/source_catalog_safety_policy.dart';
import '../../video_providers/unified/source_priority_manager.dart';
import 'source_health_probe_service.dart';

/// Rebuilds only the non-pinned PRIMARY tail from measured stream-extraction
/// evidence. It never promotes a health-only/endpoint-only result to BACKUP.
class SourceHealthPriorityRanker {
  SourceHealthPriorityRanker._();

  static int fixedPrefixLength(SourcePriorityCategory category) =>
      switch (category) {
        SourcePriorityCategory.movies || SourcePriorityCategory.series => 12,
        SourcePriorityCategory.anime => 14,
      };

  static List<String> rankPrimaryKeys({
    required SourcePriorityCategory category,
    required List<String> currentPrimaryKeys,
    required List<String> backupKeys,
    required List<SourceHealthCheckResult> results,
  }) {
    final prefixLength = fixedPrefixLength(category);
    final safeCurrentKeys = currentPrimaryKeys
        .where((key) => !_isHentaiKey(key))
        .toList(growable: false);
    final pinned = safeCurrentKeys.take(prefixLength).toList(growable: false);
    final pinnedSet = pinned.toSet();
    final backupSet = backupKeys.toSet();

    final candidates = <_RankedSource>[];
    final seen = <String>{...pinnedSet, ...backupSet};
    for (final result in results) {
      final source = result.videoSource;
      if (source == null ||
          SourceCatalogSafetyPolicy.isExcludedHentai(source) ||
          result.status != SourceHealthStatus.healthy) {
        continue;
      }
      final evidence = result.categoryEvidence[category.name];
      if (evidence == null || evidence.streamCount <= 0) continue;
      if (!seen.add(source.stableKey)) continue;
      candidates.add(_RankedSource(source.stableKey, evidence));
    }

    if (candidates.isEmpty) {
      // A failed/offline scan must never erase a previously populated tail.
      return List<String>.unmodifiable(safeCurrentKeys);
    }

    candidates.sort(_compare);
    return List<String>.unmodifiable(<String>[
      ...pinned,
      ...candidates.map((candidate) => candidate.key),
    ]);
  }

  static int _compare(_RankedSource left, _RankedSource right) {
    final a = left.evidence;
    final b = right.evidence;
    var comparison = b.qualityLabels.length.compareTo(a.qualityLabels.length);
    if (comparison != 0) return comparison;
    comparison = b.containerLabels.length.compareTo(a.containerLabels.length);
    if (comparison != 0) return comparison;
    comparison = b.audioKinds.length.compareTo(a.audioKinds.length);
    if (comparison != 0) return comparison;
    comparison = b.streamCount.compareTo(a.streamCount);
    if (comparison != 0) return comparison;
    comparison = b.subtitleTrackCount.compareTo(a.subtitleTrackCount);
    if (comparison != 0) return comparison;
    comparison = a.elapsedMs.compareTo(b.elapsedMs);
    if (comparison != 0) return comparison;
    return left.key.compareTo(right.key);
  }

  static bool _isHentaiKey(String key) =>
      SourceCatalogSafetyPolicy.isExcludedStableKey(key);
}

class _RankedSource {
  const _RankedSource(this.key, this.evidence);

  final String key;
  final SourceHealthCategoryEvidence evidence;
}
