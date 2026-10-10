import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/domain/checks/free_spot.dart';
import 'package:roomcraft/domain/checks/placement_checker.dart';
import 'package:roomcraft/domain/geometry/vec2.dart';
import 'package:roomcraft/domain/scene/nodes.dart';
import 'package:roomcraft/domain/scene/rooms.dart';
import 'package:roomcraft/domain/scene/scene.dart';

import 'fixtures.dart';

void main() {
  test('a new item in an empty room overlaps nothing', () {
    final scene = bedroom();
    final p = findFreeSpot(scene, 'bed');
    final placed = scene.withNode(item('item_new', 'bed', p.x, p.z));
    expect(PlacementChecker.checkScene(placed).isValid, isTrue);
  });

  test('a new item next to others starts clean', () {
    var scene = bedroom(items: [item('item_bed', 'bed', 3.3, 1.0)]);
    for (final id in ['sofa', 'wardrobe', 'desk', 'chair']) {
      final p = findFreeSpot(scene, id);
      scene = scene.withNode(item('item_$id', id, p.x, p.z));
      expect(PlacementChecker.checkScene(scene).isValid, isTrue, reason: id);
    }
  });

  test('in a full room the centroid is returned', () {
    final scene = Scene(
      rootId: roomId,
      nodes: {
        roomId: RoomNode(id: roomId, corners: RoomShapes.rectangle(2, 2)),
        'item_bed': item('item_bed', 'bed', 1, 1),
      },
    );
    expect(findFreeSpot(scene, 'wardrobe'), const Vec2(1, 1));
  });
}
