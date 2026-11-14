import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class HeaderInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final request = options;
    void add(String name, String value) {
      if (!request.headers.keys
          .any((key) => key.toLowerCase() == name.toLowerCase())) {
        request.headers[name] = value;
      }
    }

    add('Accept', 'application/json');
    add('Accept-Encoding', 'gzip');
    add('User-Agent', 'RAVEN23/${defaultTargetPlatform.name}');
    handler.next(request);
  }
}
