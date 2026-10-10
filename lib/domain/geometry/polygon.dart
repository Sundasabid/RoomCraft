import 'dart:math' as math;

import '../constants.dart';
import 'rect2.dart';
import 'vec2.dart';

/// Polygon helpers for room outlines (corners clockwise on the plan).
abstract final class Polygon {
  /// Distance from [p] to the segment [a]-[b].
  static double distanceToSegment(Vec2 p, Vec2 a, Vec2 b) {
    final ab = b - a;
    final len2 = ab.dot(ab);
    if (len2 == 0) return p.distanceTo(a);
    final t = ((p - a).dot(ab) / len2).clamp(0.0, 1.0);
    return p.distanceTo(a + ab * t);
  }

  static bool onBoundary(Vec2 p, List<Vec2> poly, {double tolerance = eps}) {
    for (var i = 0; i < poly.length; i++) {
      if (distanceToSegment(p, poly[i], poly[(i + 1) % poly.length]) <=
          tolerance) {
        return true;
      }
    }
    return false;
  }

  /// Ray casting; points on the boundary count as inside.
  static bool containsPoint(Vec2 p, List<Vec2> poly) {
    if (onBoundary(p, poly)) return true;
    return containsStrict(p, poly);
  }

  /// Ray casting with no boundary tolerance.
  static bool containsStrict(Vec2 p, List<Vec2> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.z > p.z) != (b.z > p.z)) {
        final xCross = (b.x - a.x) * (p.z - a.z) / (b.z - a.z) + a.x;
        if (p.x < xCross) inside = !inside;
      }
    }
    return inside;
  }

  /// Length of the part of segment [a]-[b] inside [r] (Liang-Barsky).
  static double clippedLength(Vec2 a, Vec2 b, Rect2 r) {
    final dx = b.x - a.x, dz = b.z - a.z;
    var t0 = 0.0, t1 = 1.0;
    final p = [-dx, dx, -dz, dz];
    final q = [a.x - r.minX, r.maxX - a.x, a.z - r.minZ, r.maxZ - a.z];
    for (var i = 0; i < 4; i++) {
      if (p[i] == 0) {
        if (q[i] < 0) return 0;
        continue;
      }
      final t = q[i] / p[i];
      if (p[i] < 0) {
        if (t > t1) return 0;
        if (t > t0) t0 = t;
      } else {
        if (t < t0) return 0;
        if (t < t1) t1 = t;
      }
    }
    return math.max(0, t1 - t0) * math.sqrt(dx * dx + dz * dz);
  }

  /// All four corners inside (or on the edge) and no wall edge crossing the
  /// interior. The second test catches the missing corner of an L-shape.
  static bool containsRect(Rect2 r, List<Vec2> poly) {
    for (final c in r.corners) {
      if (!containsPoint(c, poly)) return false;
    }
    final shrunk = r.inflate(-eps);
    if (shrunk.width <= 0 || shrunk.depth <= 0) return true;
    for (var i = 0; i < poly.length; i++) {
      if (clippedLength(poly[i], poly[(i + 1) % poly.length], shrunk) > 0) {
        return false;
      }
    }
    return true;
  }

  static double signedArea(List<Vec2> poly) {
    var sum = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      sum += a.x * b.z - b.x * a.z;
    }
    return sum / 2;
  }

  /// Area centroid; falls back to the vertex mean for degenerate outlines.
  static Vec2 centroid(List<Vec2> poly) {
    final area = signedArea(poly);
    if (area.abs() < 1e-12) {
      return poly.fold<Vec2>(Vec2.zero, (s, p) => s + p) /
          poly.length.toDouble();
    }
    var cx = 0.0, cz = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final cross = a.x * b.z - b.x * a.z;
      cx += (a.x + b.x) * cross;
      cz += (a.z + b.z) * cross;
    }
    return Vec2(cx / (6 * area), cz / (6 * area));
  }

  static double edgeLength(List<Vec2> poly, int i) =>
      poly[i].distanceTo(poly[(i + 1) % poly.length]);

  /// Inward normal of edge [i]: for direction (dx, dz) it is (-dz, dx).
  static Vec2 inwardNormal(List<Vec2> poly, int i) {
    final d = (poly[(i + 1) % poly.length] - poly[i]).normalized;
    return Vec2(-d.z, d.x);
  }
}
