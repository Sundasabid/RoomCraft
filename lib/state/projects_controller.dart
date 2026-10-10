import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../data/local_projects.dart';
import '../data/supabase_client.dart';
import '../domain/constants.dart';
import '../domain/scene/ids.dart';
import '../domain/scene/nodes.dart';
import '../domain/scene/scene_json.dart';
import 'cloud_sync.dart';
import 'connectivity_provider.dart';

/// Opened once in main() so the first frame can already list projects.
final localStoreProvider = Provider<LocalProjectStore>(
  (ref) => throw StateError('localStoreProvider must be overridden'),
);

/// Saved rooms, newest edit first. A deleted room disappears at once and its
/// file is removed only when the Undo toast ends.
class ProjectsController extends AsyncNotifier<List<ProjectFile>> {
  final _pendingDeletes = <String, ProjectFile>{};

  LocalProjectStore get _store => ref.read(localStoreProvider);

  @override
  Future<List<ProjectFile>> build() => _load();

  /// True when the cloud list could not be read on the last refresh.
  bool cloudFailed = false;

  CloudSync get _sync => ref.read(cloudSyncProvider.notifier);

  /// Merges local files with the cloud list by id; the newer copy wins.
  /// Newer cloud copies are downloaded, and local rooms the cloud does not
  /// have (or has an older copy of) are queued for upload.
  Future<List<ProjectFile>> _load() async {
    final local = {
      for (final p in await _store.list())
        if (!_pendingDeletes.containsKey(p.id)) p.id: p,
    };
    final sync = _sync;
    final pending = sync.pending;
    final statuses = <String, SyncStatus>{
      for (final id in local.keys)
        id: pending.contains(id) ? SyncStatus.pending : SyncStatus.localOnly,
    };
    cloudFailed = false;
    final cloud = ref.read(cloudStoreProvider);
    if (cloud != null && ref.read(isOnlineProvider)) {
      try {
        final rows = {for (final r in await cloud.list()) r.id: r};
        final deleted = sync.pendingDeletes;
        for (final row in rows.values) {
          if (deleted.contains(row.id) ||
              _pendingDeletes.containsKey(row.id) ||
              pending.contains(row.id)) {
            continue;
          }
          final mine = local[row.id];
          if (mine == null || row.updatedAt.isAfter(mine.updatedAt)) {
            final fresh = await sync.download(row.id);
            if (fresh != null) local[row.id] = fresh;
          }
          if (local.containsKey(row.id)) statuses[row.id] = SyncStatus.synced;
        }
        for (final p in local.values) {
          final row = rows[p.id];
          if (!pending.contains(p.id) &&
              (row == null || p.updatedAt.isAfter(row.updatedAt))) {
            sync.schedule(p);
            statuses[p.id] = SyncStatus.pending;
          }
        }
      } on Exception {
        cloudFailed = true;
      }
    }
    sync.setAll(statuses);
    return local.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> refresh() async => state = AsyncData(await _load());

  List<ProjectFile> get _current => state.value ?? const [];

  void _put(ProjectFile p) {
    final list = [p, ..._current.where((x) => x.id != p.id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(list);
  }

  Future<void> add(ProjectFile p) async {
    await _store.save(p);
    _put(p);
    _sync.schedule(p);
  }

  /// Called by the editor after it saves, so the list stays current.
  void updated(ProjectFile p) => _put(p);

  Future<void> rename(String id, String name) async {
    final p = _current.where((x) => x.id == id).firstOrNull;
    final clean = name.trim();
    if (p == null || clean.isEmpty) return;
    final room = p.scene.room.copyWith(name: _clip(clean));
    final next = p.copyWith(
      name: _clip(clean),
      updatedAt: DateTime.now().toUtc(),
      scene: p.scene.withNode(room),
    );
    await add(next);
  }

  /// Creates "name copy" and returns its id.
  Future<String?> duplicate(String id) async {
    final p = _current.where((x) => x.id == id).firstOrNull;
    if (p == null) return null;
    final name = _clip('${p.name}${S.copySuffix}');
    final copy = ProjectFile(
      id: newProjectId(),
      name: name,
      updatedAt: DateTime.now().toUtc(),
      displayUnit: p.displayUnit,
      scene: p.scene.withNode(
        (p.scene.nodes[p.scene.rootId]! as RoomNode).copyWith(name: name),
      ),
    );
    await add(copy);
    return copy.id;
  }

  void hide(String id) {
    final p = _current.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    _pendingDeletes[id] = p;
    state = AsyncData(_current.where((x) => x.id != id).toList());
  }

  void restore(String id) {
    final p = _pendingDeletes.remove(id);
    if (p != null) _put(p);
  }

  Future<void> purge(String id) async {
    if (_pendingDeletes.remove(id) == null) return;
    await _store.delete(id);
    await _sync.delete(id);
  }

  static String _clip(String s) =>
      s.length <= maxNameLength ? s : s.substring(0, maxNameLength);
}

final projectsProvider =
    AsyncNotifierProvider<ProjectsController, List<ProjectFile>>(
      ProjectsController.new,
    );
