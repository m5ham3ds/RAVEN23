import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/manga/anilist/anilist_catalogue_cache.dart';
import 'package:raven23/manga/anilist/anilist_manga_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_dio.dart';

class _DelayedResponseAdapter implements HttpClientAdapter {
  final Completer<void> requestStarted = Completer<void>();
  final Completer<ResponseBody> response = Completer<ResponseBody>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (!requestStarted.isCompleted) requestStarted.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('catalogue cache persists data and marks fresh entries', () async {
    final preferences = await SharedPreferences.getInstance();
    final cache = AniListCatalogueCache(preferences: preferences);
    final now = DateTime.utc(2026, 11, 14, 12);
    final data = <String, dynamic>{
      'trending': <String, dynamic>{
        'media': <Object>[
          <String, Object>{'id': 42},
        ],
      },
    };

    await cache.write('JP', data, fetchedAt: now);
    final entry = await cache.read(
      'JP',
      now: now.add(const Duration(minutes: 5)),
    );

    expect(entry, isNotNull);
    expect(entry!.data, data);
    expect(entry.isFresh(now: now.add(const Duration(minutes: 5))), isTrue);
  });

  test(
    'catalogue cache skips writes after its generation is invalidated',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final cache = AniListCatalogueCache(preferences: preferences);

      await cache.write('JP', <String, dynamic>{
        'top10': <String, dynamic>{},
      }, shouldWrite: () => false);

      expect(await cache.read('JP'), isNull);
    },
  );

  test(
    'stale catalogue remains available for offline fallback for seven days',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final cache = AniListCatalogueCache(preferences: preferences);
      final fetchedAt = DateTime.utc(2026, 11, 1);
      await cache.write('KR', <String, dynamic>{
        'popular': <String, dynamic>{},
      }, fetchedAt: fetchedAt);

      final stale = await cache.read(
        'KR',
        now: fetchedAt.add(const Duration(days: 2)),
      );
      final expired = await cache.read(
        'KR',
        now: fetchedAt.add(const Duration(days: 8)),
      );

      expect(stale, isNotNull);
      expect(
        stale!.isFresh(now: fetchedAt.add(const Duration(days: 2))),
        isFalse,
      );
      expect(expired, isNull);
    },
  );

  test(
    'AniList catalogue reopens from persistent cache when the network is offline',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final cache = AniListCatalogueCache(preferences: preferences);
      final now = DateTime.utc(2026, 11, 14, 12);
      final payload = <String, dynamic>{
        'data': <String, dynamic>{
          'top10': <String, dynamic>{
            'media': <Object>[
              <String, Object>{
                'id': 401,
                'title': <String, String>{'romaji': 'Cached manga'},
                'coverImage': <String, String>{
                  'large': 'https://img.test/401.jpg',
                },
              },
            ],
          },
        },
      };
      final onlineAdapter = FakeDioAdapter()..enqueueJson(payload);
      final onlineDio = Dio()..httpClientAdapter = onlineAdapter;
      addTearDown(onlineDio.close);
      final onlineService = AniListMangaService(
        dio: onlineDio,
        catalogueCache: cache,
      );

      final online = await onlineService.home(
        kind: MangaContentKind.manga,
        now: now,
      );
      expect(online.top10.single.title, 'Cached manga');
      expect(onlineAdapter.requests, hasLength(1));

      final offlineAdapter = FakeDioAdapter()..enqueueError();
      final offlineDio = Dio()..httpClientAdapter = offlineAdapter;
      addTearDown(offlineDio.close);
      final restartedService = AniListMangaService(
        dio: offlineDio,
        catalogueCache: AniListCatalogueCache(preferences: preferences),
      );

      final staleOffline = await restartedService
          .home(
            kind: MangaContentKind.manga,
            now: now.add(const Duration(days: 2)),
          )
          .timeout(const Duration(seconds: 1));

      expect(staleOffline.top10.single.title, 'Cached manga');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(offlineAdapter.requests, hasLength(1));
    },
  );

  test(
    'manual refresh bypasses fresh cache but falls back when AniList is offline',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final cache = AniListCatalogueCache(preferences: preferences);
      final now = DateTime.utc(2026, 11, 14, 12);
      final initialPayload = <String, dynamic>{
        'data': <String, dynamic>{
          'top10': <String, dynamic>{
            'media': <Object>[
              <String, Object>{
                'id': 501,
                'title': <String, String>{'romaji': 'Retained title'},
                'coverImage': <String, String>{
                  'large': 'https://img.test/501.jpg',
                },
              },
            ],
          },
        },
      };
      await cache.write(
        'JP',
        Map<String, dynamic>.from(initialPayload['data'] as Map),
        fetchedAt: now,
      );
      final offlineAdapter = FakeDioAdapter()..enqueueError();
      final dio = Dio()..httpClientAdapter = offlineAdapter;
      addTearDown(dio.close);
      final service = AniListMangaService(dio: dio, catalogueCache: cache);

      final refreshed = await service.home(
        kind: MangaContentKind.manga,
        now: now,
        forceRefresh: true,
      );

      expect(offlineAdapter.requests, hasLength(1));
      expect(refreshed.top10.single.title, 'Retained title');
    },
  );

  test(
    'clearing AniList cache blocks an in-flight response from repopulating it',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final cache = AniListCatalogueCache(preferences: preferences);
      final adapter = _DelayedResponseAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final service = AniListMangaService(dio: dio, catalogueCache: cache);
      final pending = service.home(kind: MangaContentKind.manga);

      await adapter.requestStarted.future;
      await AniListMangaService.clearPersistentCache();
      adapter.response.complete(
        ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'top10': <String, dynamic>{
                'media': <Object>[
                  <String, Object>{
                    'id': 601,
                    'title': <String, String>{'romaji': 'In-flight title'},
                    'coverImage': <String, String>{
                      'large': 'https://img.test/601.jpg',
                    },
                  },
                ],
              },
            },
          }),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['application/json'],
          },
        ),
      );

      final result = await pending;
      expect(result.top10.single.title, 'In-flight title');
      expect(await cache.read('JP'), isNull);
    },
  );

  test('clear removes all RAVEN23 AniList catalogue entries', () async {
    final preferences = await SharedPreferences.getInstance();
    final cache = AniListCatalogueCache(preferences: preferences);
    await cache.write('JP', <String, dynamic>{'top10': <String, dynamic>{}});
    await cache.write('CN', <String, dynamic>{'popular': <String, dynamic>{}});

    await cache.clear();

    expect(await cache.read('JP'), isNull);
    expect(await cache.read('CN'), isNull);
  });
}
