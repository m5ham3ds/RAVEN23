import 'package:google_sign_in/google_sign_in.dart';

abstract interface class GoogleIdentityClient {
  Future<String?> authenticate();
  Future<void> signOut();
}

class PlatformGoogleIdentityClient implements GoogleIdentityClient {
  PlatformGoogleIdentityClient({GoogleSignIn? client}) : _provided = client;
  final GoogleSignIn? _provided;
  GoogleSignIn? _client;

  // This is the Web OAuth client ID (client_type: 3) from the current
  // Firebase project. Firebase initialization is intentionally disabled in
  // local-development builds, so the Google Services Gradle plugin does not
  // generate default_web_client_id for those APKs. Pass it explicitly instead.
  static const String _serverClientId = String.fromEnvironment(
    'RAVEN23_GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1021333219041-pvcdfbbia4qm8auut13usj6sf329ebb3.apps.googleusercontent.com',
  );

  GoogleSignIn get client => _client ??= _provided ??
      GoogleSignIn(serverClientId: _serverClientId);

  @override
  Future<String?> authenticate() async {
    final account = await client.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    // The backend accepts only ID tokens: unlike access tokens they name the
    // client they were issued to (the project's default_web_client_id).
    final token = auth.idToken;
    if (token == null || token.isEmpty) {
      throw const FormatException('Google did not return an ID token.');
    }
    return token;
  }

  @override
  Future<void> signOut() => client.signOut();
}
