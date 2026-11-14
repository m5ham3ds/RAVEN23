import 'package:flutter/foundation.dart';
import 'package:raven23/constants/api_constants.dart';
import 'package:raven23/data/models/bootstrap_config.dart';
import 'package:raven23/data/repositories/config_repository.dart';
import 'package:raven23/provider/app_dependency_provider.dart';
import 'package:raven23/services/app_remote_config.dart';
import 'dart:convert';

/// Maps bootstrap into the provider shared by phone, tablet and television.
class BootstrapViewModel extends ChangeNotifier {
  BootstrapViewModel(this.repository, this.dependencies);
  final ConfigRepository repository;
  final AppDependencyProvider dependencies;
  BootstrapConfig _config = const BootstrapConfig();
  BootstrapConfig get config => _config;
  bool _disposed = false;
  DateTime? get lastValidatedAt => repository.lastValidatedAt;

  Future<void> hydrate() async => apply(await repository.loadCached());
  Future<void> refresh() async => apply(await repository.refresh());

  void apply(BootstrapConfig value, {bool preserveThemeSelection = false}) {
    if (_disposed) return;
    _config = value;
    AppRemoteConfig.applySnapshot({
      ...value.runtimeSettings,
      ...value.features.toJson(),
      ...value.branding.toJson(),
      ...value.updates.toJson(),
      ...value.network.toJson(),
      ...value.ads.toJson(),
      'flixquest_api_instances':
          jsonEncode(value.network.raven23ApiInstances),
    }, dependencies);
    dependencies.displayWatchNowButton = value.features.enableStream;
    dependencies.displayDownloadButton = value.features.enableDownload;
    dependencies.displayLiveTV = value.features.enableLiveTv;
    final logo = value.branding.appLogoUrl.trim();
    dependencies.raven23Logo =
        logo.isNotEmpty ? logo : value.branding.cinemaxLogo;
    dependencies.setBannerConfigs(
        {for (final banner in value.banners) banner.key: banner.toDomain()});
    dependencies.setRaven23ApiConfig(
        instances: value.network.raven23ApiInstances,
        url: value.network.raven23ApiUrlV2);
    dependencies.tmdbProxy = value.network.tmdbProxy;
    TMDB_API_KEY = value.network.tmdbApiKey;
    dependencies.applyOccasionalThemeCatalog(
        value.occasionalTheme.toDomain(resolvedAt: lastValidatedAt),
        preserveSelection: preserveThemeSelection);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
