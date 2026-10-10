import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../widgets/surfaces.dart';

class BarAction {
  const BarAction(this.icon, this.label, this.onTap, {this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
}

/// The floating white pill beside the selected item: icon over label.
class InspectorBar extends StatelessWidget {
  const InspectorBar({required this.actions, super.key});

  final List<BarAction> actions;

  static double widthFor(int n) => n * 56.0 + Space.sm * 2;
  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: softShadow(c),
        border: Border.all(color: c.fieldBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in actions)
            Semantics(
              button: true,
              label: a.label,
              excludeSemantics: true,
              child: InkResponse(
                onTap: a.onTap,
                radius: 28,
                child: SizedBox(
                  width: 56,
                  height: height,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        a.icon,
                        size: 22,
                        color: a.danger ? c.warningText : c.textPrimary,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        a.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: 1.15),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: a.danger ? c.warningText : c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ToolButton extends StatelessWidget {
  const ToolButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;

  /// Null shows the tool dimmed and unavailable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active
        ? c.onPrimaryAction
        : onTap == null
        ? c.textPrimary.withValues(alpha: 0.38)
        : c.textPrimary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(Space.xs),
        child: Material(
          color: active ? c.primaryAction : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.button),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.button),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: Sizes.touch,
                minWidth: Sizes.touch,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg),
                  const SizedBox(height: Space.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textScaler: MediaQuery.textScalerOf(
                        context,
                      ).clamp(maxScaleFactor: 1.15),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: fg),
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
