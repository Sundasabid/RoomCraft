import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/scene/scene_json.dart';

/// One row of the cloud project list (the scene is fetched separately).
class CloudRow {
  const CloudRow(this.id, this.name, this.updatedAt);

  final String id;
  final String name;
  final DateTime updatedAt;
}

/// Where projects are kept online. Tests use an in-memory version.
abstract class CloudStore {
  /// Signs in anonymously when there is no saved session.
  Future<void> ensureSession();

  Future<void> upsert(ProjectFile p);
  Future<List<CloudRow>> list();
  Future<ProjectFile?> fetch(String id);

  /// When the cloud copy was last written, or null if there is none. Cheap,
  /// so it can be checked before every upload.
  Future<DateTime?> updatedAt(String id);
  Future<void> delete(String id);
}

class SupabaseCloudStore implements CloudStore {
  SupabaseCloudStore(this._client);

  final SupabaseClient _client;

  SupabaseQueryBuilder get _projects => _client.from('projects');

  @override
  Future<void> ensureSession() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously();
  }

  @override
  Future<void> upsert(ProjectFile p) async {
    await ensureSession();
    await _projects.upsert({
      'id': p.id,
      'name': p.name,
      'scene': {...SceneJson.encode(p.scene), 'displayUnit': p.displayUnit},
      'updated_at': p.updatedAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<CloudRow>> list() async {
    await ensureSession();
    final rows = await _projects
        .select('id, name, updated_at')
        .order('updated_at', ascending: false);
    return [
      for (final r in rows)
        CloudRow(
          r['id'] as String,
          r['name'] as String,
          DateTime.parse(r['updated_at'] as String).toUtc(),
        ),
    ];
  }

  @override
  Future<ProjectFile?> fetch(String id) async {
    await ensureSession();
    final r = await _projects
        .select('id, name, scene, updated_at')
        .eq('id', id)
        .maybeSingle();
    if (r == null) return null;
    final scene = r['scene'];
    if (scene is! Map<String, Object?>) return null;
    return ProjectFile.fromJson({
      'format': projectFormat,
      'id': r['id'],
      'name': r['name'],
      'updatedAt': r['updated_at'],
      'displayUnit': scene['displayUnit'] ?? 'm',
      ...scene,
    });
  }

  @override
  Future<DateTime?> updatedAt(String id) async {
    await ensureSession();
    final r = await _projects.select('updated_at').eq('id', id).maybeSingle();
    if (r == null) return null;
    return DateTime.parse(r['updated_at'] as String).toUtc();
  }

  @override
  Future<void> delete(String id) async {
    await ensureSession();
    await _projects.delete().eq('id', id);
  }
}
