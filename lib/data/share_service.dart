import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/scene/scene.dart';
import '../domain/scene/scene_json.dart';
import '../domain/share/share_code.dart';

/// A shared room as stored online.
class ShareRow {
  const ShareRow({
    required this.code,
    required this.scene,
    required this.revision,
    required this.active,
    this.name = '',
  });

  final String code;
  final Scene scene;
  final int revision;
  final bool active;
  final String name;

  static ShareRow? fromMap(Map<String, Object?> r) {
    final scene = r['scene'];
    if (scene is! Map<String, Object?>) return null;
    try {
      return ShareRow(
        code: r['code']! as String,
        scene: SceneJson.decode(scene),
        revision: (r['revision'] as num?)?.toInt() ?? 0,
        active: r['active'] as bool? ?? false,
        name: (scene['name'] as String?) ?? '',
      );
    } on SceneFormatException {
      return null;
    }
  }
}

enum LiveStatus { connecting, live, reconnecting }

/// Callbacks a live channel raises.
class LiveHandlers {
  const LiveHandlers({
    this.onRow,
    this.onPreview,
    this.onEnded,
    this.onStatus,
    this.onViewers,
  });

  final void Function(ShareRow row)? onRow;
  final void Function(int rev, String id, double x, double z)? onPreview;
  final void Function()? onEnded;
  final void Function(LiveStatus status)? onStatus;
  final void Function(int viewers)? onViewers;
}

abstract class LiveChannel {
  void sendPreview(int rev, String id, double x, double z);
  Future<void> sendEnded();
  Future<void> close();
}

/// Live sharing: the owner writes, viewers read and listen.
abstract class ShareService {
  /// Inserts a new session and returns its code. Draws a fresh code on a clash,
  /// up to five times.
  Future<String> start({
    required String projectId,
    required String name,
    required Scene scene,
  });
  Future<void> push(String code, Scene scene, int revision, String name);
  Future<void> stop(String code);

  /// The active session with this code, or null.
  Future<ShareRow?> fetch(String code);
  LiveChannel open(
    String code, {
    required String role,
    required LiveHandlers handlers,
  });
}

class SupabaseShareService implements ShareService {
  SupabaseShareService(this._client, {this.maxAttempts = 5});

  final SupabaseClient _client;
  final int maxAttempts;

  SupabaseQueryBuilder get _table => _client.from('share_sessions');

  Map<String, Object?> _scene(Scene s, String name) => {
    ...SceneJson.encode(s),
    'name': name,
  };

  @override
  Future<String> start({
    required String projectId,
    required String name,
    required Scene scene,
  }) async {
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
    String? project = projectId;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final code = newShareCode();
      try {
        await _table.insert({
          'code': code,
          'project_id': project,
          'scene': _scene(scene, name),
          'revision': 0,
        });
        return code;
      } on PostgrestException catch (e) {
        if (e.code == '23503') {
          // The room is not in the cloud yet; the share does not need the link.
          project = null;
          attempt--;
          continue;
        }
        if (e.code != '23505') rethrow; // only a code clash is retried
      }
    }
    throw StateError('no free share code');
  }

  @override
  Future<void> push(String code, Scene scene, int revision, String name) async {
    await _table
        .update({
          'scene': _scene(scene, name),
          'revision': revision,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('code', code);
  }

  @override
  Future<void> stop(String code) async {
    await _table.update({'active': false}).eq('code', code);
  }

  @override
  Future<ShareRow?> fetch(String code) async {
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
    final r = await _table
        .select('code, scene, revision, active')
        .eq('code', code)
        .eq('active', true)
        .maybeSingle();
    return r == null ? null : ShareRow.fromMap(r);
  }

  @override
  LiveChannel open(
    String code, {
    required String role,
    required LiveHandlers handlers,
  }) {
    final channel = _client.channel('room:$code');
    if (handlers.onRow != null) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'share_sessions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'code',
          value: code,
        ),
        callback: (payload) {
          final row = ShareRow.fromMap(payload.newRecord);
          if (row == null) return;
          if (!row.active) {
            handlers.onEnded?.call();
          } else {
            handlers.onRow!(row);
          }
        },
      );
    }
    channel
      ..onBroadcast(
        event: 'preview',
        callback: (p) {
          final rev = (p['rev'] as num?)?.toInt();
          final id = p['id'];
          final x = (p['x'] as num?)?.toDouble();
          final z = (p['z'] as num?)?.toDouble();
          if (rev != null && id is String && x != null && z != null) {
            handlers.onPreview?.call(rev, id, x, z);
          }
        },
      )
      ..onBroadcast(event: 'ended', callback: (_) => handlers.onEnded?.call())
      ..onPresenceSync((_) {
        var viewers = 0;
        for (final s in channel.presenceState()) {
          viewers += s.presences
              .where((p) => p.payload['role'] == 'viewer')
              .length;
        }
        handlers.onViewers?.call(viewers);
      })
      ..subscribe((status, error) {
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            handlers.onStatus?.call(LiveStatus.live);
            unawaited(channel.track({'role': role}));
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
          case RealtimeSubscribeStatus.closed:
            handlers.onStatus?.call(LiveStatus.reconnecting);
        }
      });
    return _SupabaseLive(_client, channel);
  }
}

class _SupabaseLive implements LiveChannel {
  _SupabaseLive(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  @override
  void sendPreview(int rev, String id, double x, double z) {
    unawaited(
      _channel.sendBroadcastMessage(
        event: 'preview',
        payload: {'rev': rev, 'id': id, 'x': x, 'z': z},
      ),
    );
  }

  @override
  Future<void> sendEnded() => _channel.sendBroadcastMessage(
    event: 'ended',
    payload: <String, dynamic>{},
  );

  @override
  Future<void> close() async {
    await _client.removeChannel(_channel);
  }
}
