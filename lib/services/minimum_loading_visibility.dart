/// Prevents a cold-start skeleton from flashing away on an unusually fast
/// failure. Slow requests are never delayed beyond their own completion.
Future<void> keepLoadingPlaceholderVisible(
  DateTime startedAt, {
  Duration minimum = const Duration(milliseconds: 650),
}) async {
  final remaining = minimum - DateTime.now().difference(startedAt);
  if (remaining > Duration.zero) {
    await Future<void>.delayed(remaining);
  }
}
