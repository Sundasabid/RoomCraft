import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/core/strings.dart';
import 'package:roomcraft/domain/checks/layout_validator.dart';
import 'package:roomcraft/features/editor/ai_panel.dart';
import 'package:roomcraft/state/editor_controller.dart';
import 'package:roomcraft/widgets/buttons.dart';

import 'editor_test.dart' show project, pumpEditor;

bool enabled(WidgetTester tester) =>
    tester
        .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, S.apply))
        .onPressed !=
    null;

void main() {
  testWidgets(
    'Apply is disabled while the draft has a violation and enabled when it is clean',
    (tester) async {
      final container = await pumpEditor(tester, project());
      final c = container.read(editorProvider('p').notifier);
      final scene = container.read(editorProvider('p')).value!.scene;
      final clean = scene.withNode(scene.item('item_bed')!.copyWith(x: 3.3));
      c.openDraft(
        LayoutOption(
          name: 'Open',
          reason: 'More room.',
          scene: clean,
          score: 80,
          moved: 1,
        ),
        'Option A',
        60,
      );
      await tester.pumpAndSettle();
      expect(find.byType(DraftBar), findsOneWidget);
      expect(find.text(S.previewing('Option A')), findsOneWidget);
      expect(enabled(tester), isTrue);
      expect(find.text(S.fixToApply), findsNothing);

      // Edit the draft into an overlap: Apply turns off with its reason.
      c.addItem('wardrobe');
      final war = container.read(editorProvider('p')).value!.selection!;
      c.beginDrag(
        war,
        container
            .read(editorProvider('p'))
            .value!
            .workingScene
            .item(war)!
            .position,
      );
      c.dragTo(clean.item('item_bed')!.position);
      c.endDrag();
      await tester.pumpAndSettle();
      expect(enabled(tester), isFalse);
      expect(find.text(S.fixToApply), findsOneWidget);
    },
  );
}
