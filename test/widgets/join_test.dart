import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roomcraft/core/strings.dart';
import 'package:roomcraft/core/theme/theme.dart';
import 'package:roomcraft/data/share_service.dart';
import 'package:roomcraft/data/supabase_client.dart';
import 'package:roomcraft/features/join/join_screen.dart';
import 'package:roomcraft/state/connectivity_provider.dart';

import '../domain/fixtures.dart';
import '../state/share_test.dart' show FakeShare;

Future<GoRouter> pumpJoin(
  WidgetTester tester,
  FakeShare share, {
  bool online = true,
}) async {
  final router = GoRouter(
    initialLocation: '/join',
    routes: [
      GoRoute(path: '/join', builder: (_, _) => const JoinScreen()),
      GoRoute(
        path: '/viewer/:code',
        builder: (_, s) => Text('viewer ${s.pathParameters['code']}'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shareServiceProvider.overrideWithValue(share),
        isOnlineProvider.overrideWithValue(online),
      ],
      child: MaterialApp.router(
        theme: RoomCraftTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('typing is uppercased and a full code joins by itself', (
    tester,
  ) async {
    final share = FakeShare()
      ..rows['ABC234'] = ShareRow(
        code: 'ABC234',
        scene: bedroom(),
        revision: 0,
        active: true,
      );
    await pumpJoin(tester, share);
    await tester.enterText(find.byType(TextField), 'abc234');
    await tester.pumpAndSettle();
    expect(find.text('viewer ABC234'), findsOneWidget);
  });

  testWidgets('letters outside the code alphabet are refused with a message', (
    tester,
  ) async {
    await pumpJoin(tester, FakeShare());
    await tester.enterText(find.byType(TextField), 'AB0');
    await tester.pump();
    expect(find.text(S.badLetters), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a wrong code keeps the boxes filled and says so', (
    tester,
  ) async {
    await pumpJoin(tester, FakeShare());
    await tester.enterText(find.byType(TextField), 'ZZZ222');
    await tester.pumpAndSettle();
    expect(find.text(S.noRoom), findsOneWidget);
    expect(find.text('Z'), findsNWidgets(3));
  });

  testWidgets('offline, joining is disabled with a caption', (tester) async {
    await pumpJoin(tester, FakeShare(), online: false);
    expect(find.text(S.offlineJoin), findsOneWidget);
  });
}
