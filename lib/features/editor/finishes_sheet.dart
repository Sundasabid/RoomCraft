import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/scene/finishes.dart';
import '../../domain/scene/lighting.dart';
import '../../widgets/chips.dart';
import '../../widgets/fields.dart';
import 'plan_view/plan_painter.dart';

/// The four tabs of the sheet: three finish targets and the room lighting.
enum FinishTab { item, floor, wall, light }

/// Item, floor or wall finishes, or the lighting mood, as round swatches.
/// Each tap is one undo step and the sheet stays open so options can be
/// compared.
class FinishesSheet extends StatelessWidget {
  const FinishesSheet({
    required this.scroll,
    required this.target,
    required this.onTarget,
    required this.itemName,
    required this.current,
    required this.onPick,
    super.key,
  });

  final ScrollController scroll;
  final FinishTab target;
  final ValueChanged<FinishTab> onTarget;

  /// Selected item's name, or null when nothing is selected.
  final String? itemName;
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final title = switch (target) {
      FinishTab.item => S.finishFor(itemName ?? ''),
      FinishTab.floor => S.floorFinish,
      FinishTab.wall => S.wallFinish,
      FinishTab.light => S.lightingTitle,
    };
    final swatches = switch (target) {
      FinishTab.light => [
        for (final p in Lighting.all) (p.id, p.label, Color(p.argb)),
      ],
      FinishTab.item || FinishTab.floor || FinishTab.wall => [
        for (final f in Finishes.forTarget(switch (target) {
          FinishTab.item => FinishTarget.item,
          FinishTab.floor => FinishTarget.floor,
          _ => FinishTarget.wall,
        }))
          (f.id, f.label, finishColor(f.id)),
      ],
    };
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
      children: [
        SegmentedControl<FinishTab>(
          options: const {
            FinishTab.item: S.targetItem,
            FinishTab.floor: S.targetFloor,
            FinishTab.wall: S.targetWalls,
            FinishTab.light: S.targetLight,
          },
          value: target,
          disabled: itemName == null ? const {FinishTab.item} : const {},
          onChanged: onTarget,
        ),
        if (itemName == null && target != FinishTab.light) ...[
          const SizedBox(height: Space.sm),
          Text(S.finishPickItem, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: Space.md),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.md,
          children: [
            for (final (id, label, color) in swatches)
              Swatch(
                color: color,
                label: label,
                selected: id == current,
                onTap: () => onPick(id),
              ),
          ],
        ),
      ],
    );
  }
}
