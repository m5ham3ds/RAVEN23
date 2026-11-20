import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/quickjs/quickjs_provider_runtime.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

void main() {
  test('leases three independent QuickJS workers to three sources', () async {
    final runtime = QuickJsProviderRuntime(maxConcurrentRuntimes: 3);
    final sources = <SourceManifest>[
      for (var i = 0; i < 3; i++)
        SourceManifest(
          id: 'pool-source-$i',
          name: 'Pool source $i',
          repositoryUrl: 'https://repo.example/index.json',
          engine: SourceEngineDescriptor(
            rawType: 'javascript',
            kind: SourceEngineKind.javascript,
            endpoint: 'https://scripts.example/source-$i.js',
          ),
        ),
    ];
    final assignedWorkers = <int>{};
    final allThreeStarted = Completer<void>();
    final releaseWorkers = Completer<void>();

    final tasks = <Future<void>>[
      for (final source in sources)
        runtime.runWithSource(source, () async {
          final workerIndex = runtime.workerIndexForTesting(source);
          expect(workerIndex, isNotNull);
          assignedWorkers.add(workerIndex!);
          if (assignedWorkers.length == 3 && !allThreeStarted.isCompleted) {
            allThreeStarted.complete();
          }
          await releaseWorkers.future;
        }),
    ];

    await allThreeStarted.future.timeout(const Duration(seconds: 2));
    expect(assignedWorkers, <int>{0, 1, 2});

    releaseWorkers.complete();
    await Future.wait(tasks).timeout(const Duration(seconds: 2));
  });
}
