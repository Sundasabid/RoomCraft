import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/scene/scene_json.dart';
import 'local_projects.dart';

/// Rooms in the browser's storage, one JSON entry per room, with the same
/// behaviour as the files used on phones.
class WebProjectStore extends LocalProjectStore {
  WebProjectStore(this._prefs) : super.withoutFiles();

  static Future<WebProjectStore> open() async =>
      WebProjectStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _room = 'room.';
  static const _synced = 'roomSynced.';

  @override
  Future<void> save(ProjectFile project) =>
      _prefs.setString('$_room${project.id}', jsonEncode(project.toJson()));

  @override
  Future<void> saveSynced(ProjectFile project) =>
      _prefs.setString('$_synced${project.id}', jsonEncode(project.toJson()));

  @override
  Future<ProjectFile?> load(String id) async => _read('$_room$id');

  @override
  Future<ProjectFile?> loadSynced(String id) async => _read('$_synced$id');

  @override
  Future<bool> exists(String id) async => _prefs.containsKey('$_room$id');

  @override
  Future<List<ProjectFile>> list() async {
    final out = [
      for (final key in _prefs.getKeys())
        if (key.startsWith(_room)) ?_read(key),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  @override
  Future<void> delete(String id) async {
    await _prefs.remove('$_room$id');
    await _prefs.remove('$_synced$id');
  }

  ProjectFile? _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? ProjectFile.fromJson(json) : null;
    } on Exception {
      return null;
    }
  }
}
