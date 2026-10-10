/// Message types between Flutter and the 3D layer. Every message carries a
/// type `t` and a counter `seq`.
abstract final class ToWeb {
  static const init = 'init';
  static const sceneReplace = 'scene.replace';
  static const scenePatch = 'scene.patch';
  static const itemPreview = 'item.preview';
  static const selectionSet = 'selection.set';
  static const warningsSet = 'warnings.set';
  static const draftShow = 'draft.show';
  static const draftHide = 'draft.hide';
  static const cameraPreset = 'camera.preset';
  static const cameraFocus = 'camera.focus';
  static const themeSet = 'theme.set';
}

abstract final class FromWeb {
  static const ready = 'ready';
  static const tap = 'tap';
  static const dragStart = 'drag.start';
  static const dragMove = 'drag.move';
  static const dragEnd = 'drag.end';
  static const dragCancel = 'drag.cancel';
  static const selectionScreen = 'selection.screen';
  static const error = 'error';
}

/// A message received from the 3D layer.
class WebMessage {
  const WebMessage(this.type, this.data);

  final String type;
  final Map<String, Object?> data;

  String? get id => data['id'] as String?;
  double get x => (data['x'] as num?)?.toDouble() ?? 0;
  double get z => (data['z'] as num?)?.toDouble() ?? 0;
  double get y => (data['y'] as num?)?.toDouble() ?? 0;
}
