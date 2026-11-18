import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Reveals a browse-row item the first time it actually enters the viewport.
///
/// This mirrors Zangetsu's mobile list reveal: fade + a 28 px rise + a subtle
/// scale from 0.94 to 1.0. Visibility gating matters for horizontal shelves:
/// ListView builds cards ahead of the viewport, so starting on build would let
/// the animation finish before a user swipes the card into view.
class RevealItem extends StatefulWidget {
  const RevealItem({super.key, required this.index, required this.child});

  /// Position in the row; used for the staggered reveal wave.
  final int index;
  final Widget child;

  @override
  State<RevealItem> createState() => _RevealItemState();
}

class _RevealItemState extends State<RevealItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _fired = false;
  Timer? _staggerTimer;

  /// VisibilityDetector keys must be unique across the entire widget tree and
  /// stable for the lifetime of this row item.
  final Key _visibilityKey = UniqueKey();

  static const double _travel = 28;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (_fired || !mounted || info.visibleFraction <= 0) return;

    _fired = true;
    // A continuous cascade across the row; the cap prevents long shelves from
    // accumulating an increasingly long entrance delay.
    final delay = Duration(milliseconds: 45 * (widget.index % 8));
    _staggerTimer = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          // Opacity settles slightly ahead of the lift so the artwork becomes
          // readable while it is still easing into its final position.
          final fade = Curves.easeOut.transform(
            (_controller.value * 1.4).clamp(0.0, 1.0),
          );
          return Opacity(
            opacity: fade,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * _travel),
              child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
            ),
          );
        },
      ),
    );
  }
}
