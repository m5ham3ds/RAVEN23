import 'dart:async';

/// Collects provider results independently so a single stalled provider cannot
/// erase results already returned by other providers.
///
/// Each request is already started by the caller. Individual request failures
/// are isolated, and the batch deadline returns the partial results collected
/// up to that point. Requests that finish after the deadline are ignored.
class SubtitleProviderOrchestrator {
  SubtitleProviderOrchestrator._();

  static Future<List<T>> collectPartialResults<T>({
    required Iterable<Future<List<T>>> requests,
    required Duration timeout,
  }) async {
    final collected = <T>[];
    var acceptingResults = true;

    final tasks = requests.map((request) async {
      try {
        final values = await request;
        if (acceptingResults) collected.addAll(values);
      } catch (_) {
        // Provider-level failures must not suppress another provider's result.
      }
    }).toList(growable: false);

    try {
      await Future.wait(tasks).timeout(timeout);
    } on TimeoutException {
      acceptingResults = false;
    }

    return List<T>.unmodifiable(collected);
  }
}
