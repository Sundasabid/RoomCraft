import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/domain/scene/nodes.dart';
import 'package:roomcraft/domain/scene/scene.dart';
import 'package:roomcraft/domain/sync/scene_merge.dart';

import 'fixtures.dart';

ItemNode _bed(Scene s) => s.item('item_bed')!;

void main() {
  final base = bedroom(
    items: [
      item('item_bed', 'bed', 2.9, 1.1),
      item('item_sof', 'sofa', 2.6, 3.1),
    ],
  );

  test('edits to different items both arrive', () {
    final local = base.withNode(_bed(base).copyWith(x: 3.0));
    final remote = base.withNode(
      base.item('item_sof')!.copyWith(finish: 'walnut'),
    );
    final m = SceneMerge.merge(base, local, remote);
    expect(m.conflicts, 0);
    expect(_bed(m.scene).x, 3.0);
    expect(m.scene.item('item_sof')!.finish, 'walnut');
  });

  test('different fields of one item merge without a conflict', () {
    final local = base.withNode(_bed(base).copyWith(rotation: 90));
    final remote = base.withNode(_bed(base).copyWith(finish: 'walnut'));
    final m = SceneMerge.merge(base, local, remote);
    expect(m.conflicts, 0);
    expect(_bed(m.scene).rotation, 90);
    expect(_bed(m.scene).finish, 'walnut');
  });

  test('a position is never mixed from two moves; this phone wins', () {
    final local = base.withNode(_bed(base).copyWith(x: 3.2));
    final remote = base.withNode(_bed(base).copyWith(z: 1.5));
    final m = SceneMerge.merge(base, local, remote);
    expect(m.conflicts, 1);
    expect((_bed(m.scene).x, _bed(m.scene).z), (3.2, 1.1));
  });

  test('additions on both sides are kept, deletions on one side apply', () {
    final local = base.withNode(item('item_pl', 'plant', 3.9, 3.3));
    final remote = base
        .without(['item_sof'])
        .withNode(item('item_chr', 'chair', 0.8, 0.6));
    final m = SceneMerge.merge(base, local, remote);
    expect(m.conflicts, 0);
    expect(m.scene.items.map((i) => i.id).toSet(), {
      'item_bed',
      'item_pl',
      'item_chr',
    });
  });

  test('an item deleted there but edited here is kept', () {
    final local = base.withNode(
      base.item('item_sof')!.copyWith(finish: 'walnut'),
    );
    final remote = base.without(['item_sof']);
    final m = SceneMerge.merge(base, local, remote);
    expect(m.conflicts, 1);
    expect(m.scene.item('item_sof')!.finish, 'walnut');
  });

  test('room settings merge like any node', () {
    final local = base.withNode(base.room.copyWith(floorFinish: 'walnut'));
    final remote = base.withNode(base.room.copyWith(lighting: 'evening'));
    final m = SceneMerge.merge(base, local, remote);
    expect(m.scene.room.floorFinish, 'walnut');
    expect(m.scene.room.lighting, 'evening');
  });

  test('identical changes are not conflicts; local order is kept', () {
    final moved = base.withNode(_bed(base).copyWith(x: 3.0));
    final m = SceneMerge.merge(base, moved, moved);
    expect(m.conflicts, 0);
    expect(m.scene, moved);
    expect(m.scene.nodes.keys.toList(), moved.nodes.keys.toList());
  });

  test('plain values such as the name merge three ways', () {
    expect(SceneMerge.mergeValue('A', 'A', 'B'), ('B', false));
    expect(SceneMerge.mergeValue('A', 'C', 'A'), ('C', false));
    expect(SceneMerge.mergeValue('A', 'C', 'B'), ('C', true));
  });
}
