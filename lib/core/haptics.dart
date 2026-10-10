import 'package:flutter/services.dart';

/// Every vibration in the app goes through here so the Settings switch can
/// turn them all off.
abstract final class Haptics {
  static bool enabled = true;

  static Future<void> selectionClick() async {
    if (enabled) await HapticFeedback.selectionClick();
  }

  static Future<void> lightImpact() async {
    if (enabled) await HapticFeedback.lightImpact();
  }
}
