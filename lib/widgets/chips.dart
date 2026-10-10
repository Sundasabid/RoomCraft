import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import 'motion.dart';

/// Fully rounded 40 dp chip with a 48 dp touch area.
class RoomCraftChip extends StatelessWidget {
  const RoomCraftChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onPrimaryAction : c.primaryDark;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.round),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.touch),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: motion(context, Motion.fast),
              curve: Motion.curve,
              constraints: const BoxConstraints(minHeight: Sizes.chip),
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              decoration: BoxDecoration(
                color: selected ? c.primaryAction : c.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.round),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: Space.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: fg,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 48 dp track where the selected segment is a white pill.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    required this.options,
    required this.value,
    required this.onChanged,
    this.disabled = const {},
    this.height = Sizes.touch,
    super.key,
  });

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Set<T> disabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final keys = options.keys.toList();
    final index = keys.indexOf(value);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.all(Space.xs),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.button),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / keys.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: motion(context, Motion.medium),
                curve: Motion.curve,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark ? c.background : c.surface,
                    borderRadius: BorderRadius.circular(
                      Radii.button - Space.xs,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: c.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final k in keys)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: k == value,
                        enabled: !disabled.contains(k),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: disabled.contains(k)
                              ? null
                              : () => onChanged(k),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: height - Space.sm,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.xs,
                                ),
                                child: Text(
                                  options[k]!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: k == value
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: disabled.contains(k)
                                            ? c.textSecondary.withValues(
                                                alpha: 0.6,
                                              )
                                            : k == value
                                            ? c.primaryDark
                                            : c.textSecondary,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
