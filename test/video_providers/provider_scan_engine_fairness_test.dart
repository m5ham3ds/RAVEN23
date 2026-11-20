import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/common.dart';
import 'package:raven23/video_providers/names.dart';
import 'package:raven23/video_providers/provider_loader.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

void main() {
  test(
    'starts three QuickJS providers concurrently within the global scan budget',
    () async {
      final quickJsGate = Completer<ProviderLoadResult>();
      final threeQuickJsStarted = Completer<void>();
      var activeQuickJs = 0;
      var peakQuickJs = 0;
      final providers = <VideoProvider>[
        _source('quickjs-a', SourceEngineKind.javascript),
        _source('quickjs-b', SourceEngineKind.javascript),
        _source('quickjs-c', SourceEngineKind.javascript),
        _source('stremio-next', SourceEngineKind.stremio),
      ];
      final session = ProviderScanSession(
        providers: providers,
        maxConcurrency: 3,
        stopAfterStandardQualities: false,
        load: (provider) async {
          if (provider.sourceManifest!.engine.kind ==
              SourceEngineKind.javascript) {
            activeQuickJs++;
            if (activeQuickJs > peakQuickJs) peakQuickJs = activeQuickJs;
            if (activeQuickJs == 3 && !threeQuickJsStarted.isCompleted) {
              threeQuickJsStarted.complete();
            }
            try {
              return await quickJsGate.future;
            } finally {
              activeQuickJs--;
            }
          }
          return const ProviderLoadResult();
        },
      );

      session.start();
      await threeQuickJsStarted.future.timeout(const Duration(seconds: 2));
      expect(activeQuickJs, 3);
      expect(peakQuickJs, 3);

      quickJsGate.complete(const ProviderLoadResult());
      await session.completed.timeout(const Duration(seconds: 2));
    },
  );
}

VideoProvider _source(String id, SourceEngineKind kind) =>
    VideoProvider.unifiedSource(
      SourceManifest(
        id: id,
        name: id,
        repositoryUrl: 'https://repo.example/index.json',
        engine: SourceEngineDescriptor(
          rawType: kind.name,
          kind: kind,
          endpoint: 'https://scripts.example/$id.js',
        ),
      ),
    );
