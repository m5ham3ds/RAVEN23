import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
    'menu toggle uses radio button and mirrors selected secondary destination',
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

      expect(find.byIcon(PhosphorIcons.radioButton()), findsOneWidget);
      expect(menuIcon, findsOneWidget);
      expect(tester.widget<Icon>(menuIcon).icon, PhosphorIcons.radioButton());
      expect(tester.widget<Icon>(menuIcon).size, 30);

      await tester.tap(menuToggle);
      await tester.pumpAndSettle();
      expect(find.byIcon(PhosphorIcons.x()), findsOneWidget);

      await tester.tap(find.text('Movies'));
      await tester.pumpAndSettle();
      // Both the Movies dock item and the center toggle intentionally show
      // the filled video icon. Scope this check to the center toggle.
      expect(menuIcon, findsOneWidget);
      expect(
        tester.widget<Icon>(menuIcon).icon,
        PhosphorIcons.video(PhosphorIconsStyle.fill),
      );
      expect(find.byIcon(PhosphorIcons.radioButton()), findsNothing);

      await tester.tap(find.text('Return home'));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(PhosphorIcons.house(PhosphorIconsStyle.fill)),
        findsOneWidget,
      );
      expect(find.byIcon(PhosphorIcons.radioButton()), findsOneWidget);
      expect(tester.widget<Icon>(menuIcon).icon, PhosphorIcons.radioButton());
    },
  );
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
            onPressed: () => setState(() => _current = MobileTab.home),
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
