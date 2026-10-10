import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import 'motion.dart';
import 'pressable.dart';

enum _Kind { primary, secondary }

/// Full-width filled button, 52 dp. One per screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fill,
    this.foreground,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  /// Custom colours for buttons on solid coloured pages, such as onboarding.
  final Color? fill;
  final Color? foreground;

  @override
  Widget build(BuildContext context) => _FilledButton(
    kind: _Kind.primary,
    label: label,
    onPressed: onPressed,
    icon: icon,
    loading: loading,
    fill: fill,
    foreground: foreground,
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) => _FilledButton(
    kind: _Kind.secondary,
    label: label,
    onPressed: onPressed,
    icon: icon,
    loading: loading,
  );
}

class _FilledButton extends StatefulWidget {
  const _FilledButton({
    required this.kind,
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.loading,
    this.fill,
    this.foreground,
  });

  final Color? fill;
  final Color? foreground;
  final _Kind kind;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  State<_FilledButton> createState() => _FilledButtonState();
}

class _FilledButtonState extends State<_FilledButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onPressed != null && !widget.loading;
    final primary = widget.kind == _Kind.primary;
    final Color fill;
    final Color fg;
    if (!enabled && !widget.loading) {
      fill = c.surfaceAlt;
      fg = c.textSecondary;
    } else if (widget.fill != null) {
      fill = _pressed ? Color.lerp(widget.fill, c.shade, 0.12)! : widget.fill!;
      fg = widget.foreground ?? c.onPrimaryAction;
    } else if (primary) {
      fill = _pressed ? c.primaryDark : c.primaryAction;
      fg = _pressed && Theme.of(context).brightness == Brightness.dark
          ? c.surface
          : c.onPrimaryAction;
    } else {
      // Solid sunflower: a bright second action that never competes with
      // the emerald primary.
      fill = _pressed ? Color.lerp(c.sunflower, c.shade, 0.12)! : c.sunflower;
      fg = c.onAccent;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: Pressable(
        onTap: enabled ? widget.onPressed : null,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: motion(context, Motion.press),
            constraints: const BoxConstraints(minHeight: Sizes.button),
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(Radii.button),
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: fg),
                        const SizedBox(width: Space.sm),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: fg),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Tertiary action. [destructive] uses the warning text colour.
class RoomCraftTextButton extends StatelessWidget {
  const RoomCraftTextButton({
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.color,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? (destructive ? c.warningText : c.primaryDark);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(Sizes.touch, Sizes.touch),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        foregroundColor: fg,
        disabledForegroundColor: c.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        textStyle: Theme.of(context).textTheme.titleSmall,
      ),
      child: Text(label),
    );
  }
}

/// 48 dp icon button with a tooltip and a screen-reader label.
class RoomCraftIconButton extends StatelessWidget {
  const RoomCraftIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 24),
      color: color ?? c.textPrimary,
      disabledColor: c.textPrimary.withValues(alpha: 0.38),
      highlightColor: c.surfaceAlt,
      constraints: const BoxConstraints.tightFor(
        width: Sizes.touch,
        height: Sizes.touch,
      ),
    );
  }
}
