// Live sharing against the real project, owner and viewer as two anonymous
// users. Run: flutter test test/integration --dart-define-from-file=env.json
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/config.dart';
import 'package:roomcraft/data/share_service.dart';
import 'package:roomcraft/domain/share/share_code.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/fixtures.dart';

SupabaseClient client() => SupabaseClient(
  Config.supabaseUrl,
  Config.supabaseAnonKey,
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

void main() {
  test(
    'an owner move reaches the viewer, previews arrive, viewers cannot write, stop ends it',
    () async {
      final ownerClient = client();
      final viewerClient = client();
      await ownerClient.auth.signInAnonymously();
      await viewerClient.auth.signInAnonymously();
      final owner = SupabaseShareService(ownerClient);
      final viewer = SupabaseShareService(viewerClient);

      final scene = bedroom(items: [item('item_bed', 'bed', 2.9, 1.1)]);
      final code = await owner.start(
        projectId: '6f1c2c1e-6c3a-4a7e-9d6b-1d3f0c2a9b11',
        name: 'Live room',
        scene: scene,
      );
      expect(isShareCode(code), isTrue);

      final first = await viewer.fetch(code);
      expect(first!.scene, scene);
      expect(first.name, 'Live room');

      final rows = StreamController<ShareRow>.broadcast();
      final previews = StreamController<double>.broadcast();
      final ended = Completer<void>();
      final live = Completer<void>();
      final viewers = StreamController<int>.broadcast();
      final ownerLive = owner.open(
        code,
        role: 'owner',
        handlers: LiveHandlers(onViewers: viewers.add),
      );
      final viewerLive = viewer.open(
        code,
        role: 'viewer',
        handlers: LiveHandlers(
          onRow: rows.add,
          onPreview: (rev, id, x, z) => previews.add(x),
          onEnded: () => ended.isCompleted ? null : ended.complete(),
          onStatus: (s) {
            if (s == LiveStatus.live && !live.isCompleted) live.complete();
          },
        ),
      );
      await live.future.timeout(const Duration(seconds: 15));
      // ignore: avoid_print
      print('step: viewer subscribed');
      expect(
        await viewers.stream
            .firstWhere((n) => n >= 1)
            .timeout(const Duration(seconds: 15)),
        1,
      );

      // ignore: avoid_print
      print('step: viewer counted');
      // Owner moves the bed: the viewer sees it without asking.
      final moved = scene.withNode(scene.item('item_bed')!.copyWith(x: 2.0));
      final sw = Stopwatch()..start();
      final next = rows.stream.first.timeout(const Duration(seconds: 10));
      await owner.push(code, moved, 1, 'Live room');
      final row = await next;
      // ignore: avoid_print
      print('owner write to viewer update: ${sw.elapsedMilliseconds} ms');
      expect(row.revision, 1);
      expect(row.scene.item('item_bed')!.x, 2.0);

      // ignore: avoid_print
      print('step: row arrived');
      final preview = previews.stream.first.timeout(
        const Duration(seconds: 10),
      );
      ownerLive.sendPreview(1, 'item_bed', 1.5, 1.1);
      expect(await preview, 1.5);

      // The server refuses writes from the viewer.
      final hijack = await viewerClient
          .from('share_sessions')
          .update({'revision': 99})
          .eq('code', code)
          .select();
      expect(hijack, isEmpty);

      await ownerLive.sendEnded();
      await owner.stop(code);
      await ended.future.timeout(const Duration(seconds: 10));
      expect(await viewer.fetch(code), isNull);

      await viewerLive.close();
      await ownerLive.close();
      // ignore: avoid_print
      print(
        'users ${ownerClient.auth.currentUser!.id} ${viewerClient.auth.currentUser!.id}',
      );
      await ownerClient.dispose();
      await viewerClient.dispose();
    },
    timeout: const Timeout(Duration(seconds: 90)),
    skip: Config.isComplete ? false : 'needs --dart-define-from-file=env.json',
  );
}
