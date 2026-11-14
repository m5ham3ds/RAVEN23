import 'package:shared_preferences/shared_preferences.dart';

/// Manages Mihon-compatible protobuf repositories independently from the
/// video-provider JSON repository manager.
class MangaRepositoryManager {
  MangaRepositoryManager({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String defaultRepositoryUrl =
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb';
  static const String _repositoryUrlsKey = 'manga_mihon_repository_urls_v1';

  final SharedPreferences? _preferences;
  SharedPreferences? _resolvedPreferences;

  Future<SharedPreferences> get _prefs async {
    if (_preferences != null) return _preferences;
    return _resolvedPreferences ??= await SharedPreferences.getInstance();
  }

  /// Seeds Keiyoushi only on first use. An intentionally empty list remains
  /// empty and is not silently repopulated after the user removes a source.
  Future<List<String>> repositoryUrls() async {
    final preferences = await _prefs;
    final stored = preferences.getStringList(_repositoryUrlsKey);
    if (stored == null) {
      await preferences.setStringList(_repositoryUrlsKey, <String>[
        defaultRepositoryUrl,
      ]);
      return const <String>[defaultRepositoryUrl];
    }
    return _deduplicate(stored);
  }

  Future<void> addRepository(String value) async {
    final url = normalizeRepositoryUrl(value);
    final current = await repositoryUrls();
    if (current.contains(url)) {
      throw const FormatException('This manga repository is already added.');
    }
    final preferences = await _prefs;
    await preferences.setStringList(_repositoryUrlsKey, <String>[
      ...current,
      url,
    ]);
  }

  Future<void> updateRepository(String oldValue, String newValue) async {
    final oldUrl = normalizeRepositoryUrl(oldValue);
    final newUrl = normalizeRepositoryUrl(newValue);
    final current = await repositoryUrls();
    final index = current.indexOf(oldUrl);
    if (index < 0) {
      throw StateError('The manga repository no longer exists.');
    }
    if (newUrl != oldUrl && current.contains(newUrl)) {
      throw const FormatException('This manga repository is already added.');
    }
    final updated = List<String>.of(current)..[index] = newUrl;
    final preferences = await _prefs;
    await preferences.setStringList(_repositoryUrlsKey, updated);
  }

  Future<void> removeRepository(String value) async {
    final url = normalizeRepositoryUrl(value);
    final current = await repositoryUrls();
    final updated = current.where((entry) => entry != url).toList();
    final preferences = await _prefs;
    await preferences.setStringList(_repositoryUrlsKey, updated);
  }

  static String normalizeRepositoryUrl(String value) {
    final trimmed = value.trim();
    // Fragments are client-side only and are not part of the HTTP request.
    // Remove the separator and everything after it before parsing: using
    // Uri.replace(fragment: '') serializes an empty fragment as a trailing '#',
    // which makes a valid repository URL compare unequal to its stored form.
    final fragmentIndex = trimmed.indexOf('#');
    final withoutFragment = fragmentIndex < 0
        ? trimmed
        : trimmed.substring(0, fragmentIndex);
    final uri = Uri.tryParse(withoutFragment);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        !uri.path.toLowerCase().endsWith('.pb') ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Enter a valid HTTP(S) Mihon protobuf index URL ending in .pb.',
      );
    }
    return uri.toString();
  }

  static List<String> _deduplicate(Iterable<String> values) {
    final seen = <String>{};
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .where((value) {
          try {
            return seen.add(normalizeRepositoryUrl(value));
          } on FormatException {
            return false;
          }
        })
        .map(normalizeRepositoryUrl)
        .toList(growable: false);
  }
}
