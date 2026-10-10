import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/data/local_projects.dart';
import 'package:roomcraft/domain/checks/layout_validator.dart';
import 'package:roomcraft/domain/constants.dart';
import 'package:roomcraft/domain/geometry/vec2.dart';
import 'package:roomcraft/domain/scene/nodes.dart';
import 'package:roomcraft/domain/scene/scene_json.dart';
import 'package:roomcraft/state/cloud_sync.dart';
import 'package:roomcraft/state/editor_controller.dart';
import 'package:roomcraft/state/editor_state.dart';
import 'package:roomcraft/state/projects_controller.dart';
import 'package:roomcraft/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fixtures.dart';

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
    await store.save(
      ProjectFile(
        id: 'p',
        name: 'Bedroom',
        updatedAt: DateTime.utc(2026),
        displayUnit: 'm',
        scene: bedroom(),
      ),
    );
    container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        preferencesProvider.overrideWithValue(prefs),
      ],
    );
    container.listen(editorProvider('p'), (_, _) {});
    await container.read(editorProvider('p').future);
  });
  tearDown(() async {
    await container.read(editorProvider('p').notifier).flush();
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  EditorController c() => container.read(editorProvider('p').notifier);
  EditorState s() => container.read(editorProvider('p')).value!;

  test('adding an item lands clean, selected, and is one undo step', () {
    expect(c().addItem('bed'), isTrue);
    expect(s().scene.items, hasLength(1));
    expect(s().selection, s().scene.items.single.id);
    expect(s().report.isValid, isTrue);
    c().undo();
    expect(s().scene.items, isEmpty);
    expect(s().selection, isNull);
    c().redo();
    expect(s().scene.items, hasLength(1));
  });

  test('one drag is one undo step and no history until the drop', () {
    c().addItem('chair');
    final id = s().selection!;
    final start = s().scene.item(id)!.position;
    final pastBefore = s().history.past.length;
    c().beginDrag(id, start);
    for (var i = 1; i <= 10; i++) {
      c().dragTo(start + Vec2(i * 0.05, 0));
    }
    expect(s().history.past.length, pastBefore);
    expect(s().scene.item(id)!.position, start);
    expect(s().displayScene.item(id)!.x, closeTo(start.x + 0.5, 1e-9));
    c().endDrag();
    expect(s().history.past.length, pastBefore + 1);
    expect(s().scene.item(id)!.x, closeTo(start.x + 0.5, 1e-9));
    c().undo();
    expect(s().scene.item(id)!.position, start);
  });

  test('a drag into another item flags both until moved apart', () {
    c().addItem('bed');
    final bed = s().selection!;
    c().addItem('wardrobe');
    final war = s().selection!;
    final bedPos = s().scene.item(bed)!.position;
    final warPos = s().scene.item(war)!.position;
    c().beginDrag(war, warPos);
    c().dragTo(bedPos);
    expect(s().report.flagged, containsAll([bed, war]));
    c().endDrag();
    expect(s().report.headline, contains('overlaps'));
    c().undo();
    expect(s().report.isValid, isTrue);
  });

  test('cancelled drag leaves the item where it was', () {
    c().addItem('desk');
    final id = s().selection!;
    final start = s().scene.item(id)!.position;
    c().beginDrag(id, start);
    c().dragTo(start + const Vec2(1, 0));
    c().cancelDrag();
    expect(s().displayScene.item(id)!.position, start);
    expect(s().drag, isNull);
  });

  test('rotate, lock, finish, copy and delete', () {
    c().addItem('sofa');
    final id = s().selection!;
    c().rotateSelected();
    expect(s().scene.item(id)!.rotation, 90);
    c().toggleLockSelected();
    expect(s().scene.item(id)!.locked, isTrue);
    c().setItemFinish('walnut');
    expect(s().scene.item(id)!.finish, 'walnut');
    expect(c().duplicateSelected(), isTrue);
    final copy = s().scene.item(s().selection!)!;
    expect(copy.id, isNot(id));
    expect(copy.rotation, 90);
    expect(s().report.isValid, isTrue);
    expect(c().deleteSelected(), isA<ItemNode>());
    expect(s().scene.items, hasLength(1));
  });

  test('floor and wall finishes are one step each', () {
    c().setFloorFinish('walnut');
    c().setWallFinish('sage_wall');
    expect(s().scene.room.floorFinish, 'walnut');
    c().undo();
    expect(s().scene.room.wallFinish, 'warm_white');
    expect(s().scene.room.floorFinish, 'walnut');
  });

  test('a door dragged along its wall stays inside the wall rules', () {
    const doorId = 'opening_door0001';
    final door = s().scene.opening(doorId)!;
    c().beginDrag(doorId, const Vec2(0, 2.7));
    c().dragTo(const Vec2(0, -5));
    c().endDrag();
    final moved = s().scene.opening(doorId)!;
    expect(moved.offset, closeTo(3.6 - 0.1 - door.width / 2, 1e-9));
  });

  test('the 40 item limit holds', () {
    for (var i = 0; i < maxItems; i++) {
      expect(c().addItem('plant'), isTrue);
    }
    expect(c().addItem('plant'), isFalse);
    expect(s().scene.items, hasLength(maxItems));
  });

  test('changes are saved and reopen identically', () async {
    c().addItem('bed');
    c().rotateSelected();
    await c().flush();
    final back = await store.load('p');
    expect(back!.scene, s().scene);
  });

  group('AI draft', () {
    LayoutOption optionMoving(String id, double x, double z) {
      final scene = s().scene;
      final moved = scene.withNode(scene.item(id)!.copyWith(x: x, z: z));
      return LayoutOption(
        name: 'Open floor',
        reason: 'More room.',
        scene: moved,
        score: 90,
        moved: 1,
      );
    }

    test(
      'nothing changes until Apply; Apply is one undo step and Undo restores exactly',
      () {
        c().addItem('chair');
        final id = s().selection!;
        final before = s().scene;
        final past = s().history.past.length;
        c().openDraft(optionMoving(id, 3.5, 0.5), 'Option A', 70);
        expect(s().scene, before);
        expect(s().displayScene.item(id)!.x, 3.5);
        expect(s().canUndo, isFalse);
        // Editing inside the draft never touches the room or its history.
        c().select(id);
        c().rotateSelected();
        expect(s().draft!.scene.item(id)!.rotation, 90);
        expect(s().scene, before);
        expect(s().history.past.length, past);
        final applied = c().applyDraft();
        expect(applied!.label, 'Option A');
        expect(s().draft, isNull);
        expect(s().history.past.length, past + 1);
        expect(s().scene.item(id)!.x, 3.5);
        c().undo();
        expect(s().scene, before);
      },
    );

    test('an invalid draft can never be applied', () {
      c().addItem('bed');
      final bed = s().selection!;
      c().addItem('wardrobe');
      final war = s().selection!;
      final at = s().scene.item(bed)!.position;
      c().openDraft(optionMoving(war, at.x, at.z), 'Option B', 70);
      expect(s().report.isValid, isFalse);
      final before = s().scene;
      expect(c().applyDraft(), isNull);
      expect(s().scene, before);
      expect(s().draft, isNotNull);
    });

    test(
      'Hold to compare shows the real layout; Discard leaves the room as it was',
      () {
        c().addItem('desk');
        final id = s().selection!;
        final before = s().scene;
        c().openDraft(optionMoving(id, 3.4, 3.0), 'Option A', 70);
        c().compare(true);
        expect(s().displayScene, before);
        c().compare(false);
        expect(s().displayScene.item(id)!.x, 3.4);
        c().discardDraft();
        expect(s().scene, before);
        expect(s().displayScene, before);
      },
    );
  });

  test('lighting is one undo step and ignores unknown moods', () {
    expect(s().scene.room.lighting, 'day');
    c().setLighting('evening');
    expect(s().scene.room.lighting, 'evening');
    c().setLighting('disco');
    expect(s().scene.room.lighting, 'evening');
    c().undo();
    expect(s().scene.room.lighting, 'day');
  });

  test(
    'a merge from the cloud keeps edits made since, as one undo step',
    () async {
      final before = (await store.load('p'))!;
      c().addItem('chair');
      final chair = s().scene.items.single.id;
      final merged = before.copyWith(
        name: 'Guest room',
        scene: before.scene.withNode(item('item_pl', 'plant', 3.9, 3.3)),
      );
      container
          .read(cloudSyncProvider.notifier)
          .announce(
            MergeNotice(id: 'p', before: before, merged: merged, conflicts: 0),
          );
      await Future<void>.delayed(Duration.zero);
      expect(s().scene.item(chair), isNotNull);
      expect(s().scene.item('item_pl'), isNotNull);
      expect(s().project.name, 'Guest room');
      expect(s().merge?.seq, 1);
      c().undo();
      expect(s().scene.item('item_pl'), isNull);
      expect(s().scene.item(chair), isNotNull);
    },
  );
}
