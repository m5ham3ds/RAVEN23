import '../../video_providers/unified/source_catalog_safety_policy.dart';
import '../../video_providers/unified/source_priority_manager.dart';
import 'source_health_probe_service.dart';

/// Compatibility boundary for regression tests and older callers.
///
/// Health results are diagnostic only. They must never rank, append, remove,
/// promote or demote a user's PRIMARY or BACKUP selections. The only permitted
/// filtering is the repository's existing explicit Hentai safety policy.
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
    return List<String>.unmodifiable(
      currentPrimaryKeys.where(
        (key) => !SourceCatalogSafetyPolicy.isExcludedStableKey(key),
      ),
    );
  }
}
