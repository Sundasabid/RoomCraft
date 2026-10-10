import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme/tokens.dart';

/// LIVE pill with a breathing dot: the only looping animation in the app.
class LiveBadge extends StatefulWidget {
  const LiveBadge({this.reconnecting = false, this.trailing, super.key});

  final bool reconnecting;

  /// Optional text after LIVE, such as the viewer count.
  final String? trailing;

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: Motion.breathe,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        MediaQuery.disableAnimationsOf(context) || widget.reconnecting;
    if (still) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LiveBadge old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final off = widget.reconnecting;
    final label = off ? S.reconnecting : S.live;
    return Semantics(
      label: [label, ?widget.trailing].join(', '),
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        decoration: BoxDecoration(
          color: off ? c.surfaceAlt : c.coral,
          borderRadius: BorderRadius.circular(Radii.round),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.15).animate(
                CurvedAnimation(parent: _breath, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: off ? c.textSecondary : c.onAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(
              widget.trailing == null ? label : '$label  ${widget.trailing}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: off ? 0 : 1,
                color: off ? c.textSecondary : c.onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
