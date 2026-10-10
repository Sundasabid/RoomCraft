import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'ai_service.dart';
import 'cloud_projects.dart';
import 'share_service.dart';

/// Reads the saved session from the device; no network needed.
Future<void> initSupabase() async {
  if (!Config.isComplete) return;
  await Supabase.initialize(
    url: Config.supabaseUrl,
    publishableKey: Config.supabaseAnonKey,
  );
}

/// Null when the build has no Supabase settings.
final cloudStoreProvider = Provider<CloudStore?>(
  (ref) =>
      Config.isComplete ? SupabaseCloudStore(Supabase.instance.client) : null,
);

/// The anonymous session, created in the background at startup.
final sessionProvider = FutureProvider<void>((ref) async {
  await ref.watch(cloudStoreProvider)?.ensureSession();
});

final shareServiceProvider = Provider<ShareService?>(
  (ref) =>
      Config.isComplete ? SupabaseShareService(Supabase.instance.client) : null,
);

final aiServiceProvider = Provider<AiService?>(
  (ref) =>
      Config.isComplete ? SupabaseAiService(Supabase.instance.client) : null,
);
