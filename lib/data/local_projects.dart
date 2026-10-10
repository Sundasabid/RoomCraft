import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/scene/scene_json.dart';

/// Projects as JSON files in `<documents>/projects/<id>.json`.
///
/// Writes go to a temporary file that is then renamed, so a crash never
/// leaves a half-written project.
class LocalProjectStore {
  LocalProjectStore(this._root);

  /// Uses the app documents folder.
  static Future<LocalProjectStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    return LocalProjectStore(Directory('${docs.path}/projects'));
  }

  final Directory _root;

  File _file(String id) => File('${_root.path}/$id.json');

  /// The copy last agreed with the cloud, kept per project for merging.
  /// A sub-folder, so [list] never sees it.
  File _baseFile(String id) => File('${_root.path}/.synced/$id.json');

  Future<void> save(ProjectFile project) =>
      _writeAtomic(_file(project.id), project);

  /// Remembers [project] as the copy both this phone and the cloud have.
  Future<void> saveSynced(ProjectFile project) =>
      _writeAtomic(_baseFile(project.id), project);

  Future<ProjectFile?> loadSynced(String id) async {
    final f = _baseFile(id);
    if (!f.existsSync()) return null;
    return _read(f);
  }

  Future<void> _writeAtomic(File target, ProjectFile project) async {
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(project.toJson()), flush: true);
    await temp.rename(target.path);
  }

  Future<ProjectFile?> load(String id) async {
    final f = _file(id);
    if (!f.existsSync()) return null;
    return _read(f);
  }

  Future<bool> exists(String id) async => _file(id).existsSync();

  /// Every readable project, newest edit first. Unreadable files are skipped.
  Future<List<ProjectFile>> list() async {
    if (!_root.existsSync()) return [];
    final out = <ProjectFile>[];
    await for (final e in _root.list()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      final p = await _read(e);
      if (p != null) out.add(p);
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<void> delete(String id) async {
    for (final f in [_file(id), _baseFile(id)]) {
      if (f.existsSync()) await f.delete();
    }
  }

  Future<ProjectFile?> _read(File f) async {
    try {
      final json = jsonDecode(await f.readAsString());
      if (json is! Map<String, Object?>) return null;
      return ProjectFile.fromJson(json);
    } on Exception {
      return null;
    }
  }
}

/// Coalesces rapid saves: only the newest project is written, [delay] after
/// the last change. [flush] writes anything pending at once.
class AutosaveQueue {
  AutosaveQueue(this._write, {this.delay = const Duration(milliseconds: 300)});

  final Future<void> Function(ProjectFile) _write;
  final Duration delay;
  Timer? _timer;
  ProjectFile? _pending;
  Future<void> _last = Future.value();

  bool get hasPending => _pending != null;

  void schedule(ProjectFile project) {
    _pending = project;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  Future<void> flush() {
    _timer?.cancel();
    final p = _pending;
    _pending = null;
    if (p != null) {
      // One failed write must not stop the ones after it.
      _last = _last.then((_) => _write(p)).catchError((Object e) {
        developer.log('autosave failed: $e', name: 'roomcraft');
      });
    }
    return _last;
  }

  void dispose() => _timer?.cancel();
}
