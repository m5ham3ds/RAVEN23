import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../design/app_tokens.dart';

/// A Home-feed row whose trailing spacing is shown only when its child is.
///
/// Reuse this wrapper for optional notices and future feed inserts so
/// catalogue pages keep the same vertical rhythm as the Home page.
class HomeOptionalRow extends StatelessWidget {
  const HomeOptionalRow({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _GapBelowIfShown(gap: AppSpace.rowGap, child: child);
}

class _GapBelowIfShown extends SingleChildRenderObjectWidget {
  const _GapBelowIfShown({required this.gap, super.child});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGapBelowIfShown(gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGapBelowIfShown renderObject,
  ) => renderObject.gap = gap;
}

class _RenderGapBelowIfShown extends RenderShiftedBox {
  _RenderGapBelowIfShown(this._gap) : super(null);

  double _gap;

  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }
    child.layout(constraints.loosen(), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset.zero;
    final height = child.size.height;
    size = constraints.constrain(
      Size(child.size.width, height > 0 ? height + _gap : 0),
    );
  }
}
