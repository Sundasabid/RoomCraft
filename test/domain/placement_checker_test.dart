import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/domain/checks/placement_checker.dart';
import 'package:roomcraft/domain/geometry/rect2.dart';

import 'fixtures.dart';

void main() {
  group('overlap', () {
    test('touching edges are not an overlap', () {
      expect(
        rectsOverlap(const Rect2(0, 0, 1, 1), const Rect2(1, 0, 2, 1)),
        isFalse,
      );
    });

    test('a 1 cm overlap is an overlap', () {
      expect(
        rectsOverlap(const Rect2(0, 0, 1, 1), const Rect2(0.99, 0, 2, 1)),
        isTrue,
      );
    });

    test('rotation 90 swaps width and depth', () {
      final sofa = item('item_a', 'sofa', 2, 2, rotation: 90);
      final r = footprintOf(sofa);
      expect(r.width, closeTo(0.9, 1e-9));
      expect(r.depth, closeTo(2.0, 1e-9));
      expect(
        footprintOf(item('item_b', 'sofa', 2, 2, rotation: 270)).width,
        closeTo(0.9, 1e-9),
      );
    });

    test('a rug never overlaps', () {
      final scene = bedroom(
        items: [
          item('item_rug', 'rug', 2.5, 1.5),
          item('item_tbl', 'coffee_table', 2.5, 1.5),
        ],
      );
      expect(PlacementChecker.checkScene(scene).isValid, isTrue);
    });

    test('two items overlapping are both flagged with the right message', () {
      final scene = bedroom(
        items: [
          item('item_bed', 'bed', 2.9, 1.1),
          item('item_war', 'wardrobe', 2.9, 1.5),
        ],
      );
      final report = PlacementChecker.checkScene(scene);
      expect(report.flagged, {'item_bed', 'item_war'});
      expect(report.violations.single.message, 'Bed overlaps Wardrobe');
      expect(report.headline, 'Bed overlaps Wardrobe');
    });

    test('repeated types are numbered in creation order', () {
      final scene = bedroom(
        items: [
          item('item_c1', 'chair', 2.0, 1.0),
          item('item_c2', 'chair', 2.2, 1.0),
        ],
      );
      expect(
        PlacementChecker.checkScene(scene).violations.single.message,
        'Chair overlaps Chair 2',
      );
    });

    test('several violations read "and N more"', () {
      final scene = bedroom(
        items: [
          item('item_bed', 'bed', 2.9, 1.1),
          item('item_war', 'wardrobe', 2.9, 1.5),
          item('item_sof', 'sofa', 9, 9),
        ],
      );
      expect(
        PlacementChecker.checkScene(scene).headline,
        'Bed overlaps Wardrobe and 1 more',
      );
    });
  });

  group('inside the room', () {
    test('an item past a wall is outside, with the exact message', () {
      final scene = bedroom(items: [item('item_sof', 'sofa', 4.0, 1.5)]);
      final report = PlacementChecker.checkScene(scene);
      expect(report.violations.single.message, 'Sofa is outside the room');
    });

    test('an item flush against walls is inside', () {
      final scene = bedroom(items: [item('item_war', 'wardrobe', 0.6, 0.3)]);
      expect(PlacementChecker.checkScene(scene).isValid, isTrue);
    });

    test('an item in the missing corner of an L-shape is outside', () {
      // Notch spans x 3.5 to 5.5, z 3.0 to 4.5. The chair straddles its corner.
      final scene = lShapedStudio(items: [item('item_ch', 'chair', 3.6, 3.1)]);
      expect(PlacementChecker.checkScene(scene).flagged, {'item_ch'});
      final ok = lShapedStudio(items: [item('item_ch', 'chair', 3.2, 3.1)]);
      expect(PlacementChecker.checkScene(ok).isValid, isTrue);
    });
  });

  group('door keep-out', () {
    test('keep-out is door width by 0.9 m in front of the door', () {
      final zone = doorKeepOut(bedroom().room, leftDoor());
      expect(zone.minX, closeTo(0, 1e-9));
      expect(zone.maxX, closeTo(0.9, 1e-9));
      expect(zone.minZ, closeTo(2.25, 1e-9));
      expect(zone.maxZ, closeTo(3.15, 1e-9));
    });

    test('an item in the keep-out blocks the door, with the exact message', () {
      final scene = bedroom(
        items: [item('item_war', 'wardrobe', 0.6, 2.7, rotation: 90)],
      );
      final report = PlacementChecker.checkScene(scene);
      expect(report.violations.single.message, 'Wardrobe blocks the door');
    });

    test('an item just outside the keep-out does not block it', () {
      // Wardrobe rotated: 0.6 wide in x, starting exactly at x = 0.9.
      final scene = bedroom(
        items: [item('item_war', 'wardrobe', 1.2, 2.7, rotation: 90)],
      );
      expect(PlacementChecker.checkScene(scene).isValid, isTrue);
    });

    test('a rug may lie in the keep-out', () {
      final scene = bedroom(items: [item('item_rug', 'rug', 1.1, 2.7)]);
      expect(PlacementChecker.checkScene(scene).isValid, isTrue);
    });
  });
}
