import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/video_providers/unified/quickjs/js_engine.dart';

void main() {
  test('QuickJS exposes only the four audited bridge channels', () {
    expect(kJsChannels.toSet(), <String>{
      'fetch',
      'console',
      'crypto',
      'timer',
    });
    expect(kJsChannels, hasLength(4));
  });

  test('native XMLHttpRequest networking stays disabled', () {
    expect(kJsEnableNativeXhr, isFalse);
  });
}
