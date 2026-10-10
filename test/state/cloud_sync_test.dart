import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/data/cloud_projects.dart';
import 'package:roomcraft/data/local_projects.dart';
import 'package:roomcraft/data/supabase_client.dart';
import 'package:roomcraft/domain/scene/scene_json.dart';
import 'package:roomcraft/state/cloud_sync.dart';
import 'package:roomcraft/state/connectivity_provider.dart';
import 'package:roomcraft/state/editor_controller.dart';
import 'package:roomcraft/state/projects_controller.dart';
import 'package:roomcraft/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fixtures.dart';

/// The cloud, kept in memory. [failing] makes every call throw.
class FakeCloud implements CloudStore {
  final rows = <String, ProjectFile>{};
  bool failing = false;
  int uploads = 0;

  void _check() {
    if (failing) throw const SocketException('offline');
  }

  @override
  Future<void> ensureSession() async => _check();

  @override
  Future<void> upsert(ProjectFile p) async {
    _check();
    uploads++;
    rows[p.id] = p;
  }

  @override
  Future<List<CloudRow>> list() async {
    _check();
    return [for (final p in rows.values) CloudRow(p.id, p.name, p.updatedAt)];
  }

  @override
  Future<ProjectFile?> fetch(String id) async {
    _check();
    return rows[id];
  }

  @override
  Future<DateTime?> updatedAt(String id) async {
    _check();
    return rows[id]?.updatedAt;
  }

  @override
  Future<void> delete(String id) async {
    _check();
    rows.remove(id);
  }
}

class Online extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool v) => state = v;
}

final onlineSwitch = NotifierProvider<Online, bool>(Online.new);

ProjectFile project(String id, DateTime at, {String name = 'Room'}) =>
    ProjectFile(
      id: id,
      name: name,
      updatedAt: at,
      displayUnit: 'm',
      scene: bedroom(items: [item('item_a', 'chair', 1, 1)]),
    );

/// Waits for background sync work, up to three seconds.
Future<void> eventually(bool Function() done) async {
  for (var i = 0; i < 300 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Directory dir;
  late LocalProjectStore store;
  late FakeCloud cloud;
  late ProviderContainer c;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('roomcraft');
    store = LocalProjectStore(dir);
    cloud = FakeCloud();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        cloudStoreProvider.overrideWithValue(cloud),
        preferencesProvider.overrideWithValue(prefs),
        isOnlineProvider.overrideWith((ref) => ref.watch(onlineSwitch)),
      ],
    );
    c.listen(cloudSyncProvider, (_, _) {});
  });
  tearDown(() {
    c.dispose();
    dir.deleteSync(recursive: true);
  });

  CloudSync sync() => c.read(cloudSyncProvider.notifier);

  test('an upload waits two seconds after the last change', () async {
    final p = project('p', DateTime.utc(2026));
    await store.save(p);
    sync().schedule(p);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    sync().schedule(p);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(cloud.uploads, 0);
    expect(c.read(cloudSyncProvider)['p'], SyncStatus.pending);
    await eventually(() => c.read(cloudSyncProvider)['p'] == SyncStatus.synced);
    expect(cloud.uploads, 1);
    expect(c.read(cloudSyncProvider)['p'], SyncStatus.synced);
  });

  test('offline work stays pending and syncs on reconnect', () async {
    final p = project('p', DateTime.utc(2026));
    await store.save(p);
    c.read(onlineSwitch.notifier).set(false);
    await sync().flushAll();
    sync().schedule(p);
    await sync().flushAll();
    expect(cloud.rows, isEmpty);
    expect(sync().pending, {'p'});
    c.read(onlineSwitch.notifier).set(true);
    await eventually(() => sync().pending.isEmpty);
    expect(cloud.rows.keys, ['p']);
    expect(sync().pending, isEmpty);
  });

  test('a failed upload is kept and retried', () async {
    final p = project('p', DateTime.utc(2026));
    await store.save(p);
    cloud.failing = true;
    sync().schedule(p);
    await sync().flushAll();
    expect(sync().pending, {'p'});
    cloud.failing = false;
    await sync().retry();
    expect(cloud.rows.containsKey('p'), isTrue);
  });

  test(
    'the merged list downloads newer cloud copies and uploads local-only rooms',
    () async {
      await store.save(project('mine', DateTime.utc(2026, 1)));
      await store.save(
        project('both', DateTime.utc(2026, 1), name: 'Old name'),
      );
      cloud.rows['both'] = project(
        'both',
        DateTime.utc(2026, 5),
        name: 'New name',
      );
      cloud.rows['remote'] = project(
        'remote',
        DateTime.utc(2026, 3),
        name: 'From cloud',
      );
      final list = await c.read(projectsProvider.future);
      expect(list.map((p) => p.name), ['New name', 'From cloud', 'Room']);
      expect((await store.load('remote'))!.name, 'From cloud');
      expect(sync().pending, {'mine'});
      await sync().flushAll();
      expect(cloud.rows.containsKey('mine'), isTrue);
      expect(c.read(cloudSyncProvider)['both'], SyncStatus.synced);
    },
  );

  test(
    'after the local file is lost, opening the room restores it from the cloud',
    () async {
      final p = project('p', DateTime.utc(2026));
      cloud.rows['p'] = p;
      c.listen(editorProvider('p'), (_, _) {});
      final state = await c.read(editorProvider('p').future);
      expect(state.scene, p.scene);
      expect(await store.load('p'), isNotNull);
    },
  );

  test(
    'deleting removes both copies, even if the cloud was unreachable at first',
    () async {
      final p = project('p', DateTime.utc(2026));
      await store.save(p);
      cloud.rows['p'] = p;
      await c.read(projectsProvider.future);
      cloud.failing = true;
      final projects = c.read(projectsProvider.notifier)..hide('p');
      await projects.purge('p');
      expect(await store.load('p'), isNull);
      expect(cloud.rows.containsKey('p'), isTrue);
      expect(sync().pendingDeletes, {'p'});
      cloud.failing = false;
      await sync().retry();
      expect(cloud.rows, isEmpty);
      // A later refresh does not bring it back.
      expect(
        await c
            .read(projectsProvider.notifier)
            .refresh()
            .then((_) => c.read(projectsProvider).value),
        isEmpty,
      );
    },
  );

  test('offline edits here and new edits in the cloud are merged', () async {
    final first = project('p', DateTime.utc(2026));
    await store.save(first);
    sync().schedule(first);
    await sync().flushAll();
    expect(cloud.rows['p'], isNotNull);

    // Offline here: the chair moves.
    c.read(onlineSwitch.notifier).set(false);
    final chair = first.scene.item('item_a')!;
    final mine = first.copyWith(
      updatedAt: DateTime.utc(2026, 1, 2),
      scene: first.scene.withNode(chair.copyWith(x: 2.0)),
    );
    await store.save(mine);
    sync().schedule(mine);
    await sync().flushAll();

    // Meanwhile another phone adds a plant and renames the room.
    cloud.rows['p'] = first.copyWith(
      name: 'Guest room',
      updatedAt: DateTime.utc(2026, 1, 3),
      scene: first.scene.withNode(item('item_pl', 'plant', 3.9, 3.3)),
    );

    final notices = <MergeNotice>[];
    sync().merges.listen(notices.add);
    c.read(onlineSwitch.notifier).set(true);
    await eventually(() => notices.isNotEmpty && sync().pending.isEmpty);

    final up = cloud.rows['p']!;
    expect(up.name, 'Guest room');
    expect(up.scene.item('item_a')!.x, 2.0);
    expect(up.scene.item('item_pl'), isNotNull);
    expect((await store.load('p'))!.scene, up.scene);
    expect(notices.single.conflicts, 0);
    expect(c.read(cloudSyncProvider)['p'], SyncStatus.synced);
  });

  test('when the cloud has not moved on, nothing is merged', () async {
    final first = project('p', DateTime.utc(2026));
    await store.save(first);
    sync().schedule(first);
    await sync().flushAll();
    final next = first.copyWith(name: 'Den', updatedAt: DateTime.utc(2026, 2));
    await store.save(next);
    final notices = <MergeNotice>[];
    sync().merges.listen(notices.add);
    sync().schedule(next);
    await sync().flushAll();
    await Future<void>.delayed(Duration.zero);
    expect(notices, isEmpty);
    expect(cloud.rows['p']!.name, 'Den');
  });
}
