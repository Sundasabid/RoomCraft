import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/messages.dart';
import '../../bridge/scene_bridge.dart';
import '../../bridge/scene_sync.dart';
import '../../core/haptics.dart';
import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../core/units.dart';
import '../../domain/geometry/vec2.dart';
import '../../domain/scene/nodes.dart';
import '../../domain/scene/scene.dart';
import '../../state/editor_controller.dart';
import '../../state/editor_state.dart';
import '../../state/settings_controller.dart';
import '../../widgets/motion.dart';
import '../../widgets/over_3d.dart';
import '../../widgets/surfaces.dart';
import 'editor_chrome.dart';
import 'inspector_bar.dart';
import 'plan_view/plan_overlays.dart';
import 'plan_view/plan_semantics.dart';
import 'plan_view/plan_view.dart';
import 'view3d/view3d.dart';

enum _Source { plan, view3d }

/// Lets design screenshots show a view mode without a real 3D view.
final viewModeOverrideProvider = Provider<ViewMode?>((ref) => null);

/// The 3D view and the 2D plan of one scene, with their overlays. In
/// portrait 3D sits above the plan with a draggable divider; in landscape
/// they sit side by side (3 to 2).
class EditorViews extends ConsumerStatefulWidget {
  const EditorViews({
    required this.state,
    required this.unit,
    required this.online,
    required this.landscape,
    required this.plan,
    required this.controller,
    required this.selectionText,
    required this.barActions,
    required this.onItemAction,
    required this.onLighting,
    required this.sheetOpen,
    super.key,
  });

  final EditorState state;
  final DisplayUnit unit;
  final bool online;
  final bool landscape;
  final PlanViewController plan;
  final EditorController controller;
  final String? selectionText;
  final List<BarAction> barActions;
  final void Function(String id, PlanItemAction action) onItemAction;

  /// Opens the lighting moods.
  final VoidCallback onLighting;

  /// A sheet covers part of the screen: the plan gets most of what is left.
  final bool sheetOpen;

  @override
  ConsumerState<EditorViews> createState() => _EditorViewsState();
}

class _EditorViewsState extends ConsumerState<EditorViews> {
  SceneSync? _sync;
  String _preset = 'corner';

  /// The gesture hint over 3D goes away after the first drag there.
  bool _movedIn3d = false;
  _Source _source = _Source.plan;
  final _anchor3d = ValueNotifier<(Offset, bool)?>(null);
  RoomCraftColors? _colors;
  String _snapKey = '';
  DateTime _lastClick = DateTime(0);

  EditorState get _s => widget.state;
  EditorController get _c => widget.controller;

  Scene? _ghostScene;
  List<ItemNode>? _ghostItems;

  /// The real items shown faint under a draft; the same list while the room
  /// is unchanged, so the 3D layer is not told twice.
  List<ItemNode>? _ghost() {
    final s = _s;
    if (s.draft == null || s.comparing) return null;
    if (!identical(_ghostScene, s.scene)) {
      _ghostScene = s.scene;
      _ghostItems = s.scene.items.toList();
    }
    return _ghostItems;
  }

  SceneFrame _frame() {
    final s = _s;
    final d = s.drag;
    if (d != null && !d.isOpening) {
      final item = s.workingScene.item(d.id);
      final p = d.position ?? item?.position ?? Vec2.zero;
      return SceneFrame(
        scene: s.workingScene,
        selection: s.selection,
        flagged: s.report.flagged,
        previewId: d.id,
        previewX: p.x,
        previewZ: p.z,
        draft: _ghost(),
      );
    }
    return SceneFrame(
      scene: s.displayScene,
      selection: s.comparing ? null : s.selection,
      flagged: s.comparing ? const {} : s.report.flagged,
      draft: _ghost(),
    );
  }

  @override
  void didUpdateWidget(EditorViews old) {
    super.didUpdateWidget(old);
    if (!identical(old.state, widget.state)) _sync?.update(_frame());
    if (old.state.selection != widget.state.selection &&
        widget.state.selection == null) {
      _anchor3d.value = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = context.colors;
    if (_colors != null && _colors != c) _sync?.theme(c);
    _colors = c;
  }

  @override
  void dispose() {
    _anchor3d.dispose();
    super.dispose();
  }

  Map<String, Object?> _init(SceneBridge bridge) {
    final sync = _sync ??= SceneSync(bridge);
    return sync.init(
      _frame(),
      mode: 'editor',
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      colors: context.colors,
    );
  }

  void _onReady(SceneBridge bridge) {
    _sync!
      ..afterInit(_frame())
      ..camera(_preset);
  }

  void _on3d(WebMessage m) {
    switch (m.type) {
      case FromWeb.tap:
        _source = _Source.view3d;
        _c.select(m.id);
      case FromWeb.dragStart:
        final item = _s.workingScene.item(m.id ?? '');
        if (item == null) return;
        if (!_movedIn3d) setState(() => _movedIn3d = true);
        _source = _Source.view3d;
        _snapKey = '';
        _c.beginDrag(item.id, item.position);
      case FromWeb.dragMove:
        final key = _c.dragTo(Vec2(m.x, m.z));
        final now = DateTime.now();
        if (key != _snapKey &&
            _snapKey.isNotEmpty &&
            now.difference(_lastClick).inMilliseconds >= 100) {
          Haptics.selectionClick();
          _lastClick = now;
        }
        _snapKey = key;
      case FromWeb.dragEnd:
        _c.endDrag();
      case FromWeb.dragCancel:
        _c.cancelDrag();
      case FromWeb.selectionScreen:
        if (m.id == _s.selection) {
          _anchor3d.value = (Offset(m.x, m.y), m.data['visible'] == true);
        }
    }
  }

  void _showMe() {
    final ids = _s.report.flagged;
    widget.plan.focus(ids);
    _sync?.focus(ids);
  }

  ViewMode get _mode =>
      ref.watch(viewModeOverrideProvider) ??
      (ref.watch(view3dEnabledProvider)
          ? ref.watch(settingsProvider.select((s) => s.viewMode))
          : ViewMode.plan);

  @override
  Widget build(BuildContext context) {
    final split = ref.watch(settingsProvider.select((s) => s.viewSplit));
    final can3d = ref.watch(view3dEnabledProvider);
    final mode = _mode;
    return LayoutBuilder(
      builder: (context, box) {
        const divider = 16.0;
        final full = Offset.zero & box.biggest;
        var r3d = full;
        var rPlan = full;
        var rDivider = Rect.zero;
        if (mode == ViewMode.both && widget.landscape) {
          final w3d = (box.maxWidth - divider) * 0.6;
          r3d = Rect.fromLTWH(0, 0, w3d, box.maxHeight);
          rDivider = Rect.fromLTWH(w3d, 0, divider, box.maxHeight);
          rPlan = Rect.fromLTWH(
            w3d + divider,
            0,
            box.maxWidth - w3d - divider,
            box.maxHeight,
          );
        } else if (mode == ViewMode.both) {
          final free = box.maxHeight - divider;
          // With a sheet open the plan comes first, so the whole room and
          // some floor around it stay in view; 3D keeps a strip.
          final h3d = widget.sheetOpen
              ? (free * 0.3)
                    .clamp(120.0, math.max(free - 220, 120.0))
                    .toDouble()
              : (free * split)
                    .clamp(
                      math.min(200.0, free - 200),
                      math.max(free - 200, 0.0),
                    )
                    .toDouble();
          r3d = Rect.fromLTWH(0, 0, box.maxWidth, h3d);
          rDivider = Rect.fromLTWH(0, h3d, box.maxWidth, divider);
          rPlan = Rect.fromLTWH(
            0,
            h3d + divider,
            box.maxWidth,
            box.maxHeight - h3d - divider,
          );
        }
        return Stack(
          children: [
            // Both views stay alive in every mode, so switching is instant
            // and 3D never reloads; the one not shown is simply offstage.
            Positioned.fromRect(
              rect: r3d,
              child: Offstage(
                offstage: mode == ViewMode.plan,
                child: _view3d(context, mode),
              ),
            ),
            if (mode == ViewMode.both)
              Positioned.fromRect(
                rect: rDivider,
                child: _divider(box, divider),
              ),
            Positioned.fromRect(
              rect: rPlan,
              child: Offstage(
                offstage: mode == ViewMode.view3d,
                child: _plan(context, mode),
              ),
            ),
            if (can3d || ref.watch(viewModeOverrideProvider) != null)
              Positioned(
                top: Space.sm,
                left: Space.md,
                right: Space.md,
                child: _controls(mode),
              ),
            if (widget.barActions.isNotEmpty)
              _actionBar(box.biggest, r3d, rPlan, mode),
          ],
        );
      },
    );
  }

  /// View switch on the left; camera and lighting on the right while 3D
  /// is in view.
  Widget _controls(ViewMode mode) {
    final compact = mode == ViewMode.both && widget.sheetOpen;
    return Row(
      children: [
        Over3D(
          child: ViewSwitch(
            value: mode,
            onChanged: (m) {
              Haptics.selectionClick();
              ref.read(settingsProvider.notifier).setViewMode(m);
            },
          ),
        ),
        const Spacer(),
        if (mode != ViewMode.plan && !compact) ...[
          Over3D(
            child: _CameraButton(
              value: _preset,
              onChanged: (p) {
                setState(() => _preset = p);
                _sync?.camera(p);
              },
            ),
          ),
          const SizedBox(width: Space.xs),
          Over3D(
            child: _OverlayButton(
              icon: Icons.lightbulb_outline_rounded,
              tooltip: S.lightingTitle,
              onPressed: widget.onLighting,
            ),
          ),
        ],
      ],
    );
  }

  /// Warnings, offline and preview notices, shown over the main view.
  Widget _notices() => Over3D(child: _noticeColumn());

  Widget _noticeColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SlideBanner(
        show: _s.draft != null,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: RoomCraftBanner(
            message: S.previewing(_s.draft?.label ?? ''),
            tone: BannerTone.calm,
          ),
        ),
      ),
      SlideBanner(
        show: !widget.online,
        child: const Padding(
          padding: EdgeInsets.only(top: Space.sm),
          child: RoomCraftBanner(
            message: S.offlineEditor,
            tone: BannerTone.info,
          ),
        ),
      ),
      SlideBanner(
        show: !_s.report.isValid,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: RoomCraftBanner(
            message: _s.report.headline ?? '',
            actionLabel: S.showMe,
            onAction: _showMe,
          ),
        ),
      ),
    ],
  );

  /// Room for the controls row over a view.
  static const _controlsHeight = Sizes.touch + Space.sm;

  Widget _view3d(BuildContext context, ViewMode mode) {
    final alone = mode == ViewMode.view3d;
    final items = _s.scene.items.isNotEmpty;
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: View3D(
              buildInit: _init,
              onReady: _onReady,
              onMessage: _on3d,
            ),
          ),
          if (alone)
            Positioned(
              top: _controlsHeight,
              left: Space.md,
              right: Space.md,
              child: _notices(),
            ),
          if (alone && !items)
            Positioned(
              left: Space.lg,
              right: Space.lg,
              bottom: Space.lg,
              child: Center(child: EmptyRoomHint(landscape: widget.landscape)),
            ),
          if (alone && items && !_movedIn3d && _s.selection == null)
            const Positioned(
              left: Space.lg,
              right: Space.lg,
              bottom: Space.lg,
              child: Center(
                child: PlanPill(
                  child: Text(S.hint3d, textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _divider(BoxConstraints box, double size) {
    final c = context.colors;
    final handle = Container(
      width: widget.landscape ? 4 : 40,
      height: widget.landscape ? 40 : 4,
      decoration: BoxDecoration(
        color: c.fieldBorder,
        borderRadius: BorderRadius.circular(Radii.round),
      ),
    );
    if (widget.landscape) {
      return ColoredBox(
        color: c.background,
        child: Center(child: handle),
      );
    }
    return Semantics(
      label: S.dragToResize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) {
          final settings = ref.read(settingsProvider.notifier);
          final free = box.maxHeight - size;
          settings.setViewSplit(
            ref.read(settingsProvider).viewSplit + d.delta.dy / free,
          );
        },
        child: ColoredBox(
          color: c.background,
          child: Center(child: handle),
        ),
      ),
    );
  }

  /// Space above the room in the plan: the controls row when the plan is
  /// shown alone, then any notices, so neither covers the furniture.
  double _planTop(BuildContext context, double inset) {
    final s = _s;
    final shown = [
      s.draft != null,
      !widget.online,
      !s.report.isValid,
    ].where((b) => b).length;
    if (shown == 0) return inset;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    // Matches where the notices are placed: below the label row, each one
    // a touch target tall with a small gap, plus a little air.
    return inset +
        Space.sm +
        PresetPill.height +
        Space.xs +
        shown * (Space.sm + Sizes.touch * scale) +
        Space.sm;
  }

  /// The controls row sits over the plan only when it is shown alone.
  double _planInset(ViewMode mode) =>
      mode == ViewMode.plan && ref.watch(view3dEnabledProvider)
      ? _controlsHeight
      : 0;

  Widget _plan(BuildContext context, ViewMode mode) {
    final s = _s;
    final drag = s.drag;
    final inset = _planInset(mode);
    return Stack(
      children: [
        AnimatedPositioned(
          duration: motion(context, Motion.medium),
          curve: Motion.curve,
          top: _planTop(context, inset),
          left: 0,
          right: 0,
          bottom: 0,
          child: PlanView(
            scene: s.displayScene,
            controller: widget.plan,
            unit: widget.unit,
            lastAdded: s.lastAdded,
            ghost: s.draft != null && !s.comparing ? s.scene : null,
            onItemAction: s.comparing ? null : widget.onItemAction,
            overlay: PlanOverlay(
              selection: s.selection,
              flagged: s.report.flagged,
              dragging: drag == null || drag.isOpening ? null : drag.id,
              guides: drag?.guides ?? const [],
            ),
            actions: PlanActions(
              select: (id) {
                _source = _Source.plan;
                _c.select(id);
              },
              beginDrag: (id, p) {
                _source = _Source.plan;
                _c.beginDrag(id, p);
              },
              dragTo: _c.dragTo,
              endDrag: _c.endDrag,
              cancelDrag: _c.cancelDrag,
            ),
          ),
        ),
        Positioned(
          top: inset + Space.sm,
          left: Space.md,
          right: Space.md,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.selectionText != null)
                Flexible(
                  child: PlanPill(
                    child: Text(
                      widget.selectionText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: Space.sm),
              UnitChip(unit: widget.unit),
            ],
          ),
        ),
        // Warnings and notices sit over the plan, which always has room,
        // so they are never cut off by a short 3D view.
        Positioned(
          top: inset + Space.sm + PresetPill.height + Space.xs,
          left: Space.md,
          right: Space.md,
          child: _notices(),
        ),
        if (s.scene.items.isEmpty)
          Positioned(
            left: Space.lg,
            right: Space.lg,
            bottom: Space.lg,
            child: Center(child: EmptyRoomHint(landscape: widget.landscape)),
          ),
      ],
    );
  }

  /// 12 dp above the selection in whichever view it was chosen; docked at the
  /// top of the 3D view when the item is off-screen there.
  Widget _actionBar(Size bounds, Rect r3d, Rect rPlan, ViewMode mode) =>
      ListenableBuilder(
        listenable: Listenable.merge([widget.plan, _anchor3d]),
        builder: (context, _) {
          Rect? target;
          final use3d =
              mode == ViewMode.view3d ||
              (mode == ViewMode.both && _source == _Source.view3d);
          if (use3d && _anchor3d.value != null) {
            final (p, visible) = _anchor3d.value!;
            target = visible
                ? Rect.fromCenter(center: r3d.topLeft + p, width: 1, height: 1)
                : Rect.fromLTWH(
                    r3d.center.dx,
                    r3d.top + _controlsHeight + InspectorBar.height + Space.md,
                    1,
                    1,
                  );
          } else if (!use3d && widget.plan.selectionRect != null) {
            target = widget.plan.selectionRect!.shift(
              rPlan.topLeft + Offset(0, _planTop(context, _planInset(mode))),
            );
          }
          if (target == null) return const SizedBox.shrink();
          final w = InspectorBar.widthFor(widget.barActions.length);
          const h = InspectorBar.height;
          final left = (target.center.dx - w / 2)
              .clamp(Space.sm, math.max(Space.sm, bounds.width - w - Space.sm))
              .toDouble();
          var top = target.top - Space.md - h;
          if (top < Space.sm + PresetPill.height + Space.xs) {
            top = target.bottom + Space.md;
          }
          top = top
              .clamp(Space.sm, math.max(Space.sm, bounds.height - h - Space.sm))
              .toDouble();
          final hidden = _s.drag != null;
          return Positioned(
            left: left,
            top: top,
            child: IgnorePointer(
              ignoring: hidden,
              child: AnimatedOpacity(
                opacity: hidden ? 0 : 1,
                duration: motion(context, Motion.fast),
                child: Over3D(child: InspectorBar(actions: widget.barActions)),
              ),
            ),
          );
        },
      );
}

/// Corner, Top and Eye level; the active one is filled.
class PresetPill extends StatelessWidget {
  const PresetPill({required this.value, required this.onChanged, super.key});

  static const height = 36.0;

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const options = {
      'corner': S.cameraCorner,
      'top': S.cameraTop,
      'eye': S.cameraEye,
    };
    return Container(
      height: height,
      padding: const EdgeInsets.all(Space.xs / 2),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.fieldBorder.withValues(alpha: 0.6)),
      ),
      // Large text scales the pill down rather than cutting a camera name.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in options.entries)
              Semantics(
                button: true,
                selected: e.key == value,
                child: GestureDetector(
                  onTap: () => onChanged(e.key),
                  child: AnimatedContainer(
                    duration: motion(context, Motion.fast),
                    padding: const EdgeInsets.symmetric(horizontal: Space.md),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == value
                          ? c.primaryAction
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    child: Text(
                      e.value,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: e.key == value
                            ? c.onPrimaryAction
                            : c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UnitChip extends ConsumerWidget {
  const UnitChip({required this.unit, super.key});

  final DisplayUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlanPill(
    semantics: S.switchUnit,
    onTap: () => ref.read(settingsProvider.notifier).toggleUnit(),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.straighten_rounded,
          size: 16,
          color: context.colors.textSecondary,
        ),
        const SizedBox(width: Space.xs),
        Text(unit.symbol),
      ],
    ),
  );
}

/// Slides a banner down into place over 200 ms.
class SlideBanner extends StatelessWidget {
  const SlideBanner({required this.show, required this.child, super.key});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: motion(context, Motion.medium),
    curve: Motion.curve,
    alignment: Alignment.topCenter,
    child: AnimatedSwitcher(
      duration: motion(context, Motion.medium),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(a),
          child: child,
        ),
      ),
      child: show ? child : const SizedBox(width: double.infinity),
    ),
  );
}

/// A round white button over the 3D view, matching the camera pill.
class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: Sizes.touch,
          child: Center(
            child: Material(
              color: c.surface.withValues(alpha: 0.94),
              shape: const CircleBorder(),
              elevation: 2,
              shadowColor: c.shadow,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: Sizes.chip,
                  child: Icon(icon, size: 20, color: c.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 3D, 2D or Both: a white pill over the views; the chosen one is solid.
class ViewSwitch extends StatelessWidget {
  const ViewSwitch({required this.value, required this.onChanged, super.key});

  final ViewMode value;
  final ValueChanged<ViewMode> onChanged;

  static const _options = [
    (ViewMode.view3d, Icons.view_in_ar_rounded, S.view3d),
    (ViewMode.plan, Icons.grid_view_rounded, S.view2d),
    (ViewMode.both, Icons.splitscreen_rounded, S.viewBoth),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: Sizes.chip,
      padding: const EdgeInsets.all(Space.xs / 2),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(Radii.round),
        boxShadow: softShadow(c),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (mode, icon, label) in _options)
              Semantics(
                button: true,
                selected: mode == value,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onChanged(mode),
                  child: AnimatedContainer(
                    duration: motion(context, Motion.fast),
                    height: Sizes.chip - Space.xs,
                    padding: const EdgeInsets.symmetric(horizontal: Space.md),
                    decoration: BoxDecoration(
                      color: mode == value
                          ? c.primaryAction
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.round),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: mode == value
                              ? c.onPrimaryAction
                              : c.textPrimary,
                        ),
                        const SizedBox(width: Space.xs),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontSize: TypeScale.body,
                                color: mode == value
                                    ? c.onPrimaryAction
                                    : c.textPrimary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A round camera button with Corner, Top and Eye level in a menu.
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = {
    'corner': S.cameraCorner,
    'top': S.cameraTop,
    'eye': S.cameraEye,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<String>(
      tooltip: S.camera,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final e in _options.entries)
          PopupMenuItem(
            value: e.key,
            child: Over3D(
              child: Row(
                children: [
                  Icon(
                    e.key == value
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: e.key == value ? c.primary : c.textSecondary,
                  ),
                  const SizedBox(width: Space.sm),
                  Text(e.value),
                ],
              ),
            ),
          ),
      ],
      child: SizedBox.square(
        dimension: Sizes.touch,
        child: Center(
          child: Container(
            width: Sizes.chip,
            height: Sizes.chip,
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.94),
              shape: BoxShape.circle,
              boxShadow: softShadow(c),
            ),
            child: Icon(
              Icons.videocam_outlined,
              size: 20,
              color: c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
