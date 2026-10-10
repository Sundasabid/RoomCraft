import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../domain/constants.dart';
import '../domain/geometry/polygon.dart';
import '../domain/geometry/vec2.dart';
import '../domain/scene/ids.dart';
import '../domain/scene/nodes.dart';
import '../domain/scene/rooms.dart';
import '../domain/scene/scene.dart';
import '../domain/scene/scene_json.dart';

enum RoomTemplate { bedroom, living, studio, custom }

extension RoomTemplateLabel on RoomTemplate {
  String get label => switch (this) {
    RoomTemplate.bedroom => S.templateBedroom,
    RoomTemplate.living => S.templateLiving,
    RoomTemplate.studio => S.templateStudio,
    RoomTemplate.custom => S.templateCustom,
  };

  String get defaultName => this == RoomTemplate.custom ? S.customName : label;

  static RoomTemplate parse(String? v) => switch (v) {
    'living' => RoomTemplate.living,
    'studio' => RoomTemplate.studio,
    'custom' => RoomTemplate.custom,
    _ => RoomTemplate.bedroom,
  };
}

@immutable
class SetupState {
  const SetupState({
    required this.roomId,
    required this.template,
    required this.lShape,
    required this.width,
    required this.length,
    required this.notchWidth,
    required this.notchLength,
    required this.wallHeight,
    required this.openings,
    required this.name,
    required this.nameEdited,
    this.highlightWall,
    this.activeOpening,
  });

  final String roomId;
  final RoomTemplate template;
  final bool lShape;
  final double width;
  final double length;
  final double notchWidth;
  final double notchLength;
  final double wallHeight;
  final List<OpeningNode> openings;
  final String name;
  final bool nameEdited;
  final int? highlightWall;
  final String? activeOpening;

  List<Vec2> get corners => lShape
      ? RoomShapes.lShape(width, length, notchWidth, notchLength)
      : RoomShapes.rectangle(width, length);

  bool get hasDoor => openings.any((o) => o.isDoor);

  double get minSide => lShape ? 2.5 : minRoomSide;
  double get maxNotchWidth => width - 1.5;
  double get maxNotchLength => length - 1.5;

  Scene get scene => Scene(
    rootId: roomId,
    nodes: {
      roomId: RoomNode(
        id: roomId,
        corners: corners,
        wallHeight: wallHeight,
        name: name,
      ),
      for (final o in openings) o.id: o,
    },
  );

  SetupState copyWith({
    RoomTemplate? template,
    bool? lShape,
    double? width,
    double? length,
    double? notchWidth,
    double? notchLength,
    double? wallHeight,
    List<OpeningNode>? openings,
    String? name,
    bool? nameEdited,
    int? Function()? highlightWall,
    String? Function()? activeOpening,
  }) => SetupState(
    roomId: roomId,
    template: template ?? this.template,
    lShape: lShape ?? this.lShape,
    width: width ?? this.width,
    length: length ?? this.length,
    notchWidth: notchWidth ?? this.notchWidth,
    notchLength: notchLength ?? this.notchLength,
    wallHeight: wallHeight ?? this.wallHeight,
    openings: openings ?? this.openings,
    name: name ?? this.name,
    nameEdited: nameEdited ?? this.nameEdited,
    highlightWall: highlightWall != null ? highlightWall() : this.highlightWall,
    activeOpening: activeOpening != null ? activeOpening() : this.activeOpening,
  );
}

/// Wall name from its inward normal: "left wall", "top wall" and so on.
String wallName(SetupState s, int index) {
  if (s.lShape && (index == 2 || index == 3)) return S.notchWall;
  final n = Polygon.inwardNormal(s.corners, index);
  if (n.z > 0.5) return S.topWall;
  if (n.x < -0.5) return S.rightWall;
  if (n.z < -0.5) return S.bottomWall;
  return S.leftWall;
}

double _r2(double v) => (v * 100).roundToDouble() / 100;

class SetupController extends Notifier<SetupState> {
  /// Kinds of openings removed by the last change because their wall became
  /// too short. The screen shows a toast for each.
  List<OpeningKind> lastRemoved = const [];

  @override
  SetupState build() =>
      _fromTemplate(RoomTemplate.bedroom, newNodeId('room'), null);

  SetupState _fromTemplate(
    RoomTemplate t,
    String roomId,
    SetupState? keepName,
  ) {
    final (w, l, lShape, nw, nl) = switch (t) {
      RoomTemplate.bedroom => (4.2, 3.6, false, 2.0, 1.5),
      RoomTemplate.living => (5.0, 4.0, false, 2.0, 1.5),
      RoomTemplate.studio => (5.5, 4.5, true, 2.0, 1.5),
      RoomTemplate.custom => (4.0, 3.0, false, 2.0, 1.5),
    };
    final leftWall = lShape ? 5 : 3;
    OpeningNode opening(OpeningKind k, int wall, double offset) =>
        OpeningRules.newOpening(
          roomId: roomId,
          kind: k,
          wallIndex: wall,
          offset: offset,
        );
    final openings = [
      opening(OpeningKind.door, leftWall, 0.9),
      if (t != RoomTemplate.custom) opening(OpeningKind.window, 0, w / 2),
      if (t == RoomTemplate.living) opening(OpeningKind.window, 1, l / 2),
    ];
    final edited = keepName?.nameEdited ?? false;
    return SetupState(
      roomId: roomId,
      template: t,
      lShape: lShape,
      width: w,
      length: l,
      notchWidth: nw,
      notchLength: nl,
      wallHeight: keepName?.wallHeight ?? defaultWallHeight,
      openings: openings,
      name: edited ? keepName!.name : t.defaultName,
      nameEdited: edited,
    );
  }

  void applyTemplate(RoomTemplate t) {
    lastRemoved = const [];
    state = _fromTemplate(t, state.roomId, state);
  }

  void setShape({required bool lShape}) {
    if (lShape == state.lShape) return;
    // Keep each opening on the matching wall of the new outline.
    const toL = {0: 0, 1: 1, 2: 4, 3: 5};
    const toRect = {0: 0, 1: 1, 2: 1, 3: 2, 4: 2, 5: 3};
    final map = lShape ? toL : toRect;
    final side = lShape ? 2.5 : minRoomSide;
    var next = state.copyWith(
      lShape: lShape,
      width: state.width < side ? side : state.width,
      length: state.length < side ? side : state.length,
      openings: [
        for (final o in state.openings)
          o.copyWith(wallIndex: map[o.wallIndex] ?? 0),
      ],
      highlightWall: () => null,
    );
    next = _clampNotch(next);
    _commit(next);
  }

  void setWidth(double v) => _commit(
    _clampNotch(
      state.copyWith(width: _r2(v.clamp(state.minSide, maxRoomSide))),
    ),
  );

  void setLength(double v) => _commit(
    _clampNotch(
      state.copyWith(length: _r2(v.clamp(state.minSide, maxRoomSide))),
    ),
  );

  void setNotchWidth(double v) => _commit(
    state.copyWith(notchWidth: _r2(v.clamp(1.0, state.maxNotchWidth))),
  );

  void setNotchLength(double v) => _commit(
    state.copyWith(notchLength: _r2(v.clamp(1.0, state.maxNotchLength))),
  );

  void setWallHeight(double v) => state = state.copyWith(
    wallHeight: _r2(v.clamp(minWallHeight, maxWallHeight)),
  );

  void setName(String v) => state = state.copyWith(name: v, nameEdited: true);

  void toggleWall(int index) => state = state.copyWith(
    highlightWall: () => state.highlightWall == index ? null : index,
  );

  void selectOpening(String? id) =>
      state = state.copyWith(activeOpening: () => id);

  SetupState _clampNotch(SetupState s) => s.lShape
      ? s.copyWith(
          notchWidth: s.notchWidth.clamp(1.0, s.maxNotchWidth),
          notchLength: s.notchLength.clamp(1.0, s.maxNotchLength),
        )
      : s;

  /// Re-fits every opening to the new walls; removes any that no longer fit.
  void _commit(SetupState next) {
    final kept = <OpeningNode>[];
    final removed = <OpeningKind>[];
    var scene = next.copyWith(openings: const []).scene;
    for (final o in next.openings) {
      final offset = OpeningRules.clampOffset(
        scene: scene,
        wallIndex: o.wallIndex,
        width: o.width,
        offset: o.offset,
      );
      if (offset == null) {
        removed.add(o.kind);
        continue;
      }
      final placed = o.copyWith(offset: _r2(offset));
      kept.add(placed);
      scene = scene.withNode(placed);
    }
    lastRemoved = removed;
    state = next.copyWith(
      openings: kept,
      activeOpening: kept.any((o) => o.id == next.activeOpening)
          ? null
          : () => null,
    );
  }

  /// Adds a door or window at the centre of the highlighted wall, or of the
  /// longest wall, moving it to the nearest free spot. Returns false when no
  /// wall has room for it.
  bool addOpening(OpeningKind kind) {
    final s = state;
    final corners = s.corners;
    final walls = List.generate(corners.length, (i) => i)
      ..sort(
        (a, b) => Polygon.edgeLength(
          corners,
          b,
        ).compareTo(Polygon.edgeLength(corners, a)),
      );
    if (s.highlightWall != null) {
      walls
        ..remove(s.highlightWall)
        ..insert(0, s.highlightWall!);
    }
    final scene = s.scene;
    for (final wall in walls) {
      final probe = OpeningRules.newOpening(
        roomId: s.roomId,
        kind: kind,
        wallIndex: wall,
        offset: 0,
      );
      final offset = OpeningRules.clampOffset(
        scene: scene,
        wallIndex: wall,
        width: probe.width,
        offset: Polygon.edgeLength(corners, wall) / 2,
      );
      if (offset == null) continue;
      final o = probe.copyWith(offset: _r2(offset));
      state = s.copyWith(
        openings: [...s.openings, o],
        activeOpening: () => o.id,
      );
      return true;
    }
    return false;
  }

  void moveOpening(String id, double offset) {
    final o = state.openings.where((x) => x.id == id).firstOrNull;
    if (o == null) return;
    final clamped = OpeningRules.clampOffset(
      scene: state.scene,
      wallIndex: o.wallIndex,
      width: o.width,
      offset: offset,
      ignoreId: id,
    );
    if (clamped == null) return;
    _replace(o.copyWith(offset: _r2(clamped)));
  }

  void setOpeningWidth(String id, double width) {
    final o = state.openings.where((x) => x.id == id).firstOrNull;
    if (o == null) return;
    final w = _r2(
      width.clamp(OpeningRules.minWidth(o.kind), OpeningRules.maxWidth(o.kind)),
    );
    final offset = OpeningRules.clampOffset(
      scene: state.scene,
      wallIndex: o.wallIndex,
      width: w,
      offset: o.offset,
      ignoreId: id,
    );
    if (offset == null) return;
    _replace(o.copyWith(width: w, offset: _r2(offset)));
  }

  void deleteOpening(String id) => state = state.copyWith(
    openings: state.openings.where((o) => o.id != id).toList(),
    activeOpening: state.activeOpening == id ? () => null : null,
  );

  void _replace(OpeningNode o) => state = state.copyWith(
    openings: [for (final x in state.openings) x.id == o.id ? o : x],
    activeOpening: () => o.id,
  );

  /// The finished project, ready to save.
  ProjectFile buildProject({required String displayUnit}) {
    final name = state.name.trim().isEmpty
        ? state.template.defaultName
        : state.name.trim();
    final clipped = name.length > maxNameLength
        ? name.substring(0, maxNameLength)
        : name;
    final scene = state.copyWith(name: clipped).scene;
    return ProjectFile(
      id: newProjectId(),
      name: clipped,
      updatedAt: DateTime.now().toUtc(),
      displayUnit: displayUnit,
      scene: scene,
    );
  }
}

final setupProvider = NotifierProvider.autoDispose<SetupController, SetupState>(
  SetupController.new,
);
