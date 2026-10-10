import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomcraft/app.dart';
import 'package:roomcraft/core/haptics.dart';
import 'package:roomcraft/core/strings.dart';
import 'package:roomcraft/core/theme/theme.dart';
import 'package:roomcraft/core/units.dart';
import 'package:roomcraft/features/editor/view3d/view3d.dart';
import 'package:roomcraft/state/connectivity_provider.dart';
import 'package:roomcraft/state/projects_controller.dart';
import 'package:roomcraft/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'editor_test.dart' show MemoryStore;

Future<(ProviderContainer, SharedPreferences)> pumpApp(
  WidgetTester tester, {
  required bool onboarded,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'onboarded': onboarded});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        localStoreProvider.overrideWithValue(MemoryStore(const [])),
        isOnlineProvider.overrideWithValue(true),
        view3dEnabledProvider.overrideWithValue(false),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: RoomCraftTheme.light(),
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return (container, prefs);
}

void main() {
  testWidgets('first launch shows the welcome tour; Skip opens Rooms', (
    tester,
  ) async {
    final (_, prefs) = await pumpApp(tester, onboarded: false);
    expect(find.text(S.onboardDesignTitle), findsOneWidget);
    await tester.tap(find.text(S.skip));
    await tester.pumpAndSettle();
    expect(find.text(S.projectsTitle), findsOneWidget);
    expect(prefs.getBool('onboarded'), isTrue);
  });

  testWidgets('the tour walks through three pages to Get started', (
    tester,
  ) async {
    await pumpApp(tester, onboarded: false);
    for (final title in [S.onboard3dTitle, S.onboardLiveTitle]) {
      await tester.tap(find.text(S.next));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text(S.getStarted));
    await tester.pumpAndSettle();
    expect(find.text(S.projectsTitle), findsOneWidget);
  });

  testWidgets('later launches open Rooms; the bottom bar switches tabs', (
    tester,
  ) async {
    await pumpApp(tester, onboarded: true);
    await tester.pumpAndSettle();
    expect(find.text(S.projectsTitle), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(S.tabLive));
    await tester.pumpAndSettle();
    expect(find.text(S.liveCodeLabel), findsOneWidget);
    expect(find.text(S.howItWorks), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(S.tabSettings));
    await tester.pumpAndSettle();
    expect(find.text(S.appearance), findsOneWidget);
  });

  testWidgets('settings change units, theme and vibration', (tester) async {
    final (container, prefs) = await pumpApp(tester, onboarded: true);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(S.tabSettings));
    await tester.pumpAndSettle();

    await tester.tap(find.text(S.feet));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).unit, DisplayUnit.feet);

    await tester.tap(find.text(S.themeDark));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(prefs.getBool('haptics'), isFalse);
    expect(Haptics.enabled, isFalse);
    Haptics.enabled = true;
  });

  testWidgets('back on Watch live returns to Rooms instead of leaving', (
    tester,
  ) async {
    await pumpApp(tester, onboarded: true);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(S.tabLive));
    await tester.pumpAndSettle();
    expect(find.text(S.liveCodeLabel), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(S.projectsTitle), findsOneWidget);
  });
}
