import '../constants.dart';
import '../geometry/polygon.dart';
import '../geometry/vec2.dart';
import 'ids.dart';
import 'nodes.dart';
import 'scene.dart';

/// Room outlines, corners clockwise on the plan starting at (0, 0).
abstract final class RoomShapes {
  static List<Vec2> rectangle(double w, double l) => [
    Vec2.zero,
    Vec2(w, 0),
    Vec2(w, l),
    Vec2(0, l),
  ];

  /// A notch of [nw] by [nl] removed at the bottom right.
  static List<Vec2> lShape(double w, double l, double nw, double nl) => [
    Vec2.zero,
    Vec2(w, 0),
    Vec2(w, l - nl),
    Vec2(w - nw, l - nl),
    Vec2(w - nw, l),
    Vec2(0, l),
  ];
}

/// Opening placement rules shared by Setup and the Editor.
abstract final class OpeningRules {
  static double minWidth(OpeningKind k) =>
      k == OpeningKind.door ? minDoorWidth : minWindowWidth;

  static double maxWidth(OpeningKind k) =>
      k == OpeningKind.door ? maxDoorWidth : maxWindowWidth;

  /// Whether an opening of [width] fits on a wall of [wallLength] at all.
  static bool fits(double wallLength, double width) =>
      width + 2 * openingMargin <= wallLength + 1e-9;

  /// Clamps [offset] so the opening stays [openingMargin] from both wall ends
  /// and from the other openings on that wall. Returns null if no spot fits.
  static double? clampOffset({
    required Scene scene,
    required int wallIndex,
    required double width,
    required double offset,
    String? ignoreId,
  }) {
    final length = Polygon.edgeLength(scene.corners, wallIndex);
    if (!fits(length, width)) return null;
    final half = width / 2;
    // Free intervals for the centre, between the neighbours on this wall.
    final blocked = [
      for (final o in scene.openings)
        if (o.wallIndex == wallIndex && o.id != ignoreId)
          (
            o.offset - o.width / 2 - openingMargin - half,
            o.offset + o.width / 2 + openingMargin + half,
          ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final lo = openingMargin + half, hi = length - openingMargin - half;
    final free = <(double, double)>[];
    var start = lo;
    for (final (bLo, bHi) in blocked) {
      if (bLo > start) free.add((start, bLo < hi ? bLo : hi));
      if (bHi > start) start = bHi;
    }
    if (start <= hi) free.add((start, hi));
    double? best;
    var bestDist = double.infinity;
    for (final (a, b) in free) {
      if (b < a) continue;
      final c = offset.clamp(a, b);
      final d = (c - offset).abs();
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    return best;
  }

  static OpeningNode newOpening({
    required String roomId,
    required OpeningKind kind,
    required int wallIndex,
    required double offset,
  }) => OpeningNode(
    id: newNodeId('opening'),
    parentId: roomId,
    kind: kind,
    wallIndex: wallIndex,
    offset: offset,
    width: kind == OpeningKind.door ? doorWidth : windowWidth,
    height: kind == OpeningKind.door ? doorHeight : windowHeight,
    sillHeight: kind == OpeningKind.door ? 0 : windowSill,
  );
}
