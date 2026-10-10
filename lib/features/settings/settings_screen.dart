import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config.dart';
import '../../core/strings.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/units.dart';
import '../../state/settings_controller.dart';
import '../../widgets/brand.dart';
import '../../widgets/chips.dart';
import '../../widgets/motion.dart';
import '../../widgets/surfaces.dart';

/// Appearance, units, vibration, help and about, in plain cards.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final side = MediaQuery.sizeOf(context).width >= Sizes.tabletBreakpoint
        ? Space.xl
        : Space.lg;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: side,
        toolbarHeight: Sizes.tabBar,
        title: Text(
          S.settingsTitle,
          style: RoomCraftTheme.heading(context.colors, TypeScale.display),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.maxFormWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(side, Space.sm, side, Space.xl),
              children: [
                const _Section(S.sectionLook),
                RoomCraftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(S.appearance, style: text.titleSmall),
                      const SizedBox(height: Space.md),
                      ThemePicker(
                        value: settings.themeMode,
                        onChanged: ctl.setThemeMode,
                      ),
                    ],
                  ),
                ),
                const _Section(S.sectionMeasure),
                RoomCraftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(S.unitsTitle, style: text.titleSmall),
                      const SizedBox(height: Space.md),
                      SegmentedControl<DisplayUnit>(
                        options: const {
                          DisplayUnit.metres: S.metres,
                          DisplayUnit.feet: S.feet,
                        },
                        value: settings.unit,
                        onChanged: ctl.setUnit,
                      ),
                      const SizedBox(height: Space.lg),
                      MergeSemantics(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(S.hapticsTitle, style: text.titleSmall),
                                  Text(S.hapticsBody, style: text.bodySmall),
                                ],
                              ),
                            ),
                            const SizedBox(width: Space.md),
                            Switch(
                              value: settings.haptics,
                              onChanged: ctl.setHaptics,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const _Section(S.sectionHelp),
                RoomCraftCard(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Column(
                    children: [
                      _LinkRow(
                        icon: Icons.auto_awesome_rounded,
                        color: c.coral,
                        ink: c.onAccent,
                        label: S.replayTour,
                        onTap: () => context.push('/welcome'),
                      ),
                      _LinkRow(
                        icon: Icons.sensors_rounded,
                        color: c.sky,
                        ink: c.highlight,
                        label: S.howLiveWorks,
                        onTap: () => context.go('/live'),
                      ),
                    ],
                  ),
                ),
                const _Section(S.sectionAbout),
                RoomCraftCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LogoMark(size: Sizes.touch),
                      const SizedBox(width: Space.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.appName,
                              style: RoomCraftTheme.heading(c, TypeScale.title),
                            ),
                            Text(
                              S.versionLabel(Config.appVersion),
                              style: text.bodySmall,
                            ),
                            const SizedBox(height: Space.sm),
                            Text(S.privacyNote, style: text.bodyMedium),
                          ],
                        ),
                      ),
                    ],
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

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
    child: Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.colors.textSecondary,
          letterSpacing: 1,
        ),
      ),
    ),
  );
}

/// A tappable row with a solid coloured icon tile and a chevron.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.color,
    required this.ink,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color ink;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.appBar),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: Space.xxl + Space.xs,
                  height: Space.xxl + Space.xs,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(Radii.small),
                  ),
                  child: Icon(icon, size: 20, color: ink),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Match phone, Light and Dark as three tiles; the chosen one is solid
/// emerald.
class ThemePicker extends StatelessWidget {
  const ThemePicker({required this.value, required this.onChanged, super.key});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget option(ThemeMode m, String label, IconData icon) {
      final on = value == m;
      final fg = on ? c.onPrimaryAction : c.textPrimary;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: Material(
            color: on ? c.primaryAction : c.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.button),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.button),
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: motion(context, Motion.fast),
                padding: const EdgeInsets.symmetric(
                  vertical: Space.lg,
                  horizontal: Space.xs,
                ),
                child: Column(
                  children: [
                    Icon(icon, color: fg),
                    const SizedBox(height: Space.sm),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(ThemeMode.system, S.themeSystem, Icons.brightness_auto_rounded),
        const SizedBox(width: Space.sm),
        option(ThemeMode.light, S.themeLight, Icons.light_mode_rounded),
        const SizedBox(width: Space.sm),
        option(ThemeMode.dark, S.themeDark, Icons.dark_mode_rounded),
      ],
    );
  }
}
