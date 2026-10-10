import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/domain/share/scene_diff.dart';
import 'package:roomcraft/domain/share/share_code.dart';

import 'fixtures.dart';

void main() {
  test('1000 generated codes all match the pattern and the alphabet', () {
    for (var i = 0; i < 1000; i++) {
      final code = newShareCode();
      expect(isShareCode(code), isTrue, reason: code);
      expect(usesShareAlphabet(code), isTrue);
      expect(code, isNot(matches(RegExp('[IO01]'))));
    }
  });

  test('typed codes are normalised and checked', () {
    expect(normaliseCode(' abc-d23 '), 'ABCD23');
    expect(usesShareAlphabet('ABC0D2'), isFalse);
  });

  test('the node diff produces the right upserts and removes', () {
    final before = bedroom(
      items: [item('item_a', 'chair', 1, 1), item('item_b', 'plant', 2, 2)],
    );
    final after = bedroom(
      items: [item('item_a', 'chair', 1.5, 1), item('item_c', 'desk', 3, 1)],
    );
    final diff = diffNodes(before.nodes, after.nodes);
    expect(
      diff.upserts.map((n) => n.id),
      unorderedEquals(['item_a', 'item_c']),
    );
    expect(diff.removes, ['item_b']);
    expect(diffNodes(after.nodes, after.nodes).isEmpty, isTrue);
  });
}
