import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Flat, solid-colour drawings for the three welcome pages. [t] runs from 0
/// to 1 and loops, so pieces can float gently; it stays still when the
/// phone asks for reduced motion.
abstract class OnboardingArt extends CustomPainter {
  OnboardingArt(this.c, this.t);

  final RoomCraftColors c;
  final double t;

  double get wave => math.sin(t * 2 * math.pi);

  @override
  bool shouldRepaint(OnboardingArt old) => old.t != t || old.c != c;

  RRect box(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  Paint fill(Color color) => Paint()..color = color;

  Paint stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
}

/// Page 1, on emerald: a room from above, with a sofa sliding onto a snap
/// guide.
class DesignArt extends OnboardingArt {
  DesignArt(super.c, super.t);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final o = Offset((size.width - s) / 2, (size.height - s) / 2);
    canvas
      ..save()
      ..translate(o.dx, o.dy);
    final white = c.highlight;
    // Floor: an L-shaped room on a slightly lighter green.
    final room = Path()
      ..moveTo(0.10 * s, 0.12 * s)
      ..lineTo(0.90 * s, 0.12 * s)
      ..lineTo(0.90 * s, 0.62 * s)
      ..lineTo(0.62 * s, 0.62 * s)
      ..lineTo(0.62 * s, 0.88 * s)
      ..lineTo(0.10 * s, 0.88 * s)
      ..close();
    canvas
      ..drawPath(room, fill(white.withValues(alpha: 0.14)))
      ..drawPath(room, stroke(white, 0.035 * s));
    // Door: a gap with its swing.
    canvas
      ..drawLine(
        Offset(0.22 * s, 0.88 * s),
        Offset(0.38 * s, 0.88 * s),
        stroke(c.primaryAction, 0.036 * s)..strokeCap = StrokeCap.butt,
      )
      ..drawArc(
        Rect.fromCircle(center: Offset(0.22 * s, 0.88 * s), radius: 0.16 * s),
        -math.pi / 2,
        math.pi / 2,
        false,
        stroke(white.withValues(alpha: 0.7), 0.012 * s),
      );
    // Bed with pillows.
    canvas
      ..drawRRect(
        box(0.58 * s, 0.18 * s, 0.26 * s, 0.36 * s, 0.03 * s),
        fill(c.sunflower),
      )
      ..drawRRect(
        box(0.61 * s, 0.21 * s, 0.09 * s, 0.07 * s, 0.02 * s),
        fill(white),
      )
      ..drawRRect(
        box(0.72 * s, 0.21 * s, 0.09 * s, 0.07 * s, 0.02 * s),
        fill(white),
      );
    // Rug and plant.
    canvas
      ..drawCircle(Offset(0.36 * s, 0.40 * s), 0.12 * s, fill(c.sky))
      ..drawCircle(
        Offset(0.36 * s, 0.40 * s),
        0.08 * s,
        stroke(white.withValues(alpha: 0.6), 0.01 * s),
      )
      ..drawCircle(Offset(0.18 * s, 0.22 * s), 0.05 * s, fill(c.coral));
    // Snap guide and the sofa gliding onto it.
    final guideY = 0.72 * s;
    final dash = stroke(c.sunflower, 0.012 * s);
    for (var x = 0.12 * s; x < 0.60 * s; x += 0.05 * s) {
      canvas.drawLine(Offset(x, guideY), Offset(x + 0.025 * s, guideY), dash);
    }
    final dx = wave * 0.05 * s;
    final sofa = box(
      0.20 * s + dx,
      guideY - 0.005 * s,
      0.30 * s,
      0.11 * s,
      0.025 * s,
    );
    canvas
      ..drawRRect(
        sofa.shift(Offset(0, 0.012 * s)),
        fill(c.shade.withValues(alpha: 0.18)),
      )
      ..drawRRect(sofa, fill(c.coral))
      ..drawRRect(
        box(0.20 * s + dx, guideY - 0.005 * s, 0.30 * s, 0.035 * s, 0.02 * s),
        fill(Color.lerp(c.coral, c.shade, 0.15)!),
      );
    // A finger ring on the sofa.
    final finger = Offset(0.42 * s + dx, guideY + 0.07 * s);
    canvas
      ..drawCircle(finger, 0.055 * s, fill(white.withValues(alpha: 0.35)))
      ..drawCircle(finger, 0.03 * s, fill(white));
    canvas.restore();
  }
}

/// Page 2, on coral: an isometric room in 3D with AI sparkles above it.
class ThreeDArt extends OnboardingArt {
  ThreeDArt(super.c, super.t);

  late double _k;
  late Offset _origin;

  /// Plan (x, y) with height z, in room units, to the screen.
  Offset _iso(double x, double y, double z) =>
      _origin +
      Offset((x - y) * _k * math.cos(math.pi / 6), (x + y) * _k * 0.5 - z * _k);

  Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

  void _block(
    Canvas canvas,
    double x,
    double y,
    double w,
    double d,
    double h,
    Color color,
  ) {
    final top = [
      _iso(x, y, h),
      _iso(x + w, y, h),
      _iso(x + w, y + d, h),
      _iso(x, y + d, h),
    ];
    final left = [
      _iso(x, y + d, 0),
      _iso(x + w, y + d, 0),
      _iso(x + w, y + d, h),
      _iso(x, y + d, h),
    ];
    final right = [
      _iso(x + w, y, 0),
      _iso(x + w, y + d, 0),
      _iso(x + w, y + d, h),
      _iso(x + w, y, h),
    ];
    canvas
      ..drawPath(_poly(left), fill(Color.lerp(color, c.shade, 0.18)!))
      ..drawPath(_poly(right), fill(Color.lerp(color, c.shade, 0.30)!))
      ..drawPath(_poly(top), fill(color));
  }

  void _sparkle(Canvas canvas, Offset at, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.32;
      final pt = at + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), fill(color));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    _k = s / 5.6;
    _origin = Offset(size.width / 2, size.height / 2 - 0.12 * s);
    const n = 4.0, wall = 2.2;
    final cream = c.lampShade;
    final white = c.highlight;
    // Walls behind, then the floor.
    canvas
      ..drawPath(
        _poly([
          _iso(0, 0, 0),
          _iso(n, 0, 0),
          _iso(n, 0, wall),
          _iso(0, 0, wall),
        ]),
        fill(white),
      )
      ..drawPath(
        _poly([
          _iso(0, 0, 0),
          _iso(0, n, 0),
          _iso(0, n, wall),
          _iso(0, 0, wall),
        ]),
        fill(Color.lerp(white, cream, 0.6)!),
      )
      ..drawPath(
        _poly([_iso(0, 0, 0), _iso(n, 0, 0), _iso(n, n, 0), _iso(0, n, 0)]),
        fill(Color.lerp(cream, c.coral, 0.15)!),
      );
    // A window on the back wall.
    canvas.drawPath(
      _poly([
        _iso(1.4, 0, 1.0),
        _iso(2.6, 0, 1.0),
        _iso(2.6, 0, 1.8),
        _iso(1.4, 0, 1.8),
      ]),
      fill(c.sky),
    );
    // Furniture: bed, sofa, plant pot.
    _block(canvas, 2.3, 0.2, 1.5, 2.0, 0.5, c.primaryAction);
    _block(canvas, 2.35, 0.25, 0.6, 0.45, 0.62, white);
    _block(canvas, 0.2, 2.6, 1.9, 0.8, 0.45, c.sunflower);
    _block(canvas, 0.3, 0.3, 0.5, 0.5, 0.4, c.onAccent);
    canvas.drawCircle(_iso(0.55, 0.55, 0.85), 0.32 * _k, fill(c.primaryAction));
    // AI sparkles floating above.
    final lift = wave * 0.025 * s;
    _sparkle(
      canvas,
      Offset(size.width * 0.78, 0.14 * s + lift),
      0.075 * s,
      c.sunflower,
    );
    _sparkle(
      canvas,
      Offset(size.width * 0.88, 0.30 * s - lift),
      0.04 * s,
      white,
    );
    _sparkle(
      canvas,
      Offset(size.width * 0.20, 0.10 * s - lift),
      0.045 * s,
      white,
    );
  }
}

/// Page 3, on sky blue: two phones showing the same room, with the code
/// travelling between them.
class LiveArt extends OnboardingArt {
  LiveArt(super.c, super.t, {required this.code, required this.live});

  final String code;
  final String live;

  void _phone(Canvas canvas, Rect r, double itemShift) {
    final s = r.width;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          r.shift(Offset(0, s * 0.05)),
          Radius.circular(s * 0.16),
        ),
        fill(c.shade.withValues(alpha: 0.18)),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(s * 0.16)),
        fill(c.onAccent),
      );
    final screen = r.deflate(s * 0.07);
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, Radius.circular(s * 0.10)),
      fill(c.highlight),
    );
    // A small room on each screen.
    final room = Rect.fromLTWH(
      screen.left + screen.width * 0.14,
      screen.top + screen.height * 0.22,
      screen.width * 0.72,
      screen.height * 0.50,
    );
    canvas
      ..drawRect(room, fill(c.lampShade))
      ..drawRect(room, stroke(c.primaryAction, s * 0.035))
      ..drawRRect(
        box(
          room.left + room.width * (0.10 + itemShift),
          room.top + room.height * 0.12,
          room.width * 0.42,
          room.height * 0.30,
          s * 0.02,
        ),
        fill(c.coral),
      )
      ..drawRRect(
        box(
          room.left + room.width * 0.55,
          room.top + room.height * 0.58,
          room.width * 0.32,
          room.height * 0.30,
          s * 0.02,
        ),
        fill(c.sunflower),
      );
  }

  void _pill(
    Canvas canvas,
    Offset centre,
    String text,
    Color bg,
    Color fg,
    double size, {
    bool dot = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: size * 0.12,
          color: fg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dotSpace = dot ? size * 0.9 : 0.0;
    final rect = Rect.fromCenter(
      center: centre,
      width: tp.width + size * 1.4 + dotSpace,
      height: tp.height + size * 0.7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      fill(bg),
    );
    if (dot) {
      canvas.drawCircle(
        Offset(rect.left + size * 0.75, centre.dy),
        size * 0.28 * (1 + wave * 0.15),
        fill(fg),
      );
    }
    tp.paint(
      canvas,
      Offset(rect.left + size * 0.7 + dotSpace, centre.dy - tp.height / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2, cy = size.height / 2;
    final w = s * 0.34, h = s * 0.62;
    final shift = 0.08 + wave * 0.08;
    _phone(
      canvas,
      Rect.fromCenter(
        center: Offset(cx - s * 0.22, cy + s * 0.04),
        width: w,
        height: h,
      ),
      shift,
    );
    _phone(
      canvas,
      Rect.fromCenter(
        center: Offset(cx + s * 0.22, cy + s * 0.10),
        width: w,
        height: h,
      ),
      shift,
    );
    // Signal arcs between the phones.
    final from = Offset(cx, cy - s * 0.30);
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: from, radius: s * 0.045 * i),
        -math.pi * 0.85,
        math.pi * 0.7,
        false,
        stroke(c.highlight.withValues(alpha: 0.9 - i * 0.2), s * 0.014),
      );
    }
    _pill(
      canvas,
      Offset(cx, cy - s * 0.42),
      code,
      c.sunflower,
      c.onAccent,
      s * 0.055,
    );
    _pill(
      canvas,
      Offset(cx + s * 0.22, cy - s * 0.25),
      live,
      c.coral,
      c.highlight,
      s * 0.04,
      dot: true,
    );
  }
}
