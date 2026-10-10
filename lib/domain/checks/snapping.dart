import '../constants.dart';
import '../geometry/polygon.dart';
import '../geometry/rect2.dart';
import '../geometry/vec2.dart';

enum GuideAxis { x, z }

/// A line the 2D view draws while dragging: `x = value` or `z = value`.
class SnapGuide {
  const SnapGuide(this.axis, this.value);
  final GuideAxis axis;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is SnapGuide && other.axis == axis && other.value == value;

  @override
  int get hashCode => Object.hash(axis, value);
}

class SnapResult {
  const SnapResult(this.position, this.guides, this.key);

  final Vec2 position;
  final List<SnapGuide> guides;

  /// Changes whenever the snap target changes; drives the haptic click.
  final String key;
}

double _roundTo(double v, double step) => (v / step).roundToDouble() * step;
double _mm(double v) => (v * 1000).roundToDouble() / 1000;

abstract final class Snapper {
  /// Snaps a dragged item's centre. Order: grid, wall pull, alignment (only on
  /// an axis the wall did not take), then millimetre rounding.
  static SnapResult snap({
    required Vec2 raw,
    required double width,
    required double depth,
    required List<Vec2> corners,
    required List<Rect2> others,
  }) {
    final hw = width / 2, hd = depth / 2;
    var cx = _roundTo(raw.x, grid);
    var cz = _roundTo(raw.z, grid);

    double? wallX, wallZ;
    var bestX = double.infinity, bestZ = double.infinity;
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i], b = corners[(i + 1) % corners.length];
      final n = Polygon.inwardNormal(corners, i);
      if ((a.x - b.x).abs() < 1e-9) {
        // Vertical wall at x = a.x; the item must face it along z.
        final lo = a.z < b.z ? a.z : b.z, hi = a.z < b.z ? b.z : a.z;
        if (cz + hd <= lo + eps || cz - hd >= hi - eps) continue;
        if ((cx - a.x) * n.x <= 0) continue;
        final gap = n.x > 0 ? (cx - hw) - a.x : a.x - (cx + hw);
        if (gap.abs() <= wallSnap + 1e-9 && gap.abs() < bestX) {
          bestX = gap.abs();
          wallX = n.x > 0 ? a.x + hw : a.x - hw;
        }
      } else if ((a.z - b.z).abs() < 1e-9) {
        final lo = a.x < b.x ? a.x : b.x, hi = a.x < b.x ? b.x : a.x;
        if (cx + hw <= lo + eps || cx - hw >= hi - eps) continue;
        if ((cz - a.z) * n.z <= 0) continue;
        final gap = n.z > 0 ? (cz - hd) - a.z : a.z - (cz + hd);
        if (gap.abs() <= wallSnap + 1e-9 && gap.abs() < bestZ) {
          bestZ = gap.abs();
          wallZ = n.z > 0 ? a.z + hd : a.z - hd;
        }
      }
    }
    if (wallX != null) cx = wallX;
    if (wallZ != null) cz = wallZ;

    final guides = <SnapGuide>[];
    String? alignX, alignZ;
    if (wallX == null) {
      final hit = _align(
        [cx - hw, cx, cx + hw],
        [
          for (final r in others) ...[r.minX, r.centre.x, r.maxX],
        ],
      );
      if (hit != null) {
        cx += hit.$1;
        guides.add(SnapGuide(GuideAxis.x, _mm(hit.$2)));
        alignX = _mm(hit.$2).toString();
      }
    }
    if (wallZ == null) {
      final hit = _align(
        [cz - hd, cz, cz + hd],
        [
          for (final r in others) ...[r.minZ, r.centre.z, r.maxZ],
        ],
      );
      if (hit != null) {
        cz += hit.$1;
        guides.add(SnapGuide(GuideAxis.z, _mm(hit.$2)));
        alignZ = _mm(hit.$2).toString();
      }
    }

    final p = Vec2(_mm(cx), _mm(cz));
    final key = 'g${p.x},${p.z}|w$wallX,$wallZ|a$alignX,$alignZ';
    return SnapResult(p, guides, key);
  }

  /// Smallest shift (and the target line) that brings one of [mine] onto one
  /// of [theirs], if it is within ALIGN_SNAP.
  static (double, double)? _align(List<double> mine, List<double> theirs) {
    (double, double)? best;
    for (final m in mine) {
      for (final t in theirs) {
        final d = t - m;
        if (d.abs() <= alignSnap + 1e-9 &&
            (best == null || d.abs() < best.$1.abs())) {
          best = (d, t);
        }
      }
    }
    return best;
  }
}
