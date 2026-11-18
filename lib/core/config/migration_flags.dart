import 'app_runtime.dart';

/// Explicit feature sets for isolated tests; app runtime follows service mode.
class MigrationFlags {
  MigrationFlags.parse(String value)
      : _features = value.split(',').map((item) => item.trim()).toSet();

  /// Runtime preset used while the Laravel account API is being brought online.
  /// It keeps account/session endpoints active without enabling unrelated cloud
  /// features (ads, sync, notifications) before their backend routes are ready.
  factory MigrationFlags.fromRuntime({
    bool firebaseEnabled = AppRuntime.firebaseEnabled,
    bool localDevelopment = AppRuntime.localDevelopment,
    bool authOnly = const bool.fromEnvironment(
      'RAVEN23_AUTH_ONLY',
      defaultValue: false,
    ),
  }) {
    if (localDevelopment || authOnly) return MigrationFlags.parse('auth');
    return MigrationFlags.parse(firebaseEnabled
        ? 'auth,config,ads,sync,notifications'
        : 'auth,ads,sync');
  }

  final Set<String> _features;
  bool get auth => _features.contains('auth');
  bool get config => _features.contains('config');
  bool get ads => _features.contains('ads');
  bool get sync => _features.contains('sync');
  bool get notifications => _features.contains('notifications');
  bool get telemetry => _features.contains('telemetry');
}
