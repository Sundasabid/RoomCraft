import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/domain/history/scene_history.dart';

import 'fixtures.dart';

void main() {
  test('holds at most 50 past steps', () {
    var h = SceneHistory(bedroom());
    for (var i = 1; i <= 60; i++) {
      h = h.commit(bedroom(items: [item('item_a', 'chair', 1 + i * 0.01, 1)]));
    }
    expect(h.past, hasLength(50));
  });

  test('undo and redo restore exact scenes', () {
    final a = bedroom();
    final b = bedroom(items: [item('item_a', 'chair', 1, 1)]);
    final c = bedroom(items: [item('item_a', 'chair', 2, 1)]);
    var h = SceneHistory(a).commit(b).commit(c);
    h = h.undo();
    expect(h.present, b);
    h = h.undo();
    expect(h.present, a);
    expect(h.canUndo, isFalse);
    h = h.redo().redo();
    expect(h.present, c);
    expect(h.canRedo, isFalse);
  });

  test('committing an equal scene is a no-op', () {
    final h = SceneHistory(bedroom());
    expect(identical(h.commit(bedroom()), h), isTrue);
  });

  test('a commit after undo clears redo', () {
    var h = SceneHistory(
      bedroom(),
    ).commit(bedroom(items: [item('item_a', 'chair', 1, 1)])).undo();
    h = h.commit(bedroom(items: [item('item_b', 'plant', 1, 1)]));
    expect(h.canRedo, isFalse);
  });

  test('transient nodes never appear', () {
    final withPreview = bedroom(
      items: [
        item('item_a', 'chair', 1, 1),
        item('item_p', 'chair', 2, 2, transient: true),
      ],
    );
    final h = SceneHistory(bedroom()).commit(withPreview);
    expect(h.present.nodes.containsKey('item_p'), isFalse);
    expect(h.undo().redo().present.nodes.containsKey('item_p'), isFalse);
  });
}
