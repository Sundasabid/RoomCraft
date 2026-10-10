import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_projects.dart';
import '../domain/checks/free_spot.dart';
import '../domain/checks/layout_validator.dart';
import '../domain/checks/movement_score.dart';
import '../domain/checks/placement_checker.dart';
import '../domain/checks/snapping.dart';
import '../domain/constants.dart';
import '../domain/geometry/vec2.dart';
import '../domain/history/scene_history.dart';
import '../domain/scene/catalogue.dart';
import '../domain/scene/finishes.dart';
import '../domain/scene/ids.dart';
import '../domain/scene/lighting.dart';
import '../domain/scene/nodes.dart';
import '../domain/scene/rooms.dart';
import '../domain/scene/scene.dart';
import '../domain/sync/scene_merge.dart';
import 'cloud_sync.dart';
import 'editor_state.dart';
import 'projects_controller.dart';

/// Thrown when a project cannot be opened.
class ProjectMissing implements Exception {
  const ProjectMissing();
}

double _mm(double v) => (v * 1000).roundToDouble() / 1000;

/// The only writer of the scene. Every method builds a new immutable Scene;
/// accepted changes go through [_commit], which records one undo step and
/// schedules a save. Drags stay transient until they end.
class EditorController extends AsyncNotifier<EditorState> {
  EditorController(this.projectId);

  final String projectId;
  late AutosaveQueue _autosave;

  LocalProjectStore get _store => ref.read(localStoreProvider);

  @override
  Future<EditorState> build() async {
    // The cloud upload is queued once the local file is written, because
    // uploads read the local copy.
    _autosave = AutosaveQueue((p) async {
      await _store.save(p);
      if (ref.mounted) ref.read(cloudSyncProvider.notifier).schedule(p);
    });
    ref.onDispose(() => unawaited(_autosave.flush()));
    final merges = ref
        .read(cloudSyncProvider.notifier)
        .merges
        .where((n) => n.id == projectId)
        .listen(_takeMerge);
    ref.onDispose(merges.cancel);
    // Missing on this device: recover the cloud copy.
    final project =
        await _store.load(projectId) ??
        await ref.read(cloudSyncProvider.notifier).download(projectId);
    if (project == null) throw const ProjectMissing();
    return EditorState(
      project: project,
      history: SceneHistory(project.scene),
      report: PlacementChecker.checkScene(project.scene),
    );
  }

  EditorState? get _s => state.value;

  void _set(EditorState next) => state = AsyncData(next);

  /// One accepted change: one history step, a fresh report and a save.
  /// While an AI draft is open the change goes to the draft instead, with no
  /// history and no save.
  void _commit(
    Scene next, {
    String? Function()? select,
    String? Function()? added,
  }) {
    final s = _s;
    if (s == null) return;
    final draft = s.draft;
    if (draft != null) {
      _set(
        s.copyWith(
          draft: () => draft.withScene(next, MovementScore.of(next).score),
          report: PlacementChecker.checkScene(next),
          selection: select,
          drag: () => null,
          lastAdded: added ?? () => null,
        ),
      );
      return;
    }
    final history = s.history.commit(next);
    if (identical(history, s.history) && select == null) return;
    final project = s.project.copyWith(updatedAt: DateTime.now().toUtc());
    _set(
      s.copyWith(
        project: project,
        history: history,
        report: PlacementChecker.checkScene(history.present),
        selection: select,
        drag: () => null,
        lastAdded: added ?? () => null,
      ),
    );
    _save();
  }

  /// Folds a merge made by the cloud sync into what is open now. The merge
  /// started from [MergeNotice.before]; anything changed here since then is
  /// kept by merging once more. It is one undo step, made even while an AI
  /// draft is open, since it changes the real room.
  void _takeMerge(MergeNotice n) {
    final s = _s;
    if (s == null) return;
    final now = SceneMerge.merge(n.before.scene, s.scene, n.merged.scene);
    final (name, _) = SceneMerge.mergeValue(
      n.before.name,
      s.project.name,
      n.merged.name,
    );
    final history = s.history.commit(now.scene);
    if (identical(history, s.history) && name == s.project.name) return;
    final project = s.project.copyWith(
      name: name,
      updatedAt: DateTime.now().toUtc(),
    );
    _set(
      s.copyWith(
        project: project,
        history: history,
        report: s.draft == null
            ? PlacementChecker.checkScene(history.present)
            : null,
        selection:
            s.selection != null &&
                history.present.nodes[s.selection] == null &&
                s.draft == null
            ? () => null
            : null,
        merge: MergeInfo((s.merge?.seq ?? 0) + 1, n.conflicts + now.conflicts),
      ),
    );
    _save();
  }

  // AI drafts

  /// Opens an AI option as a draft over the faint real layout.
  void openDraft(LayoutOption option, String label, int scoreBefore) {
    final s = _s;
    if (s == null) return;
    _set(
      s.copyWith(
        draft: () => Draft(
          label: label,
          name: option.name,
          scene: option.scene,
          scoreBefore: scoreBefore,
          scoreAfter: option.score,
        ),
        report: PlacementChecker.checkScene(option.scene),
        selection: () => null,
        drag: () => null,
        comparing: false,
      ),
    );
  }

  /// Shows the real layout while "Hold to compare" is pressed.
  void compare(bool on) {
    final s = _s;
    if (s == null || s.draft == null || s.comparing == on) return;
    _set(s.copyWith(comparing: on));
  }

  /// Commits a valid draft as one undo step. Returns the draft, or null when
  /// it could not be applied.
  Draft? applyDraft() {
    final s = _s;
    final draft = s?.draft;
    if (s == null || draft == null) return null;
    if (!PlacementChecker.checkScene(draft.scene).isValid) return null;
    _set(
      s.copyWith(draft: () => null, comparing: false, selection: () => null),
    );
    _commit(draft.scene);
    return draft;
  }

  void discardDraft() {
    final s = _s;
    if (s == null || s.draft == null) return;
    _set(
      s.copyWith(
        draft: () => null,
        comparing: false,
        selection: () => null,
        drag: () => null,
        report: PlacementChecker.checkScene(s.scene),
      ),
    );
  }

  void _save() {
    final s = _s;
    if (s == null) return;
    final file = s.currentFile;
    _autosave.schedule(file);
    ref.read(projectsProvider.notifier).updated(file);
    // Uploads read the local file, so the local write lands first.
    unawaited(
      _autosave.flush().then(
        (_) => ref.read(cloudSyncProvider.notifier).schedule(file),
      ),
    );
  }

  /// Writes anything pending; called when leaving the editor.
  Future<void> flush() => _autosave.flush();

  // Selection

  void select(String? id) {
    final s = _s;
    if (s == null || s.selection == id) return;
    _set(s.copyWith(selection: () => id));
  }

  // Furniture

  /// Adds an item at the nearest free spot and selects it. Returns false at
  /// the item limit.
  bool addItem(String catalogueId) {
    final s = _s;
    if (s == null || s.workingScene.items.length >= maxItems) return false;
    final spot = findFreeSpot(s.workingScene, catalogueId);
    final item = ItemNode(
      id: newNodeId('item'),
      parentId: s.workingScene.rootId,
      catalogueId: catalogueId,
      x: spot.x,
      z: spot.z,
      finish: Catalogue.byId(catalogueId).defaultFinish,
    );
    _commit(
      s.workingScene.withNode(item),
      select: () => item.id,
      added: () => item.id,
    );
    return true;
  }

  void rotateSelected() =>
      _updateItem((i) => i.copyWith(rotation: (i.rotation + 90) % 360));

  /// Copies the selected item to the nearest clean spot beside it.
  bool duplicateSelected() {
    final s = _s;
    final item = s?.selectedItem;
    if (s == null || item == null || s.workingScene.items.length >= maxItems) {
      return false;
    }
    final spot = findFreeSpot(
      s.workingScene,
      item.catalogueId,
      rotation: item.rotation,
      near: item.position,
    );
    final copy = ItemNode(
      id: newNodeId('item'),
      parentId: item.parentId,
      catalogueId: item.catalogueId,
      x: spot.x,
      z: spot.z,
      rotation: item.rotation,
      finish: item.finish,
    );
    _commit(
      s.workingScene.withNode(copy),
      select: () => copy.id,
      added: () => copy.id,
    );
    return true;
  }

  void toggleLockSelected() =>
      _updateItem((i) => i.copyWith(locked: !i.locked));

  void setItemFinish(String finish) {
    if (!Finishes.has(finish)) return;
    _updateItem((i) => i.copyWith(finish: finish));
  }

  /// Moves an item by a fixed step; the non-touch alternative to dragging.
  void nudge(String id, double dx, double dz) {
    final s = _s;
    final item = s?.workingScene.item(id);
    if (s == null || item == null) return;
    _commit(
      s.workingScene.withNode(
        item.copyWith(x: _mm(item.x + dx), z: _mm(item.z + dz)),
      ),
    );
  }

  void _updateItem(ItemNode Function(ItemNode) change) {
    final s = _s;
    final item = s?.selection == null
        ? null
        : s!.workingScene.item(s.selection!);
    if (s == null || item == null) return;
    _commit(s.workingScene.withNode(change(item)));
  }

  /// Deletes the selected item or opening. Returns what was deleted.
  Node? deleteSelected() {
    final s = _s;
    final id = s?.selection;
    if (s == null || id == null) return null;
    final node = s.workingScene.nodes[id];
    if (node == null || node is RoomNode) return null;
    _commit(s.workingScene.without([id]), select: () => null);
    return node;
  }

  // Room

  void setFloorFinish(String finish) {
    final s = _s;
    if (s == null || !Finishes.has(finish)) return;
    _commit(
      s.workingScene.withNode(
        s.workingScene.room.copyWith(floorFinish: finish),
      ),
    );
  }

  /// Changes the room's lighting mood; one undo step, synced like a finish.
  void setLighting(String id) {
    final s = _s;
    if (s == null || !Lighting.has(id)) return;
    final room = s.workingScene.room;
    if (room.lighting == id) return;
    _commit(s.workingScene.withNode(room.copyWith(lighting: id)));
  }

  void setWallFinish(String finish) {
    final s = _s;
    if (s == null || !Finishes.has(finish)) return;
    _commit(
      s.workingScene.withNode(s.workingScene.room.copyWith(wallFinish: finish)),
    );
  }

  Future<void> rename(String name) async {
    final s = _s;
    final clean = name.trim();
    if (s == null || clean.isEmpty) return;
    final clipped = clean.length > maxNameLength
        ? clean.substring(0, maxNameLength)
        : clean;
    _set(s.copyWith(project: s.project.copyWith(name: clipped)));
    _commit(
      s.workingScene.withNode(s.workingScene.room.copyWith(name: clipped)),
    );
    if (s.workingScene.room.name == clipped) _save();
  }

  // Doors and windows

  void resizeSelectedOpening(double by) {
    final s = _s;
    final o = s?.selectedOpening;
    if (s == null || o == null) return;
    final w =
        ((o.width + by).clamp(
                  OpeningRules.minWidth(o.kind),
                  OpeningRules.maxWidth(o.kind),
                ) *
                100)
            .roundToDouble() /
        100;
    final offset = OpeningRules.clampOffset(
      scene: s.workingScene,
      wallIndex: o.wallIndex,
      width: w,
      offset: o.offset,
      ignoreId: o.id,
    );
    if (offset == null) return;
    _commit(s.workingScene.withNode(o.copyWith(width: w, offset: _mm(offset))));
  }

  // Dragging: transient until endDrag, which commits once.

  void beginDrag(String id, Vec2 pointer) {
    final s = _s;
    if (s == null) return;
    final item = s.workingScene.item(id);
    final opening = s.workingScene.opening(id);
    if (item == null && opening == null) return;
    final centre =
        item?.position ?? openingCentre(s.workingScene.room, opening!);
    _set(
      s.copyWith(
        selection: () => id,
        drag: () => DragSession(
          id: id,
          grab: pointer - centre,
          isOpening: opening != null,
        ),
      ),
    );
  }

  /// Moves the dragged node under the pointer, snapped. Returns the snap key
  /// so the view can click when the target changes.
  String dragTo(Vec2 pointer) {
    final s = _s;
    final d = s?.drag;
    if (s == null || d == null) return '';
    if (d.isOpening) {
      _dragOpening(s, d, pointer);
      return '';
    }
    final item = s.workingScene.item(d.id);
    if (item == null) return '';
    final fp = footprintAt(item, Vec2.zero);
    final others = [
      for (final o in s.workingScene.items)
        if (o.id != item.id && o.visible) footprintOf(o),
    ];
    final snap = Snapper.snap(
      raw: pointer - d.grab,
      width: fp.width,
      depth: fp.depth,
      corners: s.workingScene.corners,
      others: others,
    );
    if (snap.position == d.position) return d.snapKey;
    _set(
      s.copyWith(
        drag: () => d.copyWith(
          position: snap.position,
          guides: snap.guides,
          snapKey: snap.key,
        ),
        report: PlacementChecker.checkScene(
          s.workingScene,
          positions: {item.id: snap.position},
        ),
      ),
    );
    return snap.key;
  }

  void _dragOpening(EditorState s, DragSession d, Vec2 pointer) {
    final o = s.workingScene.opening(d.id);
    if (o == null) return;
    final corners = s.workingScene.corners;
    final a = corners[o.wallIndex];
    final b = corners[(o.wallIndex + 1) % corners.length];
    final along = (pointer - d.grab - a).dot((b - a).normalized);
    final offset = OpeningRules.clampOffset(
      scene: s.workingScene,
      wallIndex: o.wallIndex,
      width: o.width,
      offset: along,
      ignoreId: o.id,
    );
    if (offset == null || offset == d.offset) return;
    final next = s.copyWith(drag: () => d.copyWith(offset: _mm(offset)));
    _set(next.copyWith(report: PlacementChecker.checkScene(next.displayScene)));
  }

  /// Commits the drag as one undo step if anything moved.
  void endDrag() {
    final s = _s;
    final d = s?.drag;
    if (s == null || d == null) return;
    final moved = s.displayScene;
    if (moved == s.workingScene) {
      _set(
        s.copyWith(
          drag: () => null,
          report: PlacementChecker.checkScene(s.workingScene),
        ),
      );
      return;
    }
    _commit(moved, select: () => d.id);
  }

  /// A second finger landed: the node returns to where it was.
  void cancelDrag() {
    final s = _s;
    if (s == null || s.drag == null) return;
    _set(
      s.copyWith(
        drag: () => null,
        report: PlacementChecker.checkScene(s.workingScene),
      ),
    );
  }

  // History

  void undo() => _restore(_s?.history.undo());
  void redo() => _restore(_s?.history.redo());

  void _restore(SceneHistory? history) {
    final s = _s;
    if (s?.draft != null) return; // a draft is previewed, not undone
    if (s == null || history == null || identical(history, s.history)) return;
    final keep =
        s.selection != null && history.present.nodes.containsKey(s.selection);
    _set(
      s.copyWith(
        history: history,
        report: PlacementChecker.checkScene(history.present),
        selection: keep ? null : () => null,
        drag: () => null,
        lastAdded: () => null,
        project: s.project.copyWith(updatedAt: DateTime.now().toUtc()),
      ),
    );
    _save();
  }
}

final editorProvider = AsyncNotifierProvider.autoDispose
    .family<EditorController, EditorState, String>(
      EditorController.new,
      // A missing room is not fixed by trying again.
      retry: (_, _) => null,
    );
