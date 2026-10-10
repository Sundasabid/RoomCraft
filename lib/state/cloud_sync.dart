import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cloud_projects.dart';
import '../data/local_projects.dart';
import '../data/supabase_client.dart';
import '../domain/scene/scene_json.dart';
import '../domain/sync/scene_merge.dart';
import 'connectivity_provider.dart';
import 'projects_controller.dart';
import 'settings_controller.dart';

enum SyncStatus { synced, pending, localOnly }

/// A room that changed in the cloud while this phone also had changes, and
/// was merged before uploading. An open editor folds it into its own state.
class MergeNotice {
  const MergeNotice({
    required this.id,
    required this.before,
    required this.merged,
    required this.conflicts,
  });

  final String id;

  /// This phone's copy the merge started from.
  final ProjectFile before;
  final ProjectFile merged;
  final int conflicts;
}

/// Keeps the cloud copy of every project up to date.
///
/// A project waiting to upload is "pending", and the pending set is kept on
/// the device so it survives the app closing. Uploads are debounced by two
/// seconds, run at once when the app is paused, and retried whenever the
/// network comes back.
class CloudSync extends Notifier<Map<String, SyncStatus>> {
  static const delay = Duration(seconds: 2);
  static const _pendingKey = 'cloud.pendingUploads';
  static const _deletesKey = 'cloud.pendingDeletes';

  final _timers = <String, Timer>{};
  final _merges = StreamController<MergeNotice>.broadcast();
  bool _retrying = false;

  /// Merges made while uploading; see [MergeNotice].
  Stream<MergeNotice> get merges => _merges.stream;

  @visibleForTesting
  void announce(MergeNotice n) => _merges.add(n);

  CloudStore? get _cloud => ref.read(cloudStoreProvider);
  LocalProjectStore get _local => ref.read(localStoreProvider);
  bool get _online => ref.read(isOnlineProvider);

  Set<String> _read(String key) =>
      (ref.read(preferencesProvider).getStringList(key) ?? const []).toSet();
  void _write(String key, Set<String> ids) =>
      ref.read(preferencesProvider).setStringList(key, ids.toList());

  Set<String> get pending => _read(_pendingKey);
  Set<String> get pendingDeletes => _read(_deletesKey);

  @override
  Map<String, SyncStatus> build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
      unawaited(_merges.close());
    });
    ref.listen(isOnlineProvider, (was, now) {
      if (now && was == false) unawaited(retry());
    });
    return {for (final id in pending) id: SyncStatus.pending};
  }

  void _status(String id, SyncStatus s) {
    if (state[id] == s) return;
    state = {...state, id: s};
  }

  /// Statuses worked out by the merged project list.
  void setAll(Map<String, SyncStatus> statuses) => state = {...statuses};

  /// Queues an upload two seconds after the last change.
  void schedule(ProjectFile p) {
    _write(_pendingKey, pending..add(p.id));
    _status(p.id, SyncStatus.pending);
    _timers[p.id]?.cancel();
    _timers[p.id] = Timer(delay, () => unawaited(_upload(p.id)));
  }

  /// Uploads everything waiting, now (the app is going to the background).
  Future<void> flushAll() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    await retry();
  }

  /// Tries every pending upload and delete once more.
  Future<void> retry() async {
    if (_retrying) return;
    _retrying = true;
    try {
      for (final id in pending) {
        await _upload(id);
      }
      for (final id in pendingDeletes) {
        await _deleteRemote(id);
      }
    } finally {
      _retrying = false;
    }
  }

  Future<void> _upload(String id) async {
    _timers.remove(id)?.cancel();
    final cloud = _cloud;
    if (cloud == null || !_online) return;
    final p = await _local.load(id);
    if (p == null) {
      // Deleted locally before it could upload.
      _write(_pendingKey, pending..remove(id));
      return;
    }
    try {
      final upload = await _mergeIfChanged(cloud, p);
      await cloud.upsert(upload);
      await _local.saveSynced(upload);
      _write(_pendingKey, pending..remove(id));
      _status(id, SyncStatus.synced);
    } on Exception {
      _status(id, SyncStatus.pending);
    }
  }

  /// If the cloud copy moved on since this phone last synced, both sets of
  /// changes are merged into one room, saved here, and announced. Without a
  /// remembered synced copy there is nothing to merge from, and this
  /// phone's copy is uploaded as before.
  Future<ProjectFile> _mergeIfChanged(
    CloudStore cloud,
    ProjectFile mine,
  ) async {
    final base = await _local.loadSynced(mine.id);
    if (base == null) return mine;
    final cloudAt = await cloud.updatedAt(mine.id);
    if (cloudAt == null || cloudAt.isAtSameMomentAs(base.updatedAt)) {
      return mine;
    }
    final theirs = await cloud.fetch(mine.id);
    if (theirs == null) return mine;
    final scene = SceneMerge.merge(base.scene, mine.scene, theirs.scene);
    final (name, nameClash) = SceneMerge.mergeValue(
      base.name,
      mine.name,
      theirs.name,
    );
    final merged = mine.copyWith(
      scene: scene.scene,
      name: name,
      updatedAt: DateTime.now().toUtc(),
    );
    await _local.save(merged);
    _merges.add(
      MergeNotice(
        id: mine.id,
        before: mine,
        merged: merged,
        conflicts: scene.conflicts + (nameClash ? 1 : 0),
      ),
    );
    return merged;
  }

  /// Removes the cloud copy; remembered and retried if it cannot happen now.
  Future<void> delete(String id) async {
    _timers.remove(id)?.cancel();
    _write(_pendingKey, pending..remove(id));
    _write(_deletesKey, pendingDeletes..add(id));
    state = {...state}..remove(id);
    await _deleteRemote(id);
  }

  Future<void> _deleteRemote(String id) async {
    final cloud = _cloud;
    if (cloud == null || !_online) return;
    try {
      await cloud.delete(id);
      _write(_deletesKey, pendingDeletes..remove(id));
    } on Exception {
      // Stays in the pending deletes; tried again on reconnect.
    }
  }

  /// The cloud copy, downloaded into local storage. Null if there is none.
  Future<ProjectFile?> download(String id) async {
    final cloud = _cloud;
    if (cloud == null || !_online) return null;
    try {
      final p = await cloud.fetch(id);
      if (p != null) {
        await _local.save(p);
        await _local.saveSynced(p);
        _status(id, SyncStatus.synced);
      }
      return p;
    } on Exception {
      return null;
    }
  }
}

final cloudSyncProvider = NotifierProvider<CloudSync, Map<String, SyncStatus>>(
  CloudSync.new,
);
