import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/video_providers/common.dart';
import 'package:raven23/video_providers/unified/stream_host_priority_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts with the requested stream-host order', () async {
    SharedPreferences.setMockInitialValues({});
    final manager = StreamHostPriorityManager.instance;
    await manager.initialize();
    expect(manager.currentOrder, <String>[
      'VixSrc',
      'Jett',
      'YaStream',
      'VidFast',
      'VidSpark',
      'HdHub',
      'Sova',
      'Sage',
      'Phoenix',
      'CineStream',
      'VidZee',
      'VegaMovies',
    ]);
  });

  test('recognizes a pinned host followed by an underscore suffix', () async {
    SharedPreferences.setMockInitialValues({});
    final manager = StreamHostPriorityManager.instance;
    await manager.initialize();

    expect(manager.rankOf('Jett_1080p'), 1);
    expect(manager.rankOf('VixSrc_direct'), 0);
  });

  test(
    'orders pinned hosts first and preserves unobserved host order',
    () async {
      SharedPreferences.setMockInitialValues({});
      final manager = StreamHostPriorityManager.instance;
      await manager.initialize();
      final ordered = manager.orderLinks(<RegularVideoLinks>[
        RegularVideoLinks(
          url: 'https://unknown.test/1',
          quality: '720p',
          server: 'Unobserved A',
        ),
        RegularVideoLinks(
          url: 'https://sova.test/1',
          quality: '720p',
          server: 'Sova',
        ),
        RegularVideoLinks(
          url: 'https://jett.test/1',
          quality: '720p',
          server: 'Jett',
        ),
        RegularVideoLinks(
          url: 'https://unknown.test/2',
          quality: '480p',
          server: 'Unobserved B',
        ),
      ]);

      expect(ordered.map((link) => link.server), <String?>[
        'Jett',
        'Sova',
        'Unobserved A',
        'Unobserved B',
      ]);
    },
  );

  test(
    'ranks unpinned hosts by measured reliability then startup latency',
    () async {
      SharedPreferences.setMockInitialValues({});
      final manager = StreamHostPriorityManager.instance;
      await manager.initialize();
      await manager.recordPlaybackSuccess(
        server: 'FastReliable',
        startupMs: 420,
      );
      await manager.recordPlaybackSuccess(
        server: 'SlowReliable',
        startupMs: 2100,
      );
      await manager.recordPlaybackSuccess(
        server: 'LessReliable',
        startupMs: 250,
      );
      await manager.recordPlaybackFailure(server: 'LessReliable');

      expect(manager.observedHostOrder, <String>[
        'FastReliable',
        'SlowReliable',
        'LessReliable',
      ]);
    },
  );

  test('failure-only extra hosts are not activated or promoted', () async {
    SharedPreferences.setMockInitialValues({});
    final manager = StreamHostPriorityManager.instance;
    await manager.initialize();
    await manager.recordPlaybackFailure(server: 'FailureOnlyHost');

    expect(manager.observedHostOrder, isNot(contains('FailureOnlyHost')));
    expect(
      manager.rankOf('FailureOnlyHost'),
      greaterThan(manager.rankOf('NeverTestedHost')),
    );
    expect(manager.metricsFor('FailureOnlyHost')?['failures'], 1);
    expect(manager.metricsFor('FailureOnlyHost')?['successes'], 0);
  });
}
