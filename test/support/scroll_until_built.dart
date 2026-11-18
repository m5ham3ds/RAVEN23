import 'package:flutter_test/flutter_test.dart';

/// Scrolls a lazy viewport until [target] is built, then brings it into view.
///
/// Unlike WidgetController.scrollUntilVisible, this can discover a finder that
/// has no Element yet because its Sliver child has not been built. This keeps
/// tests deterministic without depending on sliver cache-extent estimates.
Future<void> scrollUntilBuiltAndVisible(
  WidgetTester tester,
  Finder scrollable,
  Finder target, {
  double delta = 240,
  int maxScrolls = 24,
}) async {
  for (var attempt = 0; attempt < maxScrolls; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }

    await tester.drag(scrollable, Offset(0, -delta));
    await tester.pumpAndSettle();
  }

  expect(
    target,
    findsOneWidget,
    reason: 'The lazy scroll view did not build the requested target',
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
