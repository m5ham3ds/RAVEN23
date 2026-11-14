// ignore_for_file: constant_identifier_names

import 'dart:convert';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';

class AppDependencies {
  static const RAVEN23_LOGO_URL = 'raven23LogoUrl';
  static const RAVEN23_API_URL = 'raven23APIURL';
  static const RAVEN23_API_INSTANCES = 'raven23APIInstances';
  // Read-only migration sources from the previous app identity. Keep these
  // until old installations and imported preference backups have migrated.
  static const _legacyLogoUrlKey = 'flixquestLogoUrl';
  static const _legacyApiUrlKey = 'flixquestAPIURL';
  static const _legacyApiInstancesKey = 'flixquestAPIInstances';
  static const TMDB_PROXY = 'tmdb_proxy';
  static const OCCASIONAL_THEME = 'occasionalTheme';
  static const OCCASIONAL_THEME_SELECTION = 'occasionalThemeSelection';
  static const OCCASIONAL_THEME_ENABLED = 'occasionalThemeEnabled';
  static const OCCASIONAL_EFFECTS_ENABLED = 'occasionalEffectsEnabled';
  static const AMBIENT_MODE_ENABLED = 'ambientModeEnabled';

  Future<void> setRAVEN23Url(String value) async {
    await sharedPrefsSingleton.setString(RAVEN23_LOGO_URL, value);
  }

  Future<String> getRaven23ApiURL() async {
    final current = sharedPrefsSingleton.getString(RAVEN23_API_URL);
    if (current != null) return current;
    final legacy = sharedPrefsSingleton.getString(_legacyApiUrlKey);
    if (legacy != null && legacy.isNotEmpty) {
      await sharedPrefsSingleton.setString(RAVEN23_API_URL, legacy);
      return legacy;
    }
    return raven23ApiUrl;
  }

  Future<void> setRaven23APIUrl(String value) async {
    await sharedPrefsSingleton.setString(RAVEN23_API_URL, value);
  }

  Future<List<String>> getRaven23ApiInstances() async {
    final current = sharedPrefsSingleton.getStringList(RAVEN23_API_INSTANCES);
    if (current != null) return current;
    final legacy = sharedPrefsSingleton.getStringList(_legacyApiInstancesKey);
    if (legacy != null) {
      await sharedPrefsSingleton.setStringList(RAVEN23_API_INSTANCES, legacy);
      return legacy;
    }
    return const [];
  }

  Future<void> setRaven23APIInstances(List<String> values) async {
    await sharedPrefsSingleton.setStringList(RAVEN23_API_INSTANCES, values);
  }

  Future<String> getRAVEN23Logo() async {
    final current = sharedPrefsSingleton.getString(RAVEN23_LOGO_URL);
    if (current != null) return current;
    final legacy = sharedPrefsSingleton.getString(_legacyLogoUrlKey);
    if (legacy != null && legacy.isNotEmpty) {
      await sharedPrefsSingleton.setString(RAVEN23_LOGO_URL, legacy);
      return legacy;
    }
    return 'default';
  }

  Future<void> setTmdbProxy(String value) async {
    await sharedPrefsSingleton.setString(TMDB_PROXY, value);
  }

  Future<String> getTmdbProxy() async {
    return sharedPrefsSingleton.getString(TMDB_PROXY) ?? '';
  }

  Future<void> setOccasionalTheme(String value) async {
    await sharedPrefsSingleton.setString(OCCASIONAL_THEME, value);
  }

  Future<String> getOccasionalTheme() async {
    return sharedPrefsSingleton.getString(OCCASIONAL_THEME) ?? '';
  }

  Future<void> setOccasionalThemeSelection(String value) async {
    await sharedPrefsSingleton.setString(OCCASIONAL_THEME_SELECTION, value);
  }

  Future<String> getOccasionalThemeSelection() async {
    return sharedPrefsSingleton.getString(OCCASIONAL_THEME_SELECTION) ??
        'automatic';
  }

  Future<void> setOccasionalThemeEnabled(bool value) async {
    await sharedPrefsSingleton.setBool(OCCASIONAL_THEME_ENABLED, value);
  }

  Future<bool> getOccasionalThemeEnabled() async {
    return sharedPrefsSingleton.getBool(OCCASIONAL_THEME_ENABLED) ?? true;
  }

  Future<void> setOccasionalEffectsEnabled(bool value) async {
    await sharedPrefsSingleton.setBool(OCCASIONAL_EFFECTS_ENABLED, value);
  }

  Future<bool> getOccasionalEffectsEnabled() async {
    return sharedPrefsSingleton.getBool(OCCASIONAL_EFFECTS_ENABLED) ?? true;
  }

  Future<void> setAmbientModeEnabled(bool value) async {
    await sharedPrefsSingleton.setBool(AMBIENT_MODE_ENABLED, value);
  }

  Future<bool> getAmbientModeEnabled() async {
    return sharedPrefsSingleton.getBool(AMBIENT_MODE_ENABLED) ?? false;
  }

  static const IS_FORCED_UPDATE = 'is_forced_update';
  static const LATEST_APP_VERSION = 'latest_app_version';
  static const LATEST_BUILD_NUMBER = 'latest_build_number';
  static const MINIMUM_BUILD_NUMBER = 'minimum_build_number';
  static const APP_DOWNLOAD_URL = 'app_download_url';
  static const APP_ABI_DOWNLOAD_URLS = 'app_abi_download_urls';
  static const CHANGE_LOG = 'change_log';

  Future<void> setUpdateConfiguration({
    required bool forced,
    required String latestVersion,
    required int latestBuild,
    required int minimumBuild,
    required String downloadUrl,
    required Map<String, String> abiDownloadUrls,
    required String changeLog,
  }) async {
    await sharedPrefsSingleton.setBool(IS_FORCED_UPDATE, forced);
    await sharedPrefsSingleton.setString(LATEST_APP_VERSION, latestVersion);
    await sharedPrefsSingleton.setInt(LATEST_BUILD_NUMBER, latestBuild);
    await sharedPrefsSingleton.setInt(MINIMUM_BUILD_NUMBER, minimumBuild);
    await sharedPrefsSingleton.setString(APP_DOWNLOAD_URL, downloadUrl);
    await sharedPrefsSingleton.setString(
        APP_ABI_DOWNLOAD_URLS, jsonEncode(abiDownloadUrls));
    await sharedPrefsSingleton.setString(CHANGE_LOG, changeLog);
  }

  Map<String, dynamic> getUpdateConfiguration() {
    return {
      'forced': sharedPrefsSingleton.getBool(IS_FORCED_UPDATE) ?? false,
      'latestVersion': sharedPrefsSingleton.getString(LATEST_APP_VERSION) ?? '',
      'latestBuild': sharedPrefsSingleton.getInt(LATEST_BUILD_NUMBER) ?? 0,
      'minimumBuild': sharedPrefsSingleton.getInt(MINIMUM_BUILD_NUMBER) ?? 0,
      'downloadUrl': sharedPrefsSingleton.getString(APP_DOWNLOAD_URL) ?? '',
      'abiDownloadUrls': _decodeAbiDownloadUrls(
          sharedPrefsSingleton.getString(APP_ABI_DOWNLOAD_URLS)),
      'changeLog': sharedPrefsSingleton.getString(CHANGE_LOG) ?? '',
    };
  }

  static Map<String, String> _decodeAbiDownloadUrls(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries)
            if (entry.value is String)
              entry.key.toString(): entry.value as String,
        };
      }
    } catch (_) {
      // A corrupt cache falls back to the universal link until the next fetch.
    }
    return const {};
  }
}
