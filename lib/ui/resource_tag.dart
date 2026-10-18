import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'app_tokens.dart';

/// A small swallowtail ribbon used for course codes and resource types.
class ResourceTag extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final double height;
  final double fontSize;

  const ResourceTag({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.height = 18,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const SwallowtailTagClipper(),
      child: Container(
        height: height,
        padding: const EdgeInsets.only(left: 10, right: 12),
        color: background,
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: context.theme.typography.bodySmall.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class SwallowtailTagClipper extends CustomClipper<Path> {
  static const point = 5.0;
  static const notch = 5.0;

  const SwallowtailTagClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(point, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - notch, size.height / 2)
    ..lineTo(size.width, size.height)
    ..lineTo(point, size.height)
    ..lineTo(0, size.height / 2)
    ..close();

  @override
  bool shouldReclip(covariant SwallowtailTagClipper oldClipper) => false;
}
