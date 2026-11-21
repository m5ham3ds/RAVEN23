import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/offline_download.dart';
import '../services/offline_download_service.dart';
import '../manga/ui/manga_notification_service.dart';

class OfflineDownloadProvider extends ChangeNotifier {
  OfflineDownloadProvider({OfflineDownloadGateway? service})
      : _service = service ?? OfflineDownloadService.instance;

  final OfflineDownloadGateway _service;
  StreamSubscription<List<OfflineDownload>>? _subscription;
  List<OfflineDownload> _downloads = const [];
  final Map<String, _DownloadRateSample> _rateSamples = {};
  final Map<String, OfflineExportProgress> _exports = {};
  final Set<String> _automaticExportProgressChecked = <String>{};
  Timer? _automaticExportPoller;
  bool _pollingAutomaticExports = false;
  bool _initialized = false;
  bool _loading = false;
  String? _error;

  List<OfflineDownload> get downloads => _downloads;
  bool get loading => _loading;
  String? get error => _error;
  OfflineExportProgress? exportFor(String id) => _exports[id];

  Future<OfflineStorageSnapshot> getStorageSnapshot() =>
      _service.getStorageSnapshot();

  OfflineDownload? downloadForId(String id) {
    for (final download in _downloads) {
      if (download.id == id) return download;
    }
    return null;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _subscription = _service.downloadEvents.listen(
      _replaceDownloads,
      onError: (Object error) {
        _error = error.toString();
        notifyListeners();
      },
    );
    await refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _replaceDownloads(await _service.getDownloads());
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> enqueue(OfflineDownloadRequest request) async {
    _error = null;
    try {
      await _service.enqueue(request);
      await refresh();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pause(String id) => _perform(() => _service.pause(id));
  Future<void> resume(String id) => _perform(() => _service.resume(id));
  Future<void> retry(String id) => _perform(() => _service.retry(id));
  Future<void> remove(String id) => _perform(() => _service.remove(id));
  Future<OfflineExportProgress> getExportProgress(String id) =>
      _service.getExportProgress(id);

  Future<String> prepareForPlayback(String id) =>
      _runExport(id, () => _service.prepareForPlayback(id));
  Future<void> openExternal(String id) =>
      _runExport(id, () => _service.openExternal(id));
  Future<bool> saveCopy(String id) =>
      _runExport(id, () => _service.saveCopy(id));

  Future<T> _runExport<T>(String id, Future<T> Function() operation) async {
    _exports[id] = const OfflineExportProgress(state: 'starting');
    notifyListeners();
    var polling = true;
    var querying = false;

    Future<void> updateProgress() async {
      if (!polling || querying) return;
      querying = true;
      try {
        final next = await _service.getExportProgress(id);
        if (!polling) return;
        if (next.state == 'idle') {
          _exports.remove(id);
        } else {
          _exports[id] = next;
        }
        notifyListeners();
      } catch (_) {
        // The export method reports the actionable error. A transient progress
        // query failure should not abort the export itself.
      } finally {
        querying = false;
      }
    }

    final timer = Timer.periodic(
      const Duration(milliseconds: 350),
      (_) => unawaited(updateProgress()),
    );
    unawaited(updateProgress());
    try {
      return await operation();
    } finally {
      polling = false;
      timer.cancel();
      _exports.remove(id);
      _syncAutomaticExportPoller();
      notifyListeners();
    }
  }

  bool _isAutomaticExportPending(OfflineExportProgress progress) =>
      const {'queued', 'starting', 'available', 'unavailable'}
          .contains(progress.state);

  void _refreshAutomaticExportProgress(String id) {
    unawaited(() async {
      try {
        final progress = await _service.getExportProgress(id);
        if (!_downloads.any((item) => item.id == id && item.isComplete)) return;
        if (progress.state == 'idle') {
          _exports.remove(id);
        } else {
          _exports[id] = progress;
        }
        _syncAutomaticExportPoller();
        notifyListeners();
      } catch (_) {
        // Downloading and playback remain independent of status polling.
      }
    }());
  }

  void _syncAutomaticExportPoller() {
    final hasPending = _exports.values.any(_isAutomaticExportPending);
    if (hasPending && _automaticExportPoller == null) {
      _automaticExportPoller = Timer.periodic(
        const Duration(milliseconds: 900),
        (_) => unawaited(_pollAutomaticExportProgress()),
      );
    } else if (!hasPending && _automaticExportPoller != null) {
      _automaticExportPoller!.cancel();
      _automaticExportPoller = null;
    }
  }

  Future<void> _pollAutomaticExportProgress() async {
    if (_pollingAutomaticExports) return;
    _pollingAutomaticExports = true;
    try {
      final pendingIds = _exports.entries
          .where((entry) => _isAutomaticExportPending(entry.value))
          .map((entry) => entry.key)
          .toList(growable: false);
      for (final id in pendingIds) {
        if (!_downloads.any((item) => item.id == id && item.isComplete)) {
          _exports.remove(id);
          continue;
        }
        try {
          final next = await _service.getExportProgress(id);
          if (next.state == 'idle') {
            _exports.remove(id);
          } else {
            _exports[id] = next;
          }
        } catch (_) {
          // Keep the last known state until the next lightweight poll.
        }
      }
      _syncAutomaticExportPoller();
      notifyListeners();
    } finally {
      _pollingAutomaticExports = false;
    }
  }

  Future<void> _perform(Future<void> Function() operation) async {
    _error = null;
    try {
      await operation();
      await refresh();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _replaceDownloads(List<OfflineDownload> downloads) {
    final previousById = {for (final item in _downloads) item.id: item};
    final now = DateTime.now();
    final activeIds = downloads.map((download) => download.id).toSet();
    final completedIds = downloads
        .where((download) => download.isComplete)
        .map((download) => download.id)
        .toSet();
    _automaticExportProgressChecked.removeWhere(
      (id) => !completedIds.contains(id),
    );
    _exports.removeWhere((id, _) => !completedIds.contains(id));
    _rateSamples.removeWhere((id, _) => !activeIds.contains(id));

    final withRates = downloads.map((download) {
      if (download.state != OfflineDownloadState.downloading) {
        _rateSamples.remove(download.id);
        return download.copyWith(networkRateBytesPerSecond: 0);
      }

      final previous = _rateSamples[download.id];
      var rate = download.networkRateBytesPerSecond;
      if (previous == null || download.bytesDownloaded < previous.bytes) {
        _rateSamples[download.id] = _DownloadRateSample(
          bytes: download.bytesDownloaded,
          sampledAt: now,
          rate: rate,
        );
      } else {
        final elapsed = now.difference(previous.sampledAt).inMilliseconds;
        if (elapsed >= 400) {
          final bytesAdded = download.bytesDownloaded - previous.bytes;
          final measuredRate = bytesAdded * 1000 / elapsed;
          rate = previous.rate <= 0
              ? measuredRate
              : (measuredRate * .65) + (previous.rate * .35);
          if (rate < 1024) rate = 0;
          _rateSamples[download.id] = _DownloadRateSample(
            bytes: download.bytesDownloaded,
            sampledAt: now,
            rate: rate,
          );
        } else {
          rate = previous.rate;
        }
      }
      return download.copyWith(networkRateBytesPerSecond: rate);
    });

    final sorted = List<OfflineDownload>.of(withRates)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _downloads = List.unmodifiable(sorted);
    for (final download in sorted) {
      if (download.isComplete &&
          _automaticExportProgressChecked.add(download.id) &&
          !_exports.containsKey(download.id)) {
        _refreshAutomaticExportProgress(download.id);
      }
      final previous = previousById[download.id];
      if (previous == null || previous.state == download.state) continue;
      if (download.state == OfflineDownloadState.completed) {
        unawaited(MangaNotificationService.instance.showDownloadStatus(
          downloadId: download.id,
          title: download.title,
          failed: false,
        ));
      } else if (download.state == OfflineDownloadState.failed) {
        unawaited(MangaNotificationService.instance.showDownloadStatus(
          downloadId: download.id,
          title: download.title,
          failed: true,
          error: download.error,
        ));
      }
    }
    _syncAutomaticExportPoller();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _automaticExportPoller?.cancel();
    super.dispose();
  }
}

class _DownloadRateSample {
  const _DownloadRateSample({
    required this.bytes,
    required this.sampledAt,
    required this.rate,
  });

  final int bytes;
  final DateTime sampledAt;
  final double rate;
}
