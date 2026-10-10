import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/domain/checks/snapping.dart';
import 'package:roomcraft/domain/geometry/rect2.dart';
import 'package:roomcraft/domain/geometry/vec2.dart';
import 'package:roomcraft/domain/scene/rooms.dart';

final room = RoomShapes.rectangle(4, 3);

SnapResult snap(
  Vec2 raw,
  double w, {
  List<Rect2> others = const [],
  double d = 0.5,
}) => Snapper.snap(raw: raw, width: w, depth: d, corners: room, others: others);

void main() {
  test('rounds the centre to 5 cm', () {
    final r = snap(const Vec2(1.512, 1.488), 0.5);
    expect(r.position, const Vec2(1.5, 1.5));
    expect(r.guides, isEmpty);
  });

  test('pulls to a wall at 0.09 m but not at 0.11 m', () {
    expect(snap(const Vec2(0.35, 1.5), 0.52).position.x, closeTo(0.26, 1e-9));
    expect(snap(const Vec2(0.35, 1.5), 0.48).position.x, closeTo(0.35, 1e-9));
  });

  test('pulls to the far wall too', () {
    // Right wall at x = 4; item edge at 3.91.
    expect(snap(const Vec2(3.65, 1.5), 0.52).position.x, closeTo(3.74, 1e-9));
  });

  test("aligns to another item's edge with a guide", () {
    final r = snap(
      const Vec2(2.25, 2.0),
      0.5,
      others: [const Rect2(2.02, 0.5, 2.52, 1.0)],
    );
    expect(r.position.x, closeTo(2.27, 1e-9));
    expect(r.guides.single.axis, GuideAxis.x);
  });

  test("aligns to another item's centre line", () {
    final r = snap(
      const Vec2(2.25, 2.0),
      0.5,
      others: [const Rect2(2.12, 0.5, 2.42, 1.0)],
    );
    expect(r.position.x, closeTo(2.27, 1e-9));
    expect(r.guides.single.value, closeTo(2.27, 1e-9));
  });

  test('wall pull wins over alignment', () {
    final r = snap(
      const Vec2(0.35, 1.5),
      0.52,
      others: [const Rect2(0.07, 0.2, 0.5, 0.6)],
    );
    expect(r.position.x, closeTo(0.26, 1e-9));
    expect(r.guides.where((g) => g.axis == GuideAxis.x), isEmpty);
  });

  test('the key changes when the snap target changes', () {
    final a = snap(const Vec2(1.5, 1.5), 0.5);
    final b = snap(const Vec2(1.5, 1.5), 0.5);
    final c = snap(const Vec2(1.6, 1.5), 0.5);
    expect(a.key, b.key);
    expect(a.key, isNot(c.key));
  });
}
