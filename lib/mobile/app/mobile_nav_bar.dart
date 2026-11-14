import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import 'mobile_tabs.dart';

/// RAVEN23's original bottom-dock artwork with a Zangetsu-style progressive
/// collapse: labels fold away and icon/spacing dimensions tighten without
/// replacing the app's colours, icon family, or selection treatment.
class MobileNavBar extends StatelessWidget {
  const MobileNavBar({
    required this.current,
    required this.onSelect,
    required this.menuOpen,
    required this.onToggleMenu,
    this.collapsed = false,
    super.key,
  });

  final MobileTab current;
  final ValueChanged<MobileTab> onSelect;
  final bool menuOpen;
  final VoidCallback onToggleMenu;
  final bool collapsed;

  static const height = 60.0;
  static const _motion = Duration(milliseconds: 340);
  static const _curve = Cubic(0.32, 0.72, 0, 1);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final solid = media.disableAnimations;
    final selectedPrimary = current.primarySelectionFor;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? palette.page : palette.scrim(0.94),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: media.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ClipRect(
              child: AnimatedSize(
                duration: solid ? Duration.zero : _motion,
                curve: _curve,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: menuOpen ? 54 : 0,
                  child: IgnorePointer(
                    ignoring: !menuOpen,
                    child: AnimatedOpacity(
                      opacity: menuOpen ? 1 : 0,
                      duration: solid
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: AnimatedSlide(
                        offset: menuOpen ? Offset.zero : const Offset(0, 0.12),
                        duration: solid
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        curve: _curve,
                        child: _SecondaryDock(
                          current: current,
                          collapsed: collapsed,
                          onSelect: onSelect,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: solid ? Duration.zero : _motion,
              curve: _curve,
              height: height - (collapsed ? 8 : 0),
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: AnimatedContainer(
                    duration: solid ? Duration.zero : _motion,
                    curve: _curve,
                    // Keep all five destinations visually grouped. This
                    // reduces the centre-to-centre gap by 12.5% while keeping
                    // every item equally sized and the dock centred.
                    width:
                        (collapsed
                            ? (5 * 54.0)
                                  .clamp(0.0, constraints.maxWidth)
                                  .toDouble()
                            : constraints.maxWidth) *
                        0.875,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _NavItem(
                              tab: MobileTab.home,
                              selected: selectedPrimary == MobileTab.home,
                              collapsed: collapsed,
                              onTap: () => onSelect(MobileTab.home),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              tab: MobileTab.newAndHot,
                              selected: selectedPrimary == MobileTab.newAndHot,
                              collapsed: collapsed,
                              onTap: () => onSelect(MobileTab.newAndHot),
                            ),
                          ),
                          Expanded(
                            child: _MenuAction(
                              open: menuOpen,
                              current: current,
                              collapsed: collapsed,
                              onTap: onToggleMenu,
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              tab: MobileTab.discover,
                              selected: selectedPrimary == MobileTab.discover,
                              collapsed: collapsed,
                              onTap: () => onSelect(MobileTab.discover),
                            ),
                          ),
                          Expanded(
                            child: _NavItem(
                              tab: MobileTab.mine,
                              selected: selectedPrimary == MobileTab.mine,
                              collapsed: collapsed,
                              onTap: () => onSelect(MobileTab.mine),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (solid) return surface;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: surface,
      ),
    );
  }
}

/// The tablet rail keeps the same RAVEN destinations. Its expansion is
/// vertical so the five content destinations remain reachable there too.
class MobileNavRail extends StatelessWidget {
  const MobileNavRail({
    required this.current,
    required this.onSelect,
    required this.menuOpen,
    required this.onToggleMenu,
    super.key,
  });

  final MobileTab current;
  final ValueChanged<MobileTab> onSelect;
  final bool menuOpen;
  final VoidCallback onToggleMenu;

  static const width = 88.0;
  static const _itemHeight = 68.0;

  static double extentOf(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return width + (rtl ? padding.right : padding.left);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final padding = MediaQuery.paddingOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final tablet = AppBreakpoints.isTablet(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final selected = current.primarySelectionFor;
    return SizedBox(
      width: extentOf(context),
      child: ColoredBox(
        color: palette.page,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: rtl ? padding.right : padding.left,
            top: padding.top,
            bottom: padding.bottom,
          ),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: tablet
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: <Widget>[
                      if (tablet) const SizedBox(height: AppSpace.sm),
                      for (final tab in <MobileTab>[
                        MobileTab.home,
                        MobileTab.newAndHot,
                      ])
                        SizedBox(
                          width: width,
                          height: _itemHeight,
                          child: _NavItem(
                            tab: tab,
                            selected: tab == selected,
                            collapsed: false,
                            onTap: () => onSelect(tab),
                          ),
                        ),
                      SizedBox(
                        width: width,
                        height: _itemHeight,
                        child: _MenuAction(
                          open: menuOpen,
                          current: current,
                          collapsed: false,
                          onTap: onToggleMenu,
                        ),
                      ),
                      for (final tab in <MobileTab>[
                        MobileTab.discover,
                        MobileTab.mine,
                      ])
                        SizedBox(
                          width: width,
                          height: _itemHeight,
                          child: _NavItem(
                            tab: tab,
                            selected: tab == selected,
                            collapsed: false,
                            onTap: () => onSelect(tab),
                          ),
                        ),
                      ClipRect(
                        child: AnimatedSize(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 340),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.topCenter,
                          child: IgnorePointer(
                            ignoring: !menuOpen,
                            child: menuOpen
                                ? Column(
                                    children: <Widget>[
                                      for (final tab
                                          in MobileTab.secondaryDestinations)
                                        SizedBox(
                                          width: width,
                                          height: _itemHeight,
                                          child: _NavItem(
                                            tab: tab,
                                            selected: tab == current,
                                            collapsed: false,
                                            onTap: () => onSelect(tab),
                                          ),
                                        ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

(IconData, IconData, String) _navLookFor(MobileTab tab) => switch (tab) {
  MobileTab.home => (
    PhosphorIcons.house(),
    PhosphorIcons.house(PhosphorIconsStyle.fill),
    'home',
  ),
  MobileTab.newAndHot => (
    PhosphorIcons.fire(),
    PhosphorIcons.fire(PhosphorIconsStyle.fill),
    'new_and_hot',
  ),
  MobileTab.discover => (
    PhosphorIcons.compass(),
    PhosphorIcons.compass(PhosphorIconsStyle.fill),
    'discover',
  ),
  MobileTab.search => (
    PhosphorIcons.magnifyingGlass(),
    PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold),
    'search',
  ),
  MobileTab.mine => (
    PhosphorIcons.userCircle(),
    PhosphorIcons.userCircle(PhosphorIconsStyle.fill),
    'my_raven23',
  ),
  MobileTab.movies => (
    PhosphorIcons.video(),
    PhosphorIcons.video(PhosphorIconsStyle.fill),
    'movies',
  ),
  MobileTab.series => (
    PhosphorIcons.televisionSimple(),
    PhosphorIcons.televisionSimple(PhosphorIconsStyle.fill),
    'series',
  ),
  MobileTab.anime => (
    PhosphorIcons.maskHappy(),
    PhosphorIcons.maskHappy(PhosphorIconsStyle.fill),
    'anime',
  ),
  MobileTab.manga => (
    PhosphorIcons.bookOpenText(),
    PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill),
    'manga',
  ),
};

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final MobileTab tab;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  (IconData, IconData, String) get _look => _navLookFor(tab);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final (icon, selectedIcon, labelKey) = _look;
    final color = selected ? palette.foreground : palette.mutedText;
    final child = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: collapsed ? 1 : 0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 340),
      curve: const Cubic(0.32, 0.72, 0, 1),
      builder: (context, fold, _) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 26 - 3 * fold,
                height: 26 - 3 * fold,
                child: Center(
                  child: Icon(
                    selected ? selectedIcon : icon,
                    size: 24 - 2.5 * fold,
                    color: color,
                  ),
                ),
              ),
              ClipRect(
                child: Align(
                  heightFactor: 1 - fold,
                  child: Opacity(
                    opacity: 1 - fold,
                    child: Padding(
                      padding: EdgeInsets.only(top: 3 * (1 - fold)),
                      child: Text(
                        tr(labelKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppType.semiBold,
                          fontSize: 11,
                          height: 14 / 11,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: tr(labelKey),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _SecondaryDock extends StatelessWidget {
  const _SecondaryDock({
    required this.current,
    required this.collapsed,
    required this.onSelect,
  });

  final MobileTab current;
  final bool collapsed;
  final ValueChanged<MobileTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.scrim(0.98),
        border: Border(top: BorderSide(color: palette.hairline, width: 0.5)),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.875,
          child: Row(
            children: <Widget>[
              for (final tab in MobileTab.secondaryDestinations)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    selected: tab == current,
                    collapsed: collapsed,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.open,
    required this.current,
    required this.collapsed,
    required this.onTap,
  });

  final bool open;
  final MobileTab current;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final hasSecondaryDestination = MobileTab.secondaryDestinations.contains(
      current,
    );
    final color = open || hasSecondaryDestination
        ? palette.foreground
        : palette.mutedText;
    final currentDestinationIcon = _navLookFor(current).$2;
    final icon = open
        ? PhosphorIcons.x()
        : hasSecondaryDestination
        ? currentDestinationIcon
        : PhosphorIcons.radioButton();
    final iconStateKey = open
        ? 'open'
        : hasSecondaryDestination
        ? 'destination-${current.id}'
        : 'closed-radio-button';
    return Semantics(
      button: true,
      expanded: open,
      label: tr(open ? 'close_catalog_menu' : 'open_catalog_menu'),
      child: GestureDetector(
        key: const ValueKey<String>('mobile-nav-menu-toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                icon,
                key: ValueKey<String>(iconStateKey),
                // The menu control has no text label, so its icon is 25%
                // larger than the labelled destinations around it.
                size: collapsed ? 26.875 : 30,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
