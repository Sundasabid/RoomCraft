import 'package:collection/collection.dart';

import '../geometry/vec2.dart';

const _cornerEq = ListEquality<Vec2>();

/// Base of every scene node. Nodes are immutable values.
sealed class Node {
  const Node({
    required this.id,
    required this.parentId,
    this.visible = true,
    this.transient = false,
  });

  final String id;
  final String? parentId;
  final bool visible;

  /// Preview-only (AI drafts, drag previews): never saved, synced or undone.
  final bool transient;

  String get type;

  Map<String, Object?> baseJson() => {
    'id': id,
    'type': type,
    'parentId': parentId,
    'visible': visible,
    if (transient) 'metadata': {'transient': true},
  };

  Map<String, Object?> toJson();
}

class RoomNode extends Node {
  const RoomNode({
    required super.id,
    required this.corners,
    this.wallHeight = 2.6,
    this.floorFinish = 'oak',
    this.wallFinish = 'warm_white',
    this.lighting = 'day',
    this.name = '',
    super.visible,
  }) : super(parentId: null);

  final List<Vec2> corners;
  final double wallHeight;
  final String floorFinish;
  final String wallFinish;

  /// Lighting mood id, see Lighting in lighting.dart.
  final String lighting;
  final String name;

  @override
  String get type => 'room';

  RoomNode copyWith({
    List<Vec2>? corners,
    double? wallHeight,
    String? floorFinish,
    String? wallFinish,
    String? lighting,
    String? name,
  }) => RoomNode(
    id: id,
    corners: corners ?? this.corners,
    wallHeight: wallHeight ?? this.wallHeight,
    floorFinish: floorFinish ?? this.floorFinish,
    wallFinish: wallFinish ?? this.wallFinish,
    lighting: lighting ?? this.lighting,
    name: name ?? this.name,
    visible: visible,
  );

  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'corners': [
      for (final c in corners) [c.x, c.z],
    ],
    'wallHeight': wallHeight,
    'floorFinish': floorFinish,
    'wallFinish': wallFinish,
    'lighting': lighting,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      other is RoomNode &&
      other.id == id &&
      other.visible == visible &&
      _cornerEq.equals(other.corners, corners) &&
      other.wallHeight == wallHeight &&
      other.floorFinish == floorFinish &&
      other.wallFinish == wallFinish &&
      other.lighting == lighting &&
      other.name == name;

  @override
  int get hashCode => Object.hash(
    id,
    visible,
    _cornerEq.hash(corners),
    wallHeight,
    floorFinish,
    wallFinish,
    lighting,
    name,
  );
}

enum OpeningKind { door, window }

class OpeningNode extends Node {
  const OpeningNode({
    required super.id,
    required super.parentId,
    required this.kind,
    required this.wallIndex,
    required this.offset,
    required this.width,
    required this.height,
    required this.sillHeight,
    super.visible,
  });

  final OpeningKind kind;
  final int wallIndex;

  /// Metres from the wall's start corner to the opening's centre.
  final double offset;
  final double width;
  final double height;
  final double sillHeight;

  bool get isDoor => kind == OpeningKind.door;

  @override
  String get type => 'opening';

  OpeningNode copyWith({int? wallIndex, double? offset, double? width}) =>
      OpeningNode(
        id: id,
        parentId: parentId,
        kind: kind,
        wallIndex: wallIndex ?? this.wallIndex,
        offset: offset ?? this.offset,
        width: width ?? this.width,
        height: height,
        sillHeight: sillHeight,
        visible: visible,
      );

  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'kind': kind.name,
    'wallIndex': wallIndex,
    'offset': offset,
    'width': width,
    'height': height,
    'sillHeight': sillHeight,
  };

  @override
  bool operator ==(Object other) =>
      other is OpeningNode &&
      other.id == id &&
      other.parentId == parentId &&
      other.visible == visible &&
      other.kind == kind &&
      other.wallIndex == wallIndex &&
      other.offset == offset &&
      other.width == width &&
      other.height == height &&
      other.sillHeight == sillHeight;

  @override
  int get hashCode => Object.hash(
    id,
    parentId,
    visible,
    kind,
    wallIndex,
    offset,
    width,
    height,
    sillHeight,
  );
}

class ItemNode extends Node {
  const ItemNode({
    required super.id,
    required super.parentId,
    required this.catalogueId,
    required this.x,
    required this.z,
    required this.finish,
    this.rotation = 0,
    this.locked = false,
    super.visible,
    super.transient,
  });

  final String catalogueId;

  /// Centre of the footprint.
  final double x;
  final double z;

  /// 0, 90, 180 or 270 degrees clockwise on the plan.
  final int rotation;
  final String finish;

  /// The AI may not move a locked item.
  final bool locked;

  Vec2 get position => Vec2(x, z);

  @override
  String get type => 'item';

  ItemNode copyWith({
    double? x,
    double? z,
    int? rotation,
    String? finish,
    bool? locked,
    bool? transient,
  }) => ItemNode(
    id: id,
    parentId: parentId,
    catalogueId: catalogueId,
    x: x ?? this.x,
    z: z ?? this.z,
    rotation: rotation ?? this.rotation,
    finish: finish ?? this.finish,
    locked: locked ?? this.locked,
    visible: visible,
    transient: transient ?? this.transient,
  );

  ItemNode at(Vec2 p) => copyWith(x: p.x, z: p.z);

  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'catalogueId': catalogueId,
    'x': x,
    'z': z,
    'rotation': rotation,
    'finish': finish,
    'locked': locked,
  };

  @override
  bool operator ==(Object other) =>
      other is ItemNode &&
      other.id == id &&
      other.parentId == parentId &&
      other.visible == visible &&
      other.transient == transient &&
      other.catalogueId == catalogueId &&
      other.x == x &&
      other.z == z &&
      other.rotation == rotation &&
      other.finish == finish &&
      other.locked == locked;

  @override
  int get hashCode => Object.hash(
    id,
    parentId,
    visible,
    transient,
    catalogueId,
    x,
    z,
    rotation,
    finish,
    locked,
  );
}
