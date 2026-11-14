import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import 'home_header.dart';

/// The shared page frame used by Home's Movies, Series, Anime and Manga feeds.
///
/// Data loading and filters belong to each catalogue adapter; the visual page
/// pipeline does not. Every feed gets the same pinned Home header, tint wash,
/// pull-to-refresh behavior, update notice slot, scroll controller contract,
/// and bottom safe-area spacing.
class HomePageFrame extends StatelessWidget {
  const HomePageFrame({
    required this.tint,
    required this.backgroundHeight,
    required this.headerHeight,
    required this.header,
    required this.onRefresh,
    required this.content,
    this.afterHeader = const <Widget>[],
    this.updateNotice,
    this.scrollController,
    this.tintEnabled = true,
    super.key,
  });

  final ValueListenable<Color?> tint;
  final double backgroundHeight;
  final double headerHeight;
  final HomeHeaderDelegate header;
  final Future<void> Function() onRefresh;
  final List<Widget> content;
  final List<Widget> afterHeader;
  final Widget? updateNotice;
  final ScrollController? scrollController;
  final bool tintEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);

    return ColoredBox(
      color: palette.page,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: backgroundHeight,
            child: IgnorePointer(
              child: ValueListenableBuilder<Color?>(
                valueListenable: tint,
                builder: (context, value, _) => TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: !tintEnabled || value == null
                        ? palette.page
                        : Color.lerp(
                            palette.page,
                            value,
                            palette.dark ? .42 : .24,
                          ),
                  ),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, color, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[color ?? palette.page, palette.page],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          RefreshIndicator(
            edgeOffset: headerHeight,
            color: palette.foreground,
            backgroundColor: palette.raisedSurface,
            onRefresh: onRefresh,
            child: CustomScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPersistentHeader(pinned: true, delegate: header),
                ...afterHeader,
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpace.md),
                ),
                if (updateNotice != null)
                  SliverToBoxAdapter(child: updateNotice),
                ...content,
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: media.padding.bottom + AppSpace.sm,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
