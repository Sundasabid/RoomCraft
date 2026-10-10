// Every editor tool, tapped the way a person would, with its effect checked.
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/core/strings.dart';
import 'package:roomcraft/features/editor/plan_view/plan_view.dart';
import 'package:roomcraft/state/editor_controller.dart';
import 'package:roomcraft/state/editor_state.dart';

import '../domain/fixtures.dart';
import 'editor_test.dart' show project, pumpEditor;

Future<void> tapTool(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label).last);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Finish changes the floor, walls, lighting and an item', (
    tester,
  ) async {
    final c = await pumpEditor(tester, project());
    EditorState s() => c.read(editorProvider('p')).value!;

    await tapTool(tester, S.toolFinish);
    expect(find.text(S.floorFinish), findsOneWidget);
    expect(find.text(S.finishPickItem), findsOneWidget);
    await tapText(tester, S.finishWalnut);
    expect(s().scene.room.floorFinish, 'walnut');

    await tapText(tester, S.targetWalls);
    await tapText(tester, S.finishSand);
    expect(s().scene.room.wallFinish, 'sand');

    await tapText(tester, S.targetLight);
    await tapText(tester, S.lightEvening);
    expect(s().scene.room.lighting, 'evening');

    // Pick the bed, then its finish.
    c.read(editorProvider('p').notifier).select('item_bed');
    await tester.pumpAndSettle();
    await tapText(tester, S.targetItem);
    expect(find.text(S.finishFor('Bed')), findsOneWidget);
    await tapText(tester, S.finishSageFabric);
    expect(s().scene.item('item_bed')!.finish, 'sage_fabric');

    // Each tap was its own undo step.
    c.read(editorProvider('p').notifier).undo();
    expect(s().scene.item('item_bed')!.finish, isNot('sage_fabric'));
    expect(s().scene.room.lighting, 'evening');
  });

  testWidgets('Add opens the tray and a card adds that piece', (tester) async {
    final c = await pumpEditor(tester, project());
    await tapTool(tester, S.toolAdd);
    expect(find.text(S.addFurniture), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Add Sofa')));
    await tester.pumpAndSettle();
    final items = c.read(editorProvider('p')).value!.scene.items;
    expect(items.map((i) => i.catalogueId), contains('sofa'));
    // The tray stays open for the next piece.
    expect(find.text(S.addFurniture), findsOneWidget);
  });

  testWidgets('AI layout and Live each open their own panel', (tester) async {
    await pumpEditor(tester, project());
    await tapTool(tester, S.toolAi);
    expect(find.text(S.aiWhatWant), findsOneWidget);
    expect(find.text(S.suggestLayouts), findsOneWidget);

    await tapTool(tester, S.shareLiveShort);
    expect(find.text(S.shareLive), findsOneWidget);
    expect(find.text(S.shareStep1), findsOneWidget);
  });

  testWidgets('tapping the open tool again closes its panel', (tester) async {
    await pumpEditor(tester, project());
    await tapTool(tester, S.toolFinish);
    expect(find.text(S.floorFinish), findsOneWidget);
    await tapTool(tester, S.toolFinish);
    expect(find.text(S.floorFinish), findsNothing);
  });

  testWidgets('switching straight between tools always shows the right panel', (
    tester,
  ) async {
    await pumpEditor(tester, project());
    final expected = {
      S.toolAdd: S.addFurniture,
      S.toolFinish: S.floorFinish,
      S.toolAi: S.aiWhatWant,
      S.shareLiveShort: S.shareLive,
    };
    for (final tool in [
      S.toolAdd,
      S.toolFinish,
      S.toolAi,
      S.shareLiveShort,
      S.toolAdd,
      S.shareLiveShort,
      S.toolFinish,
    ]) {
      await tapTool(tester, tool);
      expect(find.text(expected[tool]!), findsOneWidget, reason: tool);
      expect(tester.takeException(), isNull, reason: tool);
    }
  });

  testWidgets('with a sheet open the plan still drags furniture and pans', (
    tester,
  ) async {
    final c = await pumpEditor(tester, project());
    await tapTool(tester, S.toolAdd);
    final bed = find.bySemanticsLabel(RegExp('^Bed, .* metres'));
    expect(bed, findsOneWidget);
    final before = c.read(editorProvider('p')).value!.scene.item('item_bed')!;
    await tester.drag(bed, const Offset(-40, 0));
    await tester.pumpAndSettle();
    final after = c.read(editorProvider('p')).value!.scene.item('item_bed')!;
    expect(after.x, lessThan(before.x));
  });

  testWidgets('a piece outside the room can be dragged back in', (
    tester,
  ) async {
    final p = project();
    final out = p.copyWith(
      scene: p.scene.withNode(item('item_sof', 'sofa', 2.1, -0.2)),
    );
    final c = await pumpEditor(tester, out);
    expect(
      c.read(editorProvider('p')).value!.report.flagged,
      contains('item_sof'),
    );
    final sofa = find.bySemanticsLabel(RegExp('^Sofa, .* metres'));
    await tester.drag(sofa, const Offset(0, 60));
    await tester.pumpAndSettle();
    final s = c.read(editorProvider('p')).value!;
    expect(s.scene.item('item_sof')!.z, greaterThan(0.2));
    expect(s.report.headline ?? '', isNot(contains('outside')));
  });

  testWidgets('the plan moves but never loses the room; one tap re-centres', (
    tester,
  ) async {
    await pumpEditor(tester, project());
    final plan = find.byType(PlanView);
    final box = tester.getRect(plan);
    // Drag empty floor far up and left, well past the edge.
    await tester.dragFrom(
      box.topLeft + const Offset(20, 60),
      const Offset(-900, -900),
    );
    await tester.pumpAndSettle();
    final c = tester.widget<PlanView>(plan).controller;
    expect(c.pan.dx.abs(), lessThanOrEqualTo(box.width / 2));
    expect(c.pan.dy.abs(), lessThanOrEqualTo(box.height / 2));
    expect(find.bySemanticsLabel(S.recentre), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(S.recentre));
    await tester.pumpAndSettle();
    expect(c.pan, Offset.zero);
    expect(find.bySemanticsLabel(S.recentre), findsNothing);
  });
}
