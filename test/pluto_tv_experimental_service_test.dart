import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/services/live_tv_provider_unavailable_exception.dart';
import 'package:raven23/services/live_tv_service_manager.dart';
import 'package:raven23/services/pluto_tv_experimental_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('Pluto adapter fails closed without making network requests', () async {
    final service = PlutoTvExperimentalLiveTvService();

    await expectLater(
      service.getCatalog(),
      throwsA(isA<LiveTvProviderUnavailableException>()),
    );
    await expectLater(
      service.getStream('pluto:channel:unknown'),
      throwsA(isA<LiveTvProviderUnavailableException>()),
    );

    service.close();
  });

  test(
    'experimental adapter never fabricates catalogue or stream data',
    () async {
      final service = PlutoTvExperimentalLiveTvService();

      try {
        await service.getCatalog();
        fail('Catalog must remain unavailable until an authorized API exists.');
      } on LiveTvProviderUnavailableException catch (error) {
        expect(error.message, contains('official app or website'));
        expect(error.message, contains('authorized in-app channel access'));
      }

      try {
        await service.getStream('pluto:channel:unknown');
        fail('Stream resolution must remain unavailable.');
      } on LiveTvProviderUnavailableException catch (error) {
        expect(error.message, contains('experimental'));
      }
    },
  );

  test(
    'manager reports Pluto as unavailable, experimental and namespaced',
    () async {
      final manager = LiveTvServiceManager.standard(
        daddyLiveBaseUrl: 'https://daddy.example',
        ethioSportsBaseUrl: 'https://ethio.example',
      );
      addTearDown(manager.close);

      await manager.selectProvider(LiveTvServiceManager.plutoTvProviderId);
      expect(
        manager.selectedProvider.databaseNamespace,
        'pluto_tv_experimental',
      );
      expect(manager.selectedProvider.isExperimental, isTrue);
      expect(manager.selectedProvider.supportsEpg, isFalse);
      expect(manager.selectedProvider.externalLaunchUrl, 'https://pluto.tv/');

      await expectLater(
        manager.getCatalog(),
        throwsA(isA<LiveTvProviderUnavailableException>()),
      );
      expect(manager.selectedHealth.state, LiveTvProviderState.unavailable);
      expect(manager.selectedHealth.httpStatusCode, isNull);
      expect(
        manager.selectedHealth.message,
        contains('official app or website'),
      );

      await expectLater(
        manager.getStream('pluto:channel:unknown'),
        throwsA(isA<LiveTvProviderUnavailableException>()),
      );
      expect(manager.selectedHealth.state, LiveTvProviderState.unavailable);
    },
  );

  test('Pluto external destination is pinned to its official HTTPS origin', () {
    final uri = Uri.parse(PlutoTvExperimentalLiveTvService.officialWebsite);
    expect(uri.scheme, 'https');
    expect(uri.host, 'pluto.tv');
  });
}
