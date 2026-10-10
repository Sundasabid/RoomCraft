import 'dart:math' as math;

import '../constants.dart';
import '../geometry/polygon.dart';
import '../geometry/rect2.dart';
import '../geometry/vec2.dart';
import '../scene/nodes.dart';
import '../scene/scene.dart';
import 'placement_checker.dart';

class MovementResult {
  const MovementResult({
    required this.score,
    required this.coverage,
    required this.comfort,
    required this.itemAccess,
    required this.doorLinks,
  });

  /// 0 to 100.
  final int score;
  final double coverage;
  final double comfort;
  final double itemAccess;
  final double doorLinks;
}

/// How freely someone can walk through the room from the main door.
///
/// score = round(100 * (0.40 coverage + 0.20 comfort + 0.20 itemAccess
///                      + 0.20 doorLinks))
abstract final class MovementScore {
  static MovementResult of(Scene scene) {
    final grid = _Grid(scene.corners);
    final obstacles = [
      for (final i in scene.items)
        if (i.visible && !isFloorOnly(i)) footprintOf(i),
    ];

    final clearance = grid.clearance(obstacles);
    final emptyClearance = grid.clearance(const []);
    final base60 = grid.countPassable(emptyClearance, walkerRadiusMin);
    final base90 = grid.countPassable(emptyClearance, walkerRadiusComfort);

    final doors = scene.doors.toList()..sort((a, b) => a.id.compareTo(b.id));
    final room = scene.room;

    Set<int> region(double r) {
      if (doors.isEmpty) return grid.largestRegion(clearance, r);
      final entry = grid.entryCell(room, doors.first, clearance, r);
      return entry == null ? <int>{} : grid.flood(entry, clearance, r);
    }

    final r60 = region(walkerRadiusMin);
    final r90 = region(walkerRadiusComfort);

    final coverage = _ratio(r60.length, base60);
    final comfort = _ratio(r90.length, base90);

    final reachable = <bool>[
      for (final rect in obstacles) grid.anyWithin(r60, rect, accessDistance),
    ];
    final itemAccess = obstacles.isEmpty
        ? 1.0
        : reachable.where((x) => x).length / obstacles.length;

    final doorLinks = doors.isEmpty
        ? 1.0
        : doors.where((d) {
                final e = grid.entryCell(room, d, clearance, walkerRadiusMin);
                return e != null && r60.contains(e);
              }).length /
              doors.length;

    final score =
        (100 *
                (0.40 * coverage +
                    0.20 * comfort +
                    0.20 * itemAccess +
                    0.20 * doorLinks))
            .round()
            .clamp(0, 100);
    return MovementResult(
      score: score,
      coverage: coverage,
      comfort: comfort,
      itemAccess: itemAccess,
      doorLinks: doorLinks,
    );
  }

  static double _ratio(int n, int base) =>
      base == 0 ? 0 : math.min(1, n / base);
}

/// SCORE_CELL grid over the room's bounding box. Cells are indexed row-major.
class _Grid {
  _Grid(this.corners) : bounds = Rect2.bounding(corners) {
    cols = math.max(1, (bounds.width / scoreCell).ceil());
    rows = math.max(1, (bounds.depth / scoreCell).ceil());
    inRoom = List.generate(
      cols * rows,
      (i) => Polygon.containsStrict(centre(i), corners),
    );
    wallDistance = List.generate(cols * rows, (i) {
      if (!inRoom[i]) return 0.0;
      final p = centre(i);
      var best = double.infinity;
      for (var e = 0; e < corners.length; e++) {
        best = math.min(
          best,
          Polygon.distanceToSegment(
            p,
            corners[e],
            corners[(e + 1) % corners.length],
          ),
        );
      }
      return best;
    });
  }

  final List<Vec2> corners;
  final Rect2 bounds;
  late final int cols;
  late final int rows;
  late final List<bool> inRoom;
  late final List<double> wallDistance;

  Vec2 centre(int i) => Vec2(
    bounds.minX + (i % cols + 0.5) * scoreCell,
    bounds.minZ + (i ~/ cols + 0.5) * scoreCell,
  );

  List<double> clearance(List<Rect2> obstacles) =>
      List.generate(cols * rows, (i) {
        if (!inRoom[i]) return 0.0;
        var c = wallDistance[i];
        final p = centre(i);
        for (final r in obstacles) {
          c = math.min(c, r.distanceTo(p));
          if (c == 0) break;
        }
        return c;
      });

  bool passable(int i, List<double> clearance, double r) =>
      inRoom[i] && clearance[i] >= r - 1e-9;

  int countPassable(List<double> clearance, double r) {
    var n = 0;
    for (var i = 0; i < clearance.length; i++) {
      if (passable(i, clearance, r)) n++;
    }
    return n;
  }

  /// 8-connected flood fill over passable cells.
  Set<int> flood(int start, List<double> clearance, double r) {
    final seen = <int>{start};
    final stack = <int>[start];
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final cx = i % cols, cz = i ~/ cols;
      for (var dz = -1; dz <= 1; dz++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dz == 0) continue;
          final nx = cx + dx, nz = cz + dz;
          if (nx < 0 || nz < 0 || nx >= cols || nz >= rows) continue;
          final j = nz * cols + nx;
          if (seen.contains(j) || !passable(j, clearance, r)) continue;
          seen.add(j);
          stack.add(j);
        }
      }
    }
    return seen;
  }

  Set<int> largestRegion(List<double> clearance, double r) {
    final visited = <int>{};
    var best = <int>{};
    for (var i = 0; i < clearance.length; i++) {
      if (visited.contains(i) || !passable(i, clearance, r)) continue;
      final region = flood(i, clearance, r);
      visited.addAll(region);
      if (region.length > best.length) best = region;
    }
    return best;
  }

  /// Nearest passable cell within DOOR_ENTRY_SEARCH of the point
  /// DOOR_ENTRY_DEPTH inside the room from the door's centre.
  int? entryCell(
    RoomNode room,
    OpeningNode door,
    List<double> clearance,
    double r,
  ) {
    final n = Polygon.inwardNormal(room.corners, door.wallIndex);
    final target = openingCentre(room, door) + n * doorEntryDepth;
    int? best;
    var bestDistance = double.infinity;
    for (var i = 0; i < clearance.length; i++) {
      if (!passable(i, clearance, r)) continue;
      final d = centre(i).distanceTo(target);
      if (d <= doorEntrySearch + 1e-9 && d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  bool anyWithin(Set<int> cells, Rect2 rect, double distance) {
    for (final i in cells) {
      if (rect.distanceTo(centre(i)) <= distance + 1e-9) return true;
    }
    return false;
  }
}
