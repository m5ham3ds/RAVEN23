import 'package:raven23/api/endpoints.dart';
import 'package:raven23/catalog/catalog_controller.dart';
import 'package:raven23/catalog/home_feed_controller.dart';
import 'package:raven23/catalog/media_item.dart';
import 'package:raven23/provider/app_dependency_provider.dart';
import 'package:raven23/provider/settings_provider.dart';
import 'package:raven23/widgets/common_widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    dotenv.testLoad(
      fileInput: 'TMDB_API_KEY=test-key\nRAVEN23_API_URL=https://example.com',
    );
  });

  test('Top Rated Anime uses a rated Japanese animation TV discovery query', () {
    final settings = SettingsProvider();
    final dependencies = AppDependencyProvider();
    final source = CatalogHomeFeedSource(
      settings: settings,
      dependencies: dependencies,
    );

    final url = source.urlFor(MediaKind.series, HomeList.topRatedAnime);
    expect(url, isNotNull);
    final params = Uri.parse(url!).queryParameters;
    expect(Uri.parse(url).path, '/3/discover/tv');
    expect(params['sort_by'], 'vote_average.desc');
    expect(params['vote_count.gte'], '30');
    expect(params['with_genres'], '16');
    expect(params['with_original_language'], 'ja');
    expect(params['include_adult'], 'false');
    final adultParams = Uri.parse(
      Endpoints.topRatedAnimeTVUrl('ar', includeAdult: true),
    ).queryParameters;
    expect(adultParams['include_adult'], 'true');
    expect(
      source.urlFor(MediaKind.movie, HomeList.topRatedAnime),
      isNull,
    );
    expect(
      source.urlFor(MediaKind.series, HomeList.trendingAnime),
      isNull,
      reason: 'Trending Anime is a composite of two TMDB data sources',
    );

    settings.dispose();
    dependencies.dispose();
  });

  test('every provider Anime collection is an episodic TV collection', () {
    final settings = SettingsProvider();
    final dependencies = AppDependencyProvider();
    const provider = AppStreamingService(
      'assets/images/netflix.png',
      'Netflix',
      providerId: 8,
    );

    final collection = const CatalogController().serviceCollection(
      kind: MediaKind.series,
      service: provider,
      animeOnly: true,
      settings: settings,
      dependencies: dependencies,
    );

    expect(collection.id, 'anime-service-8');
    expect(provider.stableKey, '8');
    expect(collection.title, 'Netflix');
    expect(collection.logoAsset, provider.imagePath);
    expect(collection.kicker.toLowerCase(), 'anime');
    expect(
      () => const CatalogController().serviceCollection(
        kind: MediaKind.movie,
        service: provider,
        animeOnly: true,
        settings: settings,
        dependencies: dependencies,
      ),
      throwsArgumentError,
    );

    settings.dispose();
    dependencies.dispose();
  });

  test('streaming Anime queries include provider and anime identity filters', () {
    final params = Uri.parse(
      Endpoints.watchProvidersAnimeTVShows(
        8,
        2,
        'ar',
        includeAdult: true,
      ),
    ).queryParameters;

    expect(params['with_watch_providers'], '8');
    expect(params['watch_region'], 'US');
    expect(params['page'], '2');
    expect(params['with_genres'], '16');
    expect(params['with_original_language'], 'ja');
    expect(params['include_adult'], 'true');
  });

  test('anime discovery shelves are based on TMDB data, not title allowlists', () {
    final popular = Uri.parse(
      Endpoints.popularAnimeTVUrl('ar', includeAdult: true),
    );
    expect(popular.path, '/3/discover/tv');
    expect(popular.queryParameters['sort_by'], 'popularity.desc');
    expect(popular.queryParameters['with_genres'], '16');
    expect(popular.queryParameters['with_original_language'], 'ja');
    expect(popular.queryParameters['include_adult'], 'true');

    final airing = Uri.parse(Endpoints.newEpisodesAnimeTVUrl(
      'en',
      DateTime.utc(2026, 11, 6),
    ));
    expect(airing.queryParameters['air_date.gte'], '2026-10-31');
    expect(airing.queryParameters['air_date.lte'], '2026-11-06');
    expect(airing.queryParameters['with_genres'], '16');
    expect(airing.queryParameters['with_original_language'], 'ja');

    final trending = Uri.parse(Endpoints.popularAnimeTVUrl('en'));
    expect(trending.queryParameters['sort_by'], 'popularity.desc');
  });

  test('Warner Bros and Nickelodeon use company/network catalog identities', () {
    final nickelodeon = appStreamingServices.singleWhere(
      (service) => service.catalogKey == 'nickelodeon',
    );
    final warner = appStreamingServices.singleWhere(
      (service) => service.catalogKey == 'warner_bros',
    );

    expect(nickelodeon.providerId, isNull);
    expect(nickelodeon.movieCompanyIds, <int>[2348]);
    expect(nickelodeon.tvNetworkIds, <int>[13]);
    expect(nickelodeon.imagePath, 'assets/images/nickelodeon.png');

    expect(warner.providerId, isNull);
    expect(warner.movieCompanyIds, <int>[17, 174]);
    expect(warner.tvCompanyIds, <int>[17, 1957]);
    expect(warner.imagePath, 'assets/images/warner_bros.png');

    final nickelodeonMovies = Uri.parse(
      Endpoints.productionCompanyMoviesUrl(
        nickelodeon.movieCompanyIds,
        1,
        'en',
      ),
    );
    expect(nickelodeonMovies.queryParameters['with_companies'], '2348');
    expect(nickelodeonMovies.queryParameters.containsKey('with_watch_providers'), isFalse);

    final nickelodeonSeries = Uri.parse(
      Endpoints.televisionNetworkTVUrl(13, 1, 'en'),
    );
    expect(nickelodeonSeries.queryParameters['with_networks'], '13');
    expect(nickelodeonSeries.queryParameters.containsKey('with_watch_providers'), isFalse);

    final warnerMovies = Uri.parse(
      Endpoints.productionCompanyMoviesUrl(warner.movieCompanyIds, 1, 'en'),
    );
    expect(warnerMovies.queryParameters['with_companies'], '17|174');
    final warnerSeries = Uri.parse(
      Endpoints.productionCompanyTVUrl(warner.tvCompanyIds, 1, 'en'),
    );
    expect(warnerSeries.queryParameters['with_companies'], '17|1957');

    final settings = SettingsProvider();
    final dependencies = AppDependencyProvider();
    final nickelCollection = const CatalogController().serviceCollection(
      kind: MediaKind.movie,
      service: nickelodeon,
      settings: settings,
      dependencies: dependencies,
    );
    final warnerAnimeCollection = const CatalogController().serviceCollection(
      kind: MediaKind.series,
      service: warner,
      animeOnly: true,
      settings: settings,
      dependencies: dependencies,
    );
    expect(nickelCollection.id, 'movie-service-nickelodeon');
    expect(nickelCollection.logoAsset, 'assets/images/nickelodeon.png');
    expect(warnerAnimeCollection.id, 'anime-service-warner_bros');
    expect(warnerAnimeCollection.logoAsset, 'assets/images/warner_bros.png');
    settings.dispose();
    dependencies.dispose();
  });

}
