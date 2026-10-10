import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/share_service.dart';
import '../data/supabase_client.dart';
import '../domain/scene/scene.dart';

@immutable
class ShareState {
  const ShareState({
    this.code,
    this.projectId,
    this.starting = false,
    this.viewers = 0,
    this.revision = 0,
  });

  final String? code;
  final String? projectId;
  final bool starting;
  final int viewers;
  final int revision;

  bool get active => code != null;
  bool sharing(String projectId) => active && this.projectId == projectId;
}

/// The owner's side of live sharing. Accepted changes are written as the full
/// scene with revision + 1, at most every 150 ms; drags broadcast a preview
/// at most every 100 ms.
class ShareController extends Notifier<ShareState> {
  static const writeEvery = Duration(milliseconds: 150);
  static const previewEvery = Duration(milliseconds: 100);

  LiveChannel? _channel;
  Scene? _latest;
  String _name = '';
  Timer? _writeTimer;
  bool _writing = false;
  bool _dirty = false;
  DateTime _lastPreview = DateTime(0);
  (String, double, double)? _queuedPreview;
  Timer? _previewTimer;

  ShareService? get _service => ref.read(shareServiceProvider);

  @override
  ShareState build() {
    ref.onDispose(() {
      _writeTimer?.cancel();
      _previewTimer?.cancel();
      unawaited(_channel?.close());
    });
    return const ShareState();
  }

  /// Starts a session and returns its code. Throws if no code could be made.
  Future<String> start({
    required String projectId,
    required String name,
    required Scene scene,
  }) async {
    final service = _service;
    if (service == null) throw StateError('sharing is not configured');
    if (state.active) await stop();
    state = const ShareState(starting: true);
    try {
      final code = await service.start(
        projectId: projectId,
        name: name,
        scene: scene,
      );
      _latest = scene;
      _name = name;
      _channel = service.open(
        code,
        role: 'owner',
        handlers: LiveHandlers(
          onViewers: (n) => state = ShareState(
            code: state.code,
            projectId: state.projectId,
            viewers: n,
            revision: state.revision,
          ),
        ),
      );
      state = ShareState(code: code, projectId: projectId);
      return code;
    } catch (_) {
      state = const ShareState();
      rethrow;
    }
  }

  /// A new accepted scene. Writes are coalesced, never overlap, and always
  /// end with the latest scene.
  void commit(Scene scene, String name) {
    if (!state.active) return;
    _latest = scene;
    _name = name;
    _dirty = true;
    if (_writeTimer?.isActive ?? false) return;
    _writeTimer = Timer(writeEvery, _write);
  }

  Future<void> _write() async {
    final service = _service;
    final code = state.code;
    if (service == null || code == null || _writing || !_dirty) return;
    _writing = true;
    _dirty = false;
    final rev = state.revision + 1;
    try {
      await service.push(code, _latest!, rev, _name);
      if (state.code == code) {
        state = ShareState(
          code: code,
          projectId: state.projectId,
          viewers: state.viewers,
          revision: rev,
        );
      }
    } on Exception {
      _dirty = true; // tried again with the next change or below
    } finally {
      _writing = false;
    }
    if (_dirty && state.code == code) _writeTimer = Timer(writeEvery, _write);
  }

  /// A dragged item's snapped position, throttled; the final position always
  /// arrives through [commit] when the drag ends.
  void preview(String id, double x, double z) {
    if (!state.active) return;
    final now = DateTime.now();
    final wait = previewEvery - now.difference(_lastPreview);
    if (wait <= Duration.zero) {
      _sendPreview(id, x, z);
      return;
    }
    _queuedPreview = (id, x, z);
    _previewTimer ??= Timer(wait, () {
      _previewTimer = null;
      final q = _queuedPreview;
      _queuedPreview = null;
      if (q != null) _sendPreview(q.$1, q.$2, q.$3);
    });
  }

  void _sendPreview(String id, double x, double z) {
    _lastPreview = DateTime.now();
    _channel?.sendPreview(state.revision, id, x, z);
  }

  Future<void> stop() async {
    final code = state.code;
    final channel = _channel;
    _channel = null;
    _writeTimer?.cancel();
    _previewTimer?.cancel();
    state = const ShareState();
    if (code == null) return;
    try {
      await channel?.sendEnded();
      await _service?.stop(code);
    } finally {
      await channel?.close();
    }
  }
}

final shareControllerProvider = NotifierProvider<ShareController, ShareState>(
  ShareController.new,
);
