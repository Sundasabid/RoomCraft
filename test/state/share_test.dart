import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/data/share_service.dart';
import 'package:roomcraft/data/supabase_client.dart';
import 'package:roomcraft/domain/scene/scene.dart';
import 'package:roomcraft/state/connectivity_provider.dart';
import 'package:roomcraft/state/share_controller.dart';
import 'package:roomcraft/state/viewer_controller.dart';

import '../domain/fixtures.dart';

class FakeChannel implements LiveChannel {
  FakeChannel(this.handlers);
  final LiveHandlers handlers;
  final previews = <(int, String, double, double)>[];
  bool ended = false;
  bool closed = false;

  @override
  void sendPreview(int rev, String id, double x, double z) =>
      previews.add((rev, id, x, z));

  @override
  Future<void> sendEnded() async => ended = true;

  @override
  Future<void> close() async => closed = true;
}

class FakeShare implements ShareService {
  final rows = <String, ShareRow>{};
  final pushes = <(int, Scene)>[];
  final channels = <FakeChannel>[];

  @override
  Future<String> start({
    required String projectId,
    required String name,
    required Scene scene,
  }) async {
    rows['ABC234'] = ShareRow(
      code: 'ABC234',
      scene: scene,
      revision: 0,
      active: true,
      name: name,
    );
    return 'ABC234';
  }

  @override
  Future<void> push(String code, Scene scene, int revision, String name) async {
    pushes.add((revision, scene));
    rows[code] = ShareRow(
      code: code,
      scene: scene,
      revision: revision,
      active: true,
      name: name,
    );
  }

  @override
  Future<void> stop(String code) async {
    final r = rows[code]!;
    rows[code] = ShareRow(
      code: code,
      scene: r.scene,
      revision: r.revision,
      active: false,
    );
  }

  @override
  Future<ShareRow?> fetch(String code) async {
    final r = rows[code];
    return r != null && r.active ? r : null;
  }

  @override
  LiveChannel open(
    String code, {
    required String role,
    required LiveHandlers handlers,
  }) {
    final c = FakeChannel(handlers);
    channels.add(c);
    return c;
  }
}

Scene withBedAt(double x) => bedroom(items: [item('item_bed', 'bed', x, 1.1)]);

void main() {
  late FakeShare share;
  late ProviderContainer c;

  setUp(() {
    share = FakeShare();
    c = ProviderContainer(
      overrides: [
        shareServiceProvider.overrideWithValue(share),
        isOnlineProvider.overrideWithValue(true),
      ],
    );
  });
  tearDown(() => c.dispose());

  group('owner', () {
    ShareController owner() => c.read(shareControllerProvider.notifier);

    test(
      'rapid changes become one write with the latest scene and revision + 1',
      () async {
        await owner().start(
          projectId: 'p',
          name: 'Room',
          scene: withBedAt(2.9),
        );
        for (var i = 0; i < 5; i++) {
          owner().commit(withBedAt(2.0 + i * 0.1), 'Room');
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(share.pushes, hasLength(1));
        expect(share.pushes.single.$1, 1);
        expect(share.pushes.single.$2.item('item_bed')!.x, closeTo(2.4, 1e-9));
        owner().commit(withBedAt(1.0), 'Room');
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(share.pushes.last.$1, 2);
        expect(c.read(shareControllerProvider).revision, 2);
      },
    );

    test(
      'drag previews are throttled to about one per 100 ms and carry the revision',
      () async {
        await owner().start(
          projectId: 'p',
          name: 'Room',
          scene: withBedAt(2.9),
        );
        final ch = share.channels.single;
        for (var i = 0; i < 10; i++) {
          owner().preview('item_bed', 2.0 + i * 0.01, 1.1);
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(ch.previews.length, 2);
        expect(ch.previews.last.$3, closeTo(2.09, 1e-9));
        expect(ch.previews.every((p) => p.$1 == 0), isTrue);
      },
    );

    test('stopping tells viewers and marks the row inactive', () async {
      await owner().start(projectId: 'p', name: 'Room', scene: withBedAt(2.9));
      final ch = share.channels.single;
      await owner().stop();
      expect(ch.ended, isTrue);
      expect(ch.closed, isTrue);
      expect(share.rows['ABC234']!.active, isFalse);
      expect(c.read(shareControllerProvider).active, isFalse);
    });
  });

  group('viewer', () {
    Future<ViewerState> open() async {
      share.rows['ABC234'] = ShareRow(
        code: 'ABC234',
        scene: withBedAt(2.9),
        revision: 3,
        active: true,
        name: 'Room',
      );
      c.listen(viewerProvider('ABC234'), (_, _) {});
      return c.read(viewerProvider('ABC234').future);
    }

    ViewerState now() => c.read(viewerProvider('ABC234')).value!;
    LiveHandlers h() => share.channels.last.handlers;

    test('an unknown code fails with no live room', () async {
      c.listen(viewerProvider('ZZZ222'), (_, _) {});
      await expectLater(
        c.read(viewerProvider('ZZZ222').future),
        throwsA(isA<NoLiveRoom>()),
      );
    });

    test('newer revisions replace the scene; older ones are ignored', () async {
      await open();
      h().onRow!(
        ShareRow(
          code: 'ABC234',
          scene: withBedAt(1.0),
          revision: 4,
          active: true,
        ),
      );
      expect(now().scene.item('item_bed')!.x, 1.0);
      h().onRow!(
        ShareRow(
          code: 'ABC234',
          scene: withBedAt(3.0),
          revision: 2,
          active: true,
        ),
      );
      expect(now().scene.item('item_bed')!.x, 1.0);
      expect(now().revision, 4);
    });

    test(
      'previews apply only for the current revision and clear on the next',
      () async {
        await open();
        h().onPreview!(3, 'item_bed', 1.5, 1.1);
        expect(now().displayScene.item('item_bed')!.x, 1.5);
        expect(now().scene.item('item_bed')!.x, 2.9);
        h().onPreview!(2, 'item_bed', 0.5, 1.1);
        expect(now().displayScene.item('item_bed')!.x, 1.5);
        h().onRow!(
          ShareRow(
            code: 'ABC234',
            scene: withBedAt(1.6),
            revision: 4,
            active: true,
          ),
        );
        expect(now().previews, isEmpty);
      },
    );

    test('warnings come from the same rules as the owner', () async {
      await open();
      h().onRow!(
        ShareRow(
          code: 'ABC234',
          scene: bedroom(
            items: [
              item('item_bed', 'bed', 2.9, 1.1),
              item('item_war', 'wardrobe', 2.9, 1.5),
            ],
          ),
          revision: 4,
          active: true,
        ),
      );
      expect(now().report.headline, 'Bed overlaps Wardrobe');
    });

    test('reconnecting keeps the room and a resync replaces it', () async {
      await open();
      h().onStatus!(LiveStatus.reconnecting);
      expect(now().status, ViewerStatus.reconnecting);
      share.rows['ABC234'] = ShareRow(
        code: 'ABC234',
        scene: withBedAt(0.9),
        revision: 7,
        active: true,
      );
      await c.read(viewerProvider('ABC234').notifier).resync();
      expect(now().status, ViewerStatus.live);
      expect(now().scene.item('item_bed')!.x, 0.9);
    });

    test(
      'a missed live update is caught by the quiet check, and so is an end',
      () async {
        await open();
        // The owner writes, but no live event reaches this viewer.
        await share.push('ABC234', withBedAt(1.5), 4, 'Room');
        await Future<void>.delayed(
          ViewerController.checkEvery + const Duration(milliseconds: 200),
        );
        expect(now().revision, 4);
        expect(now().scene.item('item_bed')!.x, 1.5);
        await share.stop('ABC234');
        await Future<void>.delayed(
          ViewerController.checkEvery + const Duration(milliseconds: 200),
        );
        expect(now().status, ViewerStatus.ended);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('the owner stopping ends the session for good', () async {
      await open();
      h().onEnded!();
      expect(now().status, ViewerStatus.ended);
      h().onRow!(
        ShareRow(
          code: 'ABC234',
          scene: withBedAt(1.0),
          revision: 9,
          active: true,
        ),
      );
      expect(now().status, ViewerStatus.ended);
    });
  });
}
