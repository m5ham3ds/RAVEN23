import 'package:dio/dio.dart';
import 'package:raven23/core/cache/cache_policy.dart';
import 'package:raven23/core/error/failure.dart';
import 'package:raven23/core/error/result.dart';
import 'package:raven23/core/network/interceptors/error_interceptor.dart';
import 'package:raven23/core/network/interceptors/retry_interceptor.dart';
import 'package:raven23/services/tmdb_connectivity.dart';
import '../sources/tmdb_api.dart';

class TmdbRepository {
  const TmdbRepository(this.api);
  final TmdbApi api;

  /// [TmdbConnectivity] picks the direct or proxy route when the request is
  /// sent, so a caller's earlier view of the proxy setting can't go stale.
  Future<Result<Map<String, dynamic>>> getJson(
    String url, {
    CachePolicy? policy,
    String proxyUrl = '',
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    try {
      return Result.ok(await TmdbConnectivity.instance.route(
        proxyUrl,
        (proxied, proxyUrl) => api.getJson(url,
            policy: policy,
            proxyEnabled: proxied,
            proxyUrl: proxyUrl,
            cancelToken: cancelToken,
            timeout: timeout),
        blocked: (_) => false,
        routeFailure: _routeFailure,
      ));
    } on DioException catch (error) {
      return Result.err(failureForDio(error));
    } on FormatException {
      return const Result.err(
          Failure.unknown(message: 'Invalid TMDB response.'));
    }
  }

  /// A dropped connection, or a filtering page in place of TMDB's JSON.
  static bool _routeFailure(Object error) {
    if (error is FormatException) return true;
    if (error is! DioException) return false;
    if (isTransportFailure(error)) return true;
    final response = error.response;
    return response != null &&
        TmdbConnectivity.looksBlocked(response.statusCode ?? 0, response.data);
  }
}
