import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config.dart';
import 'core/strings.dart';
import 'core/theme/theme.dart';
import 'data/supabase_client.dart';
import 'features/editor/editor_screen.dart';
import 'features/home/home_shell.dart';
import 'features/join/join_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/projects/projects_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/setup/setup_screen.dart';
import 'features/setup_needed/setup_needed_screen.dart';
import 'features/viewer/viewer_screen.dart';
import 'state/cloud_sync.dart';
import 'state/settings_controller.dart';
import 'widgets/web_frame.dart';

/// The role comes from the route, never from stored state. First launch
/// shows the welcome tour; after that the app opens on the Rooms tab.
final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, _) =>
            ref.read(settingsProvider).onboarded ? '/rooms' : '/welcome',
      ),
      GoRoute(path: '/welcome', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rooms',
                builder: (_, _) => const ProjectsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/live',
                builder: (_, state) => JoinScreen(
                  key: ValueKey(state.uri.queryParameters['error']),
                  error: state.uri.queryParameters['error'] == 'noroom'
                      ? S.noRoom
                      : null,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Older paths, kept so links and back stacks still land somewhere.
      GoRoute(path: '/projects', redirect: (_, _) => '/rooms'),
      GoRoute(
        path: '/join',
        redirect: (_, state) => Uri(
          path: '/live',
          queryParameters: state.uri.queryParameters.isEmpty
              ? null
              : state.uri.queryParameters,
        ).toString(),
      ),
      GoRoute(
        path: '/setup',
        builder: (_, state) =>
            SetupScreen(template: state.uri.queryParameters['template']),
      ),
      GoRoute(
        path: '/editor/:id',
        builder: (_, state) =>
            EditorScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/viewer/:code',
        builder: (_, state) =>
            ViewerScreen(code: state.pathParameters['code']!),
      ),
    ],
  ),
);

class RoomCraftApp extends ConsumerStatefulWidget {
  const RoomCraftApp({super.key});

  @override
  ConsumerState<RoomCraftApp> createState() => _RoomCraftAppState();
}

class _RoomCraftAppState extends ConsumerState<RoomCraftApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Going to the background uploads anything waiting, at once.
    _lifecycle = AppLifecycleListener(
      onPause: () => ref.read(cloudSyncProvider.notifier).flushAll(),
      onResume: () => ref.read(cloudSyncProvider.notifier).retry(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    if (!Config.isComplete) {
      return MaterialApp(
        title: S.appName,
        debugShowCheckedModeBanner: false,
        theme: RoomCraftTheme.light(),
        darkTheme: RoomCraftTheme.dark(),
        themeMode: themeMode,
        home: const SetupNeededScreen(),
      );
    }
    // Signs in anonymously in the background; screens never wait for it.
    ref.listen(sessionProvider, (_, s) {
      if (s.hasValue) ref.read(cloudSyncProvider.notifier).retry();
    });
    ref.watch(sessionProvider);
    return MaterialApp.router(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: RoomCraftTheme.light(),
      darkTheme: RoomCraftTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => kIsWeb ? WebFrame(child: child!) : child!,
    );
  }
}
