import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import 'motion.dart';

/// Scales its child to 0.98 while pressed (80 ms), so every touch answers
/// at once.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return Listener(
      onPointerDown: active ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: motion(context, Motion.press),
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}
