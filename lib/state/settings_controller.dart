import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/haptics.dart';
import '../core/units.dart';

/// Loaded once in main() so settings are ready before the first frame.
final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('preferencesProvider must be overridden'),
);

/// How the editor shows the room: 3D alone, the plan alone, or both.
enum ViewMode { view3d, plan, both }

@immutable
class Settings {
  const Settings({
    this.unit = DisplayUnit.metres,
    this.themeMode = ThemeMode.system,
    this.viewSplit = 0.5,
    this.haptics = true,
    this.onboarded = false,
    this.viewMode = ViewMode.view3d,
  });

  final DisplayUnit unit;
  final ThemeMode themeMode;

  /// Share of the editor's free height given to the 3D view (0.3 to 0.7).
  final double viewSplit;

  /// Vibrations on snaps, adds and deletes.
  final bool haptics;

  /// The welcome tour has been seen or skipped.
  final bool onboarded;

  /// The editor's last chosen view; 3D first.
  final ViewMode viewMode;

  Settings copyWith({
    DisplayUnit? unit,
    ThemeMode? themeMode,
    double? viewSplit,
    bool? haptics,
    bool? onboarded,
    ViewMode? viewMode,
  }) => Settings(
    unit: unit ?? this.unit,
    themeMode: themeMode ?? this.themeMode,
    viewSplit: viewSplit ?? this.viewSplit,
    haptics: haptics ?? this.haptics,
    onboarded: onboarded ?? this.onboarded,
    viewMode: viewMode ?? this.viewMode,
  );
}

class SettingsController extends Notifier<Settings> {
  static const _unitKey = 'unit';
  static const _themeKey = 'theme';
  static const _splitKey = 'split';
  static const _hapticsKey = 'haptics';
  static const _onboardedKey = 'onboarded';
  static const _viewModeKey = 'viewMode';

  SharedPreferences get _prefs => ref.read(preferencesProvider);

  @override
  Settings build() {
    final p = ref.watch(preferencesProvider);
    Haptics.enabled = p.getBool(_hapticsKey) ?? true;
    return Settings(
      unit: p.getString(_unitKey) == 'ft'
          ? DisplayUnit.feet
          : DisplayUnit.metres,
      themeMode: switch (p.getString(_themeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      viewSplit: (p.getDouble(_splitKey) ?? 0.5).clamp(0.3, 0.7),
      haptics: p.getBool(_hapticsKey) ?? true,
      onboarded: p.getBool(_onboardedKey) ?? false,
      viewMode: ViewMode.values.firstWhere(
        (m) => m.name == p.getString(_viewModeKey),
        orElse: () => ViewMode.view3d,
      ),
    );
  }

  void setHaptics(bool on) {
    state = state.copyWith(haptics: on);
    Haptics.enabled = on;
    _prefs.setBool(_hapticsKey, on);
  }

  void setViewMode(ViewMode mode) {
    state = state.copyWith(viewMode: mode);
    _prefs.setString(_viewModeKey, mode.name);
  }

  void setOnboarded(bool done) {
    state = state.copyWith(onboarded: done);
    _prefs.setBool(_onboardedKey, done);
  }

  void setUnit(DisplayUnit unit) {
    state = state.copyWith(unit: unit);
    _prefs.setString(_unitKey, unit == DisplayUnit.feet ? 'ft' : 'm');
  }

  void toggleUnit() => setUnit(
    state.unit == DisplayUnit.metres ? DisplayUnit.feet : DisplayUnit.metres,
  );

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs.setString(_themeKey, mode.name);
  }

  void setViewSplit(double split) {
    state = state.copyWith(viewSplit: split.clamp(0.3, 0.7));
    _prefs.setDouble(_splitKey, state.viewSplit);
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);
