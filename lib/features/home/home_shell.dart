import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/motion.dart';

/// The three main places: Rooms, Watch live and Settings, with a bottom
/// navigation bar. Each tab keeps its own scroll and state.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, S.tabRooms),
    (Icons.sensors_outlined, Icons.sensors_rounded, S.tabLive),
    (Icons.settings_outlined, Icons.settings_rounded, S.tabSettings),
  ];

  @override
  Widget build(BuildContext context) => PopScope(
    // Back on Watch live or Settings goes to Rooms first; back on Rooms
    // leaves the app as usual.
    canPop: shell.currentIndex == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) shell.goBranch(0);
    },
    child: Scaffold(
      body: shell,
      bottomNavigationBar: BottomNav(
        index: shell.currentIndex,
        items: _tabs,
        onTap: (i) {
          if (i != shell.currentIndex) Haptics.selectionClick();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    ),
  );
}

/// A white bar; the current tab sits in a solid emerald pill.
class BottomNav extends StatelessWidget {
  const BottomNav({
    required this.index,
    required this.items,
    required this.onTap,
    super.key,
  });

  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: Space.xl,
            offset: const Offset(0, -Space.xs),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.sm,
          ),
          child: Row(
            children: [
              for (final (i, (icon, activeIcon, label)) in items.indexed)
                Expanded(
                  child: _NavItem(
                    icon: i == index ? activeIcon : icon,
                    label: label,
                    selected: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: motion(context, Motion.medium),
                curve: Motion.curve,
                width: selected ? Space.xxl * 2 : Space.xxl + Space.lg,
                height: Space.xxl,
                decoration: BoxDecoration(
                  color: selected ? c.primaryAction : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.round),
                ),
                child: Icon(
                  icon,
                  color: selected ? c.onPrimaryAction : c.textSecondary,
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(
                  color: selected ? c.primary : c.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
