import 'package:flutter/material.dart';
import '../../support/visibility_detector_test_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raven23/mobile/widgets/reveal_item.dart';

void main() {
  setUp(configureImmediateVisibilityUpdatesForTest);
  testWidgets('reveals a visible row item with the Zangetsu rise animation', (
    tester,
  ) async {
    const childKey = ValueKey<String>('poster-child');

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: RevealItem(
            index: 0,
            child: SizedBox(
              key: childKey,
              width: 90,
              height: 135,
              child: ColoredBox(color: Colors.red),
            ),
          ),
        ),
      ),
    );

    // Let the visibility detector collect the first laid-out frame, then
    // dispatch its pending callback explicitly. The next pump runs the
    // zero-delay stagger timer before the animation clock is advanced.
    await tester.pump();
    flushPendingVisibilityCallbacksForTest();
    await tester.pump();

    final opacityFinder = find.ancestor(
      of: find.byKey(childKey),
      matching: find.byType(Opacity),
    );
    expect(opacityFinder, findsOneWidget);
    expect(tester.widget<Opacity>(opacityFinder).opacity, 0);
    var transforms = tester.widgetList<Transform>(find.byType(Transform));
    expect(transforms, hasLength(2));
    expect(transforms.first.transform.storage[13], closeTo(28, 0.01));
    expect(transforms.last.transform.storage[0], closeTo(0.94, 0.01));

    // Timer(Duration.zero) is delivered on the next positive fake-clock
    // advance. Keep that scheduling tick separate from animation progress.
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 180));
    final halfwayOpacity = tester.widget<Opacity>(opacityFinder).opacity;
    expect(halfwayOpacity, greaterThan(0));
    expect(halfwayOpacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<Opacity>(opacityFinder).opacity, 1);

    transforms = tester.widgetList<Transform>(find.byType(Transform));
    expect(transforms, hasLength(2));
    // Outer transform is the rise and the inner transform is the scale.
    expect(transforms.first.transform.storage[13], closeTo(0, 0.01));
    expect(transforms.last.transform.storage[0], closeTo(1, 0.01));
  });

  for (final axis in Axis.values) {
    testWidgets('reveals newly visible items while scrolling ${axis.name}', (
      tester,
    ) async {
      const targetIndex = 5;
      const targetKey = ValueKey<String>('scroll-reveal-target');
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: ListView.builder(
                controller: scrollController,
                scrollDirection: axis,
                itemExtent: 100,
                itemCount: 8,
                itemBuilder: (context, index) => RevealItem(
                  index: index,
                  key: ValueKey<String>('scroll-reveal-$index'),
                  child: SizedBox(
                    key: index == targetIndex ? targetKey : null,
                    width: 100,
                    height: 100,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Jumping the scroll position isolates the visibility transition
      // from ballistic-scroll timing while exercising both viewport axes.
      scrollController.jumpTo(500);
      await tester.pump();
      await tester.pump();

      final opacityFinder = find.ancestor(
        of: find.byKey(targetKey),
        matching: find.byType(Opacity),
      );
      expect(opacityFinder, findsOneWidget);
      expect(tester.widget<Opacity>(opacityFinder).opacity, 0);

      // Index 5 has a 225 ms stagger, followed by the 380 ms entrance.
      await tester.pump(const Duration(milliseconds: 225));
      await tester.pump(const Duration(milliseconds: 190));
      final midway = tester.widget<Opacity>(opacityFinder).opacity;
      expect(midway, greaterThan(0));
      expect(midway, lessThan(1));

      await tester.pump(const Duration(milliseconds: 220));
      expect(tester.widget<Opacity>(opacityFinder).opacity, 1);
    });
  }
}
