import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/common.dart';
import 'package:raven23/video_providers/names.dart';
import 'package:raven23/video_providers/provider_loader.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

void main() {
  test(
    'a saturated QuickJS queue does not block a ready Stremio provider',
    () async {
      final quickJsGate = Completer<ProviderLoadResult>();
      final stremioStarted = Completer<void>();
      var activeQuickJs = 0;
      final providers = <VideoProvider>[
        _source('quickjs-a', SourceEngineKind.javascript),
        _source('quickjs-b', SourceEngineKind.javascript),
        _source('quickjs-c', SourceEngineKind.javascript),
        _source('stremio-ready', SourceEngineKind.stremio),
      ];
      final session = ProviderScanSession(
        providers: providers,
        maxConcurrency: 3,
        stopAfterStandardQualities: false,
        load: (provider) async {
          final kind = provider.sourceManifest!.engine.kind;
          if (kind == SourceEngineKind.javascript) {
            activeQuickJs++;
            try {
              return await quickJsGate.future;
            } finally {
              activeQuickJs--;
            }
          }
          if (provider.codeName.endsWith('stremio-ready') &&
              !stremioStarted.isCompleted) {
            stremioStarted.complete();
          }
          return const ProviderLoadResult();
        },
      );

      session.start();
      await stremioStarted.future.timeout(const Duration(seconds: 2));
      expect(activeQuickJs, 1);

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
