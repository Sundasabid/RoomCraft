import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/share_service.dart';
import '../data/supabase_client.dart';
import '../domain/checks/placement_checker.dart';
import '../domain/geometry/vec2.dart';
import '../domain/scene/scene.dart';
import 'connectivity_provider.dart';

enum ViewerStatus { live, reconnecting, ended }

@immutable
class ViewerState {
  const ViewerState({
    required this.scene,
    required this.revision,
    required this.name,
    required this.status,
    required this.updatedAt,
    this.previews = const {},
  });

  final Scene scene;
  final int revision;
  final String name;
  final ViewerStatus status;
  final DateTime updatedAt;

  /// Transient positions from the owner's drag, valid for [revision] only.
  final Map<String, Vec2> previews;

  /// The scene as the owner sees it right now, drags included.
  Scene get displayScene => previews.isEmpty
      ? scene
      : scene.withNodes([
          for (final e in previews.entries)
            if (scene.item(e.key) case final item?) item.at(e.value),
        ]);

  /// The same warnings the owner sees, from the same rules.
  ValidationReport get report => PlacementChecker.checkScene(displayScene);

  ViewerState copyWith({
    Scene? scene,
    int? revision,
    String? name,
    ViewerStatus? status,
    DateTime? updatedAt,
    Map<String, Vec2>? previews,
  }) => ViewerState(
    scene: scene ?? this.scene,
    revision: revision ?? this.revision,
    name: name ?? this.name,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
    previews: previews ?? this.previews,
  );
}

/// No live room with that code.
class NoLiveRoom implements Exception {
  const NoLiveRoom();
}

/// A viewer's read-only copy of a shared room. It never writes anything.
class ViewerController extends AsyncNotifier<ViewerState> {
  ViewerController(this.code);

  final String code;
  LiveChannel? _channel;

  /// How often the viewer quietly checks for a newer revision, in case a
  /// live update was missed (it can happen right after subscribing).
  static const checkEvery = Duration(seconds: 5);

  ShareService get _service =>
      ref.read(shareServiceProvider) ?? (throw const NoLiveRoom());

  @override
  Future<ViewerState> build() async {
    ref.onDispose(() => unawaited(_channel?.close()));
    final timer = Timer.periodic(checkEvery, (_) => unawaited(_check()));
    ref.onDispose(timer.cancel);
    final row = await _service.fetch(code);
    if (row == null) throw const NoLiveRoom();
    ref.listen(isOnlineProvider, (was, now) {
      if (!now) _status(ViewerStatus.reconnecting);
      if (now && was == false) unawaited(resync());
    });
    _open();
    return ViewerState(
      scene: row.scene,
      revision: row.revision,
      name: row.name,
      status: ViewerStatus.live,
      updatedAt: DateTime.now(),
    );
  }

  void _open() {
    unawaited(_channel?.close());
    _channel = _service.open(
      code,
      role: 'viewer',
      handlers: LiveHandlers(
        onRow: _row,
        onPreview: _preview,
        onEnded: () => _status(ViewerStatus.ended),
        onStatus: (s) {
          if (s == LiveStatus.reconnecting) _status(ViewerStatus.reconnecting);
          if (s == LiveStatus.live &&
              state.value?.status == ViewerStatus.reconnecting) {
            unawaited(resync());
          } else if (s == LiveStatus.live) {
            // Anything written between the first fetch and subscribing.
            unawaited(_check());
          }
        },
      ),
    );
  }

  void _status(ViewerStatus s) {
    final v = state.value;
    if (v == null || v.status == s || v.status == ViewerStatus.ended) return;
    state = AsyncData(v.copyWith(status: s));
  }

  /// Applies an update only if its revision is newer than what is shown.
  void _row(ShareRow row) {
    final v = state.value;
    if (v == null ||
        v.status == ViewerStatus.ended ||
        row.revision <= v.revision) {
      return;
    }
    state = AsyncData(
      v.copyWith(
        scene: row.scene,
        revision: row.revision,
        name: row.name,
        status: ViewerStatus.live,
        updatedAt: DateTime.now(),
        previews: const {},
      ),
    );
  }

  void _preview(int rev, String id, double x, double z) {
    final v = state.value;
    if (v == null || rev != v.revision || v.status == ViewerStatus.ended) {
      return;
    }
    state = AsyncData(v.copyWith(previews: {...v.previews, id: Vec2(x, z)}));
  }

  /// Fetches the row and applies it only if it is newer; ends the view if
  /// the session is gone. Never reopens the channel.
  Future<void> _check() async {
    final v = state.value;
    if (v == null ||
        v.status != ViewerStatus.live ||
        !ref.read(isOnlineProvider)) {
      return;
    }
    try {
      final row = await _service.fetch(code);
      if (row == null) {
        _status(ViewerStatus.ended);
      } else {
        _row(row);
      }
    } on Exception {
      // The next check or a reconnect will try again.
    }
  }

  /// Selects the row again and replaces the whole scene (after reconnecting
  /// or when the app resumes).
  Future<void> resync() async {
    final v = state.value;
    if (v == null || v.status == ViewerStatus.ended) return;
    try {
      final row = await _service.fetch(code);
      if (row == null) {
        _status(ViewerStatus.ended);
        return;
      }
      final now = state.value!;
      state = AsyncData(
        now.copyWith(
          scene: row.revision >= now.revision ? row.scene : now.scene,
          revision: row.revision >= now.revision ? row.revision : now.revision,
          status: ViewerStatus.live,
          updatedAt: row.revision > now.revision
              ? DateTime.now()
              : now.updatedAt,
          previews: const {},
        ),
      );
      _open();
    } on Exception {
      _status(ViewerStatus.reconnecting);
    }
  }
}

final viewerProvider = AsyncNotifierProvider.autoDispose
    .family<ViewerController, ViewerState, String>(
      ViewerController.new,
      // A missing room is not fixed by trying again.
      retry: (_, _) => null,
    );
