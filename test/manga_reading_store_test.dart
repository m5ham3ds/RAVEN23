import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raven23/manga/ui/manga_reading_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MangaReadingStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = MangaReadingStore.instance;
  });

  group('MangaReadingStore', () {
    test('persists a work-to-source binding', () async {
      const binding = MangaSourceBinding(
        anilistId: 101,
        sourceId: 9001,
        sourceName: 'Example Manga',
        mangaUrl: 'https://source.example/title/solo-leveling',
        mangaTitle: 'Solo Leveling',
        thumbnailUrl: 'https://source.example/cover.jpg',
      );
      await store.saveBinding(binding);
      final restored = await store.bindingFor(101);
      expect(restored?.sourceId, 9001);
      expect(restored?.mangaUrl, binding.mangaUrl);
      expect(restored?.mangaTitle, 'Solo Leveling');
    });

    test('scopes chapter progress by work, source and chapter URL', () async {
      await store.saveProgress(
        anilistId: 101,
        sourceId: 9001,
        chapterUrl: '/chapter/1',
        pageIndex: 7,
        totalPages: 20,
      );
      await store.saveProgress(
        anilistId: 101,
        sourceId: 9002,
        chapterUrl: '/chapter/1',
        pageIndex: 2,
        totalPages: 12,
      );
      final first = await store.progressForChapter(101, 9001, '/chapter/1');
      final second = await store.progressForChapter(101, 9002, '/chapter/1');
      expect(first?.pageIndex, 7);
      expect(second?.pageIndex, 2);
      expect(first?.isRead, isFalse);
    });

    test(
      'serializes concurrent progress writes without losing chapters',
      () async {
        await Future.wait<void>([
          for (var index = 0; index < 32; index++)
            store.saveProgress(
              anilistId: 101,
              sourceId: 9001,
              chapterUrl: '/chapter/$index',
              pageIndex: index,
              totalPages: 40,
            ),
        ]);
        final restored = await store.progressForWork(101, 9001);
        expect(restored, hasLength(32));
        expect(restored['/chapter/31']?.pageIndex, 31);
      },
    );

    test('persists Manga library membership and reading status', () async {
      expect(await store.isSaved(101), isFalse);
      expect(await store.toggleSaved(101), isTrue);
      expect(await store.isSaved(101), isTrue);
      expect(await store.toggleSaved(101), isFalse);
      expect(await store.isSaved(101), isFalse);

      expect(await store.readingStatusFor(101), 'PLANNING');
      await store.saveReadingStatus(101, 'READING');
      expect(await store.readingStatusFor(101), 'READING');
    });

    test('marking unread resets stale read position', () async {
      await store.saveProgress(
        anilistId: 101,
        sourceId: 9001,
        chapterUrl: '/chapter/1',
        pageIndex: 19,
        totalPages: 20,
        isRead: true,
      );
      await store.setRead(
        anilistId: 101,
        sourceId: 9001,
        chapterUrl: '/chapter/1',
        isRead: false,
      );
      final restored = await store.progressForChapter(101, 9001, '/chapter/1');
      expect(restored?.isRead, isFalse);
      expect(restored?.pageIndex, 0);
    });

    test('persists the last successfully used manga source', () async {
      expect(await store.lastGoodMangaSourceId(), isNull);
      await store.rememberLastGoodMangaSourceId(9002);
      expect(await store.lastGoodMangaSourceId(), 9002);
      await store.rememberLastGoodMangaSourceId(0);
      expect(await store.lastGoodMangaSourceId(), 9002);
      await store.clearLastGoodMangaSourceId();
      expect(await store.lastGoodMangaSourceId(), isNull);
    });

    test(
      'persists view, order, selected tab and notification preferences per work',
      () async {
        await store.updateWorkPreferences(
          101,
          (current) => current.copyWith(
            gridView: true,
            ascendingInList: true,
            scanlator: 'Team X',
            selectedTab: 2,
            notifyNewChapters: true,
            lastKnownChapterCount: 18,
            notificationSourceId: 9001,
          ),
        );

        final restored = await store.workPreferencesFor(101);
        expect(restored.gridView, isTrue);
        expect(restored.ascendingInList, isTrue);
        expect(restored.scanlator, 'Team X');
        expect(restored.selectedTab, 2);
        expect(restored.notifyNewChapters, isTrue);
        expect(restored.lastKnownChapterCount, 18);
        expect(restored.notificationSourceId, 9001);

        final otherWork = await store.workPreferencesFor(202);
        expect(otherWork.gridView, isFalse);
        expect(otherWork.selectedTab, 0);
      },
    );

    test('restoring preferences waits for a queued final route save', () async {
      final pending = store.updateWorkPreferences(
        101,
        (current) => current.copyWith(
          gridView: true,
          ascendingInList: false,
          selectedTab: 3,
        ),
      );
      final restored = store.workPreferencesFor(101);
      await pending;
      final value = await restored;
      expect(value.gridView, isTrue);
      expect(value.ascendingInList, isFalse);
      expect(value.selectedTab, 3);
    });

    test(
      'atomic preference updates preserve fields changed by other operations',
      () async {
        await store.updateWorkPreferences(
          101,
          (current) => current.copyWith(gridView: true, ascendingInList: false),
        );
        await store.updateWorkPreferences(
          101,
          (current) => current.copyWith(lastKnownChapterCount: 22),
        );
        final restored = await store.workPreferencesFor(101);
        expect(restored.gridView, isTrue);
        expect(restored.ascendingInList, isFalse);
        expect(restored.lastKnownChapterCount, 22);
      },
    );

    test('keeps pinned Mihon sources in user-selected order', () async {
      expect(await store.togglePinnedMihonSource(9002), isTrue);
      expect(await store.togglePinnedMihonSource(9001), isTrue);
      expect(await store.pinnedMihonSourceOrder(), <int>[9001, 9002]);
      expect(await store.pinnedMihonSourceIds(), <int>{9001, 9002});
      expect(await store.togglePinnedMihonSource(9002), isFalse);
      expect(await store.pinnedMihonSourceOrder(), <int>[9001]);
    });
  });
}
