import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:raven23/data/models/bootstrap_config.dart';
import 'package:raven23/services/app_remote_config.dart';

/// Firebase is a payload provider; only Laravel can authorize applying it.
abstract interface class FirebaseConfigSource {
  Stream<void> get updates;
  Future<BootstrapConfig?> refresh();
}

class SdkFirebaseConfigSource implements FirebaseConfigSource {
  SdkFirebaseConfigSource({FirebaseRemoteConfig? remote})
      : _providedRemote = remote;
  final FirebaseRemoteConfig? _providedRemote;
  FirebaseRemoteConfig get _remote =>
      _providedRemote ?? FirebaseRemoteConfig.instance;
  Future<void>? _configured;

  @override
  Stream<void> get updates => _remote.onConfigUpdated.map((_) {});

  @override
  Future<BootstrapConfig?> refresh() async {
    try {
      await (_configured ??= AppRemoteConfig.configure(_remote));
      final activated = await _remote.activate();
      var fetched = false;
      try {
        await _remote.fetchAndActivate();
        fetched = true;
      } catch (_) {
        // An activated SDK cache is still valid when the fetch is offline.
      }
      final published = {
        for (final entry in _remote.getAll().entries)
          if (entry.value.source == ValueSource.valueRemote)
            entry.key: entry.value.asString(),
      };
      if (published.isEmpty && !fetched && !activated) return null;
      return firebaseConfigSnapshot(published);
    } catch (_) {
      _configured = null;
      return null;
    }
  }
}

/// Firebase no longer controls application releases. These retired flat
/// update keys belonged to the old Firebase update path and must not override
/// the current Laravel bootstrap update contract.
const _retiredFirebaseUpdateKeys = <String>{
  'forced_update',
  'latest_version',
  'latest_build_number',
  'min_build_number',
  'app_download_url',
  'app_download_url_arm64_v8a',
  'app_download_url_armeabi_v7a',
  'app_download_url_x86_64',
  'change_log',
};

/// Normalize Firebase's remaining flat keys through the shared bootstrap DTO.
/// Unpublished keys use bundled defaults, including the historical enable_ott
/// fallback. Current app updates are supplied by Laravel's bootstrap only.
BootstrapConfig firebaseConfigSnapshot(Map<String, dynamic> published) {
  final activeValues = <String, dynamic>{
    for (final entry in published.entries)
      if (!_retiredFirebaseUpdateKeys.contains(entry.key)) entry.key: entry.value,
  };
  if (activeValues.isEmpty) return const BootstrapConfig(configSource: 'firebase');
  Map<String, dynamic> section(List<String> keys) => {
        for (final key in keys)
          if (activeValues.containsKey(key)) key: activeValues[key],
      };
  Object? jsonValue(String key) {
    final value = activeValues[key];
    if (value is! String) return value;
    try {
      return jsonDecode(value);
    } catch (_) {
      if (key == 'occasional_theme') rethrow;
      return null;
    }
  }

  return BootstrapConfig.fromJson({
    'config_source': 'firebase',
    'runtime_settings': activeValues,
    'features': section([
      'enable_stream',
      'enable_download',
      'enable_live_tv',
      'enable_ott',
    ]),
    'branding': section(['app_logo_url', 'cinemax_logo']),
    'network': section([
      'flixquest_api_instances',
      'flixquest_api_url_v2',
      'tmdb_api_key',
      'tmdb_proxy',
    ]),
    'ads': section([
      'banner_ad_network',
      'hosted_banner_mode',
      'unity_game_id_android',
      'unity_banner_placement_id',
      'unity_test_mode',
    ]),
    'banners': jsonValue('banners'),
    'occasional_theme': jsonValue('occasional_theme'),
  });
}
