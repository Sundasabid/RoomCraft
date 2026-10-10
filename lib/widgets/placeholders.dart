import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import 'buttons.dart';

/// surfaceAlt block with a slow left-to-right shimmer.
class Skeleton extends StatefulWidget {
  const Skeleton({
    this.width,
    this.height,
    this.radius = Radii.small,
    super.key,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: Motion.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final t = _shimmer.value * 3 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [
                c.surfaceAlt,
                Color.lerp(c.surfaceAlt, c.surface, 0.5)!,
                c.surfaceAlt,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Centred illustration, title, one sentence and one primary button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 120,
              child: CustomPaint(painter: _RoomSketch(c)),
            ),
            const SizedBox(height: Space.xl),
            Text(title, textAlign: TextAlign.center, style: text.titleLarge),
            const SizedBox(height: Space.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: Space.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: PrimaryButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An L-shaped room outline in sage with a sofa in oak.
class _RoomSketch extends CustomPainter {
  _RoomSketch(this.c);
  final RoomCraftColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    final floor = Path()
      ..moveTo(14 * s, 14 * s)
      ..lineTo(106 * s, 14 * s)
      ..lineTo(106 * s, 70 * s)
      ..lineTo(70 * s, 70 * s)
      ..lineTo(70 * s, 106 * s)
      ..lineTo(14 * s, 106 * s)
      ..close();
    canvas
      ..drawPath(floor, Paint()..color = c.oak.withValues(alpha: 0.12))
      ..drawPath(
        floor,
        Paint()
          ..color = c.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * s
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(26 * s, 26 * s, 46 * s, 18 * s),
          Radius.circular(4 * s),
        ),
        Paint()..color = c.oak,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(30 * s, 60 * s, 22 * s, 30 * s),
          Radius.circular(4 * s),
        ),
        Paint()..color = c.primary.withValues(alpha: 0.45),
      )
      ..drawCircle(
        Offset(92 * s, 30 * s),
        6 * s,
        Paint()..color = c.primary.withValues(alpha: 0.7),
      );
  }

  @override
  bool shouldRepaint(_RoomSketch old) => old.c != c;
}
