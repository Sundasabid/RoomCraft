import '../scene/nodes.dart';

/// What changed between two node maps: new or different nodes, and ids that
/// disappeared. Used to turn a full shared scene into a small 3D patch.
class NodeDiff {
  const NodeDiff(this.upserts, this.removes);

  final List<Node> upserts;
  final List<String> removes;

  bool get isEmpty => upserts.isEmpty && removes.isEmpty;
}

NodeDiff diffNodes(Map<String, Node> before, Map<String, Node> after) =>
    NodeDiff(
      [
        for (final e in after.entries)
          if (before[e.key] != e.value) e.value,
      ],
      [
        for (final id in before.keys)
          if (!after.containsKey(id)) id,
      ],
    );
