import 'dart:async';

import 'package:flutter/material.dart';

/// A subtle press response for existing interactive controls.
///
/// Raw pointer events are observed without competing with the child's tap or
/// ink recognizer. The existing callbacks, semantics, haptics and hit targets
/// therefore remain owned by the original control.
class AppPressFeedback extends StatefulWidget {
  const AppPressFeedback({
    required this.child,
    this.enabled = true,
    this.scale = 0.985,
    this.duration = const Duration(milliseconds: 100),
    this.releaseDuration = const Duration(milliseconds: 150),
    this.releaseHold = const Duration(milliseconds: 140),
    this.moveTolerance = 10,
    super.key,
  }) : assert(scale > 0 && scale <= 1),
       assert(moveTolerance >= 0);

  final Widget child;
  final bool enabled;
  final double scale;
  final Duration duration;
  final Duration releaseDuration;
  final Duration releaseHold;
  final double moveTolerance;

  @override
  State<AppPressFeedback> createState() => _AppPressFeedbackState();
}

class _AppPressFeedbackState extends State<AppPressFeedback> {
  int? _activePointer;
  Offset? _downPosition;
  bool _pressed = false;
  bool _movedBeyondTapSlop = false;
  bool _activePointerStartedEnabled = false;
  Timer? _releaseTimer;

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || _activePointer != null) {
      return;
    }
    _releaseTimer?.cancel();
    _releaseTimer = null;
    _movedBeyondTapSlop = false;
    _activePointer = event.pointer;
    _activePointerStartedEnabled = true;
    _downPosition = event.position;
    _setPressed(true);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    final origin = _downPosition;
    if (origin != null &&
        (event.position - origin).distance > widget.moveTolerance) {
      // A scroll or drag should not keep a button in its pressed state, nor
      // should it produce a tap pulse when the pointer eventually lifts.
      _movedBeyondTapSlop = true;
      _releaseTimer?.cancel();
      _releaseTimer = null;
      _setPressed(false);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _downPosition = null;
    final shouldCompleteTap = _activePointerStartedEnabled;
    _activePointerStartedEnabled = false;
    if (event is PointerUpEvent && !_movedBeyondTapSlop && shouldCompleteTap) {
      // Keep the pressed state briefly after a tap. Fast taps often release
      // before a normal scale animation can reach a visible frame; the short
      // tail makes feedback perceptible without delaying the tap callback.
      _releaseTimer?.cancel();
      _releaseTimer = Timer(widget.releaseHold, () {
        _releaseTimer = null;
        _setPressed(false);
      });
    } else {
      _releaseTimer?.cancel();
      _releaseTimer = null;
      _setPressed(false);
    }
  }

  void _setPressed(bool value) {
    if (!mounted || value == _pressed) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant AppPressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      // A tap callback can disable its button (Hero Play enters busy state)
      // before the parent Listener receives pointer-up. Preserve only the
      // pointer that began while enabled, and its short release tail. New
      // pointer-down events are still ignored by _handlePointerDown.
      final pointerInFlight =
          _activePointer != null && _activePointerStartedEnabled;
      final completingTap =
          _activePointer == null && _releaseTimer != null && _pressed;
      if (!pointerInFlight && !completingTap) {
        _releaseTimer?.cancel();
        _releaseTimer = null;
        _activePointer = null;
        _activePointerStartedEnabled = false;
        _downPosition = null;
        _pressed = false;
      }
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final pressed =
        _pressed &&
        (widget.enabled ||
            (_activePointer != null && _activePointerStartedEnabled) ||
            _releaseTimer != null);
    final feedbackDuration = reduceMotion
        ? Duration.zero
        : (pressed ? widget.duration : widget.releaseDuration);
    return Listener(
      // Receive pointer-down around nested InkWell/GestureDetector children.
      // `deferToChild` can leave the listener out of the hit-test path.
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: AnimatedOpacity(
        opacity: pressed ? 0.76 : 1,
        duration: feedbackDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: pressed ? widget.scale : 1,
          duration: feedbackDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
