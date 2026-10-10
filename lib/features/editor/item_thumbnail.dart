import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../domain/scene/catalogue.dart';
import 'furniture_art.dart';
import 'plan_view/plan_painter.dart';

/// A small top-down drawing of a catalogue item in its default finish, at a
/// common scale so a bed looks bigger than a chair.
class ItemThumbnail extends StatelessWidget {
  const ItemThumbnail({required this.item, this.size = 64, super.key});

  final CatalogueItem item;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ThumbPainter(item, context.colors)),
  );
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.item, this.c);
  final CatalogueItem item;
  final RoomCraftColors c;

  @override
  void paint(Canvas canvas, Size size) {
    // 2.1 m fills the tile; tiny pieces keep a readable minimum.
    final s = math.min(size.width, size.height) * 0.92 / 2.1;
    final minSide = size.shortestSide * 0.34;
    final w = math.max(item.width * s, minSide);
    final d = math.max(item.depth * s, minSide);
    paintFurniture(
      canvas,
      Rect.fromCenter(center: size.center(Offset.zero), width: w, height: d),
      item.id,
      finishColor(item.defaultFinish),
      c,
    );
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.item != item || old.c != c;
}
