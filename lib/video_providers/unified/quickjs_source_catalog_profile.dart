/// Curated compatibility notes for Zangetsu/Spyhell catalog entries.
///
/// These are routing guards, not claims that a provider has working playback.
/// The upstream indexes are discovery metadata; a profile only prevents known
/// non-VOD adapters from being sent to the movie/series QuickJS pipeline.
class QuickJsSourceCatalogProfile {
  const QuickJsSourceCatalogProfile({
    this.catalogRole = 'vod-candidate',
    this.requiresLiveTvAdapter = false,
    this.requiresCredentialReview = false,
    this.seriesCapabilityReview = '',
    this.seriesCapabilityVerified = false,
  });

  final String catalogRole;
  final bool requiresLiveTvAdapter;
  final bool requiresCredentialReview;
  final String seriesCapabilityReview;
  final bool seriesCapabilityVerified;

  static const Set<String> _spyhellLiveIds = <String>{
    'worldlivetv',
    'livetvindia',
    'sportslivetv',
    'movieslivetv',
    'newslivetv',
    'documentarylivetv',
    'entertainmentlivetv',
    'serieslivetv',
    'animationlivetv',
    'musictv',
    'kidstv',
    'comedytv',
    'travellivetv',
    'cookinglivetv',
    'educationlivetv',
  };

  static const Set<String> _archiveIds = <String>{
    'internetarchive',
    'wikimedia',
    'libraryofcongress',
    'prelingerarchives',
    'silentfilms',
    'orphanedfilms',
    'peertube',
  };

  static QuickJsSourceCatalogProfile classify({
    required String repositoryUrl,
    required String sourceId,
  }) {
    final repository = Uri.tryParse(repositoryUrl);
    final path = repository?.path.toLowerCase() ?? '';
    final id = sourceId.trim().toLowerCase();
    final isSpyhellExperiment = path.contains(
      '/spyhell/zangetsu-experiment-repo/',
    );

    if (isSpyhellExperiment && _spyhellLiveIds.contains(id)) {
      return const QuickJsSourceCatalogProfile(
        catalogRole: 'live-channel-adapter',
        requiresLiveTvAdapter: true,
      );
    }

    if (isSpyhellExperiment && _archiveIds.contains(id)) {
      return const QuickJsSourceCatalogProfile(catalogRole: 'archive-vod');
    }

    if (repository?.host.toLowerCase() == 'raw.githubusercontent.com' &&
        path.contains('/serenity-mist/zangetsu-sources/') &&
        (id == 'serenity-cinestream' || id == 'serenity-streamplay')) {
      return const QuickJsSourceCatalogProfile(
        catalogRole: 'vod-candidate',
        seriesCapabilityVerified: true,
        seriesCapabilityReview:
            'Reviewed provider contract: getDetail/getEpisodes and getVideoSources accept exact season/episode resolution; upstream getInfo still reports movie, so a source-specific Series override is applied.',
      );
    }

    if (id == 'torbox') {
      return const QuickJsSourceCatalogProfile(
        catalogRole: 'account-backed-vod-candidate',
        requiresCredentialReview: true,
      );
    }

    return const QuickJsSourceCatalogProfile();
  }
}
