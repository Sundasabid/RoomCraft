import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/local_projects.dart';
import 'data/supabase_client.dart';
import 'state/projects_controller.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (prefs, store, _) = await (
    SharedPreferences.getInstance(),
    LocalProjectStore.open(),
    initSupabase(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        localStoreProvider.overrideWithValue(store),
      ],
      child: const RoomCraftApp(),
    ),
  );
}
