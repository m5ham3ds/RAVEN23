/// A provider is registered, but no authorized in-app playback contract is available.
///
/// This is different from a transient network failure: callers must not retry
/// by probing undocumented endpoints or trying to bypass provider controls.
class LiveTvProviderUnavailableException implements Exception {
  const LiveTvProviderUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
