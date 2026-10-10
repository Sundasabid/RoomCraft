import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../domain/checks/placement_checker.dart';
import '../../domain/geometry/polygon.dart';
import '../../state/settings_controller.dart';
import '../../state/setup_controller.dart';
import '../editor/plan_view/plan_painter.dart';

/// The room as it is being set up. Tap a wall to target it for new openings;
/// drag a door or window along its wall.
class LivePlan extends ConsumerStatefulWidget {
  const LivePlan({super.key});

  @override
  ConsumerState<LivePlan> createState() => _LivePlanState();
}

class _LivePlanState extends ConsumerState<LivePlan> {
  String? _dragging;

  PlanPainter _painter(SetupState s) => PlanPainter(
    scene: s.scene,
    colors: context.colors,
    unit: ref.read(settingsProvider).unit,
    showDimensions: true,
    highlightWall: s.highlightWall,
    activeOpening: s.activeOpening,
    textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
  );

  String? _openingAt(SetupState s, Offset local, Size size) {
    final t = _painter(s).transformFor(size);
    for (final o in s.openings) {
      final c = t.toScreen(openingCentre(s.scene.room, o));
      final along = (o.width * t.scale / 2).clamp(16.0, double.infinity);
      if ((c - local).distance <= along) return o.id;
    }
    return null;
  }

  int? _wallAt(SetupState s, Offset local, Size size) {
    final t = _painter(s).transformFor(size);
    final p = t.toPlan(local);
    final corners = s.corners;
    int? best;
    var bestDistance = 24 / t.scale;
    for (var i = 0; i < corners.length; i++) {
      final d = Polygon.distanceToSegment(
        p,
        corners[i],
        corners[(i + 1) % corners.length],
      );
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  void _dragTo(SetupState s, Offset local, Size size) {
    final id = _dragging;
    final o = s.openings.where((x) => x.id == id).firstOrNull;
    if (o == null) return;
    final t = _painter(s).transformFor(size);
    final a = s.corners[o.wallIndex];
    final b = s.corners[(o.wallIndex + 1) % s.corners.length];
    final d = (b - a).normalized;
    final along = (t.toPlan(local) - a).dot(d);
    ref.read(setupProvider.notifier).moveOpening(o.id, along);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(setupProvider);
    ref.watch(settingsProvider.select((x) => x.unit));
    final notifier = ref.read(setupProvider.notifier);
    return Semantics(
      label: S.roomPreview,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (e) {
              final opening = _openingAt(s, e.localPosition, size);
              if (opening != null) {
                notifier.selectOpening(opening);
                return;
              }
              final wall = _wallAt(s, e.localPosition, size);
              if (wall != null) notifier.toggleWall(wall);
            },
            onPanStart: (e) {
              _dragging = _openingAt(s, e.localPosition, size);
              if (_dragging != null) notifier.selectOpening(_dragging);
            },
            onPanUpdate: (e) =>
                _dragTo(ref.read(setupProvider), e.localPosition, size),
            onPanEnd: (_) => _dragging = null,
            child: RepaintBoundary(
              child: CustomPaint(painter: _painter(s), size: size),
            ),
          );
        },
      ),
    );
  }
}
