import '../../core/strings.dart';
import '../constants.dart';
import '../geometry/polygon.dart';
import '../geometry/rect2.dart';
import '../geometry/vec2.dart';
import '../scene/catalogue.dart';
import '../scene/nodes.dart';
import '../scene/scene.dart';

/// Footprint as an axis-aligned rectangle; width and depth swap at 90 and 270.
Rect2 footprintOf(ItemNode item) => footprintAt(item, item.position);

Rect2 footprintAt(ItemNode item, Vec2 centre) {
  final c = Catalogue.byId(item.catalogueId);
  final quarter = item.rotation % 180 != 0;
  return Rect2.centred(
    centre,
    quarter ? c.depth : c.width,
    quarter ? c.width : c.depth,
  );
}

bool isFloorOnly(ItemNode item) => Catalogue.byId(item.catalogueId).floorOnly;

/// Both axis overlaps must exceed EPS; touching edges do not count.
bool rectsOverlap(Rect2 a, Rect2 b) {
  final ox =
      (a.maxX < b.maxX ? a.maxX : b.maxX) - (a.minX > b.minX ? a.minX : b.minX);
  final oz =
      (a.maxZ < b.maxZ ? a.maxZ : b.maxZ) - (a.minZ > b.minZ ? a.minZ : b.minZ);
  return ox > eps && oz > eps;
}

bool rectInsidePolygon(Rect2 r, List<Vec2> corners) =>
    Polygon.containsRect(r, corners);

/// Centre of an opening on its wall.
Vec2 openingCentre(RoomNode room, OpeningNode o) {
  final a = room.corners[o.wallIndex];
  final b = room.corners[(o.wallIndex + 1) % room.corners.length];
  return a + (b - a).normalized * o.offset;
}

/// Door width by DOOR_KEEP_OUT_DEPTH, in front of the door, inside the room.
Rect2 doorKeepOut(RoomNode room, OpeningNode door) {
  final a = room.corners[door.wallIndex];
  final b = room.corners[(door.wallIndex + 1) % room.corners.length];
  final d = (b - a).normalized;
  final n = Vec2(-d.z, d.x);
  final p = a + d * door.offset;
  final s = p - d * (door.width / 2);
  final e = p + d * (door.width / 2);
  return Rect2.bounding([
    s,
    e,
    s + n * doorKeepOutDepth,
    e + n * doorKeepOutDepth,
  ]);
}

sealed class Violation {
  const Violation(this.message);

  /// Plain sentence for the banner, for example "Bed overlaps Wardrobe".
  final String message;

  List<String> get itemIds;
}

class OverlapViolation extends Violation {
  const OverlapViolation(this.a, this.b, super.message);
  final String a;
  final String b;
  @override
  List<String> get itemIds => [a, b];
}

class OutsideRoomViolation extends Violation {
  const OutsideRoomViolation(this.item, super.message);
  final String item;
  @override
  List<String> get itemIds => [item];
}

class BlocksDoorViolation extends Violation {
  const BlocksDoorViolation(this.item, this.door, super.message);
  final String item;
  final String door;
  @override
  List<String> get itemIds => [item];
}

class ValidationReport {
  const ValidationReport(this.violations, this.flagged);

  static const clean = ValidationReport([], {});

  final List<Violation> violations;

  /// Every item id painted terracotta in both views.
  final Set<String> flagged;

  bool get isValid => violations.isEmpty;

  /// "Bed overlaps Wardrobe", or "Bed overlaps Wardrobe and 2 more".
  String? get headline {
    if (violations.isEmpty) return null;
    final first = violations.first.message;
    return violations.length == 1
        ? first
        : S.andMore(first, violations.length - 1);
  }
}

abstract final class PlacementChecker {
  /// Checks the whole scene. [positions] overrides item centres (a drag in
  /// progress) without building a new scene.
  static ValidationReport checkScene(
    Scene scene, {
    Map<String, Vec2> positions = const {},
  }) {
    final room = scene.room;
    final items = scene.items.where((i) => i.visible).toList();
    final rects = [
      for (final i in items) footprintAt(i, positions[i.id] ?? i.position),
    ];
    final keepOuts = [for (final d in scene.doors) (d, doorKeepOut(room, d))];
    final violations = <Violation>[];
    final flagged = <String>{};
    final names = {for (final i in items) i.id: scene.displayName(i.id)};

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (!rectInsidePolygon(rects[i], room.corners)) {
        violations.add(
          OutsideRoomViolation(item.id, S.outside(names[item.id]!)),
        );
        flagged.add(item.id);
      }
      if (isFloorOnly(item)) continue;
      for (var j = i + 1; j < items.length; j++) {
        final other = items[j];
        if (isFloorOnly(other)) continue;
        if (rectsOverlap(rects[i], rects[j])) {
          violations.add(
            OverlapViolation(
              item.id,
              other.id,
              S.overlaps(names[item.id]!, names[other.id]!),
            ),
          );
          flagged
            ..add(item.id)
            ..add(other.id);
        }
      }
      for (final (door, zone) in keepOuts) {
        if (rectsOverlap(rects[i], zone)) {
          violations.add(
            BlocksDoorViolation(
              item.id,
              door.id,
              S.blocksDoor(names[item.id]!),
            ),
          );
          flagged.add(item.id);
        }
      }
    }
    return ValidationReport(
      List.unmodifiable(violations),
      Set.unmodifiable(flagged),
    );
  }

  /// Whether one footprint is a clean spot: inside, no overlap, no door
  /// blocked. Used by the free spot search.
  static bool isClearSpot(
    Scene scene,
    Rect2 rect, {
    required bool floorOnly,
    String? ignoreId,
  }) {
    if (!rectInsidePolygon(rect, scene.corners)) return false;
    if (floorOnly) return true;
    for (final other in scene.items) {
      if (other.id == ignoreId || !other.visible || isFloorOnly(other)) {
        continue;
      }
      if (rectsOverlap(rect, footprintOf(other))) return false;
    }
    for (final d in scene.doors) {
      if (rectsOverlap(rect, doorKeepOut(scene.room, d))) return false;
    }
    return true;
  }
}
