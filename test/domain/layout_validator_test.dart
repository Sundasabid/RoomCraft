import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/domain/checks/layout_validator.dart';
import 'package:roomcraft/domain/scene/scene.dart';

import 'fixtures.dart';

Scene room({bool lockBed = false}) => bedroom(
  items: [
    item('item_bed', 'bed', 2.9, 1.1, locked: lockBed),
    item('item_sof', 'sofa', 2.6, 3.1),
    item('item_chr', 'chair', 0.8, 0.6),
  ],
);

Map<String, Object?> candidate(
  Map<String, List<num>> places, {
  String name = 'Try',
}) => {
  'name': name,
  'reason': 'Opens the walkway.',
  'items': [
    for (final e in places.entries)
      {'id': e.key, 'x': e.value[0], 'z': e.value[1], 'rotation': e.value[2]},
  ],
};

Map<String, List<num>> current({List<num>? chair, List<num>? bed}) => {
  'item_bed': bed ?? [2.9, 1.1, 0],
  'item_sof': [2.6, 3.1, 0],
  'item_chr': chair ?? [0.8, 0.6, 0],
};

String reasonOf(CandidateCheck c) => (c as CandidateRejected).reason;

void main() {
  test('a valid move is accepted', () {
    final r = LayoutValidator.check(
      room(),
      candidate(current(chair: [1.2, 0.5, 0])),
    );
    expect(r, isA<CandidateAccepted>());
    expect((r as CandidateAccepted).moved, 1);
    expect(r.scene.item('item_chr')!.x, 1.2);
  });

  test('missing id is rejected', () {
    final places = current(chair: [1.2, 0.5, 0])..remove('item_sof');
    expect(
      reasonOf(LayoutValidator.check(room(), candidate(places))),
      'Leaves out Sofa',
    );
  });

  test('unknown id is rejected', () {
    final places = current(chair: [1.2, 0.5, 0])..['item_zzz'] = [1, 1, 0];
    expect(
      LayoutValidator.check(room(), candidate(places)),
      isA<CandidateRejected>(),
    );
  });

  test('repeated id is rejected', () {
    final c = candidate(current(chair: [1.2, 0.5, 0]));
    (c['items']! as List<Object?>).add({
      'id': 'item_chr',
      'x': 1.0,
      'z': 1.0,
      'rotation': 0,
    });
    expect(reasonOf(LayoutValidator.check(room(), c)), 'Places Chair twice');
  });

  test('rotation 45 is rejected', () {
    expect(
      LayoutValidator.check(room(), candidate(current(chair: [1.2, 0.5, 45]))),
      isA<CandidateRejected>(),
    );
  });

  test('NaN is rejected', () {
    expect(
      LayoutValidator.check(
        room(),
        candidate(current(chair: [double.nan, 0.5, 0])),
      ),
      isA<CandidateRejected>(),
    );
  });

  test('an overlap is rejected with the violation as the reason', () {
    final r = LayoutValidator.check(
      room(),
      candidate(current(chair: [2.6, 3.1, 0])),
    );
    expect(reasonOf(r), 'Sofa overlaps Chair');
  });

  test('a blocked door is rejected', () {
    final r = LayoutValidator.check(
      room(),
      candidate(current(chair: [0.3, 2.7, 0])),
    );
    expect(reasonOf(r), 'Chair blocks the door');
  });

  test('no item moved is rejected', () {
    expect(
      reasonOf(LayoutValidator.check(room(), candidate(current()))),
      'Moves nothing',
    );
  });

  test('a locked item stays untouched even if the AI moves it', () {
    final r = LayoutValidator.check(
      room(lockBed: true),
      candidate(current(chair: [1.2, 0.5, 0], bed: [1.0, 1.0, 90])),
    );
    final scene = (r as CandidateAccepted).scene;
    expect(scene.item('item_bed')!.x, 2.9);
    expect(scene.item('item_bed')!.rotation, 0);
  });

  test('positions are snapped to 5 cm', () {
    final r = LayoutValidator.check(
      room(),
      candidate(current(chair: [1.213, 0.488, 0])),
    );
    final chair = (r as CandidateAccepted).scene.item('item_chr')!;
    expect(chair.x, 1.2);
    expect(chair.z, 0.5);
  });

  test(
    'three candidates with one invalid give two valid options in score order',
    () {
      final result = LayoutValidator.evaluate(room(), [
        candidate(current(chair: [1.2, 0.5, 0]), name: 'A'),
        candidate(current(chair: [2.6, 3.1, 0]), name: 'Bad'),
        candidate(current(chair: [3.9, 2.4, 0]), name: 'B'),
      ]);
      expect(result.options, hasLength(2));
      expect(result.options.map((o) => o.name), isNot(contains('Bad')));
      expect(
        result.options[0].score,
        greaterThanOrEqualTo(result.options[1].score),
      );
      expect(result.rejected, hasLength(1));
      expect(result.total, 3);
    },
  );

  test('a repeated layout is shown once, within a round and across rounds', () {
    final a = candidate(current(chair: [1.2, 0.5, 0]), name: 'A');
    final again = candidate(current(chair: [1.2, 0.5, 0]), name: 'Again');
    final first = LayoutValidator.evaluate(room(), [a, again]);
    expect(first.options.map((o) => o.name), ['A']);
    final later = LayoutValidator.evaluate(room(), [again]);
    expect(first.merge(later).options.map((o) => o.name), ['A']);
  });
}
