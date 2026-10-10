import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Draws one piece of furniture seen from above, in its own frame: [r] is
/// the footprint before rotation, width across and depth down, with the
/// back edge (headboard, sofa back, screen) along the top. The plan and the
/// catalogue thumbnails both use it, so a piece looks the same everywhere.
void paintFurniture(
  Canvas canvas,
  Rect r,
  String catalogueId,
  Color fill,
  RoomCraftColors c, {
  double opacity = 1,
  bool shadow = true,
}) {
  final art = _Art(canvas, r, fill, c, opacity);
  if (shadow && opacity > 0.5) art.shadow(round: _round.contains(catalogueId));
  switch (catalogueId) {
    case 'bed':
      art.bed();
    case 'sofa':
      art.sofa();
    case 'chair':
      art.chair();
    case 'wardrobe':
      art.wardrobe();
    case 'bookshelf':
      art.bookshelf();
    case 'tv_unit':
      art.tvUnit();
    case 'desk':
      art.desk();
    case 'dining_table':
      art.diningTable();
    case 'coffee_table':
      art.coffeeTable();
    case 'rug':
      art.rug();
    case 'plant':
      art.plant();
    case 'floor_lamp':
      art.lamp();
    default:
      art.block();
  }
}

const _round = {'plant', 'floor_lamp'};

class _Art {
  _Art(this.canvas, this.r, this.fill, this.c, this.opacity);

  final Canvas canvas;
  final Rect r;
  final Color fill;
  final RoomCraftColors c;
  final double opacity;

  double get w => r.width;
  double get d => r.height;
  double get unit => math.min(w, d);

  Color _a(Color color) => color.withValues(alpha: color.a * opacity);
  Paint _p(Color color) => Paint()..color = _a(color);
  Color get dark => Color.lerp(fill, c.shade, 0.28)!;
  Color get darker => Color.lerp(fill, c.shade, 0.45)!;
  Color get light => Color.lerp(fill, c.highlight, 0.35)!;
  Color get lighter => Color.lerp(fill, c.highlight, 0.7)!;
  Radius get radius => Radius.circular(math.max(1.5, unit * 0.08));

  Rect part(double x, double y, double pw, double pd) =>
      Rect.fromLTWH(r.left + x * w, r.top + y * d, pw * w, pd * d);

  void rrect(Rect rect, Color color, {double? corner}) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      rect,
      corner == null ? radius : Radius.circular(corner),
    ),
    _p(color),
  );

  void outline(Rect rect, {double? corner}) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      rect,
      corner == null ? radius : Radius.circular(corner),
    ),
    Paint()
      ..color = _a(darker)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, unit * 0.025),
  );

  void shadow({bool round = false}) {
    final s = Paint()
      ..color = _a(c.shade.withValues(alpha: 0.16))
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        math.max(1, unit * 0.06),
      );
    final at = r.shift(Offset(0, unit * 0.05));
    if (round) {
      canvas.drawOval(at, s);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(at, radius), s);
    }
  }

  void block() {
    rrect(r, fill);
    outline(r);
  }

  void bed() {
    rrect(r, dark);
    rrect(part(0, 0, 1, 0.1), darker);
    final mattress = part(0.05, 0.08, 0.9, 0.88);
    rrect(mattress, lighter);
    final pw = 0.9 * w / 2 - w * 0.05;
    for (final x in [0.08, 0.08 + pw / w + 0.04]) {
      rrect(part(x, 0.12, pw / w, 0.14), c.highlight, corner: unit * 0.06);
    }
    final blanket = part(0.05, 0.38, 0.9, 0.58);
    rrect(blanket, fill);
    rrect(part(0.05, 0.38, 0.9, 0.08), light);
    outline(r);
  }

  void sofa() {
    rrect(r, darker);
    const arm = 0.13;
    rrect(part(0, 0, 1, 0.32), dark);
    final n = w > d * 1.8 ? 3 : 2;
    final seat = (1 - 2 * arm) / n;
    for (var i = 0; i < n; i++) {
      rrect(
        part(arm + i * seat + 0.01, 0.3, seat - 0.02, 0.64),
        light,
        corner: unit * 0.1,
      );
    }
    rrect(part(0, 0.06, arm, 0.94), dark);
    rrect(part(1 - arm, 0.06, arm, 0.94), dark);
    outline(r);
  }

  void chair() {
    rrect(part(0.06, 0.1, 0.88, 0.86), fill, corner: unit * 0.18);
    rrect(part(0.04, 0, 0.92, 0.26), dark, corner: unit * 0.12);
    rrect(part(0.2, 0.36, 0.6, 0.48), light, corner: unit * 0.14);
    outline(part(0.06, 0.1, 0.88, 0.86), corner: unit * 0.18);
  }

  void wardrobe() {
    rrect(r, fill);
    rrect(part(0, 0, 1, 0.12), dark);
    final line = Paint()
      ..color = _a(darker)
      ..strokeWidth = math.max(0.8, unit * 0.03);
    canvas.drawLine(
      Offset(r.center.dx, r.top + d * 0.14),
      Offset(r.center.dx, r.bottom - d * 0.06),
      line,
    );
    for (final x in [-1, 1]) {
      canvas.drawCircle(
        Offset(r.center.dx + x * w * 0.05, r.top + d * 0.62),
        math.max(1.2, unit * 0.06),
        _p(c.sunflower),
      );
    }
    outline(r);
  }

  void bookshelf() {
    rrect(r, darker);
    final colours = [c.coral, c.sky, c.sunflower, c.primaryAction, lighter];
    const books = 9;
    final inner = part(0.04, 0.14, 0.92, 0.72);
    final step = inner.width / books;
    for (var i = 0; i < books; i++) {
      final tall = 0.75 + 0.25 * ((i * 7) % 4) / 3;
      canvas.drawRect(
        Rect.fromLTWH(
          inner.left + i * step + step * 0.1,
          inner.bottom - inner.height * tall,
          step * 0.8,
          inner.height * tall,
        ),
        _p(colours[i % colours.length]),
      );
    }
    outline(r);
  }

  void tvUnit() {
    rrect(r, fill);
    rrect(part(0.1, 0.02, 0.8, 0.2), c.onAccent, corner: unit * 0.05);
    rrect(part(0.12, 0.05, 0.76, 0.1), c.sky.withValues(alpha: 0.6), corner: 1);
    for (final x in [0.25, 0.75]) {
      canvas.drawCircle(
        Offset(r.left + x * w, r.top + d * 0.65),
        math.max(1, unit * 0.06),
        _p(dark),
      );
    }
    outline(r);
  }

  void desk() {
    rrect(r, fill);
    rrect(part(0.32, 0.06, 0.36, 0.14), c.onAccent, corner: unit * 0.04);
    rrect(part(0.36, 0.42, 0.28, 0.2), lighter, corner: unit * 0.04);
    canvas.drawCircle(
      Offset(r.left + w * 0.84, r.top + d * 0.36),
      math.max(1.5, unit * 0.07),
      _p(c.coral),
    );
    outline(r);
  }

  void diningTable() {
    rrect(r, fill, corner: unit * 0.16);
    rrect(r.deflate(unit * 0.08), light, corner: unit * 0.12);
    final mats = w >= d
        ? [(0.25, 0.3), (0.75, 0.3), (0.25, 0.7), (0.75, 0.7)]
        : [(0.3, 0.25), (0.7, 0.25), (0.3, 0.75), (0.7, 0.75)];
    for (final (x, y) in mats) {
      canvas.drawCircle(
        Offset(r.left + x * w, r.top + y * d),
        unit * 0.14,
        _p(c.highlight),
      );
    }
    canvas.drawCircle(r.center, unit * 0.1, _p(c.primaryAction));
    outline(r, corner: unit * 0.16);
  }

  void coffeeTable() {
    rrect(r, fill, corner: unit * 0.3);
    rrect(r.deflate(unit * 0.1), light, corner: unit * 0.24);
    rrect(part(0.18, 0.28, 0.24, 0.44), c.sky, corner: unit * 0.04);
    canvas.drawCircle(
      Offset(r.left + w * 0.7, r.center.dy),
      unit * 0.13,
      _p(c.highlight),
    );
    outline(r, corner: unit * 0.3);
  }

  void rug() {
    rrect(r, fill.withValues(alpha: 0.85), corner: unit * 0.05);
    final ring = Paint()
      ..color = _a(c.highlight.withValues(alpha: 0.7))
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, unit * 0.025);
    canvas
      ..drawRRect(RRect.fromRectAndRadius(r.deflate(unit * 0.08), radius), ring)
      ..drawRRect(
        RRect.fromRectAndRadius(r.deflate(unit * 0.18), radius),
        ring,
      );
    final diamond = Path()
      ..moveTo(r.center.dx, r.center.dy - unit * 0.14)
      ..lineTo(r.center.dx + unit * 0.14, r.center.dy)
      ..lineTo(r.center.dx, r.center.dy + unit * 0.14)
      ..lineTo(r.center.dx - unit * 0.14, r.center.dy)
      ..close();
    canvas.drawPath(diamond, _p(c.highlight.withValues(alpha: 0.7)));
  }

  void plant() {
    final o = r.center;
    final pot = unit * 0.3;
    canvas.drawCircle(o, pot, _p(fill));
    final leafColours = [
      c.primaryAction,
      c.primary,
      Color.lerp(c.primary, c.highlight, 0.2)!,
    ];
    for (var i = 0; i < 7; i++) {
      final a = i * 2 * math.pi / 7 - math.pi / 2;
      final at = o + Offset(math.cos(a), math.sin(a)) * unit * 0.24;
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: unit * 0.42,
          height: unit * 0.22,
        ),
        _p(leafColours[i % leafColours.length]),
      );
      canvas.restore();
    }
    canvas.drawCircle(o, unit * 0.12, _p(c.primaryAction));
  }

  void lamp() {
    final o = r.center;
    canvas
      ..drawCircle(o, unit * 0.62, _p(c.sunflower.withValues(alpha: 0.25)))
      ..drawCircle(o, unit * 0.5, _p(c.lampShade))
      ..drawCircle(
        o,
        unit * 0.5,
        Paint()
          ..color = _a(darker)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, unit * 0.03),
      )
      ..drawCircle(o, unit * 0.16, _p(c.sunflower));
  }
}
