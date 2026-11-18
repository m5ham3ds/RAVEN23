import 'dart:convert';

import 'source_manifest.dart';

/// Conservative deny-list for provider extensions dedicated to Hentai.
///
/// Repository data is untrusted metadata, so every identifying field is
/// inspected before an extension is installed or executed by a health probe.
class SourceCatalogSafetyPolicy {
  SourceCatalogSafetyPolicy._();

  /// Hanime is a Hentai-oriented provider even though its name does not contain
  /// the literal word "hentai". Keep it explicitly excluded alongside any
  /// provider whose metadata contains that word.
  static const Set<String> _knownHentaiProviderIds = <String>{
    'hanime',
    'hentaimama',
  };

  /// Checks only the source identity portion of a stable key. Repository URLs
  /// are deliberately ignored so one repository path cannot block every
  /// otherwise-safe provider published by that index.
  static bool isExcludedStableKey(String stableKey) {
    final separator = stableKey.lastIndexOf('::');
    final sourceIdentity = separator >= 0
        ? stableKey.substring(separator + 2)
        : stableKey;
    final normalized = _normalize(sourceIdentity);
    return _knownHentaiProviderIds.contains(normalized) ||
        normalized.contains('hentai') ||
        sourceIdentity.toLowerCase().contains('هنتاي');
  }

  static bool isExcludedHentai(SourceManifest source) {
    final normalizedId = _normalize(source.id);
    final normalizedName = _normalize(source.name);
    final rawIdentity = '${source.id} ${source.name}'.toLowerCase();
    if (_knownHentaiProviderIds.contains(normalizedId) ||
        _knownHentaiProviderIds.contains(normalizedName) ||
        normalizedId.contains('hentai') ||
        normalizedName.contains('hentai') ||
        rawIdentity.contains('هنتاي')) {
      return true;
    }

    // Avoid excluding every item from a repository merely because its index
    // URL or author mentions Hentai. Use source-level category/configuration
    // metadata and the source's own homepage path to identify its purpose.
    final metadata = <String>[
      ...source.tags,
      source.engine.rawType,
      source.engine.endpoint,
      source.homepage ?? '',
      _flattenConfig(source.engine.config),
    ].join(' ').toLowerCase();

    return metadata.contains('hentai') ||
        metadata.contains('هنتاي') ||
        _descriptionIdentifiesHentai(source.description);
  }

  static bool _descriptionIdentifiesHentai(String description) {
    final normalized = description.toLowerCase();
    if (!RegExp(r'\bhentai\b').hasMatch(normalized) &&
        !normalized.contains('هنتاي')) {
      return false;
    }
    if (RegExp(
      r'\b(no|not|without|exclude[sd]?|does not)\b[^.]{0,40}\bhentai\b',
    ).hasMatch(normalized)) {
      return false;
    }
    return RegExp(
      r'\b(stream|streaming|provider|anime|content|site|catalog)\b',
    ).hasMatch(normalized);
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static String _flattenConfig(Map<String, dynamic> config) {
    try {
      return jsonEncode(config);
    } catch (_) {
      return config.toString();
    }
  }
}
