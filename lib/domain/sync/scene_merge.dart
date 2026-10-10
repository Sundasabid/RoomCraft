import 'package:collection/collection.dart';

import '../scene/nodes.dart';
import '../scene/scene.dart';
import '../scene/scene_json.dart';

/// The result of combining two edited copies of one room.
class MergeResult {
  const MergeResult(this.scene, this.conflicts);

  final Scene scene;

  /// Fields both copies changed to different values. This phone's value was
  /// kept for each.
  final int conflicts;
}

/// Three-way merge of a room edited in two places since they last agreed.
///
/// [base] is the last copy both sides had, [local] is this phone's copy and
/// [remote] the cloud's. Work goes node by node, then field by field:
///
/// - a node changed on one side only takes that side's version, including
///   additions and deletions;
/// - a node changed on both sides is merged field by field, and where both
///   changed the same field, this phone wins and a conflict is counted;
/// - a node deleted on one side but edited on the other is kept, since
///   losing someone's edit is worse than keeping an item they can delete.
///
/// Fields that only make sense together (an item's x and z, an opening's
/// wall and offset) are merged as one, so an item never lands at a mix of
/// two positions.
abstract final class SceneMerge {
  static const _eq = DeepCollectionEquality();

  static const _groups = <String, List<String>>{
    'x': ['x', 'z'],
    'z': ['x', 'z'],
    'wallIndex': ['wallIndex', 'offset'],
    'offset': ['wallIndex', 'offset'],
  };

  static MergeResult merge(Scene base, Scene local, Scene remote) {
    final ids = <String>{
      ...local.nodes.keys,
      ...remote.nodes.keys,
      ...base.nodes.keys,
    };
    final out = <String, Node>{};
    var conflicts = 0;
    for (final id in ids) {
      final b = base.nodes[id];
      final l = local.nodes[id];
      final r = remote.nodes[id];
      final Node? pick;
      if (l == r) {
        pick = l;
      } else if (l == b) {
        pick = r;
      } else if (r == b) {
        pick = l;
      } else if (l == null || r == null || b == null) {
        // Deleted here and edited there (or the reverse): keep the edit.
        pick = l ?? r;
        conflicts++;
      } else {
        final (node, clashes) = _mergeFields(b, l, r);
        pick = node;
        conflicts += clashes;
      }
      if (pick != null) out[id] = pick;
    }
    // Keep the local order of nodes first, so lists stay stable on screen.
    final ordered = <String, Node>{
      for (final id in local.nodes.keys) id: ?out[id],
      ...out,
    };
    return MergeResult(Scene(rootId: local.rootId, nodes: ordered), conflicts);
  }

  static (Node, int) _mergeFields(Node base, Node local, Node remote) {
    final b = base.toJson(), l = local.toJson(), r = remote.toJson();
    if (l['type'] != r['type']) return (local, 1);
    final merged = <String, Object?>{...l};
    final done = <String>{};
    var clashes = 0;
    for (final key in {...l.keys, ...r.keys}) {
      if (done.contains(key)) continue;
      final keys = _groups[key] ?? [key];
      done.addAll(keys);
      List<Object?> of(Map<String, Object?> m) => [for (final k in keys) m[k]];
      final lv = of(l), rv = of(r), bv = of(b);
      if (_eq.equals(lv, rv) || _eq.equals(rv, bv)) continue;
      if (_eq.equals(lv, bv)) {
        for (final k in keys) {
          merged[k] = r[k];
        }
        continue;
      }
      clashes++;
    }
    return (SceneJson.nodeFromJson(merged), clashes);
  }

  /// Merges a plain value such as the room's name the same way.
  static (T, bool) mergeValue<T>(T base, T local, T remote) {
    if (local == remote || remote == base) return (local, false);
    if (local == base) return (remote, false);
    return (local, true);
  }
}
