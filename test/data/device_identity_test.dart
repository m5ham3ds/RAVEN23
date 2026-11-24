import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/data/sources/device_identity.dart';
import 'package:raven23/data/models/auth_requests.dart';
import '../support/session_harness.dart';

const login = LoginRequest(email: 'beamlak@example.com', password: 'password');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionHarness harness;
  late DeviceIdentity identity;

  setUp(() async {
    harness = await SessionHarness.create();
    identity = DeviceIdentity(
      harness.preferences,
      deviceName: () async => 'RAVEN23 test device',
    );
  });

  tearDown(() => harness.dispose());

  test('install device identity remains stable across sign-out and account switch',
      () async {
    final first = await identity.fields();
    final firstId = first['device_id'];
    expect(firstId, isA<String>());
    expect(
      RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(firstId!),
      isTrue,
    );

    harness.adapter.enqueueJson(authFixture(id: 7));
    expect(await harness.session.signIn(login), isA<Ok>());

    harness.adapter.enqueueJson({'success': true});
    await harness.session.signOut();
    expect(harness.session.ownerId.value, isNull);

    harness.adapter.enqueueJson(authFixture(id: 8, token: '8|new-owner'));
    expect(await harness.session.signIn(login), isA<Ok>());
    expect(harness.session.ownerId.value, 'user:8');

    final next = await identity.fields();
    expect(next['device_id'], firstId);
    expect(harness.preferences.getString('session.device_id'), firstId);
  });
}
