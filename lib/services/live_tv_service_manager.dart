import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/live_tv_database_controller.dart';
import '../models/live_tv.dart';
import 'daddylive_service.dart';
import 'ethio_sports_service.dart';
import 'iptv/m3u_live_tv_service.dart';
import 'iptv/spyhell_live_tv_service.dart';
import 'iptv/m3u_playlist_repository.dart';
import 'live_tv_provider_unavailable_exception.dart';
import 'pluto_tv_experimental_service.dart';

/// The last known operational state of a Live TV provider.
///
/// This is deliberately separate from channel/catalog data: a provider can be
/// installed and selectable while its upstream is temporarily unavailable.
enum LiveTvProviderState {
  idle,
  loading,
  available,
  empty,
  error,
  unavailable,
  blocked,
}

class LiveTvProviderHealth {
  const LiveTvProviderHealth({
    required this.providerId,
    required this.state,
    this.checkedAt,
    this.httpStatusCode,
    this.message,
  });

  final String providerId;
  final LiveTvProviderState state;
  final DateTime? checkedAt;
  final int? httpStatusCode;
  final String? message;

  bool get isAvailable => state == LiveTvProviderState.available;
  bool get isBlocked => state == LiveTvProviderState.blocked;
}

/// Metadata and factory for a Live TV provider.
///
/// Services are created lazily and owned by [LiveTvServiceManager]. The
/// database namespace is intentionally explicit so one provider cannot read
/// another provider's favorites, recents, or cached catalog.
class LiveTvProviderDefinition {
  const LiveTvProviderDefinition({
    required this.id,
    required this.label,
    required this.databaseNamespace,
    required this.createService,
    this.supportsEpg = false,
    this.isExperimental = false,
    this.externalLaunchUrl,
  });

  final String id;
  final String label;
  final String databaseNamespace;
  final LiveTvService Function() createService;
  final bool supportsEpg;
  final bool isExperimental;
  final String? externalLaunchUrl;
}

/// Owns the lifecycle and selection of every Live TV service.
///
/// [LiveTvService] remains the playback-facing compatibility contract used by
/// LivePlayer. The manager delegates that contract to the selected provider,
/// while also exposing provider selection, namespaced storage, refresh and
/// per-provider health state to the browse screens.
class LiveTvServiceManager implements LiveTvService {
  /// Creates the built-in provider registry used by both Mobile and TV.
  /// New providers are registered here rather than duplicated in screens.
  factory LiveTvServiceManager.standard({
    required String daddyLiveBaseUrl,
    required String ethioSportsBaseUrl,
    SharedPreferences? preferences,
  }) {
    return LiveTvServiceManager(
      preferences: preferences,
      providers: <LiveTvProviderDefinition>[
        LiveTvProviderDefinition(
          id: daddyLiveProviderId,
          label: 'DaddyLive',
          databaseNamespace: 'daddylive',
          supportsEpg: true,
          createService: () => DaddyLiveService(baseUrl: daddyLiveBaseUrl),
        ),
        LiveTvProviderDefinition(
          id: ethioSportsProviderId,
          label: 'Ethio Sports',
          databaseNamespace: 'ethiosports',
          supportsEpg: true,
          createService: () => EthioSportsService(baseUrl: ethioSportsBaseUrl),
        ),
        LiveTvProviderDefinition(
          id: m3uProviderId,
          label: 'IPTV / M3U',
          databaseNamespace: 'iptv_m3u',
          supportsEpg: true,
          createService: () => M3uLiveTvService(),
        ),
        LiveTvProviderDefinition(
          id: spyhellProviderId,
          label: 'Spyhell Live',
          databaseNamespace: SpyhellLiveTvService.databaseNamespace,
          createService: () => SpyhellLiveTvService(),
        ),
        LiveTvProviderDefinition(
          id: plutoTvProviderId,
          label: 'Pluto TV · Experimental',
          databaseNamespace: 'pluto_tv_experimental',
          isExperimental: true,
          externalLaunchUrl: PlutoTvExperimentalLiveTvService.officialWebsite,
          createService: () => PlutoTvExperimentalLiveTvService(),
        ),
      ],
    );
  }

  LiveTvServiceManager({
    required List<LiveTvProviderDefinition> providers,
    String defaultProviderId = daddyLiveProviderId,
    SharedPreferences? preferences,
  }) : _providers = List<LiveTvProviderDefinition>.unmodifiable(providers),
       _defaultProviderId = defaultProviderId,
       _preferences = preferences {
    if (_providers.isEmpty) {
      throw ArgumentError.value(providers, 'providers', 'Must not be empty.');
    }
    final ids = _providers.map((provider) => provider.id).toSet();
    final namespaces = _providers
        .map((provider) => provider.databaseNamespace)
        .toSet();
    if (ids.length != _providers.length ||
        _providers.any((provider) => provider.id.trim().isEmpty)) {
      throw ArgumentError.value(
        providers,
        'providers',
        'Provider IDs must be non-empty and unique.',
      );
    }
    if (namespaces.length != _providers.length ||
        _providers.any(
          (provider) => provider.databaseNamespace.trim().isEmpty,
        )) {
      throw ArgumentError.value(
        providers,
        'providers',
        'Database namespaces must be non-empty and unique.',
      );
    }
    if (!ids.contains(defaultProviderId)) {
      throw ArgumentError.value(
        defaultProviderId,
        'defaultProviderId',
        'The default provider must be registered.',
      );
    }
    _selectedProviderId = defaultProviderId;
  }

  static const String daddyLiveProviderId = 'daddylive';
  static const String ethioSportsProviderId = 'ethiosports';
  static const String m3uProviderId = 'iptv-m3u';
  static const String spyhellProviderId = 'spyhell-live';
  static const String plutoTvProviderId = 'pluto-tv';
  static const String _selectedProviderKey = 'live_tv_selected_provider_v1';

  final List<LiveTvProviderDefinition> _providers;
  final String _defaultProviderId;
  final SharedPreferences? _preferences;
  final Map<String, LiveTvService> _services = <String, LiveTvService>{};
  final Map<String, DaddyLiveCatalog> _catalogs = <String, DaddyLiveCatalog>{};
  final Map<String, LiveTvProviderHealth> _health =
      <String, LiveTvProviderHealth>{};

  String _selectedProviderId = daddyLiveProviderId;
  Future<void>? _initialization;
  bool _closed = false;

  List<LiveTvProviderDefinition> get providers => _providers;
  String get selectedProviderId => _selectedProviderId;

  LiveTvProviderDefinition get selectedProvider =>
      _definitionFor(_selectedProviderId);

  String get activeDatabaseNamespace => selectedProvider.databaseNamespace;

  LiveTVDatabaseController get activeDatabase =>
      LiveTVDatabaseController(namespace: activeDatabaseNamespace);

  List<String> get categories =>
      _catalogs[_selectedProviderId]?.categories ?? const <String>[];

  LiveTvProviderHealth get selectedHealth => healthFor(_selectedProviderId);

  LiveTvProviderDefinition _definitionFor(String providerId) {
    return _providers.firstWhere(
      (provider) => provider.id == providerId,
      orElse: () => throw ArgumentError.value(
        providerId,
        'providerId',
        'Unknown Live TV provider.',
      ),
    );
  }

  LiveTvService _serviceFor(String providerId) {
    if (_closed) throw StateError('Live TV service manager is closed.');
    final existing = _services[providerId];
    if (existing != null) return existing;
    final service = _definitionFor(providerId).createService();
    _services[providerId] = service;
    _health.putIfAbsent(
      providerId,
      () => LiveTvProviderHealth(
        providerId: providerId,
        state: LiveTvProviderState.idle,
      ),
    );
    return service;
  }

  /// Restores the last selected provider. Unknown/stale IDs safely fall back
  /// to DaddyLive and never prevent Live TV from opening.
  Future<void> initialize() => _initialization ??= _restoreSelection();

  Future<void> _restoreSelection() async {
    try {
      final preferences = _preferences ?? await SharedPreferences.getInstance();
      final saved = preferences.getString(_selectedProviderKey);
      if (saved != null && _providers.any((provider) => provider.id == saved)) {
        _selectedProviderId = saved;
      } else {
        _selectedProviderId = _defaultProviderId;
      }
    } on Object {
      _selectedProviderId = _defaultProviderId;
    }
  }

  /// Selects a registered provider and persists it for the next visit.
  /// Existing service instances remain owned by this manager and are closed
  /// together, which avoids leaking HTTP clients when users switch providers.
  Future<void> selectProvider(String providerId) async {
    await initialize();
    _definitionFor(providerId);
    if (_closed) throw StateError('Live TV service manager is closed.');
    _selectedProviderId = providerId;
    try {
      final preferences = _preferences ?? await SharedPreferences.getInstance();
      await preferences.setString(_selectedProviderKey, providerId);
    } on Object {
      // Selection remains usable for this session even if preferences are
      // temporarily unavailable; initialization will safely fall back later.
    }
  }

  LiveTvProviderHealth healthFor(String providerId) {
    _definitionFor(providerId);
    return _health[providerId] ??
        LiveTvProviderHealth(
          providerId: providerId,
          state: LiveTvProviderState.idle,
        );
  }

  /// Returns the last known state without performing an unsolicited network
  /// request. Call [refresh] when an actual upstream check is required.
  Future<LiveTvProviderHealth> health({String? providerId}) async {
    await initialize();
    return healthFor(providerId ?? _selectedProviderId);
  }

  void _setHealth(
    String providerId,
    LiveTvProviderState state, {
    int? statusCode,
    String? message,
  }) {
    _health[providerId] = LiveTvProviderHealth(
      providerId: providerId,
      state: state,
      checkedAt: DateTime.now(),
      httpStatusCode: statusCode,
      message: message,
    );
  }

  LiveTvProviderState _failureState(Object error) {
    if (error is LiveTvProviderUnavailableException) {
      return LiveTvProviderState.unavailable;
    }
    final statusCode = error is DaddyLiveException ? error.statusCode : null;
    if (statusCode == 401 || statusCode == 403) {
      return LiveTvProviderState.blocked;
    }
    if (statusCode == 404 ||
        statusCode == 408 ||
        statusCode == 410 ||
        statusCode == 425 ||
        statusCode == 429 ||
        (statusCode != null && statusCode >= 500)) {
      return LiveTvProviderState.unavailable;
    }
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException) {
      return LiveTvProviderState.unavailable;
    }
    return LiveTvProviderState.error;
  }

  String _safeFailureMessage(LiveTvProviderState state) {
    switch (state) {
      case LiveTvProviderState.blocked:
        return 'This Live TV provider is blocked for this request.';
      case LiveTvProviderState.unavailable:
        return 'This Live TV provider is temporarily unavailable.';
      case LiveTvProviderState.error:
        return 'This Live TV provider returned an unexpected error.';
      case LiveTvProviderState.empty:
        return 'No channels are currently available from this provider.';
      case LiveTvProviderState.loading:
        return 'Loading Live TV provider.';
      case LiveTvProviderState.idle:
        return 'Live TV provider has not been checked yet.';
      case LiveTvProviderState.available:
        return 'Live TV provider is available.';
    }
  }

  @override
  Future<DaddyLiveCatalog> getCatalog({bool refresh = false}) async {
    await initialize();
    final providerId = _selectedProviderId;
    _setHealth(providerId, LiveTvProviderState.loading);
    try {
      final catalog = await _serviceFor(
        providerId,
      ).getCatalog(refresh: refresh);
      _catalogs[providerId] = catalog;
      final state = catalog.channels.isEmpty
          ? LiveTvProviderState.empty
          : LiveTvProviderState.available;
      _setHealth(providerId, state, message: _safeFailureMessage(state));
      return catalog;
    } catch (error) {
      final state = _failureState(error);
      _setHealth(
        providerId,
        state,
        statusCode: error is DaddyLiveException ? error.statusCode : null,
        message: error is LiveTvProviderUnavailableException
            ? error.message
            : _safeFailureMessage(state),
      );
      rethrow;
    }
  }

  /// Forces a catalog revalidation through the selected provider.
  Future<DaddyLiveCatalog> refresh() => getCatalog(refresh: true);

  /// Adds a remote playlist to the built-in IPTV/M3U provider. This is kept
  /// separate from source-repository installation: M3U playlists are user
  /// supplied data and do not execute JavaScript.
  Future<M3uPlaylistDefinition> addM3uPlaylistUrl({
    required String url,
    String? name,
  }) async {
    await initialize();
    final service = _serviceFor(m3uProviderId);
    if (service is! M3uLiveTvService) {
      throw StateError('The IPTV/M3U provider is not available.');
    }
    return service.addRemotePlaylist(url: url, name: name);
  }

  Future<M3uPlaylistDefinition> addLocalM3uPlaylist({
    required String filename,
    required List<int> bytes,
    String? name,
  }) async {
    await initialize();
    final service = _serviceFor(m3uProviderId);
    if (service is! M3uLiveTvService) {
      throw StateError('The IPTV/M3U provider is not available.');
    }
    return service.addLocalPlaylist(
      filename: filename,
      bytes: bytes,
      name: name,
    );
  }

  Future<List<M3uPlaylistDefinition>> m3uPlaylists() async {
    await initialize();
    final service = _serviceFor(m3uProviderId);
    if (service is! M3uLiveTvService) return const <M3uPlaylistDefinition>[];
    return service.playlists();
  }

  Future<void> removeM3uPlaylist(String playlistId) async {
    await initialize();
    final service = _serviceFor(m3uProviderId);
    if (service is! M3uLiveTvService) {
      throw StateError('The IPTV/M3U provider is not available.');
    }
    await service.removePlaylist(playlistId);
  }

  @override
  Future<DaddyLiveStream> getStream(String channelId) async {
    await initialize();
    final providerId = _selectedProviderId;
    _setHealth(providerId, LiveTvProviderState.loading);
    try {
      final stream = _validateStream(
        await _serviceFor(providerId).getStream(channelId),
      );
      _setHealth(
        providerId,
        LiveTvProviderState.available,
        message: _safeFailureMessage(LiveTvProviderState.available),
      );
      return stream;
    } catch (error) {
      final state = _failureState(error);
      _setHealth(
        providerId,
        state,
        statusCode: error is DaddyLiveException ? error.statusCode : null,
        message: error is LiveTvProviderUnavailableException
            ? error.message
            : _safeFailureMessage(state),
      );
      rethrow;
    }
  }

  DaddyLiveStream _validateStream(DaddyLiveStream stream) {
    final uri = Uri.tryParse(stream.url.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      stream.discovery?.dispose();
      throw const DaddyLiveException(
        'The provider returned an invalid stream URL.',
      );
    }
    final expiry = stream.expiresAt;
    if (expiry != null && !expiry.isAfter(DateTime.now())) {
      stream.discovery?.dispose();
      throw const DaddyLiveException(
        'The provider returned an expired stream URL.',
        statusCode: 410,
      );
    }

    return DaddyLiveStream(
      url: uri.toString(),
      headers: _safePlaybackHeaders(stream.headers),
      embedUrl: stream.embedUrl,
      expiresAt: expiry,
      mediaType: _normalizeMediaType(stream.mediaType),
      clearKey: _normalizeClearKey(stream.clearKey),
      title: stream.title,
      variants: stream.variants
          .where(_isValidVariant)
          .map(_normalizeVariant)
          .toList(growable: false),
      discovery: stream.discovery,
    );
  }

  bool _isValidVariant(LiveStreamVariant variant) {
    final uri = Uri.tryParse(variant.url.trim());
    final expiry = variant.expiresAt;
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (expiry == null || expiry.isAfter(DateTime.now()));
  }

  LiveStreamVariant _normalizeVariant(LiveStreamVariant variant) {
    return LiveStreamVariant(
      url: Uri.parse(variant.url.trim()).toString(),
      headers: _safePlaybackHeaders(variant.headers),
      mediaType: _normalizeMediaType(variant.mediaType),
      expiresAt: variant.expiresAt,
      clearKey: _normalizeClearKey(variant.clearKey),
      title: variant.title,
      logo: variant.logo,
    );
  }

  Map<String, String> _safePlaybackHeaders(Map<String, String> headers) {
    const allowedNames = <String, String>{
      'accept': 'Accept',
      'origin': 'Origin',
      'referer': 'Referer',
      'user-agent': 'User-Agent',
    };
    final safe = <String, String>{};
    for (final entry in headers.entries) {
      final name = allowedNames[entry.key.trim().toLowerCase()];
      final value = entry.value.trim();
      if (name == null ||
          value.isEmpty ||
          value.length > 4096 ||
          value.contains('\r') ||
          value.contains('\n')) {
        continue;
      }
      safe[name] = value;
    }
    return Map<String, String>.unmodifiable(safe);
  }

  String _normalizeMediaType(String mediaType) {
    final type = mediaType.trim().toLowerCase().split(';').first.trim();
    const dashTypes = <String>{
      'dash',
      'mpd',
      'application/dash+xml',
      'application/vnd.mpeg.dash.mpd',
    };
    return dashTypes.contains(type) ? 'dash' : 'hls';
  }

  String? _normalizeClearKey(String? clearKey) {
    if (clearKey == null || clearKey.isEmpty) return null;
    final match = RegExp(
      r'^([0-9a-fA-F]{32}):([0-9a-fA-F]{32})$',
    ).firstMatch(clearKey.trim());
    if (match == null) return null;
    return '${match.group(1)!.toLowerCase()}:${match.group(2)!.toLowerCase()}';
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final service in _services.values) {
      service.close();
    }
    _services.clear();
  }
}
