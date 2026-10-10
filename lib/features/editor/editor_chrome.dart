import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/buttons.dart';
import '../../widgets/surfaces.dart';
import 'inspector_bar.dart';

enum EditorSheet { catalogue, finishes, ai, share }

/// Back, room name (tap to rename), Undo and Redo.
class EditorTopBar extends StatelessWidget {
  const EditorTopBar({
    required this.name,
    required this.canUndo,
    required this.canRedo,
    required this.onBack,
    required this.onRename,
    required this.onUndo,
    required this.onRedo,
    this.trailing = const [],
    super.key,
  });

  final String name;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: Sizes.appBar,
      child: Row(
        children: [
          const SizedBox(width: Space.xs),
          RoomCraftIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: S.back,
            onPressed: onBack,
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: '${S.renameRoom}: $name',
              excludeSemantics: true,
              child: InkWell(
                onTap: onRename,
                borderRadius: BorderRadius.circular(Radii.small),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.xs,
                    vertical: Space.sm,
                  ),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RoomCraftTheme.heading(c, TypeScale.title),
                  ),
                ),
              ),
            ),
          ),
          RoomCraftIconButton(
            icon: Icons.undo_rounded,
            tooltip: S.undo,
            onPressed: canUndo ? onUndo : null,
          ),
          RoomCraftIconButton(
            icon: Icons.redo_rounded,
            tooltip: S.redo,
            onPressed: canRedo ? onRedo : null,
          ),
          ...trailing,
          const SizedBox(width: Space.xs),
        ],
      ),
    );
  }
}

class _Tool {
  const _Tool(this.sheet, this.icon, this.label);
  final EditorSheet sheet;
  final IconData icon;
  final String label;
}

const _tools = [
  _Tool(EditorSheet.catalogue, Icons.add_box_outlined, S.toolAdd),
  _Tool(EditorSheet.finishes, Icons.palette_outlined, S.toolFinish),
  _Tool(EditorSheet.ai, Icons.auto_awesome_outlined, S.toolAi),
];

/// Bottom toolbar on phones in portrait; a left rail in landscape.
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    required this.open,
    required this.onTap,
    this.vertical = false,
    this.extra = const [],
    super.key,
  });

  final EditorSheet? open;
  final ValueChanged<EditorSheet> onTap;
  final bool vertical;

  /// Further tool buttons (AI layout arrives with its own phase).
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final buttons = [
      for (final t in _tools)
        ToolButton(
          icon: t.icon,
          label: t.label,
          active: open == t.sheet,
          onTap: () => onTap(t.sheet),
        ),
      ...extra,
    ];
    if (vertical) {
      return Container(
        width: Sizes.rail,
        color: c.surface,
        child: SafeArea(
          right: false,
          child: Column(
            children: [
              const SizedBox(height: Space.sm),
              ...buttons,
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.card),
        ),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: Sizes.toolbar,
          child: Row(children: [for (final b in buttons) Expanded(child: b)]),
        ),
      ),
    );
  }
}

/// White pill overlay on the plan (selection label, unit chip).
class PlanPill extends StatelessWidget {
  const PlanPill({required this.child, this.onTap, this.semantics, super.key});

  final Widget child;
  final VoidCallback? onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.fieldBorder.withValues(alpha: 0.6)),
      ),
      child: Center(
        widthFactor: 1,
        child: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.labelMedium,
          child: child,
        ),
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: pill,
        ),
      ),
    );
  }
}

/// "Tap Add to place your first piece", pointing at the toolbar.
class EmptyRoomHint extends StatelessWidget {
  const EmptyRoomHint({this.landscape = false, super.key});

  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RoomCraftCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (landscape)
            Icon(Icons.arrow_back_rounded, color: c.primary, size: 20),
          if (landscape) const SizedBox(width: Space.sm),
          Flexible(
            child: Text(
              S.emptyRoomHint,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (!landscape) const SizedBox(width: Space.sm),
          if (!landscape)
            Icon(Icons.arrow_downward_rounded, color: c.primary, size: 20),
        ],
      ),
    );
  }
}
