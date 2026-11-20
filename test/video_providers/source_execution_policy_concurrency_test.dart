import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/source_execution_policy.dart';
import 'package:raven23/video_providers/unified/source_manifest.dart';

void main() {
  test('supported engines can use all three source scan slots', () {
    const policy = SourceExecutionPolicy(maxConcurrentSources: 3);

    for (final kind in <SourceEngineKind>[
      SourceEngineKind.javascript,
      SourceEngineKind.animeSite,
      SourceEngineKind.stremio,
      SourceEngineKind.vidkingDirect,
      SourceEngineKind.webEmbed,
      SourceEngineKind.vidkingWebView,
      SourceEngineKind.httpJson,
      SourceEngineKind.legacyScraperApi,
      SourceEngineKind.native,
    ]) {
      expect(
        policy.concurrencyFor(kind),
        3,
        reason: '${kind.name} must support the three-worker scan budget.',
      );
    }

    expect(policy.concurrencyFor(SourceEngineKind.unsupported), 1);
  });
}
