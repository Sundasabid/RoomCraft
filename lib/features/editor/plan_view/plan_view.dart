import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/haptics.dart';
import '../../../core/strings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/units.dart';
import '../../../domain/checks/placement_checker.dart';
import '../../../domain/geometry/polygon.dart';
import '../../../domain/geometry/rect2.dart';
import '../../../domain/geometry/vec2.dart';
import '../../../domain/scene/nodes.dart';
import '../../../domain/scene/scene.dart';
import '../../../widgets/motion.dart';
import 'plan_overlays.dart';
import 'plan_painter.dart';
import 'plan_semantics.dart';
import 'plan_transform.dart';

/// Shared between the plan and the editor: zoom and pan, where the selected
/// node sits on screen (for the action bar), and "Show me" requests.
class PlanViewController extends ChangeNotifier {
  double zoom = 1;
  Offset pan = Offset.zero;

  /// Screen rectangle of the selection, in the plan's local coordinates.
  Rect? selectionRect;

  Set<String> _focus = const {};
  int _focusSeq = 0;

  void resetZoom() {
    zoom = 1;
    pan = Offset.zero;
    notifyListeners();
  }

  /// Frames these items and pulses them once.
  void focus(Set<String> ids) {
    _focus = ids;
    _focusSeq++;
    notifyListeners();
  }

  void _setSelectionRect(Rect? r) {
    if (r == selectionRect) return;
    selectionRect = r;
    notifyListeners();
  }
}

/// Callbacks the plan raises; the editor maps them to controller methods.
class PlanActions {
  const PlanActions({
    required this.select,
    required this.beginDrag,
    required this.dragTo,
    required this.endDrag,
    required this.cancelDrag,
  });

  final void Function(String? id) select;
  final void Function(String id, Vec2 pointer) beginDrag;

  /// Returns the snap key so the plan can click when it changes.
  final String Function(Vec2 pointer) dragTo;
  final VoidCallback endDrag;
  final VoidCallback cancelDrag;
}

/// The interactive top-down plan. One Listener handles every pointer, so a
/// drag, a tap and a pinch can never fight each other.
class PlanView extends StatefulWidget {
  const PlanView({
    required this.scene,
    required this.controller,
    required this.unit,
    this.actions,
    this.overlay = const PlanOverlay(),
    this.lastAdded,
    this.dragging = false,
    this.ghost,
    this.onItemAction,
    super.key,
  });

  final Scene scene;
  final PlanViewController controller;
  final DisplayUnit unit;

  /// Null in read-only mode: only zoom and pan work.
  final PlanActions? actions;
  final PlanOverlay overlay;
  final String? lastAdded;
  final bool dragging;

  /// The real layout, drawn faint under an AI draft.
  final Scene? ghost;

  /// Screen reader actions on items; null leaves items described only.
  final void Function(String id, PlanItemAction action)? onItemAction;

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> with TickerProviderStateMixin {
  static const _dragSlop = 6.0;
  static const _tapTime = Duration(milliseconds: 300);

  final _pointers = <int, Offset>{};
  Size _size = Size.zero;

  // Single pointer.
  Offset? _downAt;
  DateTime _downTime = DateTime.now();
  String? _candidate;
  bool _dragging = false;
  bool _locked = false;
  String _snapKey = '';
  DateTime _lastClick = DateTime(0);

  // Double tap.
  Offset? _lastTapAt;
  DateTime _lastTapTime = DateTime(0);

  // Pinch.
  double _pinchDistance = 1;
  double _pinchZoom = 1;
  Vec2 _pinchAnchor = Vec2.zero;

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: Motion.fast,
  );
  late final Animation<double> _popScale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.05), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _pop, curve: Motion.curve));
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Motion.pulse,
  );
  late final Animation<double> _pulseScale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.02), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 1),
  ]).animate(_pulse);
  Set<String> _pulseIds = const {};
  int _seenFocus = 0;

  // Deleted items fade out; changed finishes cross-fade.
  late final AnimationController _change = AnimationController(
    vsync: this,
    duration: Motion.fast,
    value: 1,
  );
  List<ItemNode> _fading = const [];
  Map<String, String> _finishFrom = const {};

  PlanViewController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onController);
  }

  @override
  void didUpdateWidget(PlanView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
    if (widget.lastAdded != null && widget.lastAdded != old.lastAdded) {
      _pop.duration = motion(context, Motion.fast);
      _pop.forward(from: 0);
    }
    if (!identical(old.scene, widget.scene) &&
        identical(old.ghost == null, widget.ghost == null)) {
      _trackChanges(old.scene, widget.scene);
    }
  }

  void _trackChanges(Scene before, Scene after) {
    final gone = [
      for (final i in before.items)
        if (i.visible && after.item(i.id) == null) i,
    ];
    final recoloured = {
      for (final i in before.items)
        if (after.item(i.id) case final now? when now.finish != i.finish)
          i.id: i.finish,
    };
    if (gone.isEmpty && recoloured.isEmpty) return;
    _fading = gone;
    _finishFrom = recoloured;
    final d = motion(context, Motion.fast);
    if (d == Duration.zero) {
      _change.value = 1;
      return;
    }
    _change
      ..duration = d
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.removeListener(_onController);
    _pop.dispose();
    _pulse.dispose();
    _change.dispose();
    super.dispose();
  }

  void _onController() {
    if (_c._focusSeq != _seenFocus) {
      _seenFocus = _c._focusSeq;
      _frame(_c._focus);
    }
    if (mounted) setState(() {});
  }

  PlanTransform get _t => PlanTransform.fit(
    Rect2.bounding(widget.scene.corners),
    _size,
    padding: 24,
    zoom: _c.zoom,
    pan: _c.pan,
  );

  /// Zooms so the given items fill most of the view, then pulses them.
  void _frame(Set<String> ids) {
    final rects = [
      for (final id in ids)
        if (widget.scene.item(id) case final item?) footprintOf(item),
    ];
    if (rects.isEmpty || _size.isEmpty) return;
    final union = Rect2.bounding(rects.expand((r) => r.corners));
    final room = Rect2.bounding(widget.scene.corners);
    final fitted = PlanTransform.fit(room, _size).scale;
    final want = math.min(
      _size.width / (union.width + 1.2),
      _size.height / (union.depth + 1.2),
    );
    _c.zoom = (want / fitted).clamp(1.0, 4.0);
    final s = fitted * _c.zoom;
    _c.pan = Offset(
      (room.centre.x - union.centre.x) * s,
      (room.centre.z - union.centre.z) * s,
    );
    _pulseIds = ids;
    _pulse.duration = motion(context, Motion.pulse);
    _pulse.forward(from: 0);
  }

  /// Topmost item first, exact footprints before the 48 dp touch targets,
  /// then doors and windows along their walls.
  String? _hit(Offset local) {
    final t = _t;
    final p = t.toPlan(local);
    final items = widget.scene.items.where((i) => i.visible).toList()
      ..sort(
        (a, b) => (isFloorOnly(b) ? 1 : 0).compareTo(isFloorOnly(a) ? 1 : 0),
      );
    final top = items.reversed.toList();
    for (final i in top) {
      if (footprintOf(i).contains(p)) return i.id;
    }
    final minTarget = Sizes.touch / t.scale;
    for (final i in top) {
      final r = footprintOf(i);
      final grow = math.max(0.0, (minTarget - math.min(r.width, r.depth)) / 2);
      if (grow > 0 && r.inflate(grow).contains(p)) return i.id;
    }
    final room = widget.scene.room;
    for (final o in widget.scene.openings) {
      final a = room.corners[o.wallIndex];
      final d = (room.corners[(o.wallIndex + 1) % room.corners.length] - a)
          .normalized;
      final c = openingCentre(room, o);
      final s = c - d * (o.width / 2), e = c + d * (o.width / 2);
      if (Polygon.distanceToSegment(p, s, e) * t.scale <= 16) return o.id;
    }
    return null;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _locked = false;
      _downAt = e.localPosition;
      _downTime = DateTime.now();
      _candidate = widget.actions == null ? null : _hit(e.localPosition);
      return;
    }
    // A second finger always means pan and zoom; it cancels any drag.
    if (_dragging) {
      widget.actions?.cancelDrag();
      _dragging = false;
    }
    _candidate = null;
    _locked = true;
    final pts = _pointers.values.take(2).toList();
    _pinchDistance = math.max((pts[0] - pts[1]).distance, 1);
    _pinchZoom = _c.zoom;
    _pinchAnchor = _t.toPlan((pts[0] + pts[1]) / 2);
  }

  void _move(PointerMoveEvent e) {
    final previous = _pointers[e.pointer];
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length >= 2) {
      _pinch();
      return;
    }
    if (_locked || _downAt == null) return;
    final actions = widget.actions;
    if (!_dragging && _candidate != null && actions != null) {
      if ((e.localPosition - _downAt!).distance < _dragSlop) return;
      _dragging = true;
      _snapKey = '';
      actions.beginDrag(_candidate!, _t.toPlan(_downAt!));
    }
    if (_dragging && actions != null) {
      final key = actions.dragTo(_t.toPlan(e.localPosition));
      final now = DateTime.now();
      if (key != _snapKey &&
          _snapKey.isNotEmpty &&
          now.difference(_lastClick).inMilliseconds >= 100) {
        Haptics.selectionClick();
        _lastClick = now;
      }
      _snapKey = key;
    } else if (_candidate == null && previous != null) {
      // One finger on empty floor moves the plan around; a double tap
      // brings it back to the middle.
      _c.pan = _clampPan(_c.pan + e.localPosition - previous);
      setState(() {});
    }
  }

  /// Keeps the room's centre inside the view, so the plan can be moved
  /// around but never lost off screen.
  Offset _clampPan(Offset pan) {
    final room = Rect2.bounding(widget.scene.corners);
    final s = PlanTransform.fit(room, _size).scale * _c.zoom;
    final maxX = math.max(_size.width / 2 - 24, room.width * s / 2);
    final maxY = math.max(_size.height / 2 - 24, room.depth * s / 2);
    return Offset(pan.dx.clamp(-maxX, maxX), pan.dy.clamp(-maxY, maxY));
  }

  void _pinch() {
    final pts = _pointers.values.take(2).toList();
    final focal = (pts[0] + pts[1]) / 2;
    final distance = math.max((pts[0] - pts[1]).distance, 1);
    _c.zoom = (_pinchZoom * distance / _pinchDistance).clamp(1.0, 4.0);
    final room = Rect2.bounding(widget.scene.corners);
    final s = PlanTransform.fit(room, _size).scale * _c.zoom;
    final centre = Offset(_size.width / 2, _size.height / 2);
    _c.pan = _clampPan(
      focal -
          centre -
          Offset(
            (_pinchAnchor.x - room.centre.x) * s,
            (_pinchAnchor.z - room.centre.z) * s,
          ),
    );
    setState(() {});
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;
    final actions = widget.actions;
    if (_dragging) {
      _dragging = false;
      actions?.endDrag();
      return;
    }
    if (_locked || _downAt == null || e is PointerCancelEvent) return;
    final quick = DateTime.now().difference(_downTime) <= _tapTime;
    if (!quick || (e.localPosition - _downAt!).distance >= _dragSlop) return;
    final now = DateTime.now();
    final hit = actions == null ? null : _candidate;
    if (hit == null) {
      final last = _lastTapAt;
      if (last != null &&
          now.difference(_lastTapTime) <= _tapTime &&
          (last - e.localPosition).distance <= 20) {
        _c.resetZoom();
        _lastTapAt = null;
        return;
      }
      _lastTapAt = e.localPosition;
      _lastTapTime = now;
    }
    actions?.select(hit);
  }

  void _reportSelection() {
    final id = widget.overlay.selection;
    Rect? r;
    if (id != null && !_size.isEmpty) {
      final t = _t;
      final item = widget.scene.item(id);
      final opening = widget.scene.opening(id);
      if (item != null) {
        r = t.rect(footprintOf(item));
      } else if (opening != null) {
        r = Rect.fromCenter(
          center: t.toScreen(openingCentre(widget.scene.room, opening)),
          width: 24,
          height: 24,
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _c._setSelectionRect(r),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _size = box.biggest;
      _reportSelection();
      final actions = widget.actions;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        // The plan never paints outside its own box.
        child: ClipRect(
          child: Stack(
            children: [
              _paint(context),
              if (_c.zoom != 1 || _c.pan != Offset.zero)
                Positioned(
                  right: Space.md,
                  bottom: Space.md,
                  child: _RecentreButton(onPressed: _c.resetZoom),
                ),
              if (!_size.isEmpty)
                ...planItemSemantics(
                  scene: widget.scene,
                  transform: _t,
                  size: _size,
                  unit: widget.unit,
                  flagged: widget.overlay.flagged,
                  selection: widget.overlay.selection,
                  onSelect: actions?.select,
                  onAction: widget.onItemAction,
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _paint(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: Listenable.merge([_pop, _pulse, _change]),
      builder: (context, _) => CustomPaint(
        size: _size,
        painter: PlanPainter(
          scene: widget.scene,
          colors: context.colors,
          unit: widget.unit,
          showDimensions: true,
          zoom: _c.zoom,
          pan: _c.pan,
          activeOpening: widget.scene
              .opening(widget.overlay.selection ?? '')
              ?.id,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: 1.3),
          ghost: widget.ghost,
          overlay: PlanOverlay(
            selection: widget.scene.item(widget.overlay.selection ?? '') == null
                ? null
                : widget.overlay.selection,
            flagged: widget.overlay.flagged,
            dragging: widget.overlay.dragging,
            guides: widget.overlay.guides,
            popId: _pop.isAnimating ? widget.lastAdded : null,
            popScale: _popScale.value,
            pulseIds: _pulse.isAnimating ? _pulseIds : const {},
            pulseScale: _pulseScale.value,
            fading: _change.isAnimating ? _fading : const [],
            finishFrom: _change.isAnimating ? _finishFrom : const {},
            changeT: _change.value,
          ),
        ),
      ),
    ),
  );
}

/// Brings a moved or zoomed plan back to the whole room.
class _RecentreButton extends StatelessWidget {
  const _RecentreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: S.recentre,
      child: Semantics(
        button: true,
        label: S.recentre,
        excludeSemantics: true,
        child: Material(
          color: c.surface,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: c.shadow,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: Sizes.touch,
              child: Icon(
                Icons.center_focus_strong_rounded,
                color: c.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
