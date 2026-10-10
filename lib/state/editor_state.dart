import 'package:flutter/foundation.dart';

import '../domain/checks/placement_checker.dart';
import '../domain/checks/snapping.dart';
import '../domain/geometry/vec2.dart';
import '../domain/history/scene_history.dart';
import '../domain/scene/nodes.dart';
import '../domain/scene/scene.dart';
import '../domain/scene/scene_json.dart';

/// A drag in progress. Positions here are transient: never saved or undone.
@immutable
class DragSession {
  const DragSession({
    required this.id,
    required this.grab,
    required this.isOpening,
    this.position,
    this.offset,
    this.guides = const [],
    this.snapKey = '',
  });

  final String id;

  /// Pointer minus the node's centre at the start, so the item does not jump.
  final Vec2 grab;
  final bool isOpening;

  /// Snapped centre of a dragged item.
  final Vec2? position;

  /// Offset along the wall of a dragged door or window.
  final double? offset;
  final List<SnapGuide> guides;
  final String snapKey;

  DragSession copyWith({
    Vec2? position,
    double? offset,
    List<SnapGuide>? guides,
    String? snapKey,
  }) => DragSession(
    id: id,
    grab: grab,
    isOpening: isOpening,
    position: position ?? this.position,
    offset: offset ?? this.offset,
    guides: guides ?? this.guides,
    snapKey: snapKey ?? this.snapKey,
  );
}

/// An AI option opened for preview and editing. Temporary until Apply.
@immutable
class Draft {
  const Draft({
    required this.label,
    required this.name,
    required this.scene,
    required this.scoreBefore,
    required this.scoreAfter,
  });

  /// "Option A" or "Option B".
  final String label;
  final String name;
  final Scene scene;
  final int scoreBefore;
  final int scoreAfter;

  Draft withScene(Scene next, int score) => Draft(
    label: label,
    name: name,
    scene: next,
    scoreBefore: scoreBefore,
    scoreAfter: score,
  );
}

@immutable
class EditorState {
  const EditorState({
    required this.project,
    required this.history,
    required this.report,
    this.selection,
    this.drag,
    this.lastAdded,
    this.draft,
    this.comparing = false,
    this.merge,
  });

  /// Wrapper fields (id, name, unit). Its scene is not kept current; use
  /// [scene].
  final ProjectFile project;
  final SceneHistory history;

  /// Report for what is on screen, including a drag in progress.
  final ValidationReport report;

  /// Selected item or opening id.
  final String? selection;
  final DragSession? drag;

  /// The item that just arrived, for its pop-in.
  final String? lastAdded;

  /// An AI draft being previewed; edits go to it instead of the room.
  final Draft? draft;

  /// "Hold to compare" is pressed: show the real layout.
  final bool comparing;

  /// The latest changes merged in from the cloud, for a one-time toast.
  final MergeInfo? merge;

  Scene get scene => history.present;

  /// What edits apply to: the draft while one is open, else the room.
  Scene get workingScene => draft?.scene ?? scene;

  /// The committed scene with any drag applied: what both views draw.
  Scene get displayScene {
    if (comparing) return scene;
    final base = workingScene;
    final d = drag;
    if (d == null) return base;
    if (d.isOpening) {
      final o = base.opening(d.id);
      return o == null || d.offset == null
          ? base
          : base.withNode(o.copyWith(offset: d.offset));
    }
    final i = base.item(d.id);
    return i == null || d.position == null
        ? base
        : base.withNode(i.at(d.position!));
  }

  ItemNode? get selectedItem =>
      selection == null ? null : displayScene.item(selection!);
  OpeningNode? get selectedOpening =>
      selection == null ? null : displayScene.opening(selection!);

  bool get canUndo => draft == null && history.canUndo;
  bool get canRedo => draft == null && history.canRedo;

  ProjectFile get currentFile => project.copyWith(scene: scene);

  EditorState copyWith({
    ProjectFile? project,
    SceneHistory? history,
    ValidationReport? report,
    String? Function()? selection,
    DragSession? Function()? drag,
    String? Function()? lastAdded,
    Draft? Function()? draft,
    bool? comparing,
    MergeInfo? merge,
  }) => EditorState(
    project: project ?? this.project,
    history: history ?? this.history,
    report: report ?? this.report,
    selection: selection != null ? selection() : this.selection,
    drag: drag != null ? drag() : this.drag,
    lastAdded: lastAdded != null ? lastAdded() : this.lastAdded,
    draft: draft != null ? draft() : this.draft,
    comparing: comparing ?? this.comparing,
    merge: merge ?? this.merge,
  );
}

/// A merge the editor took in. [seq] changes every time, so the screen can
/// tell two merges with the same conflict count apart.
@immutable
class MergeInfo {
  const MergeInfo(this.seq, this.conflicts);
  final int seq;
  final int conflicts;
}
