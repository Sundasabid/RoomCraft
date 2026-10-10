import 'package:roomcraft/domain/geometry/vec2.dart';
import 'package:roomcraft/domain/scene/nodes.dart';
import 'package:roomcraft/domain/scene/rooms.dart';
import 'package:roomcraft/domain/scene/scene.dart';

const roomId = 'room_test0001';

/// 4.2 by 3.6 m with a door on the left wall whose centre is at (0, 2.7).
Scene bedroom({List<ItemNode> items = const [], bool door = true}) => Scene(
  rootId: roomId,
  nodes: {
    roomId: RoomNode(
      id: roomId,
      corners: RoomShapes.rectangle(4.2, 3.6),
      name: 'Bedroom',
    ),
    if (door) 'opening_door0001': leftDoor(),
    for (final i in items) i.id: i,
  },
);

OpeningNode leftDoor() => const OpeningNode(
  id: 'opening_door0001',
  parentId: roomId,
  kind: OpeningKind.door,
  wallIndex: 3,
  offset: 0.9,
  width: 0.9,
  height: 2.1,
  sillHeight: 0,
);

ItemNode item(
  String id,
  String catalogueId,
  double x,
  double z, {
  int rotation = 0,
  bool locked = false,
  bool transient = false,
}) => ItemNode(
  id: id,
  parentId: roomId,
  catalogueId: catalogueId,
  x: x,
  z: z,
  rotation: rotation,
  finish: 'oak',
  locked: locked,
  transient: transient,
);

Scene lShapedStudio({List<ItemNode> items = const []}) => Scene(
  rootId: roomId,
  nodes: {
    roomId: RoomNode(
      id: roomId,
      corners: RoomShapes.lShape(5.5, 4.5, 2.0, 1.5),
    ),
    for (final i in items) i.id: i,
  },
);

const centre = Vec2(2.1, 1.8);
