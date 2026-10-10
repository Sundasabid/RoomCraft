// Renders key screens at 360 by 800 in light and dark for a design review.
// Run: flutter test tool/screenshots/screens_test.dart --update-goldens
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roomcraft/app.dart';
import 'package:roomcraft/core/theme/theme.dart';
import 'package:roomcraft/data/ai_service.dart';
import 'package:roomcraft/data/local_projects.dart';
import 'package:roomcraft/data/supabase_client.dart';
import 'package:roomcraft/domain/scene/scene_json.dart';
import 'package:roomcraft/features/editor/editor_screen.dart';
import 'package:roomcraft/features/editor/editor_views.dart';
import 'package:roomcraft/features/editor/view3d/view3d.dart';

import 'package:roomcraft/state/ai_controller.dart';
import 'package:roomcraft/state/connectivity_provider.dart';
import 'package:roomcraft/state/editor_controller.dart';
import 'package:roomcraft/state/projects_controller.dart';
import 'package:roomcraft/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/domain/fixtures.dart';

class ScriptedAi implements AiService {
  @override
  Future<List<Object?>> suggest({
    required String goal,
    required Map<String, Object?> input,
    List<Map<String, Object?>> feedback = const [],
  }) async {
    Map<String, Object?> c(String name, String reason, List<List<num>> at) => {
      'name': name,
      'reason': reason,
      'items': [
        for (final (i, id) in [
          'item_bed',
          'item_war',
          'item_rug',
          'item_sof',
          'item_pl',
        ].indexed)
          {'id': id, 'x': at[i][0], 'z': at[i][1], 'rotation': at[i][2]},
      ],
    };
    return [
      c(
        'Open centre',
        'Moves the sofa back so the middle of the room is free to walk.',
        [
          [2.9, 1.1, 0],
          [0.7, 0.35, 0],
          [2.4, 2.6, 0],
          [3.1, 3.1, 0],
          [3.9, 3.3, 0],
        ],
      ),
      c(
        'Wall hugger',
        'Keeps everything on the walls for one wide path from the door.',
        [
          [3.3, 1.0, 0],
          [0.7, 0.35, 0],
          [2.0, 2.4, 0],
          [3.1, 3.15, 0],
          [0.4, 1.3, 0],
        ],
      ),
      c('Clash', 'Puts the sofa in the door path.', [
        [2.9, 1.1, 0],
        [0.7, 0.35, 0],
        [2.4, 2.6, 0],
        [0.9, 2.7, 0],
        [3.9, 3.3, 0],
      ]),
    ];
  }
}

class MemoryStore extends LocalProjectStore {
  MemoryStore(this.projects) : super(Directory.systemTemp);
  final List<ProjectFile> projects;
  @override
  Future<List<ProjectFile>> list() async => projects;
  @override
  Future<void> save(ProjectFile project) async {}
  @override
  Future<ProjectFile?> load(String id) async =>
      projects.where((p) => p.id == id).firstOrNull;
}

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await family('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  await family('Poppins', [
    'assets/fonts/Poppins-SemiBold.ttf',
    'assets/fonts/Poppins-Bold.ttf',
  ]);
  final flutterRoot = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent.parent.parent.path;
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

final sample = [
  ProjectFile(
    id: 'p1',
    name: 'Bedroom',
    updatedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
    displayUnit: 'm',
    scene: bedroom(
      items: [
        item('item_bed', 'bed', 2.9, 1.1),
        item('item_war', 'wardrobe', 0.7, 0.35),
        item('item_rug', 'rug', 2.4, 2.6),
        item('item_sof', 'sofa', 2.6, 3.1),
        item('item_pl', 'plant', 3.9, 3.3),
      ],
    ),
  ),
  ProjectFile(
    id: 'p3',
    name: 'Empty room',
    updatedAt: DateTime.utc(2025),
    displayUnit: 'm',
    scene: bedroom(),
  ),
  ProjectFile(
    id: 'p4',
    name: 'Clash',
    updatedAt: DateTime.utc(2025),
    displayUnit: 'm',
    scene: bedroom(
      items: [
        item('item_bed', 'bed', 2.9, 1.1),
        item('item_war', 'wardrobe', 2.6, 2.3),
        item('item_rug', 'rug', 1.6, 2.6),
        item('item_chr', 'chair', 0.9, 0.6, locked: true),
      ],
    ),
  ),
  ProjectFile(
    id: 'p2',
    name: 'Studio flat',
    updatedAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
    displayUnit: 'm',
    scene: lShapedStudio(items: [item('item_desk', 'desk', 1.0, 0.4)]),
  ),
];

void main() {
  setUpAll(loadFonts);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final (name, path, projects) in [
      ('welcome_1', '/welcome', sample),
      ('welcome_2', '/welcome', sample),
      ('welcome_3', '/welcome', sample),
      ('rooms', '/rooms', sample),
      ('rooms_empty', '/rooms', <ProjectFile>[]),
      ('live', '/live', sample),
      ('settings', '/settings', sample),
      ('setup', '/setup', sample),
      ('editor_empty', '/editor/p3', sample),
      ('editor_furnished', '/editor/p1', sample),
      ('editor_warning', '/editor/p4', sample),
      ('editor_catalogue', '/editor/p3', sample),
      ('editor_finishes', '/editor/p1', sample),
      ('editor_lighting', '/editor/p1', sample),
      ('editor_share', '/editor/p4', sample),
      ('editor_3d', '/editor/p4', sample),
      ('editor_3d_tray', '/editor/p1', sample),
      ('editor_both', '/editor/p1', sample),
      ('editor_warning_tray', '/editor/p4', sample),
      ('ai_ask', '/editor/p1', sample),
      ('ai_results', '/editor/p1', sample),
      ('ai_draft', '/editor/p1', sample),
    ]) {
      testWidgets('$name $mode', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarded', true);
        late GoRouter router;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesProvider.overrideWithValue(prefs),
              localStoreProvider.overrideWithValue(MemoryStore(projects)),
              isOnlineProvider.overrideWithValue(true),
              view3dEnabledProvider.overrideWithValue(false),
              aiServiceProvider.overrideWithValue(ScriptedAi()),
              viewModeOverrideProvider.overrideWithValue(
                name.startsWith('editor_3d')
                    ? ViewMode.view3d
                    : name == 'editor_both'
                    ? ViewMode.both
                    : null,
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                router = ref.watch(routerProvider);
                return MaterialApp.router(
                  debugShowCheckedModeBanner: false,
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
        if (name.startsWith('welcome')) {
          Future<void> frames() async {
            for (var f = 0; f < 12; f++) {
              await tester.pump(const Duration(milliseconds: 50));
            }
          }

          await frames();
          for (var i = 1; i < int.parse(name.split('_').last); i++) {
            await tester.tap(find.text('Next'));
            await frames();
          }
        } else {
          await tester.pumpAndSettle();
        }
        if (name == 'editor_furnished' || name == 'editor_warning') {
          final id = name == 'editor_warning' ? 'p4' : 'p1';
          final container = ProviderScope.containerOf(
            tester.element(find.byType(EditorScreen)),
          );
          container
              .read(editorProvider(id).notifier)
              .select(name == 'editor_warning' ? 'item_war' : 'item_sof');
          await tester.pumpAndSettle();
        }
        if (name == 'editor_catalogue' ||
            name == 'editor_finishes' ||
            name == 'editor_lighting') {
          await tester.tap(
            find.text(name == 'editor_catalogue' ? 'Add' : 'Finish').last,
          );
          await tester.pumpAndSettle();
        }
        if (name == 'editor_share') {
          await tester.tap(find.bySemanticsLabel('Live').last);
          await tester.pumpAndSettle();
        }
        if (name == 'editor_3d_tray') {
          await tester.tap(find.text('Add').last);
          await tester.pumpAndSettle();
        }
        if (name == 'editor_warning_tray') {
          await tester.tap(find.text('Add').last);
          await tester.pumpAndSettle();
        }
        if (name == 'editor_lighting') {
          await tester.tap(find.text('Light'));
          await tester.pumpAndSettle();
        }
        if (name.startsWith('ai_')) {
          Future<void> settle() async {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 1500)),
            );
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump(const Duration(milliseconds: 500));
          }

          await tester.tap(find.text('AI layout').last);
          await settle();
          if (name != 'ai_ask') {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(EditorScreen)),
            );
            final scene = container.read(editorProvider('p1')).value!.scene;
            unawaited(
              container
                  .read(aiControllerProvider.notifier)
                  .suggest(scene, 'Improve movement'),
            );
            await settle();
            await settle();
          }
          if (name == 'ai_draft') {
            await tester.ensureVisible(find.text('Wall hugger').first);
            await tester.pump();
            await tester.tap(find.text('Wall hugger').first);
            await settle();
          }
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('out/${name}_$mode.png'),
        );
      });
    }
  }
}
