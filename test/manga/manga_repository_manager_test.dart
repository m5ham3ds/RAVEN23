import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/manga/mihon/manga_repository_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MangaRepositoryManager', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('seeds the Keiyoushi index only on first use', () async {
      final manager = MangaRepositoryManager();

      expect(await manager.repositoryUrls(), <String>[
        MangaRepositoryManager.defaultRepositoryUrl,
      ]);
      await manager.removeRepository(
        MangaRepositoryManager.defaultRepositoryUrl,
      );
      expect(await manager.repositoryUrls(), isEmpty);
    });

    test('adds, edits and removes protobuf repository URLs', () async {
      final manager = MangaRepositoryManager();
      final original = MangaRepositoryManager.defaultRepositoryUrl;
      const customInput = 'https://example.com/manga/index.pb#details';
      const custom = 'https://example.com/manga/index.pb';
      const edited = 'https://example.org/releases/mihon.pb';

      await manager.addRepository(customInput);
      expect(await manager.repositoryUrls(), <String>[original, custom]);

      await manager.updateRepository(custom, edited);
      expect(await manager.repositoryUrls(), <String>[original, edited]);

      await manager.removeRepository(edited);
      expect(await manager.repositoryUrls(), <String>[original]);
    });

    test(
      'rejects video JSON indexes and duplicate manga repositories',
      () async {
        final manager = MangaRepositoryManager();

        await expectLater(
          manager.addRepository('https://example.com/video/index.json'),
          throwsFormatException,
        );
        await expectLater(
          manager.addRepository(
            '${MangaRepositoryManager.defaultRepositoryUrl}#',
          ),
          throwsFormatException,
        );
      },
    );

    test('rejects updating a repository that no longer exists', () async {
      final manager = MangaRepositoryManager();
      await manager.repositoryUrls();

      await expectLater(
        manager.updateRepository(
          'https://example.com/removed/index.pb',
          'https://example.com/replacement/index.pb',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects changing a repository to an existing URL', () async {
      final manager = MangaRepositoryManager();
      const custom = 'https://example.com/custom/index.pb';
      await manager.addRepository(custom);

      await expectLater(
        manager.updateRepository(
          custom,
          MangaRepositoryManager.defaultRepositoryUrl,
        ),
        throwsFormatException,
      );
    });
  });
}
