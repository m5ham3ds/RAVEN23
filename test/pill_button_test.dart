import 'package:flutter/material.dart';
import 'package:raven23/mobile/widgets/pill_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() {
  testWidgets('right to left, Play still points forward; other icons mirror', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: <Widget>[
              PillButton(
                label: 'Play',
                icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                onPressed: () {},
              ),
              PillButton(
                label: 'My List',
                icon: PhosphorIcons.plus(),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
    TextDirection directionOf(IconData icon) =>
        Directionality.of(tester.element(find.byIcon(icon)));
    expect(
      directionOf(PhosphorIcons.play(PhosphorIconsStyle.fill)),
      TextDirection.ltr,
    );
    expect(directionOf(PhosphorIcons.plus()), TextDirection.rtl);
  });

  testWidgets(
    'Play and My List animate while pressed and invoke their actions',
    (tester) async {
      var playTaps = 0;
      var listTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Wrap(
                children: <Widget>[
                  PillButton(
                    label: 'Play',
                    icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                    onPressed: () => playTaps++,
                  ),
                  PillButton(
                    label: 'My List',
                    icon: PhosphorIcons.plus(),
                    onPressed: () => listTaps++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in <String>['Play', 'My List']) {
        final button = find.text(label);
        final scale = find.descendant(
          of: find.ancestor(of: button, matching: find.byType(PillButton)),
          matching: find.byType(AnimatedScale),
        );
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 12));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 1));
        expect(tester.widget<AnimatedScale>(scale).scale, 0.94);
        await tester.pump(const Duration(milliseconds: 140));
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.widget<AnimatedScale>(scale).scale, 1);
      }

      expect(playTaps, 1);
      expect(listTaps, 1);
    },
  );

  testWidgets('Hero action keeps its tap pulse when it enters busy state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _BusyPillHost()));
    await tester.pumpAndSettle();

    final button = find.byType(PillButton);
    final scale = find.descendant(
      of: button,
      matching: find.byType(AnimatedScale),
    );
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<AnimatedScale>(scale).scale, 0.94);
    await tester.pump(const Duration(milliseconds: 145));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
  });
}

class _BusyPillHost extends StatefulWidget {
  const _BusyPillHost();

  @override
  State<_BusyPillHost> createState() => _BusyPillHostState();
}

class _BusyPillHostState extends State<_BusyPillHost> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: PillButton(
        label: 'Play',
        busy: _busy,
        onPressed: () => setState(() => _busy = true),
      ),
    ),
  );
}
