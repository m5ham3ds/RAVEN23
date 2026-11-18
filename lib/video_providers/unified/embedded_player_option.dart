/// A provider page that must be presented in a browser context instead of
/// being handed to the native video player as if its HTML were a media stream.
enum EmbeddedPlayerReadiness { interactive, verificationRequired }

class UnifiedEmbeddedPlayerOption {
  const UnifiedEmbeddedPlayerOption({
    required this.sourceId,
    required this.sourceName,
    required this.url,
    this.headers = const <String, String>{},
    this.readiness = EmbeddedPlayerReadiness.interactive,
  });

  final String sourceId;
  final String sourceName;
  final String url;

  /// Safe initial navigation headers only; the Android WebView applies its
  /// own allowlist and never accepts Cookie/Authorization values here.
  final Map<String, String> headers;
  final EmbeddedPlayerReadiness readiness;

  bool get requiresManualVerification =>
      readiness == EmbeddedPlayerReadiness.verificationRequired;
}
