import 'dart:io';
import 'package:dio/dio.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:raven23/core/cache/cache_key.dart';
import 'package:raven23/core/cache/response_cache_store.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart'
    hide CachePolicy;
import 'package:raven23/core/cache/http_cache.dart';
import 'package:raven23/core/config/app_environment.dart';
import 'package:raven23/core/network/dio_factory.dart';
import 'package:raven23/core/network/network_runtime.dart';
import 'package:raven23/functions/network.dart';
import 'package:raven23/services/tmdb_connectivity.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_dio.dart';

void main() {
  test(
    'legacy fetchMovies uses the shared cache across API key rotation',
    () async {
      final cache = HttpCache(MemCacheStore());
      final adapter = FakeDioAdapter()
        ..enqueueJson({
          'page': 1,
          'total_pages': 1,
          'total_results': 1,
          'results': [
            {
              'id': 7,
              'title': 'Example',
              'overview': '',
              'poster_path': null,
              'backdrop_path': null,
              'release_date': '2026-10-03',
              'vote_average': 8.0,
              'genre_ids': [18],
            },
          ],
        });
      final dio = createPublicDio(
        AppEnvironment.resolve(isDebug: true),
        httpCache: cache,
        debugLogging: false,
      );
      dio.httpClientAdapter = adapter;
      NetworkRuntime.configure(publicDio: dio, httpCache: cache);
      addTearDown(dio.close);
      addTearDown(cache.close);
      final first = await fetchMovies(
        'https://api.themoviedb.org/3/movie/popular?api_key=one',
        false,
        '',
      );
      final offline = await fetchMovies(
        'https://api.themoviedb.org/3/movie/popular?api_key=two',
        false,
        '',
      );
      expect(first.single.id, 7);
      expect(offline.single.title, 'Example');
      expect(adapter.requests, hasLength(1));
    },
  );
  test(
    'expired retained TMDB rows render immediately and refresh in background',
    () async {
      final cache = HttpCache(MemCacheStore());
      final adapter = FakeDioAdapter()
        ..enqueueJson({
          'results': [
            {
              'id': 71,
              'title': 'Cached title',
              'overview': '',
              'poster_path': null,
              'backdrop_path': null,
              'release_date': '2026-10-03',
              'vote_average': 8.0,
              'genre_ids': [18],
            },
          ],
        })
        ..enqueueJson({
          'results': [
            {
              'id': 72,
              'title': 'Fresh title',
              'overview': '',
              'poster_path': null,
              'backdrop_path': null,
              'release_date': '2026-10-04',
              'vote_average': 8.2,
              'genre_ids': [18],
            },
          ],
        });
      final dio = createPublicDio(
        AppEnvironment.resolve(isDebug: true),
        httpCache: cache,
        debugLogging: false,
        retryDelay: (_) async {},
      );
      dio.httpClientAdapter = adapter;
      NetworkRuntime.configure(publicDio: dio, httpCache: cache);
      addTearDown(dio.close);
      addTearDown(cache.close);
      const url = 'https://api.themoviedb.org/3/movie/popular';

      final first = await fetchMovies(url, false, '');
      expect(first.single.title, 'Cached title');
      final key = normalizedCacheKey(RequestOptions(path: url), scope: 'tmdb');
      final entry = (await cache.store.get(key))!;
      final expiredAt = DateTime.now().subtract(const Duration(hours: 1));
      await cache.store.set(
        entry.copyWith(requestDate: expiredAt, responseDate: expiredAt),
      );

      final stale = await fetchMovies(url, false, '');
      expect(stale.single.title, 'Cached title');

      for (var attempt = 0; attempt < 30; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (adapter.requests.length >= 2) break;
      }
      expect(adapter.requests, hasLength(2));
      final refreshed = await fetchMovies(url, false, '');
      expect(refreshed.single.title, 'Fresh title');
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'manual TMDB refresh bypasses fresh cache and keeps stale fallback offline',
    () async {
      final cache = HttpCache(MemCacheStore());
      final adapter = FakeDioAdapter()
        ..enqueueJson({
          'results': [
            {
              'id': 81,
              'title': 'Cached title',
              'overview': '',
              'poster_path': null,
              'backdrop_path': null,
              'release_date': '2026-10-03',
              'vote_average': 8.0,
              'genre_ids': [18],
            },
          ],
        })
        ..enqueueJson({
          'results': [
            {
              'id': 82,
              'title': 'Fresh title',
              'overview': '',
              'poster_path': null,
              'backdrop_path': null,
              'release_date': '2026-10-04',
              'vote_average': 8.2,
              'genre_ids': [18],
            },
          ],
        });
      final dio = createPublicDio(
        AppEnvironment.resolve(isDebug: true),
        httpCache: cache,
        debugLogging: false,
        retryDelay: (_) async {},
      );
      dio.httpClientAdapter = adapter;
      NetworkRuntime.configure(publicDio: dio, httpCache: cache);
      addTearDown(dio.close);
      addTearDown(cache.close);

      final originalConnectivity = TmdbConnectivity.instance;
      final offlineConnectivity = TmdbConnectivity(
        hasNetwork: () async => false,
      );
      TmdbConnectivity.instance = offlineConnectivity;
      addTearDown(() {
        offlineConnectivity.dispose();
        TmdbConnectivity.instance = originalConnectivity;
      });

      const url = 'https://api.themoviedb.org/3/movie/popular';
      final initial = await fetchMovies(url, false, '');
      expect(initial.single.title, 'Cached title');

      final refreshed = await fetchMovies(
        url,
        false,
        '',
        forceRefresh: true,
        retryLimit: 0,
        timeout: const Duration(seconds: 2),
      );
      expect(refreshed.single.title, 'Fresh title');
      expect(adapter.requests, hasLength(2));

      final offlineAdapter = FakeDioAdapter()..enqueueError();
      dio.httpClientAdapter = offlineAdapter;
      final retained = await fetchMovies(
        url,
        false,
        '',
        forceRefresh: true,
        retryLimit: 0,
        timeout: const Duration(seconds: 2),
      );
      expect(retained.single.title, 'Fresh title');
      expect(offlineAdapter.requests, hasLength(1));
    },
  );

  test(
    'legacy TMDB rows render offline after restarting the SQLite cache',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'raven23-offline-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/cache.db';
      const url = 'https://api.themoviedb.org/3/movie/popular';
      final firstCache = HttpCache(
        await ResponseCacheStore.open(factory: databaseFactoryFfi, path: path),
      );
      final firstDio = createPublicDio(
        AppEnvironment.resolve(isDebug: true),
        httpCache: firstCache,
        debugLogging: false,
      );
      firstDio.httpClientAdapter = FakeDioAdapter()
        ..enqueueJson({
          'results': [
            {
              'id': 7,
              'title': 'Example',
              'overview': '',
              'poster_path': null,
              'backdrop_path': null,
              'release_date': '2026-10-03',
              'vote_average': 8.0,
              'genre_ids': [18],
            },
          ],
        });
      NetworkRuntime.configure(publicDio: firstDio, httpCache: firstCache);
      expect((await fetchMovies(url, false, '')).single.id, 7);
      final key = normalizedCacheKey(RequestOptions(path: url), scope: 'tmdb');
      final cached = (await firstCache.store.get(key))!;
      final old = DateTime.now().subtract(const Duration(hours: 1));
      await firstCache.store.set(
        cached.copyWith(requestDate: old, responseDate: old),
      );
      firstDio.close();
      await firstCache.close();
      final cache = HttpCache(
        await ResponseCacheStore.open(factory: databaseFactoryFfi, path: path),
      );
      final dio = createPublicDio(
        AppEnvironment.resolve(isDebug: true),
        httpCache: cache,
        debugLogging: false,
        retryDelay: (_) async {},
      );
      dio.httpClientAdapter = FakeDioAdapter()
        ..enqueueError()
        ..enqueueError()
        ..enqueueError();
      NetworkRuntime.configure(publicDio: dio, httpCache: cache);
      addTearDown(dio.close);
      addTearDown(cache.close);
      expect((await fetchMovies(url, false, '')).single.title, 'Example');
    },
  );
}
