import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/data/local_projects.dart';
import 'package:roomcraft/domain/scene/scene_json.dart';

import '../domain/fixtures.dart';

ProjectFile project(String id, DateTime at, {String name = 'Room'}) =>
    ProjectFile(
      id: id,
      name: name,
      updatedAt: at,
      displayUnit: 'm',
      scene: bedroom(items: [item('item_a', 'chair', 1, 1)]),
    );

void main() {
  late Directory dir;
  late LocalProjectStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('roomcraft');
    store = LocalProjectStore(Directory('${dir.path}/projects'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('save then load gives back the exact project', () async {
    final p = project('p1', DateTime.utc(2026, 10, 9));
    await store.save(p);
    final back = await store.load('p1');
    expect(back!.scene, p.scene);
    expect(back.name, p.name);
    expect(
      Directory(
        '${dir.path}/projects',
      ).listSync().where((e) => e.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('list is newest first and skips broken files', () async {
    await store.save(project('old', DateTime.utc(2026, 1, 1)));
    await store.save(project('new', DateTime.utc(2026, 10, 9)));
    File('${dir.path}/projects/broken.json').writeAsStringSync('{nope');
    final ids = (await store.list()).map((p) => p.id);
    expect(ids, ['new', 'old']);
  });

  test('delete removes the file', () async {
    await store.save(project('p1', DateTime.utc(2026)));
    await store.delete('p1');
    expect(await store.load('p1'), isNull);
  });

  test('autosave writes only the newest version after the delay', () {
    fakeAsync((async) {
      final written = <String>[];
      final q = AutosaveQueue((p) async => written.add(p.name));
      q.schedule(project('p', DateTime.utc(2026), name: 'a'));
      q.schedule(project('p', DateTime.utc(2026), name: 'b'));
      async.elapse(const Duration(milliseconds: 200));
      expect(written, isEmpty);
      async.elapse(const Duration(milliseconds: 200));
      expect(written, ['b']);
    });
  });
}
