import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/data/sync/library_scope.dart';
import 'package:raven23/data/sync/sync_runner.dart';

DioException connectionFailure() => DioException(
      requestOptions: RequestOptions(path: '/sync'),
      type: DioExceptionType.connectionError,
    );

void main() {
  test(
      'coalesces requests and schedules one follow-up after an in-flight local write',
      () async {
    LibraryScope.activate('user:1');
    final first = Completer<void>();
    final second = Completer<void>();
    var runs = 0;
    final runner = SyncRunner(
        canSync: () => true,
        run: (_, __) async {
          runs++;
          if (runs == 1) {
            await first.future;
          } else {
            second.complete();
          }
        },
        autoInterval: const Duration(minutes: 2),
        debounce: const Duration(seconds: 5));
    final started = runner.sync();
    runner.changed();
    first.complete();
    expect(await started, isTrue);
    await second.future;
    expect(runs, 2);
    await Future<void>.delayed(Duration.zero);
    runner.dispose();
    LibraryScope.activate(null);
  });

  test(
      'an account transition invalidates the old result and runs the requested new account afterward',
      () async {
    LibraryScope.activate('user:1');
    final first = Completer<void>();
    final done = Completer<void>();
    final owners = <String>[];
    final runner = SyncRunner(
        canSync: () => true,
        run: (owner, current) async {
          owners.add(owner);
          if (owner == 'user:1') {
            await first.future;
          } else {
            done.complete();
          }
        },
        autoInterval: const Duration(minutes: 2),
        debounce: const Duration(seconds: 5));
    final old = runner.sync();
    LibraryScope.activate('user:2');
    runner.ownerChanged();
    runner.sync();
    first.complete();
    expect(await old, isFalse);
    await done.future.timeout(const Duration(seconds: 1));
    expect(owners, ['user:1', 'user:2']);
    await Future<void>.delayed(Duration.zero);
    runner.dispose();
    LibraryScope.activate(null);
  });

  test('retries transient transport failures with bounded exponential backoff',
      () async {
    LibraryScope.activate('user:retry');
    final runs = <int>[];
    final delays = <Duration>[];
    final runner = SyncRunner(
      canSync: () => true,
      run: (_, __) async {
        runs.add(runs.length + 1);
        if (runs.length < 3) throw connectionFailure();
      },
      autoInterval: const Duration(minutes: 2),
      debounce: const Duration(seconds: 5),
      wait: (delay) async => delays.add(delay),
    );

    expect(await runner.sync(), isTrue);
    expect(runs, [1, 2, 3]);
    expect(delays, const [
      Duration(seconds: 1),
      Duration(seconds: 2),
    ]);
    expect(runner.lastAttemptCount.value, 3);
    expect(runner.lastSyncDurationMs.value, isNotNull);
    expect(runner.consecutiveFailures.value, 0);
    expect(runner.status.value, 'success');

    runner.dispose();
    LibraryScope.activate(null);
  });

  test('does not retry authentication or validation responses', () async {
    LibraryScope.activate('user:no-retry');
    var runs = 0;
    final delays = <Duration>[];
    final request = RequestOptions(path: '/sync');
    final runner = SyncRunner(
      canSync: () => true,
      run: (_, __) async {
        runs++;
        throw DioException(
          requestOptions: request,
          response: Response<dynamic>(
            requestOptions: request,
            statusCode: 422,
            data: {'errors': {'since_revision': ['invalid']}},
          ),
          type: DioExceptionType.badResponse,
        );
      },
      autoInterval: const Duration(minutes: 2),
      debounce: const Duration(seconds: 5),
      wait: (delay) async => delays.add(delay),
    );

    expect(await runner.sync(), isFalse);
    expect(runs, 1);
    expect(delays, isEmpty);
    expect(runner.lastAttemptCount.value, 1);
    expect(runner.consecutiveFailures.value, 1);
    expect(runner.status.value, 'error');

    runner.dispose();
    LibraryScope.activate(null);
  });

  test('cancels pending backoff when the authenticated owner changes',
      () async {
    LibraryScope.activate('user:old');
    final waiting = Completer<void>();
    final release = Completer<void>();
    var runs = 0;
    final runner = SyncRunner(
      canSync: () => true,
      run: (_, __) async {
        runs++;
        throw connectionFailure();
      },
      autoInterval: const Duration(minutes: 2),
      debounce: const Duration(seconds: 5),
      wait: (_) async {
        waiting.complete();
        await release.future;
      },
    );

    final old = runner.sync();
    await waiting.future;
    LibraryScope.activate('user:new');
    runner.ownerChanged();
    release.complete();

    expect(await old, isFalse);
    expect(runs, 1);
    expect(runner.status.value, 'idle');
    expect(runner.lastAttemptCount.value, 0);

    runner.dispose();
    LibraryScope.activate(null);
  });
}
