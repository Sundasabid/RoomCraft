import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../core/units.dart';
import '../../domain/constants.dart';
import '../../domain/scene/nodes.dart';
import '../../domain/scene/rooms.dart';
import '../../state/projects_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/setup_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chips.dart';
import '../../widgets/fields.dart';
import '../../widgets/motion.dart';
import '../../widgets/surfaces.dart';
import 'live_plan.dart';
import 'setup_widgets.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({this.template, super.key});

  final String? template;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late final TextEditingController _name;
  bool _more = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = RoomTemplateLabel.parse(widget.template);
    final setup = ref.read(setupProvider.notifier);
    if (t != RoomTemplate.bedroom) setup.applyTemplate(t);
    _name = TextEditingController(text: ref.read(setupProvider).name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  SetupController get _setup => ref.read(setupProvider.notifier);

  /// Runs a dimension change and announces any opening it pushed off a wall.
  void _change(void Function() update) {
    update();
    for (final kind in _setup.lastRemoved) {
      unawaited(
        showToast(
          context,
          kind == OpeningKind.door ? S.doorRemoved : S.windowRemoved,
          bottomOffset: Sizes.button + Space.lg,
        ),
      );
    }
  }

  void _template(RoomTemplate t) {
    _setup.applyTemplate(t);
    final s = ref.read(setupProvider);
    if (!s.nameEdited) _name.text = s.name;
  }

  Future<void> _start() async {
    setState(() => _saving = true);
    try {
      final unit = ref.read(settingsProvider).unit;
      final project = _setup.buildProject(displayUnit: unit.symbol);
      await ref.read(projectsProvider.notifier).add(project);
      if (mounted) context.pushReplacement('/editor/${project.id}');
    } on Exception {
      if (mounted) {
        setState(() => _saving = false);
        unawaited(
          showToast(
            context,
            S.genericError,
            bottomOffset: Sizes.button + Space.lg,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(setupProvider);
    final unit = ref.watch(settingsProvider.select((x) => x.unit));
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final side = MediaQuery.sizeOf(context).width >= Sizes.tabletBreakpoint
        ? Space.xl
        : Space.lg;

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: Space.md),
          ...children,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: RoomCraftIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: S.back,
          onPressed: () => context.pop(),
        ),
        title: const Text(S.setupTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Space.md),
            child: RoomCraftChip(
              label: unit.symbol,
              icon: Icons.straighten_rounded,
              selected: false,
              onTap: () => ref.read(settingsProvider.notifier).toggleUnit(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Sizes.maxFormWidth,
                  ),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      side,
                      Space.sm,
                      side,
                      Space.xl,
                    ),
                    children: [
                      RoomCraftCard(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.card),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: const AspectRatio(
                              aspectRatio: 4 / 3,
                              child: LivePlan(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: [
                            for (final t in RoomTemplate.values) ...[
                              RoomCraftChip(
                                label: t.label,
                                selected: s.template == t,
                                onTap: () => _template(t),
                              ),
                              const SizedBox(width: Space.sm),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      SegmentedControl<bool>(
                        options: const {
                          false: S.shapeRectangle,
                          true: S.shapeL,
                        },
                        value: s.lShape,
                        onChanged: (v) =>
                            _change(() => _setup.setShape(lShape: v)),
                      ),
                      const SizedBox(height: Space.lg),
                      DimensionRow(
                        label: S.width,
                        value: s.width,
                        min: s.minSide,
                        max: maxRoomSide,
                        unit: unit,
                        onChanged: (v) => _change(() => _setup.setWidth(v)),
                      ),
                      DimensionRow(
                        label: S.length,
                        value: s.length,
                        min: s.minSide,
                        max: maxRoomSide,
                        unit: unit,
                        onChanged: (v) => _change(() => _setup.setLength(v)),
                      ),
                      if (s.lShape) ...[
                        DimensionRow(
                          label: S.notchWidth,
                          value: s.notchWidth,
                          min: 1.0,
                          max: s.maxNotchWidth,
                          unit: unit,
                          onChanged: (v) =>
                              _change(() => _setup.setNotchWidth(v)),
                        ),
                        DimensionRow(
                          label: S.notchLength,
                          value: s.notchLength,
                          min: 1.0,
                          max: s.maxNotchLength,
                          unit: unit,
                          onChanged: (v) =>
                              _change(() => _setup.setNotchLength(v)),
                        ),
                      ],
                      InkWell(
                        onTap: () => setState(() => _more = !_more),
                        borderRadius: BorderRadius.circular(Radii.button),
                        child: SizedBox(
                          height: Sizes.touch,
                          child: Row(
                            children: [
                              Text(
                                S.more,
                                style: text.titleSmall?.copyWith(
                                  color: c.textSecondary,
                                ),
                              ),
                              const SizedBox(width: Space.xs),
                              AnimatedRotation(
                                turns: _more ? 0.5 : 0,
                                duration: motion(context, Motion.medium),
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: motion(context, Motion.medium),
                        curve: Motion.curve,
                        alignment: Alignment.topCenter,
                        child: _more
                            ? DimensionRow(
                                label: S.wallHeight,
                                value: s.wallHeight,
                                min: minWallHeight,
                                max: maxWallHeight,
                                unit: unit,
                                onChanged: _setup.setWallHeight,
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      section(S.openingsTitle, [
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                label: S.addDoor,
                                icon: Icons.door_front_door_outlined,
                                onPressed: () =>
                                    _setup.addOpening(OpeningKind.door),
                              ),
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: SecondaryButton(
                                label: S.addWindow,
                                icon: Icons.window_outlined,
                                onPressed: () =>
                                    _setup.addOpening(OpeningKind.window),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.md),
                        for (final o in s.openings) ...[
                          OpeningRow(
                            key: ValueKey(o.id),
                            icon: o.isDoor
                                ? Icons.door_front_door_outlined
                                : Icons.window_outlined,
                            title: S.openingRow(
                              o.isDoor ? S.door : S.window,
                              wallName(s, o.wallIndex),
                            ),
                            offset: S.atOffset(unit.format(o.offset)),
                            width: unit.format(o.width),
                            selected: s.activeOpening == o.id,
                            onTap: () => _setup.selectOpening(o.id),
                            onNarrower:
                                o.width > OpeningRules.minWidth(o.kind) + 1e-9
                                ? () => _setup.setOpeningWidth(
                                    o.id,
                                    o.width - 0.1,
                                  )
                                : null,
                            onWider:
                                o.width < OpeningRules.maxWidth(o.kind) - 1e-9
                                ? () => _setup.setOpeningWidth(
                                    o.id,
                                    o.width + 0.1,
                                  )
                                : null,
                            onDelete: () => _setup.deleteOpening(o.id),
                          ),
                          const SizedBox(height: Space.sm),
                        ],
                        if (!s.hasDoor)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.xs),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: c.textSecondary,
                                ),
                                const SizedBox(width: Space.sm),
                                Expanded(
                                  child: Text(
                                    S.addDoorHint,
                                    style: text.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ]),
                      section(S.roomName, [
                        RoomCraftTextField(
                          controller: _name,
                          label: S.roomName,
                          maxLength: maxNameLength,
                          onChanged: _setup.setName,
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(side, Space.md, side, Space.lg),
              decoration: BoxDecoration(
                color: c.background,
                border: Border(
                  top: BorderSide(color: c.fieldBorder.withValues(alpha: 0.6)),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Sizes.maxFormWidth,
                  ),
                  child: PrimaryButton(
                    label: S.startDesigning,
                    loading: _saving,
                    onPressed: _start,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
