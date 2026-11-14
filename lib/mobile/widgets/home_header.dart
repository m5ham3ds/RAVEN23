import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/flix_ai_mark.dart';
import '../../widgets/app_logo.dart';
import 'filter_chips.dart';
import '../screens/flix_ai_screen.dart';

/// Home's top: the logo, Downloads and Search, and the filter chips. It
/// sits clear over the featured title's wash, and takes on the page colour,
/// frosted, once the page scrolls under it.
class HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  HomeHeaderDelegate({
    required this.topInset,
    required this.palette,
    required this.reduceMotion,
    required this.chips,
    required this.onSearch,
    required this.onDownloads,
    this.searchActive = false,
  });

  final double topInset;
  final AppPalette palette;
  final bool reduceMotion;
  final List<FilterChipSpec> chips;
  final VoidCallback onSearch;
  final VoidCallback onDownloads;
  final bool searchActive;

  /// Scrolled this far, the bar is fully solid.
  static const _solidAfter = 80.0;

  @override
  double get maxExtent => topInset + HomeHeader.barHeight;

  @override
  double get minExtent => maxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final solid = (shrinkOffset / _solidAfter).clamp(0.0, 1.0);
    final header = HomeHeader(
      topInset: topInset,
      chips: chips,
      onSearch: onSearch,
      onDownloads: onDownloads,
      searchActive: searchActive,
    );
    final background = ColoredBox(
      color: palette.scrim(solid * (reduceMotion ? 1 : .94)),
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (solid > 0 && !reduceMotion)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12 * solid, sigmaY: 12 * solid),
              child: background,
            ),
          )
        else
          background,
        header,
      ],
    );
  }

  @override
  bool shouldRebuild(HomeHeaderDelegate oldDelegate) =>
      topInset != oldDelegate.topInset ||
      !identical(palette, oldDelegate.palette) ||
      reduceMotion != oldDelegate.reduceMotion ||
      chips != oldDelegate.chips ||
      searchActive != oldDelegate.searchActive;
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.topInset,
    required this.chips,
    required this.onSearch,
    required this.onDownloads,
    this.searchActive = false,
  });

  final double topInset;
  final List<FilterChipSpec> chips;
  final VoidCallback onSearch;
  final VoidCallback onDownloads;
  final bool searchActive;

  static const _appBarHeight = 52.0;
  static const barHeight = _appBarHeight + FilterChips.height + 12;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: _appBarHeight,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter - 8, 0),
              child: Row(
                children: <Widget>[
                  // The mark in the theme's colour, as the TV rail has it (a
                  // logo set remotely still takes its place), and the name
                  // in heavy type in the text colour beside it.
                  // Tight, so the Spacer's share of the free space is all
                  // that's left and the icons sit at the bar's far end.
                  Flexible(
                    fit: FlexFit.tight,
                    child: Semantics(
                      header: true,
                      label: 'RAVEN23',
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AppLogo(
                            fallbackAsset: 'assets/images/fq_mark.svg',
                            height: 26,
                            fallbackColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          // A logo, so it keeps its size at any text size,
                          // and gives way only if the bar runs out of room.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                'RAVEN23',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: palette.foreground,
                                  fontFamily: 'FigtreeBlack',
                                  fontSize: 20,
                                  height: 1,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: tr('downloads'),
                    color: palette.foreground,
                    onPressed: onDownloads,
                    icon: Icon(PhosphorIcons.downloadSimple(), size: 24),
                  ),
                  IconButton(
                    tooltip: 'FlixAI',
                    color: palette.foreground,
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/flix-ai'),
                        builder: (_) => const FlixAiScreen(),
                      ),
                    ),
                    icon: const FlixAiMark(height: 22),
                  ),
                  // Search last, at the bar's far end.
                  IconButton(
                    tooltip: tr(searchActive ? 'close' : 'search'),
                    color: palette.foreground,
                    onPressed: onSearch,
                    icon: Icon(
                      searchActive
                          ? PhosphorIcons.x()
                          : PhosphorIcons.magnifyingGlass(),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          FilterChips(chips: chips),
        ],
      ),
    );
  }
}
