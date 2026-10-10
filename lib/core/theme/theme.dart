import 'package:flutter/material.dart';

import 'tokens.dart';

const _display = 'Poppins';
const _sans = 'Inter';

abstract final class RoomCraftTheme {
  static ThemeData light() => _build(RoomCraftColors.light, Brightness.light);
  static ThemeData dark() => _build(RoomCraftColors.dark, Brightness.dark);

  static TextStyle heading(RoomCraftColors c, double size) => TextStyle(
    fontFamily: _display,
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: c.textPrimary,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static ThemeData _build(RoomCraftColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primaryAction,
      onPrimary: c.onPrimaryAction,
      secondary: c.oak,
      onSecondary: c.onPrimaryAction,
      error: c.warning,
      onError: c.onPrimaryAction,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceAlt,
      outline: c.fieldBorder,
    );

    TextStyle sans(double size, FontWeight weight, {Color? color}) => TextStyle(
      fontFamily: _sans,
      fontSize: size,
      fontWeight: weight,
      height: TypeScale.bodyHeight,
      color: color ?? c.textPrimary,
    );

    // Poppins for titles and buttons, Inter for reading.
    TextStyle display(double size, FontWeight weight) =>
        sans(size, weight).copyWith(fontFamily: _display, height: 1.3);

    final text = TextTheme(
      displaySmall: heading(c, TypeScale.display),
      headlineSmall: heading(c, TypeScale.wordmark),
      titleLarge: heading(c, TypeScale.title),
      titleMedium: display(TypeScale.heading, FontWeight.w600),
      titleSmall: display(TypeScale.body, FontWeight.w600),
      bodyLarge: sans(TypeScale.heading, FontWeight.w400),
      bodyMedium: sans(TypeScale.body, FontWeight.w400),
      bodySmall: sans(TypeScale.label, FontWeight.w400, color: c.textSecondary),
      labelLarge: display(TypeScale.heading, FontWeight.w600),
      labelMedium: sans(TypeScale.label, FontWeight.w600),
      labelSmall: sans(TypeScale.caption, FontWeight.w500),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _sans,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: text,
      extensions: [c],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: Sizes.appBar,
        foregroundColor: c.textPrimary,
        titleTextStyle: heading(c, TypeScale.title),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      iconTheme: IconThemeData(color: c.textPrimary, size: 24),
      dividerTheme: DividerThemeData(color: c.fieldBorder, thickness: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.toast,
          borderRadius: BorderRadius.circular(Radii.small),
        ),
        textStyle: sans(TypeScale.label, FontWeight.w500, color: c.onToast),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primary.withValues(alpha: 0.3),
        selectionHandleColor: c.primary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: c.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        textStyle: sans(TypeScale.body, FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.dialog),
        ),
        titleTextStyle: heading(c, TypeScale.title),
        contentTextStyle: sans(TypeScale.body, FontWeight.w400),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.toast,
        contentTextStyle: sans(
          TypeScale.body,
          FontWeight.w500,
          color: c.onToast,
        ),
        actionTextColor: c.onToast,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceAlt,
        thumbColor: c.surface,
        overlayColor: c.primary.withValues(alpha: 0.12),
        thumbShape: _RingThumb(c.surface, c.primary),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        showValueIndicator: ShowValueIndicator.never,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeUpTransitions(),
          TargetPlatform.iOS: _FadeUpTransitions(),
          TargetPlatform.linux: _FadeUpTransitions(),
        },
      ),
    );
  }
}

/// A 24 dp white thumb with a 2 dp sage ring.
class _RingThumb extends SliderComponentShape {
  const _RingThumb(this.fill, this.ring);

  final Color fill;
  final Color ring;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas
      ..drawCircle(
        center + const Offset(0, 1),
        12,
        Paint()
          ..color = const Color(0x22000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawCircle(center, 12, Paint()..color = fill)
      ..drawCircle(
        center,
        11,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }
}

/// Page change: fade plus a 12 dp upward slide; instant with reduce motion.
class _FadeUpTransitions extends PageTransitionsBuilder {
  const _FadeUpTransitions();

  @override
  Duration get transitionDuration => Motion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 12 * (1 - curved.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}
