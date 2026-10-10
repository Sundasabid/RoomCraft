import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/units.dart';
import '../../../domain/checks/placement_checker.dart';
import '../../../domain/geometry/polygon.dart';
import '../../../domain/geometry/rect2.dart';
import '../../../domain/geometry/vec2.dart';
import '../../../domain/scene/catalogue.dart';
import '../../../domain/scene/finishes.dart';
import '../../../domain/scene/nodes.dart';
import '../../../domain/scene/scene.dart';
import '../furniture_art.dart';
import 'plan_overlays.dart';
import 'plan_transform.dart';
import 'plan_walls.dart';

/// Short labels for footprints too small for the full name.
const _shortLabels = {
  'bed': 'Bd',
  'sofa': 'So',
  'chair': 'Ch',
  'wardrobe': 'Wd',
  'bookshelf': 'Bk',
  'tv_unit': 'TV',
  'desk': 'Dk',
  'dining_table': 'Dt',
  'coffee_table': 'Ct',
  'rug': 'Rg',
  'plant': 'Pl',
  'floor_lamp': 'La',
};

Color finishColor(String id) =>
    Color(Finishes.has(id) ? Finishes.byId(id).argb : 0xFFB98B5E);

/// Draws the room from above. This class covers the base layers: page and
/// grid, floor, walls with doors and windows, furniture, and dimension labels.
class PlanPainter extends CustomPainter {
  PlanPainter({
    required this.scene,
    required this.colors,
    this.unit = DisplayUnit.metres,
    this.showGrid = true,
    this.showDimensions = false,
    this.showLabels = true,
    this.highlightWall,
    this.activeOpening,
    this.padding = 24,
    this.zoom = 1,
    this.pan = Offset.zero,
    this.textScaler = TextScaler.noScaling,
    this.background,
    this.overlay,
    this.ghost,
  });

  final Scene scene;
  final RoomCraftColors colors;
  final DisplayUnit unit;
  final bool showGrid;
  final bool showDimensions;
  final bool showLabels;
  final int? highlightWall;
  final String? activeOpening;
  final double padding;
  final double zoom;
  final Offset pan;
  final TextScaler textScaler;

  /// Page colour behind the room; defaults to the screen background.
  final Color? background;

  /// Editor layers (warnings, selection, drag aids); null for previews.
  final PlanOverlay? overlay;

  /// Layer 9: the real layout drawn faint under an AI draft; the draft's
  /// own items then get a sage outline.
  final Scene? ghost;

  late final _overlayPainter = OverlayPainter(colors);

  final _labels = <String, TextPainter>{};

  PlanTransform transformFor(Size size) {
    var pad = padding;
    if (showDimensions) pad += 18;
    return PlanTransform.fit(
      Rect2.bounding(scene.corners),
      size,
      padding: pad,
      zoom: zoom,
      pan: pan,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = transformFor(size);
    final corners = scene.corners;
    final floorPath = Path()
      ..addPolygon([for (final c in corners) t.toScreen(c)], true);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = background ?? colors.background,
    );
    if (showGrid) _grid(canvas, size, t);

    final dark = colors.background.computeLuminance() < 0.2;
    final floor = Color.alphaBlend(
      finishColor(scene.room.floorFinish).withValues(alpha: dark ? 0.30 : 0.35),
      colors.planFloor,
    );
    canvas.drawPath(floorPath, Paint()..color = floor);

    final g = ghost;
    if (g != null) {
      for (final item in g.items.where((i) => i.visible)) {
        paintItem(
          canvas,
          t,
          item,
          footprintOf(item),
          opacity: 0.25,
          label: false,
        );
      }
    }
    paintWalls(
      canvas,
      t,
      scene,
      colors,
      highlightWall: highlightWall,
      activeOpening: activeOpening,
    );
    final rects = _items(canvas, t);
    if (g != null) {
      final sage = Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final r in rects.values) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            t.rect(r).inflate(1),
            const Radius.circular(3),
          ),
          sage,
        );
      }
    }
    final o = overlay;
    if (o != null) _overlays(canvas, size, t, o, rects);
    if (showDimensions && o?.selection == null) _dimensions(canvas, t);
  }

  void _overlays(
    Canvas canvas,
    Size size,
    PlanTransform t,
    PlanOverlay o,
    Map<String, Rect2> rects,
  ) {
    final op = _overlayPainter;
    if (o.dragging != null || o.flagged.isNotEmpty) {
      op.keepOuts(canvas, t, scene);
    }
    final sel = o.selection == null ? null : rects[o.selection];
    if (sel != null) op.selection(canvas, t.rect(sel));
    final dragged = o.dragging == null ? null : rects[o.dragging];
    if (dragged == null) return;
    op.guides(canvas, size, t, o.guides);
    for (final (a, b, metres) in op.wallGaps(scene, dragged, t)) {
      if ((b - a).distance < 18) continue;
      op.measure(canvas, a, b);
      _pill(canvas, (a + b) / 2, unit.format(metres, decimals: 2));
    }
    op.resetGuide();
    final r = t.rect(dragged);
    _pill(canvas, Offset(r.center.dx, r.bottom + 16), sizeLabel(unit, dragged));
  }

  /// White pill label at 92 percent, 12 sp.
  void _pill(Canvas canvas, Offset centre, String text) {
    final tp = _label(text, colors.textPrimary, 12, weight: FontWeight.w600);
    final box = Rect.fromCenter(
      center: centre,
      width: tp.width + 14,
      height: tp.height + 8,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(Radii.card)),
        Paint()..color = colors.surface.withValues(alpha: 0.92),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(Radii.card)),
        Paint()
          ..color = colors.fieldBorder
          ..style = PaintingStyle.stroke,
      );
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  void _grid(Canvas canvas, Size size, PlanTransform t) {
    final paint = Paint()
      ..color = colors.primaryDark.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    final start = t.toPlan(Offset.zero),
        end = t.toPlan(Offset(size.width, size.height));
    for (var x = start.x.floorToDouble(); x <= end.x; x += 1) {
      final sx = t.toScreen(Vec2(x, 0)).dx;
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), paint);
    }
    for (var z = start.z.floorToDouble(); z <= end.z; z += 1) {
      final sz = t.toScreen(Vec2(0, z)).dy;
      canvas.drawLine(Offset(0, sz), Offset(size.width, sz), paint);
    }
  }

  /// Draws rugs first, then the rest; returns each footprint as drawn.
  Map<String, Rect2> _items(Canvas canvas, PlanTransform t) {
    final items = scene.items.where((i) => i.visible).toList()
      ..sort(
        (a, b) => (isFloorOnly(b) ? 1 : 0).compareTo(isFloorOnly(a) ? 1 : 0),
      );
    final rects = <String, Rect2>{};
    for (final item in items) {
      var r = footprintOf(item);
      final k = overlay?.scaleFor(item.id) ?? 1;
      if (k != 1) r = Rect2.centred(r.centre, r.width * k, r.depth * k);
      rects[item.id] = r;
      // A rug's name is hidden once furniture stands on it.
      final covered =
          isFloorOnly(item) &&
          items.any((o) => !isFloorOnly(o) && rectsOverlap(footprintOf(o), r));
      final from = overlay?.finishFrom[item.id];
      paintItem(
        canvas,
        t,
        item,
        r,
        warn: overlay?.flagged.contains(item.id) ?? false,
        // Names show for the selected piece and any with a problem; the
        // drawings speak for the rest, and the plan stays calm.
        label:
            !covered &&
            (overlay?.selection == item.id ||
                (overlay?.flagged.contains(item.id) ?? false) ||
                overlay == null),
        fillOverride: from == null
            ? null
            : Color.lerp(
                finishColor(from),
                finishColor(item.finish),
                overlay!.changeT,
              ),
      );
      if (item.locked && overlay != null) _lockBadge(canvas, t.rect(r));
    }
    final o = overlay;
    if (o != null && o.changeT < 1) {
      final k = 1 - 0.1 * o.changeT;
      for (final item in o.fading) {
        final r = footprintOf(item);
        paintItem(
          canvas,
          t,
          item,
          Rect2.centred(r.centre, r.width * k, r.depth * k),
          opacity: 1 - o.changeT,
          label: false,
        );
      }
    }
    return rects;
  }

  void _lockBadge(Canvas canvas, Rect r) {
    final c = r.topRight + const Offset(-2, 2);
    canvas
      ..drawCircle(c, 9, Paint()..color = colors.primaryDark)
      ..drawCircle(
        c,
        9,
        Paint()
          ..color = colors.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    final icon = _icon(Icons.lock_rounded, colors.surface);
    icon.paint(canvas, c - Offset(icon.width / 2, icon.height / 2));
  }

  TextPainter _icon(IconData data, Color color) => _labels.putIfAbsent(
    'icon${data.codePoint}${color.toARGB32()}',
    () => TextPainter(
      text: TextSpan(
        text: String.fromCharCode(data.codePoint),
        style: TextStyle(
          fontFamily: data.fontFamily,
          fontSize: 11,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );

  /// One piece drawn from above in its finish colour, turned to its
  /// rotation, with the warning hatch on top and, when asked, its name in a
  /// small pill.
  void paintItem(
    Canvas canvas,
    PlanTransform t,
    ItemNode item,
    Rect2 rect, {
    double opacity = 1,
    bool warn = false,
    bool label = true,
    Color? fillOverride,
  }) {
    final screen = t.rect(rect);
    final fill = fillOverride ?? finishColor(item.finish);
    final quarter = item.rotation % 180 == 90;
    final local = Rect.fromCenter(
      center: Offset.zero,
      width: quarter ? screen.height : screen.width,
      height: quarter ? screen.width : screen.height,
    );
    canvas
      ..save()
      ..translate(screen.center.dx, screen.center.dy)
      ..rotate(item.rotation * math.pi / 180);
    paintFurniture(
      canvas,
      local,
      item.catalogueId,
      fill,
      colors,
      opacity: opacity,
    );
    canvas.restore();
    final r = RRect.fromRectAndRadius(screen, const Radius.circular(2));
    if (warn) _overlayPainter.warning(canvas, r);
    if (!showLabels || !label) return;
    final ink = warn ? colors.warningText : colors.textPrimary;
    final name = Catalogue.byId(item.catalogueId).name;
    for (final text in [name, _shortLabels[item.catalogueId] ?? '']) {
      final tp = _label(
        text,
        ink.withValues(alpha: opacity),
        11,
        weight: FontWeight.w600,
      );
      if (tp.width + 10 <= r.width + 8 && tp.height + 4 <= r.height) {
        final at = r.center - Offset(tp.width / 2, tp.height / 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(at.dx - 5, at.dy - 2, tp.width + 10, tp.height + 4),
            const Radius.circular(Radii.small),
          ),
          Paint()..color = colors.surface.withValues(alpha: 0.92 * opacity),
        );
        tp.paint(canvas, at);
        return;
      }
    }
  }

  void _dimensions(Canvas canvas, PlanTransform t) {
    final corners = scene.corners;
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i], b = corners[(i + 1) % corners.length];
      final n = Polygon.inwardNormal(corners, i);
      final mid = t.toScreen((a + b) / 2);
      final tp = _label(
        unit.format(a.distanceTo(b)),
        colors.textSecondary,
        11,
        weight: FontWeight.w600,
      );
      final out =
          Offset(-n.x, -n.z) *
          (wallThickness * t.scale / 2 +
              6 +
              math.max(tp.width * n.x.abs(), tp.height * n.z.abs()) / 2);
      tp.paint(canvas, mid + out - Offset(tp.width / 2, tp.height / 2));
    }
  }

  TextPainter _label(
    String text,
    Color color,
    double size, {
    FontWeight weight = FontWeight.w500,
  }) => _labels.putIfAbsent(
    '$text|${color.toARGB32()}|$size|$weight',
    () => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(),
  );

  @override
  bool shouldRepaint(PlanPainter old) =>
      old.scene != scene ||
      old.colors != colors ||
      old.unit != unit ||
      old.highlightWall != highlightWall ||
      old.activeOpening != activeOpening ||
      old.showDimensions != showDimensions ||
      old.zoom != zoom ||
      old.pan != pan ||
      old.overlay != overlay ||
      !identical(old.ghost, ghost);
}
