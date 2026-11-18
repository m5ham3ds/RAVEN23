import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/core/config/app_environment.dart';
import 'package:raven23/core/network/dio_factory.dart';

void main() {
  late AppEnvironment environment;

  setUp(() {
    environment = AppEnvironment.resolve(
      defineUrl: 'https://backend.example',
      isDebug: false,
    );
  });

  test('Laravel client allows Render free cold-start response time', () {
    final client = createLaravelDio(environment);
    addTearDown(() => client.close(force: true));

    expect(client.options.baseUrl, 'https://backend.example/api/v1/');
    expect(client.options.connectTimeout, const Duration(seconds: 20));
    expect(client.options.receiveTimeout, const Duration(seconds: 90));
  });

  test('public client retains short catalogue request timeouts', () {
    final client = createPublicDio(environment);
    addTearDown(() => client.close(force: true));

    expect(client.options.connectTimeout, const Duration(seconds: 10));
    expect(client.options.receiveTimeout, const Duration(seconds: 20));
  });
}
