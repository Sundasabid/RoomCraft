import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../../core/strings.dart';
import '../../../core/units.dart';
import '../../../domain/checks/placement_checker.dart';
import '../../../domain/geometry/rect2.dart';
import '../../../domain/scene/nodes.dart';
import '../../../domain/scene/scene.dart';
import 'plan_transform.dart';

/// What a screen reader can do to an item on the plan: the non-touch
/// alternative to dragging and the action bar.
enum PlanItemAction {
  moveLeft,
  moveRight,
  moveUp,
  moveDown,
  rotate,
  lock,
  delete,
}

/// One accessibility step, in metres.
const nudgeStep = 0.25;

extension PlanItemActionStep on PlanItemAction {
  /// Plan offset for the move actions; zero for the rest.
  (double, double) get offset => switch (this) {
    PlanItemAction.moveLeft => (-nudgeStep, 0),
    PlanItemAction.moveRight => (nudgeStep, 0),
    PlanItemAction.moveUp => (0, -nudgeStep),
    PlanItemAction.moveDown => (0, nudgeStep),
    _ => (0, 0),
  };

  bool get isMove => offset != (0.0, 0.0);
}

/// "Sofa, 2.0 by 0.9 metres, left side of the room".
String spokenItem(
  Scene scene,
  ItemNode item,
  DisplayUnit unit, {
  bool flagged = false,
}) {
  final r = footprintOf(item);
  String n(double m) => unit.fromMetres(m).toStringAsFixed(1);
  final parts = [
    S.itemSpoken(
      scene.displayName(item.id),
      n(r.width),
      n(r.depth),
      unit == DisplayUnit.feet ? S.feetWord : S.metresWord,
      _place(Rect2.bounding(scene.corners), r),
    ),
    if (item.locked) S.isLocked,
    if (flagged) S.hasProblem,
  ];
  return parts.join(', ');
}

/// Which ninth of the room the item's centre falls in.
String _place(Rect2 room, Rect2 item) {
  int third(double v, double lo, double size) {
    final k = size <= 0 ? 0.5 : (v - lo) / size;
    return k < 1 / 3 ? 0 : (k > 2 / 3 ? 2 : 1);
  }

  final h = third(item.centre.x, room.minX, room.width);
  final v = third(item.centre.z, room.minZ, room.depth);
  if (h != 1 && v != 1) {
    return S.placeCorner(v == 0 ? S.top : S.bottom, h == 0 ? S.left : S.right);
  }
  if (h == 0) return S.placeLeft;
  if (h == 2) return S.placeRight;
  if (v == 0) return S.placeTop;
  if (v == 2) return S.placeBottom;
  return S.placeMiddle;
}

/// Invisible boxes over each footprint that carry the item's description and
/// actions. They do not take part in hit testing, so touch is unaffected.
List<Widget> planItemSemantics({
  required Scene scene,
  required PlanTransform transform,
  required Size size,
  required DisplayUnit unit,
  required Set<String> flagged,
  required String? selection,
  void Function(String id)? onSelect,
  void Function(String id, PlanItemAction action)? onAction,
}) {
  final items = scene.items.where((i) => i.visible).toList()
    ..sort((a, b) {
      final z = a.z.compareTo(b.z);
      return z != 0 ? z : a.x.compareTo(b.x);
    });
  final bounds = Offset.zero & size;
  return [
    for (final (index, item) in items.indexed)
      if (transform.rect(footprintOf(item)).intersect(bounds) case final r
          when r.width > 0 && r.height > 0)
        Positioned.fromRect(
          rect: r,
          child: IgnorePointer(
            child: Semantics(
              container: true,
              sortKey: OrdinalSortKey(index.toDouble()),
              label: spokenItem(
                scene,
                item,
                unit,
                flagged: flagged.contains(item.id),
              ),
              selected: item.id == selection,
              button: onSelect != null,
              onTap: onSelect == null ? null : () => onSelect(item.id),
              customSemanticsActions: onAction == null
                  ? null
                  : {
                      for (final a in PlanItemAction.values)
                        CustomSemanticsAction(label: _label(a, item)): () =>
                            onAction(item.id, a),
                    },
              child: const SizedBox.expand(),
            ),
          ),
        ),
  ];
}

String _label(PlanItemAction a, ItemNode item) => switch (a) {
  PlanItemAction.moveLeft => S.moveLeft,
  PlanItemAction.moveRight => S.moveRight,
  PlanItemAction.moveUp => S.moveUp,
  PlanItemAction.moveDown => S.moveDown,
  PlanItemAction.rotate => S.rotate,
  PlanItemAction.lock => item.locked ? S.unlock : S.lock,
  PlanItemAction.delete => S.delete,
};
