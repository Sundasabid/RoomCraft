import 'dart:math';

final _random = Random.secure();
const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// A type prefix plus 8 random characters, for example `item_b7w2n4cd`.
String newNodeId(String prefix) =>
    '${prefix}_${List.generate(8, (_) => _chars[_random.nextInt(_chars.length)]).join()}';

/// Random version 4 UUID for project ids.
String newProjectId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
