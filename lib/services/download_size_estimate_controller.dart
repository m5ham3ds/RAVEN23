import 'dart:async';

import 'package:flutter/foundation.dart';

import '../video_providers/quality_catalog.dart';
import '../video_providers/scraper_api.dart';

/// Resolves backend-signed size tokens. It never estimates size from a
/// resolution label or runtime, and keeps unavailable estimates explicit.
class DownloadSizeEstimateController {
  DownloadSizeEstimateController(String apiBaseUrl)
      : _api = ScraperApi(apiBaseUrl);

  final ScraperApi _api;
  final ValueNotifier<Map<String, int?>> estimates =
      ValueNotifier<Map<String, int?>>(<String, int?>{});
  final Map<String, Future<int?>> _pending = <String, Future<int?>>{};
  bool _disposed = false;

  void observe(Iterable<QualityCatalogEntry> entries) {
    for (final entry in entries) {
      if (entry.link.sizeToken?.trim().isNotEmpty == true) {
        unawaited(estimate(entry));
      }
    }
  }

  Future<int?> estimate(QualityCatalogEntry entry) {
    final token = entry.link.sizeToken?.trim() ?? '';
    if (token.isEmpty) return Future<int?>.value(null);
    final key = entry.sizeEstimateKey;
    if (estimates.value.containsKey(key)) {
      return Future<int?>.value(estimates.value[key]);
    }
    final existing = _pending[key];
    if (existing != null) return existing;

    final future = _api.estimateStreamSize(token).then((result) {
      final bytes = result?.estimatedBytes;
      final safeBytes = bytes != null && bytes > 0 ? bytes : null;
      if (!_disposed) {
        estimates.value = <String, int?>{...estimates.value, key: safeBytes};
      }
      return safeBytes;
    }).catchError((Object _) {
      if (!_disposed) {
        estimates.value = <String, int?>{...estimates.value, key: null};
      }
      return null;
    }).whenComplete(() {
      _pending.remove(key);
    });
    _pending[key] = future;
    return future;
  }

  void dispose() {
    _disposed = true;
    estimates.dispose();
    _pending.clear();
  }
}
