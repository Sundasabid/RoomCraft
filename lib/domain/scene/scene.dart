import 'package:collection/collection.dart';

import '../geometry/vec2.dart';
import 'catalogue.dart';
import 'nodes.dart';

const _nodesEq = MapEquality<String, Node>();

/// The whole room as one flat, immutable map from id to node.
///
/// Map order is creation order; replacing a node keeps its place, which keeps
/// names like "Chair 2" stable.
class Scene {
  Scene({required this.rootId, required Map<String, Node> nodes})
    : nodes = Map.unmodifiable(nodes);

  final String rootId;
  final Map<String, Node> nodes;

  RoomNode get room => nodes[rootId]! as RoomNode;
  List<Vec2> get corners => room.corners;

  Iterable<OpeningNode> get openings => nodes.values.whereType<OpeningNode>();
  Iterable<OpeningNode> get doors => openings.where((o) => o.isDoor);
  Iterable<OpeningNode> get windows => openings.where((o) => !o.isDoor);
  Iterable<ItemNode> get items => nodes.values.whereType<ItemNode>();

  ItemNode? item(String id) {
    final n = nodes[id];
    return n is ItemNode ? n : null;
  }

  OpeningNode? opening(String id) {
    final n = nodes[id];
    return n is OpeningNode ? n : null;
  }

  Scene withNode(Node node) =>
      Scene(rootId: rootId, nodes: {...nodes, node.id: node});

  Scene withNodes(Iterable<Node> updates) => Scene(
    rootId: rootId,
    nodes: {...nodes, for (final n in updates) n.id: n},
  );

  Scene without(Iterable<String> ids) {
    final remove = ids.toSet();
    return Scene(
      rootId: rootId,
      nodes: {
        for (final e in nodes.entries)
          if (!remove.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// The same scene with transient nodes dropped.
  Scene get persistent => nodes.values.any((n) => n.transient)
      ? Scene(
          rootId: rootId,
          nodes: {
            for (final e in nodes.entries)
              if (!e.value.transient) e.key: e.value,
          },
        )
      : this;

  /// "Chair", then "Chair 2", "Chair 3" in creation order.
  String displayName(String itemId) {
    final target = item(itemId);
    if (target == null) return '';
    final base = Catalogue.byId(target.catalogueId).name;
    var n = 0;
    for (final i in items) {
      if (i.catalogueId != target.catalogueId) continue;
      n++;
      if (i.id == itemId) break;
    }
    return n <= 1 ? base : '$base $n';
  }

  @override
  bool operator ==(Object other) =>
      other is Scene &&
      other.rootId == rootId &&
      _nodesEq.equals(other.nodes, nodes);

  @override
  int get hashCode => Object.hash(rootId, _nodesEq.hash(nodes));
}
