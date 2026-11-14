// Runtime supported by a source manifest entry.
import 'media_identity.dart';

enum SourceSafetyClassification { declaredSafe, declaredAdult, unknown }

enum SourceEngineKind {
  stremio,
  vidkingDirect,
  vidkingWebView,
  webEmbed,
  animeSite,
  javascript,
  httpJson,
  legacyScraperApi,
  native,
  unsupported,
}

SourceEngineKind sourceEngineKindFrom(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'stremio':
    case 'stremio-addon':
      return SourceEngineKind.stremio;
    case 'vidking-direct':
      return SourceEngineKind.vidkingDirect;
    case 'vidking-webview':
      return SourceEngineKind.vidkingWebView;
    case 'web-embed':
      return SourceEngineKind.webEmbed;
    case 'anikoto':
    case 'reanime':
    case 'animepahe':
    case 'fouranimo':
    case 'animegg':
      return SourceEngineKind.animeSite;
    case 'javascript':
    case 'quickjs':
    case 'js':
      return SourceEngineKind.javascript;
    case 'http-json':
    case 'http_json':
      return SourceEngineKind.httpJson;
    case 'scraper-api':
    case 'legacy-scraper-api':
      return SourceEngineKind.legacyScraperApi;
    case 'native':
      return SourceEngineKind.native;
    default:
      return SourceEngineKind.unsupported;
  }
}

class SourceEngineDescriptor {
  const SourceEngineDescriptor({
    required this.rawType,
    required this.kind,
    this.endpoint = '',
    this.priority = 50,
    this.language,
    this.audioLanguage,
    this.qualityFilter,
    this.movieUrl,
    this.tvUrl,
    this.config = const <String, dynamic>{},
  });

  final String rawType;
  final SourceEngineKind kind;
  final String endpoint;
  final int priority;

  /// Engine-specific language selector retained for API compatibility.
  /// It is not the repository display language or a subtitle language.
  final String? language;

  /// Explicit expected audio language for engines that expose language-aware
  /// streams. Canonicalized by the owning engine adapter when recognized.
  final String? audioLanguage;

  /// Video-resolution filter only (for example `1080p` or `4K`).
  final String? qualityFilter;
  final String? movieUrl;
  final String? tvUrl;
  final Map<String, dynamic> config;
}

class SourceManifest {
  const SourceManifest({
    required this.id,
    required this.name,
    required this.engine,
    this.description = '',
    this.version = '1.0.0',
    this.versionCode = 1,
    this.apiVersion = 1,
    this.language = 'Multi',
    this.authors = const <String>[],
    this.tags = const <String>[],
    this.homepage,
    this.iconUrl,
    this.repositoryUrl,
    this.enabled = true,
    this.installedByDefault = false,
    this.isFallback = false,
    this.isNsfw = false,
    this.declaredNsfw,
    this.status = 1,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String version;
  final int versionCode;
  final int apiVersion;
  final String language;
  final List<String> authors;
  final List<String> tags;
  final String? homepage;
  final String? iconUrl;
  final String? repositoryUrl;
  final bool enabled;
  final bool installedByDefault;

  /// OpenStream marks Web Embed providers as deferred fallbacks.
  final bool isFallback;
  final bool isNsfw;

  /// Nullable upstream declaration. `null` means the repository did not
  /// declare a safety value; it must not be presented as explicitly safe.
  final bool? declaredNsfw;

  SourceSafetyClassification get safetyClassification {
    if (declaredNsfw == true || isNsfw) {
      return SourceSafetyClassification.declaredAdult;
    }
    if (declaredNsfw == false) {
      return SourceSafetyClassification.declaredSafe;
    }
    return SourceSafetyClassification.unknown;
  }

  bool get requiresLiveTvAdapter =>
      engine.config['requiresLiveTvAdapter'] == true;

  bool get isArchiveCatalog => engine.config['catalogRole'] == 'archive-vod';

  /// Source catalog status: 0=down, 1=ok, 2=slow, 3=beta (OpenStream format).
  final int status;
  final DateTime? updatedAt;
  final SourceEngineDescriptor engine;

  String get stableKey => '${repositoryUrl ?? 'local'}::$id';

  /// True only when the manifest explicitly identifies an anime-exclusive
  /// source. A generic `anime` tag does not override `movies` or `series` tags;
  /// multi-content providers remain available for every declared category.
  bool get isAnimeOnly {
    if (engine.kind == SourceEngineKind.animeSite) return true;

    final providerType = (engine.config['providerType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (engine.kind == SourceEngineKind.javascript &&
        const {
          'anime',
          'anime-only',
          'anime_only',
          'donghua',
        }.contains(providerType)) {
      return true;
    }

    final normalizedTags = tags
        .map((tag) => tag.trim().toLowerCase().replaceAll('_', '-'))
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final advertisesAnime =
        normalizedTags.contains('anime') ||
        normalizedTags.contains('anime-only') ||
        normalizedTags.contains('donghua');
    const movieCapabilities = <String>{
      'movie',
      'movies',
      'film',
      'films',
      'live-action-movies',
    };
    const seriesCapabilities = <String>{
      'series',
      'tv',
      'show',
      'shows',
      'live-action-series',
    };
    const universalCapabilities = <String>{
      'all',
      'multi',
      'multi-content',
      'universal',
      'movies-and-series',
    };
    final advertisesMovies = normalizedTags.any(movieCapabilities.contains);
    final advertisesSeries = normalizedTags.any(seriesCapabilities.contains);
    final advertisesUniversal = normalizedTags.any(
      universalCapabilities.contains,
    );
    return advertisesAnime &&
        !advertisesMovies &&
        !advertisesSeries &&
        !advertisesUniversal;
  }

  /// Media labels in a source manifest are advisory, not execution filters.
  /// Any installed VOD source may be tried for Movies, Series or Anime; only
  /// an adapter explicitly reserved for Live TV stays outside the VOD path.
  bool supportsMedia(MediaIdentity _) => !requiresLiveTvAdapter;

  bool get isRunnable => enabled && engine.kind != SourceEngineKind.unsupported;
}

class SourceRepositoryManifest {
  const SourceRepositoryManifest({
    required this.url,
    required this.name,
    this.description = '',
    this.website,
    this.iconUrl,
    this.extensions = const <SourceManifest>[],
    this.extensionLists = const <String>[],
    this.isStremioAddon = false,
  });

  final String url;
  final String name;
  final String description;
  final String? website;
  final String? iconUrl;
  final List<SourceManifest> extensions;
  final List<String> extensionLists;
  final bool isStremioAddon;
}
