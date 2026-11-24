import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'library_scope.dart';

/// One serialized sync at a time, with a coalesced follow-up for local writes.
class SyncRunner {
  SyncRunner({
    required this.canSync,
    required this.run,
    required this.autoInterval,
    required this.debounce,
    this.maxAttempts = 3,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.retryMaxDelay = const Duration(seconds: 8),
    Future<void> Function(Duration)? wait,
    bool Function(Object error)? isRetryable,
  })  : _wait = wait ?? _defaultWait,
        _isRetryable = isRetryable ?? isTransientFailure {
    assert(maxAttempts >= 1);
    assert(retryBaseDelay >= Duration.zero);
    assert(retryMaxDelay >= retryBaseDelay);
  }

  final bool Function() canSync;
  final Future<void> Function(String owner, bool Function() current) run;
  final Duration autoInterval, debounce;
  final int maxAttempts;
  final Duration retryBaseDelay, retryMaxDelay;
  final Future<void> Function(Duration) _wait;
  final bool Function(Object error) _isRetryable;

  final status = ValueNotifier<String>('idle');
  final lastSynced = ValueNotifier<DateTime?>(null);
  final lastAttemptCount = ValueNotifier<int>(0);
  final lastSyncDurationMs = ValueNotifier<int?>(null);
  final consecutiveFailures = ValueNotifier<int>(0);

  Future<bool>? _running;
  Timer? _timer;
  bool _followUp = false;
  bool _disposed = false;
  String? _lastOwner;
  DateTime? _autoAt;

  static Future<void> _defaultWait(Duration duration) =>
      Future<void>.delayed(duration);

  /// Retry transport failures and explicitly transient HTTP responses only.
  /// Authentication, validation, conflict and malformed-response errors must
  /// surface immediately for their domain-specific recovery.
  static bool isTransientFailure(Object error) {
    if (error is! DioException) return false;

    final status = error.response?.statusCode;
    if (status != null) {
      return const {408, 425, 429, 500, 502, 503, 504}.contains(status);
    }

    return const {
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    }.contains(error.type);
  }

  Duration _retryDelay(int failedAttempt, Object error) {
    if (error is DioException && error.response?.statusCode == 429) {
      final retryAfter = int.tryParse(
          error.response?.headers.value('retry-after') ?? '');
      if (retryAfter != null && retryAfter > 0) {
        final milliseconds = (retryAfter * 1000)
            .clamp(0, const Duration(minutes: 2).inMilliseconds)
            .toInt();
        return Duration(milliseconds: milliseconds);
      }
    }

    final exponent = (failedAttempt - 1).clamp(0, 10).toInt();
    final milliseconds = retryBaseDelay.inMilliseconds * (1 << exponent);
    return Duration(
        milliseconds:
            milliseconds.clamp(0, retryMaxDelay.inMilliseconds).toInt());
  }

  void ownerChanged() {
    _timer?.cancel();
    _timer = null;
    _followUp = false;
    _lastOwner = null;
    _autoAt = null;
    lastSynced.value = null;
    lastAttemptCount.value = 0;
    lastSyncDurationMs.value = null;
    consecutiveFailures.value = 0;
    status.value = 'idle';
  }

  void changed() {
    if (!canSync()) return;
    if (_running != null) _followUp = true;
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(sync());
    });
  }

  Future<void> flush() async {
    if (_timer == null) return;
    _timer?.cancel();
    _timer = null;
    await sync();
  }

  Future<void> autoSync() async {
    if (!canSync()) return;
    final owner = LibraryScope.owner;
    if (_lastOwner == owner &&
        _autoAt != null &&
        DateTime.now().difference(_autoAt!) < autoInterval) {
      return;
    }
    if (await sync()) {
      _lastOwner = owner;
      _autoAt = DateTime.now();
    }
  }

  Future<bool> sync() {
    if (_disposed || !canSync()) return Future.value(false);
    if (_running != null) {
      _followUp = true;
      return _running!;
    }

    final owner = LibraryScope.owner;
    final generation = LibraryScope.generation;
    bool current() =>
        !_disposed &&
        canSync() &&
        LibraryScope.owner == owner &&
        LibraryScope.generation == generation;

    final completer = Completer<bool>();
    _running = completer.future;
    () async {
      var success = false;
      var attempts = 0;
      final stopwatch = Stopwatch()..start();

      void recordFailure() {
        if (!current()) return;
        consecutiveFailures.value++;
        status.value = 'error';
      }

      try {
        while (current() && attempts < maxAttempts) {
          attempts++;
          lastAttemptCount.value = attempts;
          try {
            status.value = 'syncing';
            await run(owner, current);
            if (current()) {
              lastSynced.value = DateTime.now();
              status.value = 'success';
              consecutiveFailures.value = 0;
              success = true;
            }
            break;
          } catch (error) {
            if (!current()) break;
            if (attempts >= maxAttempts || !_isRetryable(error)) {
              recordFailure();
              break;
            }
            await _wait(_retryDelay(attempts, error));
          }
        }
      } catch (_) {
        recordFailure();
      } finally {
        stopwatch.stop();
        if (current()) {
          lastAttemptCount.value = attempts;
          lastSyncDurationMs.value = stopwatch.elapsedMilliseconds;
        }
        _running = null;
        completer.complete(success);
        if (_followUp && !_disposed && canSync()) {
          _followUp = false;
          _timer?.cancel();
          _timer = null;
          unawaited(sync());
        }
      }
    }();

    return completer.future;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    status.dispose();
    lastSynced.dispose();
    lastAttemptCount.dispose();
    lastSyncDurationMs.dispose();
    consecutiveFailures.dispose();
  }
}
