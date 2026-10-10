import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/domain/scene/scene.dart';
import 'package:roomcraft/domain/scene/scene_json.dart';

import 'fixtures.dart';

ProjectFile project({bool transient = false}) => ProjectFile(
  id: '6f1c2c1e-6c3a-4a7e-9d6b-1d3f0c2a9b11',
  name: 'Bedroom',
  updatedAt: DateTime.utc(2026, 10, 9, 8, 30),
  displayUnit: 'm',
  scene: bedroom(
    items: [
      item('item_bed', 'bed', 2.1, 1.5, rotation: 90, locked: true),
      item('item_rug', 'rug', 1.0, 1.0),
      if (transient) item('item_tmp', 'chair', 3, 3, transient: true),
    ],
  ),
);

void main() {
  test('round trip is identical', () {
    final original = project();
    final text = jsonEncode(original.toJson());
    final back = ProjectFile.fromJson(jsonDecode(text) as Map<String, Object?>);
    expect(back.scene, original.scene);
    expect(back.name, original.name);
    expect(back.updatedAt, original.updatedAt);
    expect(jsonEncode(back.toJson()), text);
  });

  test('creation order survives a round trip', () {
    final original = project();
    final back = ProjectFile.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
    );
    expect(back.scene.nodes.keys.toList(), original.scene.nodes.keys.toList());
  });

  test('a file with format 2 is refused', () {
    final json = project().toJson()..['format'] = 2;
    expect(
      () => ProjectFile.fromJson(json),
      throwsA(isA<SceneFormatException>()),
    );
  });

  test('transient nodes are not written', () {
    final text = jsonEncode(project(transient: true).toJson());
    expect(text, isNot(contains('item_tmp')));
  });

  test('the example from the planning documents parses', () {
    const example = '''
{"format":1,"id":"6f1c2c1e-6c3a-4a7e-9d6b-1d3f0c2a9b11","name":"Bedroom",
 "updatedAt":"2026-10-09T08:30:00Z","displayUnit":"m","rootId":"room_k3m9x2ab",
 "nodes":{
  "room_k3m9x2ab":{"id":"room_k3m9x2ab","type":"room","parentId":null,"visible":true,
    "corners":[[0,0],[4.2,0],[4.2,3.6],[0,3.6]],"wallHeight":2.6,
    "floorFinish":"oak","wallFinish":"warm_white","name":"Bedroom"},
  "opening_q8d1zz07":{"id":"opening_q8d1zz07","type":"opening","parentId":"room_k3m9x2ab","visible":true,
    "kind":"door","wallIndex":3,"offset":0.9,"width":0.9,"height":2.1,"sillHeight":0},
  "item_b7w2n4cd":{"id":"item_b7w2n4cd","type":"item","parentId":"room_k3m9x2ab","visible":true,
    "catalogueId":"bed","x":2.1,"z":1.5,"rotation":0,"finish":"beige_linen","locked":false}}}''';
    final p = ProjectFile.fromJson(jsonDecode(example) as Map<String, Object?>);
    expect(p.scene.items.single.catalogueId, 'bed');
    expect(p.scene.doors.single.offset, 0.9);
  });

  test('lighting survives a round trip; old or unknown values fall back', () {
    Scene trip(String text) =>
        SceneJson.decode(jsonDecode(text) as Map<String, Object?>);
    final lit = bedroom().withNode(bedroom().room.copyWith(lighting: 'golden'));
    final text = jsonEncode(SceneJson.encode(lit));
    expect(trip(text).room.lighting, 'golden');
    expect(
      trip(text.replaceAll('"lighting":"golden",', '')).room.lighting,
      'day',
    );
    expect(trip(text.replaceAll('golden', 'disco')).room.lighting, 'day');
  });
}
