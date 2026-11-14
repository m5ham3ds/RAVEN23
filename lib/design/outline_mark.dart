import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The RAVEN23 outline mark, kept as a dedicated replaceable SVG asset.
class OutlineMark extends StatelessWidget {
  const OutlineMark({required this.height, required this.color, super.key});

  final double height;
  final Color color;

  static const asset = 'assets/images/fq_svg.svg';

  static double heightFor(double side) =>
      (side.isFinite ? side * .34 : 40.0).clamp(16.0, 64.0);

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        asset,
        height: height,
        excludeFromSemantics: true,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
