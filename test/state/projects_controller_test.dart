import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/core/time_ago.dart';
import 'package:roomcraft/data/local_projects.dart';
import 'package:roomcraft/domain/scene/scene_json.dart';
import 'package:roomcraft/state/projects_controller.dart';
import 'package:roomcraft/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fixtures.dart';

ProjectFile project(String id, String name, DateTime at) => ProjectFile(
  id: id,
  name: name,
  updatedAt: at,
  displayUnit: 'm',
  scene: bedroom(),
);

void main() {
  late Directory dir;
  late ProviderContainer container;
  late LocalProjectStore store;
  late SharedPreferences prefs;

  setUp(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dir = Directory.systemTemp.createTempSync('roomcraft');
    store = LocalProjectStore(dir);
    container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        preferencesProvider.overrideWithValue(prefs),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  Future<List<String>> names() async => (await container.read(
    projectsProvider.future,
  )).map((p) => p.name).toList();

  test('lists newest first, renames, duplicates', () async {
    await store.save(project('a', 'Old', DateTime.utc(2026)));
    await store.save(project('b', 'New', DateTime.utc(2026, 5)));
    expect(await names(), ['New', 'Old']);
    final c = container.read(projectsProvider.notifier);
    await c.rename('a', '  Study  ');
    expect((await names()).first, 'Study');
    expect((await store.load('a'))!.scene.room.name, 'Study');
    final copy = await c.duplicate('b');
    expect((await store.load(copy!))!.name, 'New copy');
  });

  test('delete hides at once, Undo restores, purge removes the file', () async {
    await store.save(project('a', 'Room', DateTime.utc(2026)));
    await names();
    final c = container.read(projectsProvider.notifier)..hide('a');
    expect(await names(), isEmpty);
    c.restore('a');
    expect(await names(), ['Room']);
    c.hide('a');
    await c.purge('a');
    expect(await store.load('a'), isNull);
  });

  test('time wording', () {
    final now = DateTime(2026, 10, 12, 15);
    expect(
      editedAgo(now.subtract(const Duration(seconds: 20)), now),
      'just now',
    );
    expect(
      editedAgo(now.subtract(const Duration(minutes: 5)), now),
      '5 min ago',
    );
    expect(editedAgo(now.subtract(const Duration(hours: 3)), now), '3 h ago');
    expect(editedAgo(DateTime(2026, 10, 11, 20), now), 'yesterday');
    expect(editedAgo(DateTime(2026, 10, 2, 9), now), '2 Oct');
  });
}
