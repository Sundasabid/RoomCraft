import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// The app mark: a solid emerald tile holding a white L-shaped room with a
/// sunflower sofa and a coral plant. The launcher icon uses the same shapes.
class LogoMark extends StatelessWidget {
  const LogoMark({this.size = 72, super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: LogoPainter(context.colors)),
  );
}

class LogoPainter extends CustomPainter {
  LogoPainter(this.c, {this.tile = true});
  final RoomCraftColors c;

  /// False draws only the room, for use on an existing coloured surface.
  final bool tile;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset p(double x, double y) => Offset(x * s, y * s);
    if (tile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & Size.square(s),
          Radius.circular(s * 0.26),
        ),
        Paint()..color = c.primaryAction,
      );
    }
    final room = Path()
      ..moveTo(p(0.24, 0.24).dx, p(0.24, 0.24).dy)
      ..lineTo(p(0.76, 0.24).dx, p(0.76, 0.24).dy)
      ..lineTo(p(0.76, 0.56).dx, p(0.76, 0.56).dy)
      ..lineTo(p(0.56, 0.56).dx, p(0.56, 0.56).dy)
      ..lineTo(p(0.56, 0.76).dx, p(0.56, 0.76).dy)
      ..lineTo(p(0.24, 0.76).dx, p(0.24, 0.76).dy)
      ..close();
    canvas
      ..drawPath(
        room,
        Paint()
          ..color = c.onPrimaryAction
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.07
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.33 * s, 0.33 * s, 0.32 * s, 0.13 * s),
          Radius.circular(s * 0.035),
        ),
        Paint()..color = c.sunflower,
      )
      ..drawCircle(p(0.40, 0.62), s * 0.065, Paint()..color = c.coral);
  }

  @override
  bool shouldRepaint(LogoPainter old) => old.c != c || old.tile != tile;
}
