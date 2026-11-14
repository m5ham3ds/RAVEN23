import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// VisibilityDetector batches callbacks every 500ms by default. That batching
/// leaves real timers pending after widget tests dispose their trees. Deliver
/// callbacks at frame end during tests and restore the process-wide setting
/// after each test.
///
/// Dispatch visibility changes synchronously after a widget has been pumped,
/// avoiding dependence on the detector's batching timer.
void flushPendingVisibilityCallbacksForTest() {
  VisibilityDetectorController.instance.notifyNow();
}

void configureImmediateVisibilityUpdatesForTest() {
  final controller = VisibilityDetectorController.instance;
  final previousInterval = controller.updateInterval;
  controller.updateInterval = Duration.zero;
  addTearDown(() {
    controller.updateInterval = previousInterval;
    controller.notifyNow();
  });
}
