/// Runtime switches for local development and the future Firebase rollout.
///
/// Firebase is opt-in and is always suppressed by the local-only preset. The
/// local preset is explicit so ordinary unit tests and backend-enabled
/// developer builds can still exercise their services.
class AppRuntime {
  AppRuntime._();

  static const bool localDevelopment =
      bool.fromEnvironment('LOCAL_DEV_MODE', defaultValue: false);

  static const bool firebaseEnabled =
      bool.fromEnvironment('ENABLE_FIREBASE', defaultValue: false) &&
          !localDevelopment;

  /// Local development suppresses Firebase SDK initialization, but Google
  /// identity sign-in is still available through the platform identity client.
  static const bool googleSignInAvailable = true;

  /// This build preset keeps account endpoints local-only until a backend is configured.
  static const bool useLocalServices = localDevelopment;
}
