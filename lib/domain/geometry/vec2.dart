import 'dart:math' as math;

/// A point or direction on the floor plan: x to the right, z downward.
class Vec2 {
  const Vec2(this.x, this.z);

  static const zero = Vec2(0, 0);

  final double x;
  final double z;

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, z + o.z);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, z - o.z);
  Vec2 operator *(double s) => Vec2(x * s, z * s);
  Vec2 operator /(double s) => Vec2(x / s, z / s);

  double dot(Vec2 o) => x * o.x + z * o.z;
  double get length => math.sqrt(x * x + z * z);
  double distanceTo(Vec2 o) => (this - o).length;
  Vec2 get normalized => length == 0 ? this : this / length;

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.z == z;

  @override
  int get hashCode => Object.hash(x, z);

  @override
  String toString() => 'Vec2($x, $z)';
}
