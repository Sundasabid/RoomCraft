import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// In a wide browser window the app sits in a phone-sized frame in the
/// middle, since every screen is designed for a phone. Narrow windows and
/// phones get the app edge to edge.
class WebFrame extends StatelessWidget {
  const WebFrame({required this.child, super.key});

  final Widget child;

  static const _width = 412.0;
  static const _maxHeight = 900.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < _width + 2 * Space.xxl) return child;
    final c = context.colors;
    final height = math.min(media.size.height - 2 * Space.xl, _maxHeight);
    return ColoredBox(
      color: c.primaryAction,
      child: Center(
        child: Container(
          width: _width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.dialog * 2),
            border: Border.all(color: c.onAccent, width: Space.md),
            boxShadow: [
              BoxShadow(
                color: c.shade.withValues(alpha: 0.3),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.dialog * 2 - Space.md),
            child: MediaQuery(
              data: media.copyWith(
                size: Size(_width - 2 * Space.md, height - 2 * Space.md),
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
