import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/haptics.dart';
import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../state/cloud_sync.dart';
import '../../state/connectivity_provider.dart';
import '../../state/editor_controller.dart';
import '../../state/share_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/live_badge.dart';
import '../../widgets/steps.dart';
import '../../widgets/surfaces.dart';

/// "Share live": start a session, show its code and who is watching, stop it.
class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({required this.projectId, required this.scroll, super.key});

  final String projectId;
  final ScrollController scroll;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  bool _starting = false;

  Future<void> _start() async {
    final editor = ref.read(editorProvider(widget.projectId)).value;
    if (editor == null) return;
    setState(() => _starting = true);
    try {
      // Upload the room first so the session can point at it.
      await ref.read(editorProvider(widget.projectId).notifier).flush();
      await ref.read(cloudSyncProvider.notifier).flushAll();
      await ref
          .read(shareControllerProvider.notifier)
          .start(
            projectId: widget.projectId,
            name: editor.project.name,
            scene: editor.scene,
          );
      unawaited(Haptics.lightImpact());
    } on Object {
      if (mounted) unawaited(showToast(context, S.genericError));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop() async {
    final stop = await showRoomCraftDialog<bool>(
      context,
      title: S.stopSharingTitle,
      body: const Text(S.stopSharingBody),
      actions: [
        RoomCraftTextButton(
          label: S.keepSharing,
          onPressed: () => Navigator.pop(context, false),
        ),
        RoomCraftTextButton(
          label: S.stopSharing,
          destructive: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (stop ?? false) await ref.read(shareControllerProvider.notifier).stop();
  }

  @override
  Widget build(BuildContext context) {
    final share = ref.watch(shareControllerProvider);
    final online = ref.watch(isOnlineProvider);
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final code = share.sharing(widget.projectId) ? share.code : null;

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.xl),
      children: [
        Text(S.shareLive, style: text.titleLarge),
        const SizedBox(height: Space.sm),
        if (code == null) ...[
          Text(
            S.shareBody,
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.lg),
          NumberedStep(
            number: 1,
            color: c.primaryAction,
            ink: c.onPrimaryAction,
            text: S.shareStep1,
          ),
          NumberedStep(
            number: 2,
            color: c.coral,
            ink: c.onAccent,
            text: S.shareStep2,
          ),
          NumberedStep(
            number: 3,
            color: c.sunflower,
            ink: c.onAccent,
            text: S.shareStep3,
          ),
          const SizedBox(height: Space.md),
          PrimaryButton(
            label: S.startSharing,
            icon: Icons.sensors_rounded,
            loading: _starting,
            onPressed: online ? _start : null,
          ),
          if (!online) ...[
            const SizedBox(height: Space.sm),
            Text(
              S.offlineShare,
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ] else ...[
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.symmetric(vertical: Space.xl),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Semantics(
              label: code.split('').join(' '),
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  code,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 8,
                    color: c.primaryDark,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: S.copyCode,
                  icon: Icons.content_copy_rounded,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      unawaited(showToast(context, S.codeCopied));
                    }
                  },
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: SecondaryButton(
                  label: S.share,
                  icon: Icons.ios_share_rounded,
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: S.shareText(code)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              const LiveBadge(),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(S.watching(share.viewers), style: text.bodyMedium),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Center(
            child: RoomCraftTextButton(
              label: S.stopSharing,
              destructive: true,
              onPressed: _stop,
            ),
          ),
        ],
      ],
    );
  }
}
