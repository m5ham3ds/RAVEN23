import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/services/subtitle_provider_orchestrator.dart';

void main() {
  group('SubtitleProviderOrchestrator.collectPartialResults', () {
    test('collects results from every provider that completes', () async {
      final results =
          await SubtitleProviderOrchestrator.collectPartialResults<String>(
            requests: <Future<List<String>>>[
              Future<List<String>>.value(<String>['arabic-a']),
              Future<List<String>>.value(<String>['arabic-b']),
            ],
            timeout: const Duration(seconds: 1),
          );

      expect(results, <String>['arabic-a', 'arabic-b']);
    });

    test('retains completed results when another provider misses deadline',
        () async {
      final slowProvider = Completer<List<String>>();

      final results =
          await SubtitleProviderOrchestrator.collectPartialResults<String>(
            requests: <Future<List<String>>>[
              Future<List<String>>.value(<String>['available-result']),
              slowProvider.future,
            ],
            timeout: const Duration(milliseconds: 20),
          );

      expect(results, <String>['available-result']);
      slowProvider.complete(<String>['too-late']);
      await Future<void>.delayed(Duration.zero);
      expect(results, <String>['available-result']);
    });

    test('isolates a provider exception from successful providers', () async {
      final results =
          await SubtitleProviderOrchestrator.collectPartialResults<String>(
            requests: <Future<List<String>>>[
              Future<List<String>>.error(StateError('provider unavailable')),
              Future<List<String>>.value(<String>['working-provider']),
            ],
            timeout: const Duration(seconds: 1),
          );

      expect(results, <String>['working-provider']);
    });

    test('returns an immutable result snapshot', () async {
      final results =
          await SubtitleProviderOrchestrator.collectPartialResults<String>(
            requests: <Future<List<String>>>[
              Future<List<String>>.value(<String>['one']),
            ],
            timeout: const Duration(seconds: 1),
          );

      expect(() => results.add('two'), throwsUnsupportedError);
    });
  });
}
