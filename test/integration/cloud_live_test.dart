// Talks to the real Supabase project. Skipped unless the settings are passed:
// flutter test test/integration --dart-define-from-file=env.json
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/config.dart';
import 'package:roomcraft/data/cloud_projects.dart';
import 'package:roomcraft/domain/scene/ids.dart';
import 'package:roomcraft/domain/scene/scene_json.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/fixtures.dart';

void main() {
  test(
    'save, list, recover exactly and delete against the live project',
    () async {
      final client = SupabaseClient(
        Config.supabaseUrl,
        Config.supabaseAnonKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final store = SupabaseCloudStore(client);
      final p = ProjectFile(
        id: newProjectId(),
        name: 'Live check',
        updatedAt: DateTime.now().toUtc(),
        displayUnit: 'ft',
        scene: bedroom(
          items: [
            item('item_bed', 'bed', 2.9, 1.1, rotation: 90, locked: true),
            item('item_rug', 'rug', 1.5, 2.5),
          ],
        ),
      );
      await store.upsert(p);
      final rows = await store.list();
      final row = rows.firstWhere((r) => r.id == p.id);
      expect(row.updatedAt, p.updatedAt);
      final back = await store.fetch(p.id);
      expect(back!.scene, p.scene);
      expect(back.displayUnit, 'ft');
      expect(back.updatedAt, p.updatedAt);
      await store.delete(p.id);
      expect(await store.fetch(p.id), isNull);
      // ignore: avoid_print
      print('anon user ${client.auth.currentUser?.id}');
      await client.dispose();
    },
    skip: Config.isComplete ? false : 'needs --dart-define-from-file=env.json',
  );
}
