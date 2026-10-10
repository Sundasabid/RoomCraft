/// Build-time settings, passed with `--dart-define-from-file=env.json`.
abstract final class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Shown in Settings; keep in step with `version` in pubspec.yaml.
  static const appVersion = '0.1.0';

  static bool get isComplete =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
