import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/domain/checks/movement_score.dart';
import 'package:roomcraft/domain/scene/nodes.dart';
import 'package:roomcraft/domain/scene/rooms.dart';
import 'package:roomcraft/domain/scene/scene.dart';

import 'fixtures.dart';

void main() {
  test('an empty room with a clear door scores 100', () {
    expect(MovementScore.of(bedroom()).score, 100);
  });

  test("an item blocking the door's entry gives 0 coverage", () {
    final blocked = bedroom(
      items: [item('item_tbl', 'dining_table', 0.8, 2.7)],
    );
    final r = MovementScore.of(blocked);
    expect(r.coverage, 0);
    expect(r.comfort, 0);
    expect(r.doorLinks, 0);
  });

  test('moving the blocker away raises the score', () {
    final blocked = bedroom(
      items: [item('item_tbl', 'dining_table', 0.8, 2.7)],
    );
    final clear = bedroom(items: [item('item_tbl', 'dining_table', 3.2, 0.6)]);
    expect(
      MovementScore.of(clear).score,
      greaterThan(MovementScore.of(blocked).score),
    );
  });

  test('the same scene always gives the same score', () {
    final scene = bedroom(
      items: [
        item('item_bed', 'bed', 2.9, 1.1),
        item('item_sof', 'sofa', 2.6, 3.1),
      ],
    );
    final a = MovementScore.of(scene).score;
    expect(MovementScore.of(scene).score, a);
    expect(a, inInclusiveRange(1, 99));
  });

  test('a room with no door still scores', () {
    final r = MovementScore.of(
      bedroom(door: false, items: [item('item_bed', 'bed', 2.9, 1.1)]),
    );
    expect(r.score, greaterThan(0));
    expect(r.doorLinks, 1);
  });

  test('a 12 by 12 m room scores quickly', () {
    final big = Scene(
      rootId: roomId,
      nodes: {
        roomId: RoomNode(id: roomId, corners: RoomShapes.rectangle(12, 12)),
        'opening_door0001': leftDoor(),
        'item_bed': item('item_bed', 'bed', 6, 6),
      },
    );
    final sw = Stopwatch()..start();
    MovementScore.of(big);
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });
}
