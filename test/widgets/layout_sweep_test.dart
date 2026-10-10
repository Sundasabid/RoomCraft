// Every screen at the smallest phone, the reference phone, a tablet and in
// landscape, with text at 130 percent, in light and dark. Any overflow or
// layout error fails the test.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roomcraft/app.dart';
import 'package:roomcraft/core/strings.dart';
import 'package:roomcraft/core/theme/theme.dart';
import 'package:roomcraft/data/supabase_client.dart';
import 'package:roomcraft/domain/scene/scene_json.dart';
import 'package:roomcraft/features/editor/editor_screen.dart';
import 'package:roomcraft/features/editor/view3d/view3d.dart';
import 'package:roomcraft/state/connectivity_provider.dart';
import 'package:roomcraft/state/editor_controller.dart';
import 'package:roomcraft/state/projects_controller.dart';
import 'package:roomcraft/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/fixtures.dart';
import '../state/share_test.dart' show FakeShare;
import 'editor_test.dart' show MemoryStore;

final _rooms = [
  ProjectFile(
    id: 'p1',
    name: 'A rather long room name for the main bedroom',
    updatedAt: DateTime.utc(2026),
    displayUnit: 'm',
    scene: bedroom(
      items: [
        item('item_bed', 'bed', 2.9, 1.1),
        item('item_war', 'wardrobe', 2.6, 2.3),
        item('item_sof', 'sofa', 2.6, 3.1),
      ],
    ),
  ),
  ProjectFile(
    id: 'p2',
    name: 'Studio',
    updatedAt: DateTime.utc(2025),
    displayUnit: 'ft',
    scene: lShapedStudio(items: [item('item_desk', 'desk', 1.0, 0.4)]),
  ),
];

const _sizes = {
  'small phone': Size(320, 568),
  'phone': Size(360, 800),
  'tablet': Size(840, 1200),
  'landscape': Size(800, 360),
};

/// What to open after the first frame, if anything.
typedef _Step = Future<void> Function(WidgetTester tester);

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

final _screens = <String, (String, _Step?)>{
  'welcome': ('/welcome', null),
  'welcome last page': (
    '/welcome',
    (tester) async {
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text(S.next));
        for (var f = 0; f < 10; f++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }
    },
  ),
  'rooms': ('/rooms', null),
  'settings': ('/settings', null),
  'setup': ('/setup', null),
  'editor': ('/editor/p1', null),
  'editor selected': (
    '/editor/p1',
    (tester) async {
      ProviderScope.containerOf(
        tester.element(find.byType(EditorScreen)),
      ).read(editorProvider('p1').notifier).select('item_sof');
      await tester.pumpAndSettle();
    },
  ),
  'catalogue': ('/editor/p1', (t) => _tapText(t, S.toolAdd)),
  'finishes': ('/editor/p1', (t) => _tapText(t, S.toolFinish)),
  'ai panel': ('/editor/p1', (t) => _tapText(t, S.toolAi)),
  'lighting': (
    '/editor/p1',
    (tester) async {
      await _tapText(tester, S.toolFinish);
      await _tapText(tester, S.targetLight);
    },
  ),
  'share sheet': (
    '/editor/p1',
    (tester) async {
      await tester.tap(find.bySemanticsLabel(S.shareLiveShort));
      await tester.pumpAndSettle();
    },
  ),
  'live': ('/live', null),
  'viewer': ('/viewer/ABC234', null),
};

void main() {
  for (final dark in [false, true]) {
    for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
      for (final MapEntry(key: screen, value: (path, step))
          in _screens.entries) {
        final name = '$screen, $sizeName, ${dark ? 'dark' : 'light'}';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          // ignore: invalid_use_of_visible_for_testing_member
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarded', true);
          late GoRouter router;
          final share = FakeShare();
          await share.start(
            projectId: 'p1',
            name: _rooms.first.name,
            scene: _rooms.first.scene,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                preferencesProvider.overrideWithValue(prefs),
                localStoreProvider.overrideWithValue(MemoryStore(_rooms)),
                isOnlineProvider.overrideWithValue(true),
                view3dEnabledProvider.overrideWithValue(false),
                shareServiceProvider.overrideWithValue(share),
              ],
              child: Consumer(
                builder: (context, ref, _) {
                  router = ref.watch(routerProvider);
                  return MaterialApp.router(
                    theme: RoomCraftTheme.light(),
                    darkTheme: RoomCraftTheme.dark(),
                    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                    routerConfig: router,
                  );
                },
              ),
            ),
          );
          router.go(path);
          if (path.startsWith('/viewer') || path == '/welcome') {
            // The LIVE dot and the welcome art move forever, so never settle.
            for (var i = 0; i < 10; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
          } else {
            await tester.pumpAndSettle();
          }
          await step?.call(tester);
          // Unmount so screens can cancel their timers and subscriptions.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 3));
        });
      }
    }
  }
}
