import '../constants.dart';
import '../geometry/polygon.dart';
import '../geometry/rect2.dart';
import '../geometry/vec2.dart';
import '../scene/catalogue.dart';
import '../scene/scene.dart';
import 'placement_checker.dart';

/// Nearest spot to the room's centroid where a new item starts clean: inside,
/// overlapping nothing and clear of every door. Falls back to the centroid.
/// With [near], the search is ordered by distance to that point instead.
Vec2 findFreeSpot(
  Scene scene,
  String catalogueId, {
  int rotation = 0,
  Vec2? near,
}) {
  final c = Catalogue.byId(catalogueId);
  final quarter = rotation % 180 != 0;
  final w = quarter ? c.depth : c.width;
  final d = quarter ? c.width : c.depth;
  final corners = scene.corners;
  final centroid = Polygon.centroid(corners);
  final target = near ?? centroid;
  final bounds = Rect2.bounding(corners);

  final candidates = <Vec2>[];
  for (
    var x = bounds.minX + w / 2;
    x <= bounds.maxX - w / 2 + 1e-9;
    x += freeSpotStep
  ) {
    for (
      var z = bounds.minZ + d / 2;
      z <= bounds.maxZ - d / 2 + 1e-9;
      z += freeSpotStep
    ) {
      candidates.add(Vec2(_snap(x), _snap(z)));
    }
  }
  candidates.sort((a, b) {
    final byDistance = a.distanceTo(target).compareTo(b.distanceTo(target));
    if (byDistance != 0) return byDistance;
    final byZ = a.z.compareTo(b.z);
    return byZ != 0 ? byZ : a.x.compareTo(b.x);
  });
  for (final p in candidates) {
    if (PlacementChecker.isClearSpot(
      scene,
      Rect2.centred(p, w, d),
      floorOnly: c.floorOnly,
    )) {
      return p;
    }
  }
  return Vec2(_snap(centroid.x), _snap(centroid.z));
}

/// Keeps starting spots on the 5 cm grid so the first drag does not jump.
double _snap(double v) =>
    ((v / grid).roundToDouble() * grid * 1000).roundToDouble() / 1000;
