import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/data/local_projects.dart';
import 'package:roomcraft/domain/checks/placement_checker.dart';
import 'package:roomcraft/domain/scene/nodes.dart';
import 'package:roomcraft/state/setup_controller.dart';

void main() {
  late ProviderContainer container;
  SetupController setup() => container.read(setupProvider.notifier);
  SetupState state() => container.read(setupProvider);

  setUp(() {
    container = ProviderContainer();
    container.listen(setupProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  test(
    'the bedroom template matches the plan: 4.2 by 3.6 m, 1 door, 1 window',
    () {
      final s = state();
      expect((s.width, s.length), (4.2, 3.6));
      expect(s.openings.where((o) => o.isDoor), hasLength(1));
      expect(s.openings.where((o) => !o.isDoor), hasLength(1));
      final door = s.openings.firstWhere((o) => o.isDoor);
      final centre = openingCentre(s.scene.room, door);
      expect(centre.x, closeTo(0, 1e-9));
      expect(centre.z, closeTo(2.7, 1e-9));
    },
  );

  test('every template builds a valid room', () {
    for (final t in RoomTemplate.values) {
      setup().applyTemplate(t);
      final s = state();
      expect(s.hasDoor, isTrue, reason: t.name);
      expect(s.scene.corners.length, s.lShape ? 6 : 4);
    }
    setup().applyTemplate(RoomTemplate.living);
    expect(state().openings.where((o) => !o.isDoor), hasLength(2));
  });

  test('dimensions are clamped to 2 to 12 m', () {
    setup().setWidth(20);
    expect(state().width, 12);
    setup().setLength(0.5);
    expect(state().length, 2);
  });

  test('L-shape notch limits run from 1.0 m to the side minus 1.5 m', () {
    setup().setShape(lShape: true);
    setup().setNotchWidth(10);
    expect(state().notchWidth, closeTo(state().width - 1.5, 1e-9));
    setup().setNotchLength(0.2);
    expect(state().notchLength, 1.0);
    setup().setWidth(3.0);
    expect(state().notchWidth, lessThanOrEqualTo(1.5 + 1e-9));
  });

  test('shortening a wall moves an opening inward so it still fits', () {
    final window = state().openings.firstWhere((o) => !o.isDoor);
    setup().moveOpening(window.id, 4.0);
    setup().setWidth(3.0);
    final moved = state().openings.firstWhere((o) => o.id == window.id);
    expect(moved.offset + moved.width / 2, lessThanOrEqualTo(3.0 - 0.1 + 1e-9));
    expect(setup().lastRemoved, isEmpty);
  });

  test('a window that no longer fits is removed and reported', () {
    setup().setShape(lShape: true);
    // Put a wide window on the notch wall, then shrink the notch below it.
    setup().toggleWall(3);
    expect(setup().addOpening(OpeningKind.window), isTrue);
    final id = state().activeOpening!;
    setup().setOpeningWidth(id, 1.3);
    setup().setNotchLength(1.0);
    expect(state().openings.any((o) => o.id == id), isFalse);
    expect(setup().lastRemoved, [OpeningKind.window]);
  });

  test('a new opening goes on the highlighted wall at its centre', () {
    setup().toggleWall(1);
    setup().addOpening(OpeningKind.door);
    final door = state().openings.firstWhere(
      (o) => o.id == state().activeOpening,
    );
    expect(door.wallIndex, 1);
    expect(door.offset, closeTo(1.8, 1e-9));
  });

  test('openings never overlap each other on a wall', () {
    setup().toggleWall(0);
    for (var i = 0; i < 6; i++) {
      setup().addOpening(OpeningKind.window);
    }
    final onTop = state().openings.where((o) => o.wallIndex == 0).toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));
    for (var i = 1; i < onTop.length; i++) {
      final gap =
          (onTop[i].offset - onTop[i].width / 2) -
          (onTop[i - 1].offset + onTop[i - 1].width / 2);
      expect(gap, greaterThanOrEqualTo(0.1 - 1e-9));
    }
  });

  test('switching template keeps a name the user typed', () {
    setup().setName('Guest room');
    setup().applyTemplate(RoomTemplate.studio);
    expect(state().name, 'Guest room');
  });

  test(
    'a room with doors and windows is created, saved and reopened identically',
    () async {
      final dir = Directory.systemTemp.createTempSync('roomcraft');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = LocalProjectStore(dir);
      setup().applyTemplate(RoomTemplate.studio);
      final project = setup().buildProject(displayUnit: 'm');
      await store.save(project);
      final back = await store.load(project.id);
      expect(back!.scene, project.scene);
      expect(back.scene.openings, hasLength(2));
      expect(back.name, 'Studio');
    },
  );
}
