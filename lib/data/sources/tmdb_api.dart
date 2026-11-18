import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:raven23/core/cache/cache_policy.dart';

class TmdbApi {
  const TmdbApi(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> getJson(
    String url, {
    CachePolicy? policy,
    bool proxyEnabled = false,
    String proxyUrl = '',
    CancelToken? cancelToken,
    Duration? timeout,
    int? retryLimit,
    bool forceRefresh = false,
  }) async {
    final response = await dio.get<Object>(
      url,
      cancelToken: cancelToken,
      options: Options(
        // Dio 5.9 exposes per-request send/receive limits here. The shared
        // public client owns the connection timeout through BaseOptions.
        receiveTimeout: timeout,
        sendTimeout: timeout,
        extra: <String, Object>{
          'cacheScope': 'tmdb',
          if (policy != null) 'cachePolicy': policy,
          'tmdbProxyEnabled': proxyEnabled,
          'tmdbProxyUrl': proxyUrl,
          // Serve an expired-but-retained catalogue immediately, then revalidate
          // it in the background instead of making the first paint wait on TMDB.
          'refreshStale': !forceRefresh,
          'forceCacheRefresh': forceRefresh,
          if (retryLimit != null) 'retryLimit': retryLimit,
        },
      ),
    );
    final body = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object from TMDB');
    }
    return body;
  }
}
