import 'dart:math' as math;

import 'vec2.dart';

/// An axis-aligned rectangle on the plan.
class Rect2 {
  const Rect2(this.minX, this.minZ, this.maxX, this.maxZ);

  factory Rect2.centred(Vec2 c, double width, double depth) =>
      Rect2(c.x - width / 2, c.z - depth / 2, c.x + width / 2, c.z + depth / 2);

  factory Rect2.bounding(Iterable<Vec2> points) {
    var minX = double.infinity, minZ = double.infinity;
    var maxX = double.negativeInfinity, maxZ = double.negativeInfinity;
    for (final p in points) {
      minX = math.min(minX, p.x);
      minZ = math.min(minZ, p.z);
      maxX = math.max(maxX, p.x);
      maxZ = math.max(maxZ, p.z);
    }
    return Rect2(minX, minZ, maxX, maxZ);
  }

  final double minX;
  final double minZ;
  final double maxX;
  final double maxZ;

  double get width => maxX - minX;
  double get depth => maxZ - minZ;
  Vec2 get centre => Vec2((minX + maxX) / 2, (minZ + maxZ) / 2);

  List<Vec2> get corners => [
    Vec2(minX, minZ),
    Vec2(maxX, minZ),
    Vec2(maxX, maxZ),
    Vec2(minX, maxZ),
  ];

  Rect2 shift(Vec2 d) => Rect2(minX + d.x, minZ + d.z, maxX + d.x, maxZ + d.z);

  Rect2 inflate(double by) => Rect2(minX - by, minZ - by, maxX + by, maxZ + by);

  bool contains(Vec2 p) =>
      p.x >= minX && p.x <= maxX && p.z >= minZ && p.z <= maxZ;

  /// Distance from a point to the rectangle; 0 inside it.
  double distanceTo(Vec2 p) {
    final dx = math.max(math.max(minX - p.x, 0.0), p.x - maxX);
    final dz = math.max(math.max(minZ - p.z, 0.0), p.z - maxZ);
    return math.sqrt(dx * dx + dz * dz);
  }

  @override
  bool operator ==(Object other) =>
      other is Rect2 &&
      other.minX == minX &&
      other.minZ == minZ &&
      other.maxX == maxX &&
      other.maxZ == maxZ;

  @override
  int get hashCode => Object.hash(minX, minZ, maxX, maxZ);

  @override
  String toString() => 'Rect2($minX, $minZ, $maxX, $maxZ)';
}
