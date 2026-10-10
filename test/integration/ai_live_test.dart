// The whole AI path against the deployed function: real room in, Gemini
// layouts out, the app's validator deciding. Needs the GEMINI_API_KEY secret.
// Run: flutter test test/integration --dart-define-from-file=env.json
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/config.dart';
import 'package:roomcraft/data/ai_service.dart';
import 'package:roomcraft/data/supabase_client.dart';
import 'package:roomcraft/domain/checks/placement_checker.dart';
import 'package:roomcraft/state/ai_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/fixtures.dart';

void main() {
  test(
    'Gemini proposes layouts and only valid ones survive',
    () async {
      final client = SupabaseClient(
        Config.supabaseUrl,
        Config.supabaseAnonKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final ai = SupabaseAiService(client);
      // A cramped bedroom: the chair sits right in the door's path.
      final room = bedroom(
        items: [
          item('item_bed', 'bed', 1.6, 1.6),
          item('item_war', 'wardrobe', 3.5, 0.35),
          item('item_desk', 'desk', 3.75, 2.2, rotation: 90),
          item('item_chair', 'chair', 1.1, 3.0),
          item('item_plant', 'plant', 3.95, 3.35, locked: true),
        ],
      );
      final sw = Stopwatch()..start();
      // The same path the panel uses: ask, check, and one corrective round.
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(ai)],
      );
      container.listen(aiControllerProvider, (_, _) {});
      await container
          .read(aiControllerProvider.notifier)
          .suggest(room, 'Improve movement');
      final state = container.read(aiControllerProvider);
      if (state is AiFailed) fail('function said ${state.error}');
      final result = (state as AiResults).evaluation;
      // ignore: avoid_print
      print(
        '${sw.elapsedMilliseconds} ms, ${result.total} candidates, '
        'score ${result.currentScore} -> ${result.options.map((o) => '${o.name}:${o.score}').join(', ')}, '
        'rejected: ${result.rejected}',
      );
      expect(result.total, greaterThan(0));
      for (final o in result.options) {
        expect(PlacementChecker.checkScene(o.scene).isValid, isTrue);
        expect(
          o.scene.item('item_plant')!.position,
          room.item('item_plant')!.position,
        );
      }
      container.dispose();
      // ignore: avoid_print
      print('anon user ${client.auth.currentUser?.id}');
      await client.dispose();
    },
    timeout: const Timeout(Duration(seconds: 60)),
    skip: Config.isComplete ? false : 'needs --dart-define-from-file=env.json',
  );
}
