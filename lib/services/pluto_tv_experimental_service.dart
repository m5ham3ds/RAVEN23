import '../models/live_tv.dart';
import 'daddylive_service.dart';
import 'live_tv_provider_unavailable_exception.dart';

/// Conservative Pluto TV entry in the unified Live TV registry.
///
/// The project does not have an authorized third-party channel API contract or
/// partner credentials for Pluto TV. The service therefore fails closed and
/// leaves playback to Pluto's official application/site. It intentionally does
/// not scrape the website, call undocumented endpoints, capture tokens, or
/// manufacture channel/stream records.
class PlutoTvExperimentalLiveTvService implements LiveTvService {
  static const String officialWebsite = 'https://pluto.tv/';
  static const String unavailableMessage =
      'Pluto TV is experimental in RAVEN23. Watch through Pluto TV’s official app or website in supported regions; authorized in-app channel access is not configured.';

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    throw const LiveTvProviderUnavailableException(unavailableMessage);
  }

  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    throw const LiveTvProviderUnavailableException(unavailableMessage);
  }

  @override
  void close() {}
}
