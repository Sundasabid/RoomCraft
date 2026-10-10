import 'package:flutter/material.dart';

/// Every colour the app uses, defined once per brightness.
///
/// Widgets read these through `context.colors` and never write a hex value.
@immutable
class RoomCraftColors extends ThemeExtension<RoomCraftColors> {
  const RoomCraftColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primaryAction,
    required this.primaryDark,
    required this.onPrimaryAction,
    required this.oak,
    required this.walnut,
    required this.warning,
    required this.warningText,
    required this.textPrimary,
    required this.textSecondary,
    required this.wallLine,
    required this.fieldBorder,
    required this.shadow,
    required this.scrim,
    required this.toast,
    required this.onToast,
    required this.planFloor,
    required this.inkOnLight,
    required this.inkOnDark,
    required this.shade,
    required this.highlight,
    required this.swatchEdge,
    required this.lampShade,
    required this.coral,
    required this.sunflower,
    required this.sky,
    required this.onAccent,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color primaryAction;
  final Color primaryDark;
  final Color onPrimaryAction;
  final Color oak;
  final Color walnut;
  final Color warning;
  final Color warningText;
  final Color textPrimary;
  final Color textSecondary;
  final Color wallLine;
  final Color fieldBorder;
  final Color shadow;
  final Color scrim;
  final Color toast;
  final Color onToast;

  /// Bare floor under the finish tint on the plan.
  final Color planFloor;

  /// Label ink on light and dark furniture fills.
  final Color inkOnLight;
  final Color inkOnDark;

  /// Mixed into a finish colour for outlines and highlights.
  final Color shade;
  final Color highlight;

  /// Thin inner ring that keeps pale swatches visible.
  final Color swatchEdge;

  /// Lamp shade in drawings of the floor lamp.
  final Color lampShade;

  /// Solid accent fills for onboarding, steps and highlights.
  final Color coral;
  final Color sunflower;
  final Color sky;

  /// Text on coral and sunflower fills (white fails contrast there).
  final Color onAccent;

  /// Linen cream, sage and oak: a calm, sunlit room.
  static const light = RoomCraftColors(
    background: Color(0xFFFFFBF5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4EDE1),
    primary: Color(0xFF1E7B52),
    primaryAction: Color(0xFF1E7B52),
    primaryDark: Color(0xFF0F3A28),
    onPrimaryAction: Color(0xFFFFFFFF),
    oak: Color(0xFFB98B5E),
    walnut: Color(0xFF7A5230),
    warning: Color(0xFFD9482B),
    warningText: Color(0xFFA3321B),
    textPrimary: Color(0xFF0F3A28),
    textSecondary: Color(0xFF4C5E54),
    wallLine: Color(0xFFC9B896),
    fieldBorder: Color(0xFFE2D6C3),
    shadow: Color(0x0F000000),
    scrim: Color(0x33000000),
    toast: Color(0xFF0F3A28),
    onToast: Color(0xFFFFFFFF),
    planFloor: Color(0xFFF7F3EC),
    inkOnLight: Color(0xFF2F4F3E),
    inkOnDark: Color(0xFFFFFFFF),
    shade: Color(0xFF000000),
    highlight: Color(0xFFFFFFFF),
    swatchEdge: Color(0x14000000),
    lampShade: Color(0xFFE6D9C3),
    coral: Color(0xFFFF6B4A),
    sunflower: Color(0xFFFFC23D),
    sky: Color(0xFF2F6BEB),
    onAccent: Color(0xFF0F3A28),
  );

  /// The same room at dusk: deep forest charcoal, lamp-lit cream text,
  /// a brighter sage so selection still reads clearly.
  static const dark = RoomCraftColors(
    background: Color(0xFF0D1712),
    surface: Color(0xFF16241C),
    surfaceAlt: Color(0xFF213429),
    primary: Color(0xFF3CC285),
    primaryAction: Color(0xFF1E7B52),
    primaryDark: Color(0xFFF4EFE6),
    onPrimaryAction: Color(0xFFFFFFFF),
    oak: Color(0xFFCC9F72),
    walnut: Color(0xFFA77850),
    warning: Color(0xFFFF7A5C),
    warningText: Color(0xFFFFA28C),
    textPrimary: Color(0xFFF4EFE6),
    textSecondary: Color(0xFFA6B9AD),
    wallLine: Color(0xFF6B624F),
    fieldBorder: Color(0xFF2F463A),
    shadow: Color(0x40000000),
    scrim: Color(0x66000000),
    toast: Color(0xFFF4EFE6),
    onToast: Color(0xFF16241C),
    planFloor: Color(0xFF2C352D),
    inkOnLight: Color(0xFF2F4F3E),
    inkOnDark: Color(0xFFFFFFFF),
    shade: Color(0xFF000000),
    highlight: Color(0xFFFFFFFF),
    swatchEdge: Color(0x1FFFFFFF),
    lampShade: Color(0xFFE6D9C3),
    coral: Color(0xFFFF6B4A),
    sunflower: Color(0xFFFFC23D),
    sky: Color(0xFF2F6BEB),
    onAccent: Color(0xFF0F3A28),
  );

  @override
  RoomCraftColors copyWith() => this;

  @override
  RoomCraftColors lerp(RoomCraftColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return RoomCraftColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      primary: l(primary, other.primary),
      primaryAction: l(primaryAction, other.primaryAction),
      primaryDark: l(primaryDark, other.primaryDark),
      onPrimaryAction: l(onPrimaryAction, other.onPrimaryAction),
      oak: l(oak, other.oak),
      walnut: l(walnut, other.walnut),
      warning: l(warning, other.warning),
      warningText: l(warningText, other.warningText),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      wallLine: l(wallLine, other.wallLine),
      fieldBorder: l(fieldBorder, other.fieldBorder),
      shadow: l(shadow, other.shadow),
      scrim: l(scrim, other.scrim),
      toast: l(toast, other.toast),
      onToast: l(onToast, other.onToast),
      planFloor: l(planFloor, other.planFloor),
      inkOnLight: l(inkOnLight, other.inkOnLight),
      inkOnDark: l(inkOnDark, other.inkOnDark),
      shade: l(shade, other.shade),
      highlight: l(highlight, other.highlight),
      swatchEdge: l(swatchEdge, other.swatchEdge),
      lampShade: l(lampShade, other.lampShade),
      coral: l(coral, other.coral),
      sunflower: l(sunflower, other.sunflower),
      sky: l(sky, other.sky),
      onAccent: l(onAccent, other.onAccent),
    );
  }

  /// Hex string for the 3D layer, which receives colours as CSS values.
  static String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

/// Spacing scale: 4, 8, 12, 16, 24, 32 dp only.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class Radii {
  static const double small = 8;
  static const double button = 12;
  static const double card = 16;
  static const double dialog = 20;
  static const double pill = 28;
  static const double round = 999;
}

abstract final class Sizes {
  static const double touch = 48;
  static const double button = 52;
  static const double appBar = 56;
  static const double tabBar = 72;
  static const double field = 56;
  static const double toolbar = 64;
  static const double rail = 72;
  static const double chip = 40;
  static const double swatch = 56;
  static const double sheetHandleWidth = 40;
  static const double sheetHandleHeight = 4;
  static const double maxFormWidth = 560;
  static const double sidePanel = 360;
  static const double tabletBreakpoint = 600;
}

abstract final class Motion {
  static const press = Duration(milliseconds: 80);
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 200);
  static const page = Duration(milliseconds: 220);
  static const sheet = Duration(milliseconds: 250);
  static const pulse = Duration(milliseconds: 300);
  static const camera = Duration(milliseconds: 400);
  static const shimmer = Duration(milliseconds: 1400);
  static const breathe = Duration(milliseconds: 1600);
  static const toastShort = Duration(seconds: 3);
  static const toastUndo = Duration(seconds: 6);
  static const curve = Curves.easeOutCubic;
}

abstract final class TypeScale {
  static const double display = 28;
  static const double wordmark = 32;
  static const double onboarding = 30;
  static const double title = 20;
  static const double heading = 16;
  static const double body = 14;
  static const double label = 12;
  static const double caption = 11;
  static const double bodyHeight = 1.4;
}

extension RoomCraftThemeContext on BuildContext {
  RoomCraftColors get colors => Theme.of(this).extension<RoomCraftColors>()!;
}
