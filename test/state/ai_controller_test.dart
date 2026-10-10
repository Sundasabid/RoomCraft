import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/data/ai_service.dart';
import 'package:roomcraft/data/supabase_client.dart';
import 'package:roomcraft/state/ai_controller.dart';

import '../domain/fixtures.dart';

class FakeAi implements AiService {
  FakeAi(this.answer);
  final Future<List<Object?>> Function() answer;
  String? goal;
  int calls = 0;
  List<Map<String, Object?>> lastFeedback = const [];
  Map<String, Object?>? input;

  @override
  Future<List<Object?>> suggest({
    required String goal,
    required Map<String, Object?> input,
    List<Map<String, Object?>> feedback = const [],
  }) {
    calls++;
    lastFeedback = feedback;
    this.goal = goal;
    this.input = input;
    return answer();
  }
}

final room = bedroom(
  items: [
    item('item_bed', 'bed', 2.9, 1.1),
    item('item_sof', 'sofa', 2.6, 3.1),
    item('item_chr', 'chair', 0.8, 0.6),
  ],
);

Map<String, Object?> candidate(String name, List<num> chair) => {
  'name': name,
  'reason': 'Opens the walkway.',
  'items': [
    {'id': 'item_bed', 'x': 2.9, 'z': 1.1, 'rotation': 0},
    {'id': 'item_sof', 'x': 2.6, 'z': 3.1, 'rotation': 0},
    {'id': 'item_chr', 'x': chair[0], 'z': chair[1], 'rotation': 0},
  ],
};

ProviderContainer containerWith(AiService ai) {
  final c = ProviderContainer(
    overrides: [aiServiceProvider.overrideWithValue(ai)],
  );
  c.listen(aiControllerProvider, (_, _) {});
  return c;
}

void main() {
  test(
    'three candidates with one invalid give two options and one rejection',
    () async {
      final ai = FakeAi(
        () async => [
          candidate('A', [1.2, 0.5]),
          candidate('Bad', [2.6, 3.1]),
          candidate('B', [3.9, 2.4]),
        ],
      );
      final c = containerWith(ai);
      final stages = <AiState>[];
      c.listen(aiControllerProvider, (_, s) => stages.add(s));
      await c.read(aiControllerProvider.notifier).suggest(room, S_goal);
      final result = c.read(aiControllerProvider) as AiResults;
      expect(result.evaluation.options, hasLength(2));
      expect(result.evaluation.rejected.single, 'Sofa overlaps Chair');
      expect(ai.goal, S_goal);
      expect((ai.input!['items']! as List).length, 3);
      // The stages ran in order: reading, asking, checking, results.
      expect(stages.whereType<AiWorking>().map((s) => s.stage), [
        AiStage.reading,
        AiStage.asking,
        AiStage.checking,
      ]);
    },
  );

  test(
    'fewer than two valid layouts sends the reasons back once and merges the rounds',
    () async {
      var round = 0;
      final ai = FakeAi(() async {
        round++;
        return round == 1
            ? [
                candidate('A', [1.2, 0.5]),
                candidate('Bad', [2.6, 3.1]),
                candidate('Bad 2', [0.3, 2.7]),
              ]
            : [
                candidate('B', [3.9, 2.4]),
              ];
      });
      final c = containerWith(ai);
      await c.read(aiControllerProvider.notifier).suggest(room, S_goal);
      final result = c.read(aiControllerProvider) as AiResults;
      expect(ai.calls, 2);
      expect(ai.lastFeedback.map((f) => f['problems']), [
        ['Sofa overlaps Chair'],
        ['Chair blocks the door'],
      ]);
      expect(
        result.evaluation.options.map((o) => o.name),
        unorderedEquals(['A', 'B']),
      );
      expect(result.evaluation.rejected, hasLength(2));
      expect(result.evaluation.total, 4);
    },
  );

  test('a failure from the function becomes its plain error', () async {
    final c = containerWith(
      FakeAi(() async => throw const AiFailure(AiError.rateLimited)),
    );
    await c.read(aiControllerProvider.notifier).suggest(room, S_goal);
    expect(
      (c.read(aiControllerProvider) as AiFailed).error,
      AiError.rateLimited,
    );
  });

  test('cancelling drops a late answer', () async {
    final pending = Completer<List<Object?>>();
    final c = containerWith(FakeAi(() => pending.future));
    final run = c.read(aiControllerProvider.notifier).suggest(room, S_goal);
    await Future<void>.delayed(Duration.zero);
    c.read(aiControllerProvider.notifier).cancel();
    pending.complete([
      candidate('A', [1.2, 0.5]),
    ]);
    await run;
    expect(c.read(aiControllerProvider), isA<AiIdle>());
  });
}

// ignore: constant_identifier_names
const S_goal = 'Improve movement';
