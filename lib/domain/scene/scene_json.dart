import '../geometry/vec2.dart';
import 'lighting.dart';
import 'nodes.dart';
import 'scene.dart';

const projectFormat = 1;

/// Thrown for a file this version cannot read.
class SceneFormatException implements Exception {
  const SceneFormatException(this.message);
  final String message;
  @override
  String toString() => 'SceneFormatException: $message';
}

/// A saved project: the scene plus its wrapper fields.
class ProjectFile {
  const ProjectFile({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.displayUnit,
    required this.scene,
  });

  final String id;
  final String name;
  final DateTime updatedAt;

  /// 'm' or 'ft'.
  final String displayUnit;
  final Scene scene;

  ProjectFile copyWith({
    String? name,
    DateTime? updatedAt,
    String? displayUnit,
    Scene? scene,
  }) => ProjectFile(
    id: id,
    name: name ?? this.name,
    updatedAt: updatedAt ?? this.updatedAt,
    displayUnit: displayUnit ?? this.displayUnit,
    scene: scene ?? this.scene,
  );

  Map<String, Object?> toJson() => {
    'format': projectFormat,
    'id': id,
    'name': name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'displayUnit': displayUnit,
    ...SceneJson.encode(scene),
  };

  static ProjectFile fromJson(Map<String, Object?> json) {
    final format = json['format'];
    if (format != projectFormat) {
      throw SceneFormatException('Unsupported format $format');
    }
    return ProjectFile(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      updatedAt: DateTime.parse(_string(json, 'updatedAt')).toUtc(),
      displayUnit: json['displayUnit'] == 'ft' ? 'ft' : 'm',
      scene: SceneJson.decode(json),
    );
  }
}

/// Hand-written JSON for scenes: `{rootId, nodes}`. Transient nodes are never
/// written.
abstract final class SceneJson {
  static Map<String, Object?> encode(Scene scene) => {
    'rootId': scene.rootId,
    'nodes': {
      for (final n in scene.nodes.values)
        if (!n.transient) n.id: n.toJson(),
    },
  };

  static Scene decode(Map<String, Object?> json) {
    final rootId = _string(json, 'rootId');
    final raw = json['nodes'];
    if (raw is! Map<String, Object?>) {
      throw const SceneFormatException('nodes missing');
    }
    final nodes = <String, Node>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map<String, Object?>) {
        throw SceneFormatException('node ${entry.key} is not an object');
      }
      final node = nodeFromJson(value);
      if (!node.transient) nodes[node.id] = node;
    }
    if (nodes[rootId] is! RoomNode) {
      throw const SceneFormatException('root room missing');
    }
    return Scene(rootId: rootId, nodes: nodes);
  }

  static Node nodeFromJson(Map<String, Object?> j) {
    final id = _string(j, 'id');
    final parentId = j['parentId'] as String?;
    final visible = j['visible'] as bool? ?? true;
    final meta = j['metadata'];
    final transient = meta is Map<String, Object?> && meta['transient'] == true;
    switch (j['type']) {
      case 'room':
        final corners = j['corners'];
        if (corners is! List<Object?> || corners.length < 4) {
          throw const SceneFormatException('room needs at least 4 corners');
        }
        return RoomNode(
          id: id,
          visible: visible,
          corners: [
            for (final c in corners)
              if (c is List<Object?> && c.length == 2)
                Vec2(_num(c[0]), _num(c[1]))
              else
                throw const SceneFormatException('bad corner'),
          ],
          wallHeight: _num(j['wallHeight'] ?? 2.6),
          floorFinish: j['floorFinish'] as String? ?? 'oak',
          wallFinish: j['wallFinish'] as String? ?? 'warm_white',
          lighting: switch (j['lighting']) {
            final String id when Lighting.has(id) => id,
            _ => Lighting.fallback,
          },
          name: j['name'] as String? ?? '',
        );
      case 'opening':
        return OpeningNode(
          id: id,
          parentId: parentId,
          visible: visible,
          kind: j['kind'] == 'window' ? OpeningKind.window : OpeningKind.door,
          wallIndex: _num(j['wallIndex']).toInt(),
          offset: _num(j['offset']),
          width: _num(j['width']),
          height: _num(j['height']),
          sillHeight: _num(j['sillHeight'] ?? 0),
        );
      case 'item':
        return ItemNode(
          id: id,
          parentId: parentId,
          visible: visible,
          transient: transient,
          catalogueId: _string(j, 'catalogueId'),
          x: _num(j['x']),
          z: _num(j['z']),
          rotation: _num(j['rotation'] ?? 0).toInt(),
          finish: _string(j, 'finish'),
          locked: j['locked'] as bool? ?? false,
        );
      default:
        throw SceneFormatException('unknown node type ${j['type']}');
    }
  }
}

String _string(Map<String, Object?> j, String key) {
  final v = j[key];
  if (v is String) return v;
  throw SceneFormatException('$key missing');
}

double _num(Object? v) {
  if (v is num && v.isFinite) return v.toDouble();
  throw SceneFormatException('expected a number, got $v');
}
