import 'package:flutter/cupertino.dart';

/// Apple's activity indicator, the spokes, in place of Material's
/// spinning arc — which is what every loading state used to draw.
///
/// [size] is the box it fills. [color] is the ground's muted text by
/// default at the call sites, the button's own text colour on a button,
/// and white over media.
class ShiftSpinner extends StatelessWidget {
  const ShiftSpinner({required this.color, this.size = 18, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CupertinoActivityIndicator(color: color, radius: size / 2),
      );
}
