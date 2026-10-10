import 'dart:math' as math;
import 'dart:ui';

import '../../../core/theme/tokens.dart';
import '../../../core/units.dart';
import '../../../domain/checks/placement_checker.dart';
import '../../../domain/checks/snapping.dart';
import '../../../domain/constants.dart';
import '../../../domain/geometry/rect2.dart';
import '../../../domain/scene/nodes.dart';
import '../../../domain/scene/scene.dart';
import 'plan_transform.dart';

/// Editor state the plan draws on top of the room: layers 5 to 8.
class PlanOverlay {
  const PlanOverlay({
    this.selection,
    this.flagged = const {},
    this.dragging,
    this.guides = const [],
    this.popId,
    this.popScale = 1,
    this.pulseIds = const {},
    this.pulseScale = 1,
    this.fading = const [],
    this.finishFrom = const {},
    this.changeT = 1,
  });

  final String? selection;
  final Set<String> flagged;
  final String? dragging;
  final List<SnapGuide> guides;
  final String? popId;
  final double popScale;
  final Set<String> pulseIds;
  final double pulseScale;

  /// Items just deleted, drawn fading and shrinking to 0.9.
  final List<ItemNode> fading;

  /// Previous finish of items whose finish just changed, for a cross-fade.
  final Map<String, String> finishFrom;

  /// Progress of the delete fade and finish cross-fade, 0 to 1.
  final double changeT;

  double scaleFor(String id) =>
      (id == popId ? popScale : 1) * (pulseIds.contains(id) ? pulseScale : 1);

  @override
  bool operator ==(Object other) =>
      other is PlanOverlay &&
      other.selection == selection &&
      other.dragging == dragging &&
      other.popId == popId &&
      other.popScale == popScale &&
      other.pulseScale == pulseScale &&
      other.changeT == changeT &&
      identical(other.fading, fading) &&
      identical(other.finishFrom, finishFrom) &&
      _setEq(other.flagged, flagged) &&
      _setEq(other.pulseIds, pulseIds) &&
      _listEq(other.guides, guides);

  @override
  int get hashCode => Object.hash(
    selection,
    dragging,
    popId,
    popScale,
    pulseScale,
    changeT,
    flagged.length,
    guides.length,
  );

  static bool _setEq<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);
  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Paints the overlay layers. Paint objects are reused between frames.
class OverlayPainter {
  OverlayPainter(this.colors);

  final RoomCraftColors colors;
  late final _hatch = Paint()
    ..color = colors.warning
    ..strokeWidth = 2;
  late final _warnStroke = Paint()
    ..color = colors.warning
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  late final _select = Paint()
    ..color = colors.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  late final _handleFill = Paint()..color = colors.surface;
  late final _keepOutFill = Paint()
    ..color = colors.warning.withValues(alpha: 0.10);
  late final _keepOutEdge = Paint()
    ..color = colors.warning.withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  late final _guide = Paint()
    ..color = colors.primary
    ..strokeWidth = 1.2;

  /// Layer 5: door keep-out zones.
  void keepOuts(Canvas canvas, PlanTransform t, Scene scene) {
    for (final d in scene.doors) {
      final r = t.rect(doorKeepOut(scene.room, d));
      canvas.drawRect(r, _keepOutFill);
      _dashedRect(canvas, r, _keepOutEdge);
    }
  }

  /// Layer 6: hatch and outline on flagged items.
  void warning(Canvas canvas, RRect r) {
    canvas
      ..save()
      ..clipRRect(r);
    final h = r.height;
    for (var x = r.left - h; x < r.right; x += 8) {
      canvas.drawLine(Offset(x, r.bottom), Offset(x + h, r.top), _hatch);
    }
    canvas
      ..restore()
      ..drawRRect(r, _warnStroke);
  }

  /// Layer 7: sage outline with four corner handles.
  void selection(Canvas canvas, Rect r) {
    final box = r.inflate(3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(3)),
      _select,
    );
    for (final c in [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ]) {
      final h = Rect.fromCenter(center: c, width: 8, height: 8);
      canvas
        ..drawRect(h, _handleFill)
        ..drawRect(h, _select..strokeWidth = 1.5);
    }
    _select.strokeWidth = 2;
  }

  /// Layer 8: alignment guides across the plan.
  void guides(
    Canvas canvas,
    Size size,
    PlanTransform t,
    List<SnapGuide> guides,
  ) {
    for (final g in guides) {
      if (g.axis == GuideAxis.x) {
        final x = t.offset.dx + g.value * t.scale;
        _dashedLine(canvas, Offset(x, 0), Offset(x, size.height), _guide);
      } else {
        final z = t.offset.dy + g.value * t.scale;
        _dashedLine(canvas, Offset(0, z), Offset(size.width, z), _guide);
      }
    }
  }

  /// Layer 8: distances to the nearest walls on all four sides.
  List<(Offset, Offset, double)> wallGaps(
    Scene scene,
    Rect2 r,
    PlanTransform t,
  ) {
    final corners = scene.corners;
    double? left, right, top, bottom;
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i], b = corners[(i + 1) % corners.length];
      if ((a.x - b.x).abs() < 1e-9) {
        if (r.centre.z < math.min(a.z, b.z) ||
            r.centre.z > math.max(a.z, b.z)) {
          continue;
        }
        if (a.x <= r.minX + eps) {
          left = math.min(left ?? double.infinity, r.minX - a.x);
        }
        if (a.x >= r.maxX - eps) {
          right = math.min(right ?? double.infinity, a.x - r.maxX);
        }
      } else if ((a.z - b.z).abs() < 1e-9) {
        if (r.centre.x < math.min(a.x, b.x) ||
            r.centre.x > math.max(a.x, b.x)) {
          continue;
        }
        if (a.z <= r.minZ + eps) {
          top = math.min(top ?? double.infinity, r.minZ - a.z);
        }
        if (a.z >= r.maxZ - eps) {
          bottom = math.min(bottom ?? double.infinity, a.z - r.maxZ);
        }
      }
    }
    final c = t.toScreen(r.centre);
    final s = t.scale;
    final rr = t.rect(r);
    return [
      if (left != null)
        (Offset(rr.left - left * s, c.dy), Offset(rr.left, c.dy), left),
      if (right != null)
        (Offset(rr.right, c.dy), Offset(rr.right + right * s, c.dy), right),
      if (top != null)
        (Offset(c.dx, rr.top - top * s), Offset(c.dx, rr.top), top),
      if (bottom != null)
        (Offset(c.dx, rr.bottom), Offset(c.dx, rr.bottom + bottom * s), bottom),
    ];
  }

  void measure(Canvas canvas, Offset a, Offset b) => _dashedLine(
    canvas,
    a,
    b,
    _guide..color = colors.textSecondary.withValues(alpha: 0.7),
  );

  void resetGuide() => _guide.color = colors.primary;

  static void _dashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
    final len = (b - a).distance;
    if (len == 0) return;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += 9) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 5, len), p);
    }
  }

  static void _dashedRect(Canvas canvas, Rect r, Paint p) {
    _dashedLine(canvas, r.topLeft, r.topRight, p);
    _dashedLine(canvas, r.topRight, r.bottomRight, p);
    _dashedLine(canvas, r.bottomRight, r.bottomLeft, p);
    _dashedLine(canvas, r.bottomLeft, r.topLeft, p);
  }
}

/// "1.6 x 2.0 m" for a footprint as drawn.
String sizeLabel(DisplayUnit unit, Rect2 r) =>
    unit.formatSize(r.width, r.depth);
