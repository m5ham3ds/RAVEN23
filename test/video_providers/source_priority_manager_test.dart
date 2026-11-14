import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/video_providers/unified/source_priority_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('primary and backup lists have independent 20 and 30 item limits', () async {
    final manager = SourcePriorityManager();
    final primary = List<String>.generate(21, (index) => 'primary-$index');
    final backup = List<String>.generate(31, (index) => 'backup-$index');

    await manager.setPriorityKeys(SourcePriorityCategory.movies, primary);
    await manager.setBackupKeys(SourcePriorityCategory.movies, backup);

    expect(
      await manager.getPriorityKeys(SourcePriorityCategory.movies),
      hasLength(SourcePriorityManager.maxPrimarySources),
    );
    expect(
      await manager.getBackupKeys(SourcePriorityCategory.movies),
      hasLength(SourcePriorityManager.maxBackupSources),
    );
    expect(
      await manager.addPriorityKey(SourcePriorityCategory.movies, 'overflow'),
      isFalse,
    );
    expect(
      await manager.addKey(
        SourcePriorityCategory.movies,
        SourcePriorityLane.backup,
        'overflow',
      ),
      isFalse,
    );
  });

  test('same source cannot be added to both lanes of one media category', () async {
    final manager = SourcePriorityManager();
    expect(
      await manager.addKey(
        SourcePriorityCategory.movies,
        SourcePriorityLane.primary,
        'repo::source-a',
      ),
      isTrue,
    );
    expect(
      await manager.addKey(
        SourcePriorityCategory.movies,
        SourcePriorityLane.backup,
        'repo::source-a',
      ),
      isFalse,
    );
    expect(
      await manager.addKey(
        SourcePriorityCategory.series,
        SourcePriorityLane.backup,
        'repo::source-a',
      ),
      isTrue,
    );
  });

  test('legacy v1 priority list is preserved as the primary list', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'raven23.source_priorities.v1.movies': <String>[
        'repo::first',
        'repo::second',
      ],
    });
    final manager = SourcePriorityManager();

    expect(
      await manager.getPriorityKeys(SourcePriorityCategory.movies),
      <String>['repo::first', 'repo::second'],
    );
    expect(
      await manager.getBackupKeys(SourcePriorityCategory.movies),
      isEmpty,
    );
  });

  test('legacy backup migration seeds only missing backup lanes', () async {
    final manager = SourcePriorityManager();
    final seeded = await manager.seedBackupKeysIfMissing(
      SourcePriorityCategory.series,
      <String>['repo::legacy-a', 'repo::legacy-b'],
    );
    expect(seeded, isTrue);

    await manager.setBackupKeys(
      SourcePriorityCategory.series,
      <String>['repo::user-choice'],
    );
    final reseeded = await manager.seedBackupKeysIfMissing(
      SourcePriorityCategory.series,
      <String>['repo::new-default'],
    );

    expect(reseeded, isFalse);
    expect(
      await manager.getBackupKeys(SourcePriorityCategory.series),
      <String>['repo::user-choice'],
    );
  });

  test('cross-lane swap exchanges positions and maintains uniqueness', () async {
    final manager = SourcePriorityManager();
    await manager.setPriorityKeys(SourcePriorityCategory.anime, <String>[
      'repo::p1',
      'repo::p2',
    ]);
    await manager.setBackupKeys(SourcePriorityCategory.anime, <String>[
      'repo::b1',
      'repo::b2',
    ]);

    final swapped = await manager.swapKeys(
      SourcePriorityCategory.anime,
      firstKey: 'repo::p2',
      secondKey: 'repo::b1',
    );

    expect(swapped, isTrue);
    expect(
      await manager.getPriorityKeys(SourcePriorityCategory.anime),
      <String>['repo::p1', 'repo::b1'],
    );
    expect(
      await manager.getBackupKeys(SourcePriorityCategory.anime),
      <String>['repo::p2', 'repo::b2'],
    );
    final all = <String>{
      ...(await manager.getPriorityKeys(SourcePriorityCategory.anime)),
      ...(await manager.getBackupKeys(SourcePriorityCategory.anime)),
    };
    expect(all, hasLength(4));
  });

  test('reordering is isolated to the selected lane', () async {
    final manager = SourcePriorityManager();
    await manager.setPriorityKeys(SourcePriorityCategory.series, <String>[
      'repo::p1',
      'repo::p2',
    ]);
    await manager.setBackupKeys(SourcePriorityCategory.series, <String>[
      'repo::b1',
      'repo::b2',
    ]);

    await manager.reorderKey(
      SourcePriorityCategory.series,
      SourcePriorityLane.backup,
      oldIndex: 0,
      newIndex: 2,
    );

    expect(
      await manager.getPriorityKeys(SourcePriorityCategory.series),
      <String>['repo::p1', 'repo::p2'],
    );
    expect(
      await manager.getBackupKeys(SourcePriorityCategory.series),
      <String>['repo::b2', 'repo::b1'],
    );
  });

  test('repository removal clears primary and backup entries', () async {
    final manager = SourcePriorityManager();
    await manager.setPriorityKeys(SourcePriorityCategory.movies, <String>[
      'https://repo.example/index.json::movie-source',
      'other::keep',
    ]);
    await manager.setBackupKeys(SourcePriorityCategory.movies, <String>[
      'https://repo.example/index.json::backup-source',
      'other::backup-keep',
    ]);

    await manager.removeRepositorySources('https://repo.example/index.json');

    expect(
      await manager.getPriorityKeys(SourcePriorityCategory.movies),
      <String>['other::keep'],
    );
    expect(
      await manager.getBackupKeys(SourcePriorityCategory.movies),
      <String>['other::backup-keep'],
    );
  });
}
