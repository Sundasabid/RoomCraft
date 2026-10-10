import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../domain/geometry/polygon.dart';
import '../../../domain/scene/scene.dart';
import 'plan_transform.dart';

const wallThickness = 0.10;

/// Layer 3: walls as thick strokes broken around openings; doors as a leaf
/// with its swing, windows as a thin double line.
void paintWalls(
  Canvas canvas,
  PlanTransform t,
  Scene scene,
  RoomCraftColors colors, {
  int? highlightWall,
  String? activeOpening,
}) {
  final corners = scene.corners;
  final thick = math.max(wallThickness * t.scale, 3.0);
  final wall = Paint()
    ..color = colors.wallLine
    ..strokeWidth = thick
    ..strokeCap = StrokeCap.butt;
  final detail = Paint()
    ..color = Color.lerp(colors.wallLine, colors.primaryDark, 0.45)!
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, thick * 0.18);

  for (var i = 0; i < corners.length; i++) {
    final a = corners[i], b = corners[(i + 1) % corners.length];
    final len = a.distanceTo(b);
    final d = (b - a) / len;
    final n = Polygon.inwardNormal(corners, i);
    final onWall = scene.openings.where((o) => o.wallIndex == i).toList()
      ..sort((x, y) => x.offset.compareTo(y.offset));

    // Solid pieces between openings.
    var from = 0.0;
    for (final o in onWall) {
      final s = (o.offset - o.width / 2).clamp(0.0, len);
      if (s > from) {
        canvas.drawLine(t.toScreen(a + d * from), t.toScreen(a + d * s), wall);
      }
      from = math.max(from, (o.offset + o.width / 2).clamp(0.0, len));
    }
    if (from < len) {
      canvas.drawLine(t.toScreen(a + d * from), t.toScreen(b), wall);
    }

    if (highlightWall == i) {
      canvas.drawLine(
        t.toScreen(a),
        t.toScreen(b),
        Paint()
          ..color = colors.primary
          ..strokeWidth = thick + 3
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final o in onWall) {
      final s = a + d * (o.offset - o.width / 2);
      final e = a + d * (o.offset + o.width / 2);
      final active = o.id == activeOpening;
      final accent = active ? colors.primary : detail.color;
      if (o.isDoor) {
        // Leaf standing open into the room, and its swing.
        final leafEnd = s + n * o.width;
        canvas.drawLine(
          t.toScreen(s),
          t.toScreen(leafEnd),
          detail..color = accent,
        );
        final r = o.width * t.scale;
        final start = math.atan2(d.z, d.x);
        final sweep = math.atan2(n.z, n.x) - start;
        canvas.drawArc(
          Rect.fromCircle(center: t.toScreen(s), radius: r),
          start,
          (sweep + math.pi) % (2 * math.pi) - math.pi,
          false,
          Paint()
            ..color = accent.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      } else {
        final inset = n * (wallThickness * 0.28);
        canvas
          ..drawLine(
            t.toScreen(s),
            t.toScreen(e),
            Paint()
              ..color = colors.surface
              ..strokeWidth = thick,
          )
          ..drawLine(
            t.toScreen(s + inset),
            t.toScreen(e + inset),
            detail..color = accent,
          )
          ..drawLine(
            t.toScreen(s - inset),
            t.toScreen(e - inset),
            detail..color = accent,
          );
      }
      if (active) {
        canvas.drawCircle(
          t.toScreen(a + d * o.offset),
          7,
          Paint()..color = colors.primary,
        );
        canvas.drawCircle(
          t.toScreen(a + d * o.offset),
          3,
          Paint()..color = colors.surface,
        );
      }
    }
  }
  // Square the corners so wall pieces meet cleanly.
  for (final c in corners) {
    canvas.drawRect(
      Rect.fromCenter(center: t.toScreen(c), width: thick, height: thick),
      Paint()..color = colors.wallLine,
    );
  }
}
