import 'dart:async';

import 'package:visibility_detector/visibility_detector.dart';

/// VisibilityDetector batches callbacks in production. Widget tests use a
/// zero interval so row reveal animations do not leave pending timers behind.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  await testMain();
}
