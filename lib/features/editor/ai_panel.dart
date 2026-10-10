import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../core/units.dart';
import '../../data/ai_service.dart';
import '../../domain/ai/ai_input_builder.dart';
import '../../domain/checks/layout_validator.dart';
import '../../domain/checks/movement_score.dart';
import '../../domain/scene/scene.dart';
import '../../state/ai_controller.dart';
import '../../state/connectivity_provider.dart';
import '../../state/editor_controller.dart';
import '../../state/settings_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chips.dart';
import '../../widgets/fields.dart';
import '../../widgets/placeholders.dart';
import '../../widgets/steps.dart';
import '../../widgets/surfaces.dart';
import 'plan_view/plan_thumbnail.dart';

String aiMessage(AiError e) => switch (e) {
  AiError.badRequest => S.aiBadRequest,
  AiError.rateLimited => S.aiRateLimited,
  AiError.unavailable => S.aiUnavailable,
  AiError.badOutput => S.aiBadOutput,
  AiError.timeout => S.aiTimeout,
};

int _scoreOf(Scene s) => MovementScore.of(s).score;

/// "AI layout": Ask, Working, Results (and errors). Opening a result turns
/// the panel into the draft bar.
class AiPanel extends ConsumerStatefulWidget {
  const AiPanel({
    required this.projectId,
    required this.scroll,
    required this.onOpenDraft,
    super.key,
  });

  final String projectId;
  final ScrollController scroll;
  final void Function(LayoutOption option, String label, int before)
  onOpenDraft;

  @override
  ConsumerState<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends ConsumerState<AiPanel> {
  final _goal = TextEditingController();

  /// The picked goal chip; typing your own words clears it.
  String? _chip = S.goalOpen;
  Future<int>? _scoreNow;
  Scene? _scoredScene;
  bool _showRejected = false;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<int> _movementNow(Scene scene) {
    if (!identical(scene, _scoredScene)) {
      _scoredScene = scene;
      _scoreNow = Future<void>.delayed(
        Duration.zero,
      ).then((_) => _scoreOf(scene));
    }
    return _scoreNow!;
  }

  void _suggest(Scene scene) {
    final typed = _goal.text.trim();
    final goal = typed.isNotEmpty ? typed : _chip ?? S.goalMovement;
    unawaited(
      ref
          .read(aiControllerProvider.notifier)
          .suggest(scene, goal.length > 200 ? goal.substring(0, 200) : goal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorProvider(widget.projectId)).value;
    final ai = ref.watch(aiControllerProvider);
    final text = Theme.of(context).textTheme;
    if (editor == null) return const SizedBox.shrink();

    ref.listen(aiControllerProvider, (_, next) {
      if (next is AiResults && next.evaluation.options.isNotEmpty) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          S.aiReady,
          TextDirection.ltr,
        );
      }
    });

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
      children: [
        Text(S.aiTitle, style: text.titleLarge),
        const SizedBox(height: Space.md),
        ...switch (ai) {
          AiIdle() => _ask(editor.scene),
          AiWorking(:final stage) => _working(stage),
          AiResults(:final evaluation) => _results(evaluation, editor.scene),
          AiFailed(:final error) => [
            _MessageCard(message: aiMessage(error)),
            const SizedBox(height: Space.md),
            SecondaryButton(
              label: S.tryAgain,
              onPressed: () => _suggest(editor.scene),
            ),
          ],
        },
      ],
    );
  }

  static const _goals = [
    (S.goalOpen, Icons.open_in_full_rounded),
    (S.goalDoors, Icons.door_front_door_outlined),
    (S.goalBedAway, Icons.bed_outlined),
    (S.goalCosy, Icons.weekend_outlined),
    (S.goalWork, Icons.desk_outlined),
  ];

  List<Widget> _ask(Scene scene) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final online = ref.watch(isOnlineProvider);
    final summary = AiInputBuilder.build(scene).summary;
    final empty = summary.items == 0;
    return [
      Text(S.aiIntro, style: text.bodyMedium?.copyWith(color: c.textSecondary)),
      const SizedBox(height: Space.lg),
      Text(S.aiWhatWant, style: text.titleMedium),
      const SizedBox(height: Space.sm),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.xs,
        children: [
          for (final (g, icon) in _goals)
            RoomCraftChip(
              label: g,
              icon: icon,
              selected: _chip == g && _goal.text.trim().isEmpty,
              onTap: () => setState(() {
                _chip = g;
                _goal.clear();
              }),
            ),
        ],
      ),
      const SizedBox(height: Space.md),
      RoomCraftTextField(
        controller: _goal,
        label: S.goalTypeHint,
        maxLength: 200,
        onChanged: (v) => setState(() {}),
      ),
      const SizedBox(height: Space.md),
      PrimaryButton(
        label: S.suggestLayouts,
        icon: Icons.auto_awesome_rounded,
        onPressed: empty || !online ? null : () => _suggest(scene),
      ),
      if (empty || !online) ...[
        const SizedBox(height: Space.sm),
        Text(
          empty ? S.addFurnitureFirst : S.offlineAi,
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
      const SizedBox(height: Space.xl),
      Text(S.howItWorks, style: text.titleSmall),
      const SizedBox(height: Space.sm),
      NumberedStep(
        number: 1,
        color: c.primaryAction,
        ink: c.onPrimaryAction,
        text: S.aiStep1,
      ),
      NumberedStep(number: 2, color: c.coral, ink: c.onAccent, text: S.aiStep2),
      NumberedStep(
        number: 3,
        color: c.sunflower,
        ink: c.onAccent,
        text: S.aiStep3,
      ),
      const SizedBox(height: Space.sm),
      const SizedBox(height: Space.md),
      Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(S.whatIUnderstood, style: text.titleSmall),
            const SizedBox(height: Space.xs),
            Text(
              [
                S.aiRoomLine(
                  unit.formatSize(summary.width, summary.length),
                  S.doors(summary.doors),
                  S.items(summary.items),
                ),
                if (summary.windows > 0) S.windows(summary.windows),
                if (summary.locked > 0) S.locked(summary.locked),
              ].join(' · '),
              style: text.bodyMedium,
            ),
            const SizedBox(height: Space.md),
            FutureBuilder<int>(
              future: _movementNow(scene),
              builder: (context, snap) => _MovementBar(score: snap.data),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _working(AiStage stage) => [
    for (final (s, label) in [
      (AiStage.reading, S.stageReading),
      (AiStage.asking, S.stageAsking),
      (AiStage.checking, S.stageChecking),
    ])
      _StageLine(
        label: label,
        state: s.index < stage.index ? 2 : (s == stage ? 1 : 0),
      ),
    const SizedBox(height: Space.md),
    Center(
      child: RoomCraftTextButton(
        label: S.cancel,
        onPressed: ref.read(aiControllerProvider.notifier).cancel,
      ),
    ),
  ];

  List<Widget> _results(LayoutEvaluation e, Scene scene) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    final ai = ref.read(aiControllerProvider.notifier);
    return [
      if (e.options.isEmpty)
        const _MessageCard(message: S.noneValid)
      else ...[
        Text(S.aiFound(e.options.length), style: text.titleMedium),
        const SizedBox(height: Space.md),
        for (final (i, option) in e.options.indexed) ...[
          _OptionCard(
            label: S.option(String.fromCharCode(65 + i)),
            tag: [c.primaryAction, c.coral, c.sky][i % 3],
            tagInk: [c.onPrimaryAction, c.onAccent, c.highlight][i % 3],
            option: option,
            before: e.currentScore,
            onTap: () => widget.onOpenDraft(
              option,
              S.option(String.fromCharCode(65 + i)),
              e.currentScore,
            ),
          ),
          const SizedBox(height: Space.md),
        ],
      ],
      if (e.rejected.isNotEmpty) ...[
        InkWell(
          onTap: () => setState(() => _showRejected = !_showRejected),
          borderRadius: BorderRadius.circular(Radii.small),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.touch),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: c.textSecondary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    S.aiSkipped(e.rejected.length),
                    style: text.bodySmall,
                  ),
                ),
                Icon(
                  _showRejected
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_showRejected)
          for (final r in e.rejected)
            Padding(
              padding: const EdgeInsets.only(left: Space.xl, bottom: Space.xs),
              child: Text(r, style: text.bodySmall),
            ),
        const SizedBox(height: Space.sm),
      ],
      SecondaryButton(
        label: S.tryAgain,
        icon: Icons.refresh_rounded,
        onPressed: () => _suggest(scene),
      ),
      Center(
        child: RoomCraftTextButton(label: S.changeRequest, onPressed: ai.reset),
      ),
    ];
  }
}

class _MovementBar extends StatelessWidget {
  const _MovementBar({required this.score});
  final int? score;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(S.movementNow, style: text.titleSmall)),
            if (score == null)
              const Skeleton(width: 28, height: 16)
            else
              Text(
                '$score',
                style: text.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.round),
          child: LinearProgressIndicator(
            value: (score ?? 0) / 100,
            minHeight: 6,
            backgroundColor: c.surfaceAlt,
            color: c.primary,
          ),
        ),
      ],
    );
  }
}

class _StageLine extends StatelessWidget {
  const _StageLine({required this.label, required this.state});

  final String label;

  /// 0 waiting, 1 active, 2 done.
  final int state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: Sizes.touch,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 24,
            child: Center(
              child: switch (state) {
                2 => Icon(
                  Icons.check_circle_rounded,
                  color: c.primary,
                  size: 22,
                ),
                1 => SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.primary,
                  ),
                ),
                _ => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.fieldBorder,
                    shape: BoxShape.circle,
                  ),
                ),
              },
            ),
          ),
          const SizedBox(width: Space.md),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: state == 0 ? c.textSecondary : c.textPrimary,
              fontWeight: state == 1 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => RoomCraftCard(
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, color: context.colors.textSecondary),
        const SizedBox(width: Space.md),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

/// "+23" in sage, a drop in terracotta.
class ChangeChip extends StatelessWidget {
  const ChangeChip({required this.before, required this.after, super.key});

  final int before;
  final int after;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = after - before;
    final up = d >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: (up ? c.primary : c.warning).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.round),
      ),
      child: Text(
        up ? '+$d' : '$d',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: up ? c.primaryDark : c.warningText,
        ),
      ),
    );
  }
}

/// One suggested layout: a large picture of the room as it would be, its
/// name and reason, what changes, and a clear way to preview it.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.tag,
    required this.tagInk,
    required this.option,
    required this.before,
    required this.onTap,
  });

  final String label;
  final Color tag;
  final Color tagInk;
  final LayoutOption option;
  final int before;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.colors;
    return RoomCraftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.button),
            child: ColoredBox(
              color: c.background,
              child: SizedBox(
                height: 180,
                child: PlanThumbnail(scene: option.scene),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.sm,
                  vertical: Space.xs,
                ),
                decoration: BoxDecoration(
                  color: tag,
                  borderRadius: BorderRadius.circular(Radii.round),
                ),
                child: Text(
                  label,
                  style: text.labelMedium?.copyWith(color: tagInk),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  option.name.isEmpty ? label : option.name,
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(option.reason, style: text.bodyMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              Text(
                S.movement(before, option.score),
                style: text.bodySmall?.copyWith(color: c.textPrimary),
              ),
              ChangeChip(before: before, after: option.score),
              Text('· ${S.itemsMoved(option.moved)}', style: text.bodySmall),
            ],
          ),
          const SizedBox(height: Space.md),
          SecondaryButton(
            label: S.previewLayout,
            icon: Icons.visibility_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Replaces the panel while a draft is open: name and change on the left,
/// Hold to compare, then Apply and Discard.
class DraftBar extends ConsumerWidget {
  const DraftBar({
    required this.projectId,
    required this.onApply,
    required this.onDiscard,
    super.key,
  });

  final String projectId;
  final VoidCallback onApply;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(editorProvider(projectId)).value;
    final draft = s?.draft;
    if (s == null || draft == null) return const SizedBox.shrink();
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final valid = s.report.isValid;
    final controller = ref.read(editorProvider(projectId).notifier);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.md,
        Space.md,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.card),
        ),
        boxShadow: softShadow(c),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  S.draftTitle(draft.label, draft.name),
                  style: text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Space.sm),
              ChangeChip(before: draft.scoreBefore, after: draft.scoreAfter),
              RoomCraftTextButton(label: S.discard, onPressed: onDiscard),
            ],
          ),
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Listener(
                onPointerDown: (_) => controller.compare(true),
                onPointerUp: (_) => controller.compare(false),
                onPointerCancel: (_) => controller.compare(false),
                child: RoomCraftTextButton(
                  label: S.holdToCompare,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: PrimaryButton(
                  label: S.apply,
                  onPressed: valid ? onApply : null,
                ),
              ),
            ],
          ),
          if (!valid)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                S.fixToApply,
                style: text.bodySmall?.copyWith(color: c.warningText),
              ),
            ),
        ],
      ),
    );
  }
}
