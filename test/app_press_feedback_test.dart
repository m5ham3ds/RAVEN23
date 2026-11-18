import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/design/app_press_feedback.dart';
import 'package:raven23/mobile/widgets/pill_button.dart';

void main() {
  testWidgets(
    'receives pointer feedback around a nested InkWell and keeps tap',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppPressFeedback(
                child: Material(
                  child: InkWell(
                    onTap: () => taps++,
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nested action'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scale = find.descendant(
        of: find.byType(AppPressFeedback),
        matching: find.byType(AnimatedScale),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Nested action')),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<AnimatedScale>(scale).scale, 0.985);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      expect(taps, 1);
    },
  );

  testWidgets('quick taps keep a visible press pulse after pointer release', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppPressFeedback(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('Quick action'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scale = find.descendant(
      of: find.byType(AppPressFeedback),
      matching: find.byType(AnimatedScale),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Quick action')),
    );
    await tester.pump(const Duration(milliseconds: 12));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1));

    expect(tester.widget<AnimatedScale>(scale).scale, 0.985);
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 140));
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('drag cancels the press pulse and preserves scrolling intent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppPressFeedback(
              child: Material(
                child: InkWell(
                  onTap: () {},
                  child: const SizedBox(width: 120, height: 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scale = find.descendant(
      of: find.byType(AppPressFeedback),
      matching: find.byType(AnimatedScale),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(InkWell)),
    );
    await tester.pump(const Duration(milliseconds: 8));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump(const Duration(milliseconds: 8));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
  });

  testWidgets('receives pointer feedback around a FilledButton and keeps tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppPressFeedback(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('Read'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scale = find.descendant(
      of: find.byType(AppPressFeedback),
      matching: find.byType(AnimatedScale),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Read')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<AnimatedScale>(scale).scale, 0.985);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    expect(taps, 1);
  });

  testWidgets('tap feedback survives the action entering a busy state', (
    tester,
  ) async {
    var busy = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => PillButton(
                label: 'Start',
                busy: busy,
                onPressed: () => setState(() => busy = true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final feedback = find.byType(AppPressFeedback);
    final scale = find.descendant(
      of: feedback,
      matching: find.byType(AnimatedScale),
    );
    final opacity = find.descendant(
      of: feedback,
      matching: find.byType(AnimatedOpacity),
    );
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(milliseconds: 12));
    // PillButton intentionally uses its stronger 0.94 press scale.
    expect(tester.widget<AnimatedScale>(scale).scale, 0.94);
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0.76);
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
  });
}
