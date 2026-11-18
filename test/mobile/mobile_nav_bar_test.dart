import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:raven23/design/app_press_feedback.dart';
import 'package:raven23/mobile/app/mobile_nav_bar.dart';
import 'package:raven23/mobile/app/mobile_tabs.dart';

import '../support/tv_localization.dart';

void main() {
  initializeTvTranslations();

  testWidgets('uses the requested Phosphor icons on both navigation docks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          bottomNavigationBar: MobileNavBar(
            current: MobileTab.home,
            menuOpen: true,
            onSelect: (_) {},
            onToggleMenu: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
      findsOneWidget,
    );
    expect(find.byIcon(PhosphorIcons.fire()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.video()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.televisionSimple()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.magnifyingGlass()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.maskHappy()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.bookOpenText()), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.x()), findsOneWidget);

    final homeLabel = find.text('Home');
    final homeFeedback = find
        .ancestor(of: homeLabel, matching: find.byType(AppPressFeedback))
        .first;
    expect(
      find.descendant(
        of: homeFeedback,
        matching: find.byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('centre toggle stays 25% larger in collapsed navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          bottomNavigationBar: MobileNavBar(
            current: MobileTab.home,
            menuOpen: false,
            collapsed: true,
            onSelect: (_) {},
            onToggleMenu: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final menuIcon = find.descendant(
      of: find.byKey(const ValueKey<String>('mobile-nav-menu-toggle')),
      matching: find.byType(Icon),
    );
    expect(tester.widget<Icon>(menuIcon).size, 26.875);
  });

  testWidgets(
    'primary destination icon and label share the centre-toggle press animation',
    (tester) async {
      await tester.pumpWidget(const _NavigationHost());
      await tester.pumpAndSettle();

      final itemFeedback = find.byKey(
        const ValueKey<String>('mobile-nav-item-new'),
      );
      final label = find.descendant(
        of: itemFeedback,
        matching: find.text('New & Hot'),
      );
      final icon = find.descendant(
        of: itemFeedback,
        matching: find.byIcon(PhosphorIcons.fire()),
      );
      final scale = find.descendant(
        of: itemFeedback,
        matching: find.byType(AnimatedScale),
      );

      expect(itemFeedback, findsOneWidget);
      expect(label, findsOneWidget);
      expect(icon, findsOneWidget);
      expect(scale, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(label));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<AnimatedScale>(scale).scale, 0.94);
      // Icon and caption are descendants of the same AnimatedScale boundary.
      expect(
        find.descendant(of: itemFeedback, matching: find.text('New & Hot')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: itemFeedback,
          matching: find.byIcon(PhosphorIcons.fire()),
        ),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      expect(
        find.descendant(
          of: itemFeedback,
          matching: find.byIcon(PhosphorIcons.fire(PhosphorIconsStyle.fill)),
        ),
        findsOneWidget,
      );

      // The centre action uses the same AppPressFeedback defaults as every
      // destination: identical scale, duration and release behavior.
      final menuToggle = find.byKey(
        const ValueKey<String>('mobile-nav-menu-toggle'),
      );
      final menuScale = find.descendant(
        of: menuToggle,
        matching: find.byType(AnimatedScale),
      );
      expect(menuToggle, findsOneWidget);
      expect(menuScale, findsOneWidget);
      final menuGesture = await tester.startGesture(
        tester.getCenter(menuToggle),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<AnimatedScale>(menuScale).scale, 0.985);
      await menuGesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(menuScale).scale, 1);
    },
  );

  testWidgets(
    'all four persistent destinations receive visible press feedback',
    (tester) async {
      await tester.pumpWidget(const _NavigationHost());
      await tester.pumpAndSettle();

      for (final tabId in <String>['home', 'new', 'discover', 'mine']) {
        final item = find.byKey(ValueKey<String>('mobile-nav-item-$tabId'));
        final scale = find.descendant(
          of: item,
          matching: find.byType(AnimatedScale),
        );
        expect(item, findsOneWidget, reason: 'missing navigation item: $tabId');
        final gesture = await tester.startGesture(tester.getCenter(item));
        await tester.pump(const Duration(milliseconds: 12));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          tester.widget<AnimatedScale>(scale).scale,
          0.94,
          reason: 'quick-tap feedback did not activate for $tabId',
        );
        await tester.pump(const Duration(milliseconds: 140));
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.widget<AnimatedScale>(scale).scale, 1);
      }
    },
  );

  testWidgets(
    'secondary dock collapses after selection and restores both selections when reopened',
    (tester) async {
      await tester.pumpWidget(const _NavigationHost());
      await tester.pumpAndSettle();

      final menuToggle = find.byKey(
        const ValueKey<String>('mobile-nav-menu-toggle'),
      );
      final menuIcon = find.descendant(
        of: menuToggle,
        matching: find.byType(Icon),
      );

      expect(find.byIcon(PhosphorIcons.compassRose()), findsOneWidget);
      expect(menuIcon, findsOneWidget);
      _expectIconGlyph(tester, menuIcon, PhosphorIcons.compassRose());
      expect(tester.widget<Icon>(menuIcon).size, 30);
      final menuCaption = find.descendant(
        of: menuToggle,
        matching: find.text(' '),
      );
      expect(menuCaption, findsOneWidget);
      final menuFeedback = find
          .ancestor(of: menuCaption, matching: find.byType(AppPressFeedback))
          .first;
      expect(
        find.descendant(of: menuFeedback, matching: find.byType(Icon)),
        findsOneWidget,
      );

      await tester.tap(menuToggle);
      await tester.pumpAndSettle();
      expect(find.byIcon(PhosphorIcons.x()), findsOneWidget);

      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      // AnimatedSize intentionally retains the child in the widget tree so
      // it can animate cleanly. The collapsed dock must have zero extent and
      // its retained label must no longer be visible or hit-testable.
      final secondaryDockSize = find.byType(AnimatedSize).first;
      expect(tester.getSize(secondaryDockSize).height, 0);
      expect(find.text('Movies').hitTestable(), findsNothing);
      // The centre icon reflects the selected secondary destination.
      _expectIconGlyph(
        tester,
        menuIcon,
        PhosphorIcons.video(PhosphorIconsStyle.fill),
      );
      expect(
        find.byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        findsOneWidget,
      );

      // Reopening reveals the retained secondary selection beside Home.
      await tester.tap(menuToggle);
      await tester.pumpAndSettle();
      expect(tester.getSize(secondaryDockSize).height, 54);
      expect(find.text('Movies').hitTestable(), findsOneWidget);
      expect(
        find.byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        findsOneWidget,
      );
      expect(
        find.byIcon(PhosphorIcons.video(PhosphorIconsStyle.fill)),
        findsOneWidget,
      );

      await tester.tap(find.text('Series'));
      await tester.pumpAndSettle();
      expect(tester.getSize(secondaryDockSize).height, 0);
      expect(find.text('Series').hitTestable(), findsNothing);
      _expectIconGlyph(
        tester,
        menuIcon,
        PhosphorIcons.televisionSimple(PhosphorIconsStyle.fill),
      );
      expect(
        find.byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        findsOneWidget,
      );

      await tester.tap(menuToggle);
      await tester.pumpAndSettle();
      expect(tester.getSize(secondaryDockSize).height, 54);
      await tester.tap(find.text('Anime'));
      await tester.pumpAndSettle();
      expect(tester.getSize(secondaryDockSize).height, 0);
      expect(find.text('Anime').hitTestable(), findsNothing);
      _expectIconGlyph(
        tester,
        menuIcon,
        PhosphorIcons.maskHappy(PhosphorIconsStyle.fill),
      );
      expect(
        find.byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        findsOneWidget,
      );

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        findsOneWidget,
      );
      expect(find.byIcon(PhosphorIcons.compassRose()), findsOneWidget);
      _expectIconGlyph(tester, menuIcon, PhosphorIcons.compassRose());
    },
  );

  testWidgets(
    'shared press feedback scales the complete button briefly without stealing its tap',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppPressFeedback(
                child: IconButton(
                  key: const ValueKey<String>('press-feedback-icon'),
                  onPressed: () => taps++,
                  icon: const Icon(Icons.play_arrow),
                ),
              ),
            ),
          ),
        ),
      );

      final button = find.byKey(const ValueKey<String>('press-feedback-icon'));
      final feedback = find
          .ancestor(of: button, matching: find.byType(AppPressFeedback))
          .first;
      final scale = find.descendant(
        of: feedback,
        matching: find.byType(AnimatedScale),
      );

      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<AnimatedScale>(scale).scale, 0.985);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
    },
  );
}

void _expectIconGlyph(
  WidgetTester tester,
  Finder iconFinder,
  IconData expected,
) {
  final nullableActual = tester.widget<Icon>(iconFinder).icon;
  expect(nullableActual, isNotNull);
  final actual = nullableActual!;

  // phosphor_flutter can return distinct IconData wrapper instances for the
  // same glyph. Compare the rendered glyph identity rather than wrapper
  // object equality so the assertion remains stable across icon factories.
  expect(actual.codePoint, expected.codePoint);
  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.fontPackage, expected.fontPackage);
  expect(actual.matchTextDirection, expected.matchTextDirection);
}

class _NavigationHost extends StatefulWidget {
  const _NavigationHost();

  @override
  State<_NavigationHost> createState() => _NavigationHostState();
}

class _NavigationHostState extends State<_NavigationHost> {
  MobileTab _current = MobileTab.home;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => setState(() {
              _current = MobileTab.home;
              _menuOpen = false;
            }),
            child: const Text('Return home'),
          ),
        ),
        bottomNavigationBar: MobileNavBar(
          current: _current,
          menuOpen: _menuOpen,
          onSelect: (tab) => setState(() {
            _current = tab;
            _menuOpen = false;
          }),
          onToggleMenu: () => setState(() => _menuOpen = !_menuOpen),
        ),
      ),
    );
  }
}
