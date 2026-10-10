import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/geometry/rect2.dart';
import '../../../domain/geometry/vec2.dart';

/// Maps plan metres to screen pixels: screen = offset + scale * plan.
class PlanTransform {
  const PlanTransform(this.scale, this.offset);

  /// Fits [bounds] into [size] with [padding] on every side, then applies a
  /// user zoom (1 to 4 times) and pan.
  factory PlanTransform.fit(
    Rect2 bounds,
    Size size, {
    double padding = 24,
    double zoom = 1,
    Offset pan = Offset.zero,
  }) {
    final w = math.max(size.width - 2 * padding, 1.0);
    final h = math.max(size.height - 2 * padding, 1.0);
    final fitted = math.min(
      w / math.max(bounds.width, 0.01),
      h / math.max(bounds.depth, 0.01),
    );
    final s = fitted * zoom;
    final centre = Offset(size.width / 2, size.height / 2) + pan;
    final c = bounds.centre;
    return PlanTransform(s, centre - Offset(c.x * s, c.z * s));
  }

  final double scale;
  final Offset offset;

  Offset toScreen(Vec2 p) =>
      Offset(offset.dx + p.x * scale, offset.dy + p.z * scale);

  Vec2 toPlan(Offset s) =>
      Vec2((s.dx - offset.dx) / scale, (s.dy - offset.dy) / scale);

  Rect rect(Rect2 r) => Rect.fromLTRB(
    offset.dx + r.minX * scale,
    offset.dy + r.minZ * scale,
    offset.dx + r.maxX * scale,
    offset.dy + r.maxZ * scale,
  );
}
