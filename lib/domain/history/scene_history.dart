import '../constants.dart';
import '../scene/scene.dart';

/// Undo and redo over immutable scenes. Snapshots share structure, so they
/// are cheap. Transient nodes are stripped before anything is stored.
class SceneHistory {
  SceneHistory(Scene present, {this.limit = historyLimit})
    : present = present.persistent,
      past = const [],
      future = const [];

  const SceneHistory._(this.past, this.present, this.future, this.limit);

  final List<Scene> past;
  final Scene present;
  final List<Scene> future;
  final int limit;

  bool get canUndo => past.isNotEmpty;
  bool get canRedo => future.isNotEmpty;

  /// Pushes the present, clears the future and drops the oldest step beyond
  /// the limit. Committing an equal scene changes nothing.
  SceneHistory commit(Scene next) {
    final clean = next.persistent;
    if (clean == present) return this;
    final newPast = [...past, present];
    if (newPast.length > limit) newPast.removeRange(0, newPast.length - limit);
    return SceneHistory._(List.unmodifiable(newPast), clean, const [], limit);
  }

  SceneHistory undo() {
    if (!canUndo) return this;
    return SceneHistory._(
      List.unmodifiable(past.sublist(0, past.length - 1)),
      past.last,
      List.unmodifiable([present, ...future]),
      limit,
    );
  }

  SceneHistory redo() {
    if (!canRedo) return this;
    return SceneHistory._(
      List.unmodifiable([...past, present]),
      future.first,
      List.unmodifiable(future.sublist(1)),
      limit,
    );
  }
}
