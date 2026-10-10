import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roomcraft/core/strings.dart';
import 'package:roomcraft/core/theme/theme.dart';
import 'package:roomcraft/data/local_projects.dart';
import 'package:roomcraft/domain/scene/scene_json.dart';
import 'package:roomcraft/features/editor/editor_screen.dart';
import 'package:roomcraft/features/editor/view3d/view3d.dart';
import 'package:roomcraft/state/connectivity_provider.dart';
import 'package:roomcraft/state/editor_controller.dart';
import 'package:roomcraft/state/projects_controller.dart';
import 'package:roomcraft/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fixtures.dart';

class MemoryStore extends LocalProjectStore {
  MemoryStore(this.projects) : super(Directory.systemTemp);
  final List<ProjectFile> projects;
  @override
  Future<List<ProjectFile>> list() async => projects;
  @override
  Future<ProjectFile?> load(String id) async =>
      projects.where((p) => p.id == id).firstOrNull;
  @override
  Future<void> save(ProjectFile project) async {}
}

Future<ProviderContainer> pumpEditor(
  WidgetTester tester,
  ProjectFile p, {
  bool online = true,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        localStoreProvider.overrideWithValue(MemoryStore([p])),
        isOnlineProvider.overrideWithValue(online),
        view3dEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        theme: RoomCraftTheme.light(),
        routerConfig: GoRouter(
          initialLocation: '/editor/${p.id}',
          routes: [
            GoRoute(
              path: '/editor/:id',
              builder: (_, s) =>
                  EditorScreen(projectId: s.pathParameters['id']!),
            ),
            GoRoute(path: '/projects', builder: (_, _) => const SizedBox()),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(EditorScreen)));
}

ProjectFile project({bool clash = false}) => ProjectFile(
  id: 'p',
  name: 'Bedroom',
  updatedAt: DateTime.utc(2026),
  displayUnit: 'm',
  scene: bedroom(
    items: [
      item('item_bed', 'bed', 2.9, 1.1),
      if (clash) item('item_war', 'wardrobe', 2.6, 2.3),
    ],
  ),
);

void _custom(WidgetTester tester, Finder f, CustomSemanticsAction a) {
  final node = tester.getSemantics(f);
  node.owner!.performAction(
    node.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(a),
  );
}

void main() {
  testWidgets(
    'the warning banner shows the right sentence and clears when fixed',
    (tester) async {
      final container = await pumpEditor(tester, project(clash: true));
      expect(find.text('Bed overlaps Wardrobe'), findsOneWidget);
      expect(find.text(S.showMe), findsOneWidget);
      container.read(editorProvider('p').notifier).select('item_war');
      container.read(editorProvider('p').notifier).deleteSelected();
      await tester.pumpAndSettle();
      expect(find.text('Bed overlaps Wardrobe'), findsNothing);
    },
  );

  testWidgets(
    'an empty room shows the hint; adding from the catalogue removes it',
    (tester) async {
      final empty = ProjectFile(
        id: 'p',
        name: 'Empty',
        updatedAt: DateTime.utc(2026),
        displayUnit: 'm',
        scene: bedroom(),
      );
      final container = await pumpEditor(tester, empty);
      expect(find.text(S.emptyRoomHint), findsOneWidget);
      await tester.tap(find.text(S.toolAdd));
      await tester.pumpAndSettle();
      expect(find.text(S.addFurniture), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('^Add Sofa')));
      await tester.pumpAndSettle();
      final s = container.read(editorProvider('p')).value!;
      expect(s.scene.items.single.catalogueId, 'sofa');
      expect(s.report.isValid, isTrue);
      expect(find.text(S.emptyRoomHint), findsNothing);
    },
  );

  testWidgets('selecting an item shows its label and the action bar', (
    tester,
  ) async {
    final container = await pumpEditor(tester, project());
    container.read(editorProvider('p').notifier).select('item_bed');
    await tester.pumpAndSettle();
    expect(find.text('Bed, 1.6 x 2.0 m'), findsOneWidget);
    for (final label in [S.rotate, S.copy, S.lock, S.delete]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the offline banner shows when there is no network', (
    tester,
  ) async {
    await pumpEditor(tester, project(), online: false);
    expect(find.text(S.offlineEditor), findsOneWidget);
  });

  testWidgets('plan items are described and can be moved without dragging', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final container = await pumpEditor(tester, project());
    final bed = find.bySemanticsLabel(
      'Bed, 1.6 by 2.0 metres, top right corner of the room',
    );
    expect(bed, findsOneWidget);

    _custom(tester, bed, const CustomSemanticsAction(label: S.moveLeft));
    await tester.pumpAndSettle();
    final s = container.read(editorProvider('p')).value!;
    expect(s.selection, 'item_bed');
    expect(s.scene.item('item_bed')!.x, closeTo(2.65, 1e-9));

    container.read(editorProvider('p').notifier).undo();
    await tester.pumpAndSettle();
    expect(
      container.read(editorProvider('p')).value!.scene.item('item_bed')!.x,
      closeTo(2.9, 1e-9),
    );

    _custom(
      tester,
      find.bySemanticsLabel(RegExp('^Bed, .* metres, ')),
      const CustomSemanticsAction(label: S.lock),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Bed, .*, locked\$')), findsOneWidget);
    handle.dispose();
  });
}
