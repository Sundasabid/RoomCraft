import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/time_ago.dart';
import '../../data/supabase_client.dart';
import '../../domain/constants.dart';
import '../../domain/scene/scene_json.dart';
import '../../state/cloud_sync.dart';
import '../../state/connectivity_provider.dart';
import '../../state/projects_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/fields.dart';
import '../../widgets/motion.dart';
import '../../widgets/placeholders.dart';
import '../../widgets/surfaces.dart';
import '../editor/plan_view/plan_thumbnail.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final _scroll = ScrollController();
  String? _flashId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _rename(ProjectFile p) async {
    final controller = TextEditingController(text: p.name)
      ..selection = TextSelection(baseOffset: 0, extentOffset: p.name.length);
    final name = await showRoomCraftDialog<String>(
      context,
      title: S.renameRoom,
      body: RoomCraftTextField(
        controller: controller,
        label: S.roomName,
        maxLength: maxNameLength,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        RoomCraftTextButton(
          label: S.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        RoomCraftTextButton(
          label: S.save,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(projectsProvider.notifier).rename(p.id, name);
    }
  }

  Future<void> _duplicate(ProjectFile p) async {
    final id = await ref.read(projectsProvider.notifier).duplicate(p.id);
    if (id == null || !mounted) return;
    setState(() => _flashId = id);
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        0,
        duration: motion(context, Motion.sheet),
        curve: Motion.curve,
      );
    }
  }

  Future<void> _delete(ProjectFile p) async {
    final projects = ref.read(projectsProvider.notifier)..hide(p.id);
    final undone = await showToast(
      context,
      S.roomDeleted,
      withUndo: true,
      bottomOffset: Sizes.button + Space.lg,
    );
    if (undone) {
      projects.restore(p.id);
    } else {
      await projects.purge(p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final statuses = ref.watch(cloudSyncProvider);
    final online = ref.watch(isOnlineProvider);
    final cloudFailed = ref.read(projectsProvider.notifier).cloudFailed;
    final signInFailed = ref.watch(sessionProvider).hasError;
    final notice = !online
        ? S.offlineList
        : signInFailed
        ? S.genericError
        : cloudFailed
        ? S.cloudListFailed
        : null;
    final width = MediaQuery.sizeOf(context).width;
    final side = width >= Sizes.tabletBreakpoint ? Space.xl : Space.lg;
    final columns = width >= Sizes.tabletBreakpoint ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: side,
        toolbarHeight: Sizes.tabBar,
        title: Text(
          S.projectsTitle,
          style: RoomCraftTheme.heading(context.colors, TypeScale.display),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            if (notice != null && projects.hasValue)
              Positioned(
                top: 0,
                left: side,
                right: side,
                child: signInFailed && online
                    ? RoomCraftBanner(
                        message: notice,
                        actionLabel: S.tryAgain,
                        onAction: () => ref.invalidate(sessionProvider),
                      )
                    : RoomCraftBanner(message: notice, tone: BannerTone.info),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: notice != null && projects.hasValue
                    ? Sizes.touch + Space.sm
                    : 0,
              ),
              child: switch (projects) {
                AsyncData(:final value) when value.isEmpty => EmptyState(
                  title: S.projectsEmptyTitle,
                  body: S.projectsEmptyBody,
                  actionLabel: S.newRoom,
                  onAction: () => context.push('/setup'),
                ),
                AsyncData(:final value) => RefreshIndicator(
                  color: context.colors.primary,
                  onRefresh: () =>
                      ref.read(projectsProvider.notifier).refresh(),
                  child: GridView.builder(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      side,
                      Space.sm,
                      side,
                      84 + Space.lg,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: Space.md,
                      mainAxisSpacing: Space.md,
                      mainAxisExtent: _cardHeight(
                        context,
                        width,
                        side,
                        columns,
                      ),
                    ),
                    itemCount: value.length,
                    itemBuilder: (context, i) {
                      final p = value[i];
                      return _ProjectCard(
                        key: ValueKey(p.id),
                        project: p,
                        status: statuses[p.id] ?? SyncStatus.localOnly,
                        flash: p.id == _flashId,
                        onOpen: () => context.push('/editor/${p.id}'),
                        onRename: () => _rename(p),
                        onDuplicate: () => _duplicate(p),
                        onDelete: () => _delete(p),
                      );
                    },
                  ),
                ),
                AsyncError() => EmptyState(
                  title: S.genericError,
                  body: '',
                  actionLabel: S.tryAgain,
                  onAction: () => ref.invalidate(projectsProvider),
                ),
                _ => GridView.count(
                  crossAxisCount: columns,
                  padding: EdgeInsets.fromLTRB(side, Space.sm, side, Space.lg),
                  crossAxisSpacing: Space.md,
                  mainAxisSpacing: Space.md,
                  childAspectRatio: 0.8,
                  children: [
                    for (var i = 0; i < 4; i++)
                      const Skeleton(radius: Radii.card),
                  ],
                ),
              },
            ),
            if (projects.value?.isNotEmpty ?? false)
              Positioned(
                left: side,
                right: side,
                bottom: Space.lg,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: Sizes.maxFormWidth,
                    ),
                    child: PrimaryButton(
                      label: S.newRoom,
                      icon: Icons.add_rounded,
                      onPressed: () => context.push('/setup'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Thumbnail at 4:3 plus the text block, which grows with the text scale.
  double _cardHeight(
    BuildContext context,
    double width,
    double side,
    int columns,
  ) {
    final cardWidth = (width - 2 * side - (columns - 1) * Space.md) / columns;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return cardWidth * 3 / 4 + Space.xl + 60 * scale + Space.xs;
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.status,
    required this.flash,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    super.key,
  });

  final ProjectFile project;
  final SyncStatus status;
  final bool flash;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final edited = editedAgo(project.updatedAt, DateTime.now());
    return RoomCraftCard(
      padding: EdgeInsets.zero,
      onTap: onOpen,
      border: flash ? Border.all(color: c.primary, width: 2) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ColoredBox(
                  color: c.background,
                  child: PlanThumbnail(scene: project.scene),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<String>(
                  tooltip: S.more,
                  icon: Icon(Icons.more_horiz_rounded, color: c.textPrimary),
                  onSelected: (v) => switch (v) {
                    'rename' => onRename(),
                    'duplicate' => onDuplicate(),
                    _ => onDelete(),
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      height: Sizes.touch,
                      child: Text(S.rename),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      height: Sizes.touch,
                      child: Text(S.duplicate),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      height: Sizes.touch,
                      child: Text(
                        S.delete,
                        style: TextStyle(color: c.warningText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.md,
              Space.md,
              Space.sm,
              Space.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        S.projectSubtitle(edited, project.scene.items.length),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: switch (status) {
                    SyncStatus.synced => S.synced,
                    SyncStatus.pending => S.pendingSync,
                    SyncStatus.localOnly => S.localOnly,
                  },
                  child: Icon(
                    switch (status) {
                      SyncStatus.synced => Icons.cloud_done_rounded,
                      SyncStatus.pending => Icons.cloud_sync_rounded,
                      SyncStatus.localOnly => Icons.cloud_off_rounded,
                    },
                    size: 18,
                    color: status == SyncStatus.synced
                        ? c.primary
                        : c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
