import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../domain/scene/catalogue.dart';
import '../domain/scene/finishes.dart';
import '../domain/scene/nodes.dart';
import '../domain/scene/scene.dart';
import '../domain/scene/scene_json.dart';
import '../domain/share/scene_diff.dart';
import 'messages.dart';
import 'scene_bridge.dart';

/// What the 3D layer should show right now.
@immutable
class SceneFrame {
  const SceneFrame({
    required this.scene,
    this.selection,
    this.flagged = const {},
    this.previewId,
    this.previewX = 0,
    this.previewZ = 0,
    this.draft,
    this.previews = const {},
  });

  /// Committed scene (plus any door or window being dragged).
  final Scene scene;
  final String? selection;
  final Set<String> flagged;

  /// An item being dragged and its snapped position.
  final String? previewId;
  final double previewX;
  final double previewZ;

  /// AI draft items, shown over the faint real layout.
  final List<ItemNode>? draft;

  /// Viewer only: the owner's dragged items and where they are now.
  final Map<String, (double, double)> previews;
}

/// Turns state changes into the smallest set of bridge messages.
class SceneSync {
  SceneSync(this.bridge);

  final SceneBridge bridge;
  Map<String, Node> _nodes = const {};
  String? _selection;
  Set<String> _flagged = const {};
  String? _previewId;
  List<ItemNode>? _draft;
  Map<String, (double, double)> _previews = const {};

  static Map<String, Object?> palette(RoomCraftColors c) => {
    'background': RoomCraftColors.hex(c.background),
    'primary': RoomCraftColors.hex(c.primary),
    'warning': RoomCraftColors.hex(c.warning),
  };

  /// Payload for `init`; also resets what has been sent.
  Map<String, Object?> init(
    SceneFrame f, {
    required String mode,
    required bool reduceMotion,
    required RoomCraftColors colors,
    bool debug = false,
  }) {
    _nodes = f.scene.nodes;
    _selection = null;
    _flagged = const {};
    _previewId = null;
    _draft = null;
    return {
      'mode': mode,
      'reduceMotion': reduceMotion,
      'debug': debug,
      'palette': palette(colors),
      'catalogue': [for (final c in Catalogue.items) c.toJson()],
      'finishes': [for (final f in Finishes.all) f.toJson()],
      'scene': SceneJson.encode(f.scene),
    };
  }

  /// Called after init so states that arrived with it are drawn too.
  void afterInit(SceneFrame f) {
    _sendStates(f);
  }

  void update(SceneFrame f) {
    if (!identical(f.scene.nodes, _nodes)) {
      final diff = diffNodes(_nodes, f.scene.nodes);
      _nodes = f.scene.nodes;
      if (!diff.isEmpty) {
        bridge.send(ToWeb.scenePatch, {
          'upserts': [for (final n in diff.upserts) n.toJson()],
          'removes': diff.removes,
        });
      }
    }
    _sendStates(f);
  }

  void _sendStates(SceneFrame f) {
    if (f.selection != _selection) {
      _selection = f.selection;
      bridge.send(ToWeb.selectionSet, {
        'ids': [?f.selection],
      });
    }
    if (!const SetEquality<String>().equals(f.flagged, _flagged)) {
      _flagged = f.flagged;
      bridge.send(ToWeb.warningsSet, {'ids': f.flagged.toList()});
    }
    if (f.previewId != null) {
      bridge.sendPreview(f.previewId!, f.previewX, f.previewZ);
    } else if (_previewId != null) {
      // The drag ended or was cancelled: settle on the committed position.
      final item = f.scene.item(_previewId!);
      if (item != null) bridge.sendPreview(item.id, item.x, item.z);
    }
    _previewId = f.previewId;
    if (!identical(f.previews, _previews)) {
      for (final e in f.previews.entries) {
        if (_previews[e.key] != e.value) {
          bridge.sendPreview(e.key, e.value.$1, e.value.$2);
        }
      }
      _previews = f.previews;
    }
    if (!identical(f.draft, _draft)) {
      _draft = f.draft;
      final d = f.draft;
      if (d == null) {
        bridge.send(ToWeb.draftHide);
      } else {
        bridge.send(ToWeb.draftShow, {
          'items': [for (final i in d) i.toJson()],
        });
      }
    }
  }

  void theme(RoomCraftColors c) =>
      bridge.send(ToWeb.themeSet, {'palette': palette(c)});

  void camera(String preset) =>
      bridge.send(ToWeb.cameraPreset, {'name': preset});

  void focus(Set<String> ids) =>
      bridge.send(ToWeb.cameraFocus, {'ids': ids.toList()});
}
