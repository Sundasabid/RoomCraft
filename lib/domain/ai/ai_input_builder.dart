import '../checks/placement_checker.dart';
import '../geometry/rect2.dart';
import '../scene/catalogue.dart';
import '../scene/scene.dart';

/// The room as the AI sees it, and the same facts as a short summary.
class AiInput {
  const AiInput(this.json, this.summary);

  final Map<String, Object?> json;
  final RoomSummary summary;
}

/// What the "What I understood" card shows.
class RoomSummary {
  const RoomSummary({
    required this.width,
    required this.length,
    required this.doors,
    required this.windows,
    required this.items,
    required this.locked,
  });

  final double width;
  final double length;
  final int doors;
  final int windows;
  final int items;
  final int locked;
}

abstract final class AiInputBuilder {
  static double _r(double v) => (v * 1000).roundToDouble() / 1000;

  static AiInput build(Scene scene) {
    final room = scene.room;
    final bounds = Rect2.bounding(room.corners);
    final items = scene.items.where((i) => i.visible).toList();
    final json = <String, Object?>{
      'room': {
        'corners': [
          for (final c in room.corners) [_r(c.x), _r(c.z)],
        ],
        'wallHeight': room.wallHeight,
        'bounds': _rect(bounds),
      },
      'doors': [
        for (final d in scene.doors)
          {
            'id': d.id,
            'centre': _point(
              openingCentre(room, d).x,
              openingCentre(room, d).z,
            ),
            'width': d.width,
            'keepOut': _rect(doorKeepOut(room, d)),
          },
      ],
      'windows': [
        for (final w in scene.windows)
          {
            'id': w.id,
            'centre': _point(
              openingCentre(room, w).x,
              openingCentre(room, w).z,
            ),
            'width': w.width,
          },
      ],
      'items': [
        for (final i in items)
          {
            'id': i.id,
            'type': i.catalogueId,
            'width': Catalogue.byId(i.catalogueId).width,
            'depth': Catalogue.byId(i.catalogueId).depth,
            'x': _r(i.x),
            'z': _r(i.z),
            'rotation': i.rotation,
            'locked': i.locked,
            'floorOnly': isFloorOnly(i),
            'rect': _rect(footprintOf(i)),
          },
      ],
    };
    return AiInput(
      json,
      RoomSummary(
        width: bounds.width,
        length: bounds.depth,
        doors: scene.doors.length,
        windows: scene.windows.length,
        items: items.length,
        locked: items.where((i) => i.locked).length,
      ),
    );
  }

  static List<double> _point(double x, double z) => [_r(x), _r(z)];

  static Map<String, double> _rect(Rect2 r) => {
    'minX': _r(r.minX),
    'minZ': _r(r.minZ),
    'maxX': _r(r.maxX),
    'maxZ': _r(r.maxZ),
  };
}
