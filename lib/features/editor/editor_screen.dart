import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../core/units.dart';
import '../../domain/checks/placement_checker.dart';
import '../../domain/constants.dart';
import '../../domain/scene/rooms.dart';
import '../../state/ai_controller.dart';
import '../../state/connectivity_provider.dart';
import '../../state/editor_controller.dart';
import '../../state/editor_state.dart';
import '../../state/settings_controller.dart';
import '../../state/share_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/fields.dart';
import '../../widgets/live_badge.dart';
import '../../widgets/placeholders.dart';
import '../../widgets/surfaces.dart';
import 'ai_panel.dart';
import 'catalogue_sheet.dart';
import 'editor_chrome.dart';
import 'editor_panel.dart';
import 'editor_views.dart';
import 'finishes_sheet.dart';
import 'inspector_bar.dart';
import 'plan_view/plan_semantics.dart';
import 'plan_view/plan_view.dart';
import 'share_sheet.dart';

class EditorScreen extends ConsumerWidget {
  const EditorScreen({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(editorProvider(projectId));
    return switch (editor) {
      AsyncData() => _Editor(projectId: projectId),
      AsyncError() => Scaffold(
        appBar: AppBar(
          leading: RoomCraftIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: S.back,
            onPressed: () => context.go('/rooms'),
          ),
        ),
        body: EmptyState(
          title: S.genericError,
          body: '',
          actionLabel: S.tryAgain,
          onAction: () => ref.invalidate(editorProvider(projectId)),
        ),
      ),
      _ => const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Skeleton(radius: Radii.card),
          ),
        ),
      ),
    };
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _plan = PlanViewController();
  // Keeps the 3D view alive when rotation moves it to a new parent.
  final _viewsKey = GlobalKey();

  /// One controller per sheet: switching straight from one tool to another
  /// briefly has both sheets on screen, and a controller can drive only one.
  final _controllers = {
    for (final s in EditorSheet.values) s: DraggableScrollableController(),
  };

  DraggableScrollableController get _sheetController =>
      _controllers[_sheet ?? EditorSheet.catalogue]!;

  EditorSheet? _sheet;
  FinishTab _finishTarget = FinishTab.floor;

  EditorController get _c =>
      ref.read(editorProvider(widget.projectId).notifier);
  EditorState get _s => ref.read(editorProvider(widget.projectId)).requireValue;

  @override
  void dispose() {
    _plan.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _leave() async {
    await _c.flush();
    if (mounted) context.go('/rooms');
  }

  void _openSheet(EditorSheet sheet) {
    setState(() {
      if (_sheet == sheet) {
        _sheet = null;
        return;
      }
      _sheet = sheet;
      if (sheet == EditorSheet.finishes) {
        _finishTarget = _s.selectedItem != null
            ? FinishTab.item
            : FinishTab.floor;
      }
    });
  }

  void _add(String catalogueId) {
    if (!_c.addItem(catalogueId)) {
      unawaited(showToast(context, S.roomFullToast));
      return;
    }
    unawaited(Haptics.selectionClick());
  }

  Future<void> _delete() async {
    if (_c.deleteSelected() == null) return;
    unawaited(Haptics.lightImpact());
    final after = _s.scene;
    final undone = await showToast(
      context,
      S.itemDeleted,
      withUndo: true,
      bottomOffset: Sizes.toolbar,
    );
    if (undone && mounted && _s.scene == after) {
      _c.undo();
      unawaited(Haptics.lightImpact());
    }
  }

  Future<void> _apply() async {
    final draft = _c.applyDraft();
    if (draft == null) return;
    unawaited(Haptics.lightImpact());
    ref.read(aiControllerProvider.notifier).reset();
    final after = _s.scene;
    final undone = await showToast(
      context,
      S.layoutApplied(draft.scoreBefore, draft.scoreAfter),
      withUndo: true,
      bottomOffset: Sizes.toolbar,
    );
    if (undone && mounted && _s.scene == after) {
      _c.undo();
      unawaited(Haptics.lightImpact());
    }
  }

  void _discard() {
    _c.discardDraft();
    setState(() => _sheet = EditorSheet.ai);
  }

  void _closeSheet() {
    if (_sheet == EditorSheet.ai &&
        ref.read(aiControllerProvider) is AiWorking) {
      ref.read(aiControllerProvider.notifier).cancel();
    }
    setState(() => _sheet = null);
  }

  Future<void> _rename() async {
    final name = _s.project.name;
    final controller = TextEditingController(text: name)
      ..selection = TextSelection(baseOffset: 0, extentOffset: name.length);
    final next = await showRoomCraftDialog<String>(
      context,
      title: S.renameRoom,
      body: RoomCraftTextField(
        controller: controller,
        label: S.roomName,
        maxLength: maxNameLength,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        RoomCraftTextButton(
          label: S.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        RoomCraftTextButton(
          label: S.save,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    );
    controller.dispose();
    if (next != null) await _c.rename(next);
  }

  /// Screen reader actions on a plan item: select it, then act as the
  /// action bar would.
  void _itemAction(String id, PlanItemAction action) {
    _c.select(id);
    if (action.isMove) {
      final (dx, dz) = action.offset;
      _c.nudge(id, dx, dz);
      final item = _s.workingScene.item(id);
      if (item != null) {
        unawaited(
          SemanticsService.sendAnnouncement(
            View.of(context),
            spokenItem(_s.displayScene, item, ref.read(settingsProvider).unit),
            TextDirection.ltr,
          ),
        );
      }
      return;
    }
    switch (action) {
      case PlanItemAction.rotate:
        _c.rotateSelected();
        unawaited(Haptics.selectionClick());
      case PlanItemAction.lock:
        _c.toggleLockSelected();
      case PlanItemAction.delete:
        unawaited(_delete());
      default:
    }
  }

  List<BarAction> _barActions(EditorState s) {
    final item = s.selectedItem;
    if (item != null) {
      return [
        BarAction(Icons.rotate_90_degrees_cw_rounded, S.rotate, () {
          _c.rotateSelected();
          Haptics.selectionClick();
        }),
        BarAction(Icons.content_copy_rounded, S.copy, () {
          if (_c.duplicateSelected()) {
            Haptics.selectionClick();
          } else {
            showToast(context, S.roomFullToast);
          }
        }),
        BarAction(Icons.palette_outlined, S.toolFinish, () {
          setState(() {
            _sheet = EditorSheet.finishes;
            _finishTarget = FinishTab.item;
          });
        }),
        BarAction(
          item.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
          item.locked ? S.unlock : S.lock,
          _c.toggleLockSelected,
        ),
        BarAction(
          Icons.delete_outline_rounded,
          S.delete,
          _delete,
          danger: true,
        ),
      ];
    }
    final o = s.selectedOpening;
    if (o == null) return const [];
    return [
      BarAction(
        Icons.close_fullscreen_rounded,
        S.narrower,
        o.width > OpeningRules.minWidth(o.kind) + 1e-9
            ? () => _c.resizeSelectedOpening(-0.1)
            : null,
      ),
      BarAction(
        Icons.open_in_full_rounded,
        S.wider,
        o.width < OpeningRules.maxWidth(o.kind) - 1e-9
            ? () => _c.resizeSelectedOpening(0.1)
            : null,
      ),
      BarAction(Icons.delete_outline_rounded, S.delete, _delete, danger: true),
    ];
  }

  String? _selectionText(EditorState s, DisplayUnit unit) {
    final item = s.selectedItem;
    if (item != null) {
      final r = footprintOf(item);
      return S.selectionLabel(
        s.displayScene.displayName(item.id),
        unit.formatSize(r.width, r.depth),
      );
    }
    final o = s.selectedOpening;
    if (o == null) return null;
    return S.selectionLabel(o.isDoor ? S.door : S.window, unit.format(o.width));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(editorProvider(widget.projectId)).requireValue;
    final unit = ref.watch(settingsProvider.select((x) => x.unit));
    final online = ref.watch(isOnlineProvider);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    ref.listen(
      editorProvider(widget.projectId).select((v) => v.value?.report.headline),
      (before, now) {
        if (now != null && now != before) {
          Haptics.selectionClick();
          SemanticsService.sendAnnouncement(
            View.of(context),
            now,
            TextDirection.ltr,
          );
        }
      },
    );

    ref.listen(editorProvider(widget.projectId).select((v) => v.value?.merge), (
      before,
      now,
    ) {
      if (now == null || now.seq == before?.seq) return;
      unawaited(
        showToast(
          context,
          now.conflicts > 0 ? S.mergedKeptMine : S.mergedChanges,
          bottomOffset: Sizes.toolbar,
        ),
      );
    });

    // Live sharing: every accepted change goes out as the full scene; a drag
    // goes out as throttled previews.
    ref.listen(editorProvider(widget.projectId).select((v) => v.value), (
      before,
      now,
    ) {
      final share = ref.read(shareControllerProvider);
      if (now == null || !share.sharing(widget.projectId)) return;
      final ctl = ref.read(shareControllerProvider.notifier);
      if (before == null ||
          !identical(before.scene, now.scene) ||
          before.project.name != now.project.name) {
        ctl.commit(now.scene, now.project.name);
      }
      final d = now.drag;
      if (d != null && !d.isOpening && d.position != null) {
        ctl.preview(d.id, d.position!.x, d.position!.z);
      }
    });
    // Keeps AI results while a draft is open, for Discard to return to.
    ref.watch(aiControllerProvider);
    final share = ref.watch(shareControllerProvider);
    final sharing = share.sharing(widget.projectId);

    final views = EditorViews(
      key: _viewsKey,
      state: s,
      unit: unit,
      online: online,
      landscape: landscape,
      plan: _plan,
      controller: _c,
      selectionText: _selectionText(s, unit),
      barActions: _barActions(s),
      onItemAction: _itemAction,
      sheetOpen: _sheet != null && !landscape,
      onLighting: () => setState(() {
        _sheet = EditorSheet.finishes;
        _finishTarget = FinishTab.light;
      }),
    );

    final sheetStart = switch (_sheet) {
      EditorSheet.finishes => _finishesSnap(context),
      EditorSheet.catalogue => _traySnap(context),
      // Asking needs the goals and the button in view; each layout brings
      // its own picture of the room.
      EditorSheet.ai => 0.9,
      EditorSheet.share => _shareSnap(context),
      null => 0.6,
    };
    final panel = _sheet == null
        ? null
        : EditorPanel(
            key: ValueKey('$_sheet$landscape'),
            landscape: landscape,
            controller: _sheetController,
            initial: sheetStart,
            snaps: _sheet == EditorSheet.ai ? const [0.6, 0.9] : [sheetStart],
            onClose: _closeSheet,
            builder: (context, scroll) => _sheet == EditorSheet.share
                ? ShareSheet(projectId: widget.projectId, scroll: scroll)
                : _sheet == EditorSheet.ai
                ? AiPanel(
                    projectId: widget.projectId,
                    scroll: scroll,
                    onOpenDraft: (option, label, before) {
                      _c.openDraft(option, label, before);
                      setState(() => _sheet = null);
                    },
                  )
                : _sheet == EditorSheet.catalogue
                ? CatalogueSheet(
                    scroll: scroll,
                    unit: unit,
                    full: s.scene.items.length >= maxItems,
                    onAdd: _add,
                  )
                : _finishes(s, scroll),
          );

    final topBar = EditorTopBar(
      name: s.project.name,
      canUndo: s.canUndo,
      canRedo: s.canRedo,
      onBack: _leave,
      onRename: _rename,
      onUndo: () {
        _c.undo();
        Haptics.lightImpact();
      },
      onRedo: _c.redo,
      trailing: [
        if (sharing)
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: () => setState(() => _sheet = EditorSheet.share),
              child: LiveBadge(trailing: '${share.viewers}'),
            ),
          ),
        const SizedBox(width: Space.sm),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sheet != null) {
          setState(() => _sheet = null);
        } else {
          unawaited(_leave());
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: landscape
              ? Row(
                  children: [
                    EditorToolbar(
                      open: _sheet,
                      onTap: _openSheet,
                      vertical: true,
                      extra: _toolExtras(),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          topBar,
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(child: views),
                                if (s.draft != null)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: DraftBar(
                                      projectId: widget.projectId,
                                      onApply: _apply,
                                      onDiscard: _discard,
                                    ),
                                  ),
                                if (panel != null)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: panel,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    topBar,
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) => Stack(
                          children: [
                            // The room re-fits above an open sheet so it stays visible.
                            Positioned.fill(
                              child: ListenableBuilder(
                                listenable: _sheetController,
                                builder: (context, child) {
                                  final size = panel == null
                                      ? 0.0
                                      : _sheetController.isAttached
                                      ? _sheetController.size
                                      : sheetStart;
                                  final inset = size * box.maxHeight;
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: inset),
                                    child: child,
                                  );
                                },
                                child: views,
                              ),
                            ),
                            if (panel != null) Positioned.fill(child: panel),
                          ],
                        ),
                      ),
                    ),
                    if (s.draft != null)
                      DraftBar(
                        projectId: widget.projectId,
                        onApply: _apply,
                        onDiscard: _discard,
                      ),
                    EditorToolbar(
                      open: _sheet,
                      onTap: _openSheet,
                      extra: _toolExtras(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// The finishes sheet stays low (30 percent) but never cuts off its
  /// swatch names, even with large text.
  /// Live sits with the other tools, one tap away.
  List<Widget> _toolExtras() => [
    ToolButton(
      icon: Icons.sensors_rounded,
      label: S.shareLiveShort,
      active: _sheet == EditorSheet.share,
      onTap: () => _openSheet(EditorSheet.share),
    ),
  ];

  /// Tall enough for the share sheet in either state (the steps before
  /// sharing, the code and buttons after), and no taller. Fixed while open.
  double _shareSnap(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height - Sizes.appBar - Sizes.toolbar;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final need = Space.xl + 440 * scale;
    return (need / h).clamp(0.4, 0.9);
  }

  /// The furniture tray takes only what its one row of cards needs, so
  /// the room stays in view above it.
  double _traySnap(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height - Sizes.appBar - Sizes.toolbar;
    return (CatalogueSheet.heightFor(context) / h).clamp(0.25, 0.6);
  }

  double _finishesSnap(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height - Sizes.appBar - Sizes.toolbar;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final need =
        40 +
        Sizes.touch +
        Space.md +
        28 * scale +
        Space.md +
        100 * scale +
        Space.lg +
        // Room for the hint shown while no furniture is selected. Kept even
        // when something is selected: a sheet whose size changes while it is
        // being built jumps and misbehaves.
        Space.sm +
        34 * scale;
    return (need / h).clamp(0.3, 0.6);
  }

  Widget _finishes(EditorState s, ScrollController scroll) {
    final item = s.selectedItem;
    final target = item == null && _finishTarget == FinishTab.item
        ? FinishTab.floor
        : _finishTarget;
    final current = switch (target) {
      FinishTab.item => item!.finish,
      FinishTab.floor => s.scene.room.floorFinish,
      FinishTab.wall => s.scene.room.wallFinish,
      FinishTab.light => s.workingScene.room.lighting,
    };
    return FinishesSheet(
      scroll: scroll,
      target: target,
      onTarget: (t) => setState(() => _finishTarget = t),
      itemName: item == null ? null : s.scene.displayName(item.id),
      current: current,
      onPick: (f) => switch (target) {
        FinishTab.item => _c.setItemFinish(f),
        FinishTab.floor => _c.setFloorFinish(f),
        FinishTab.wall => _c.setWallFinish(f),
        FinishTab.light => _c.setLighting(f),
      },
    );
  }
}
