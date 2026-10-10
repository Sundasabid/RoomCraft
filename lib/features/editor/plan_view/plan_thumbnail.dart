import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../domain/scene/scene.dart';
import 'plan_painter.dart';

/// Small top-down picture of a room for project cards.
class PlanThumbnail extends StatelessWidget {
  const PlanThumbnail({required this.scene, super.key});

  final Scene scene;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: PlanPainter(
        scene: scene,
        colors: context.colors,
        showGrid: false,
        showLabels: false,
        padding: 10,
        background: Color.alphaBlend(
          context.colors.surfaceAlt.withValues(alpha: 0.45),
          context.colors.surface,
        ),
      ),
      size: Size.infinite,
    ),
  );
}
