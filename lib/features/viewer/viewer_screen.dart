import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/scene_bridge.dart';
import '../../bridge/scene_sync.dart';
import '../../core/strings.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../state/settings_controller.dart';
import '../../state/viewer_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/live_badge.dart';
import '../../widgets/placeholders.dart';
import '../../widgets/surfaces.dart';
import '../editor/editor_views.dart';
import '../editor/plan_view/plan_overlays.dart';
import '../editor/plan_view/plan_view.dart';
import '../editor/view3d/view3d.dart';

/// Read-only live room. No toolbar, no catalogue, no editing gestures; the
/// viewer only moves their own camera.
class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  final _plan = PlanViewController();
  // Keeps the 3D view alive when rotation moves it.
  final _view3dKey = GlobalKey();
  late final AppLifecycleListener _lifecycle;
  SceneSync? _sync;
  String _preset = 'corner';
  RoomCraftColors? _colors;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(viewerProvider(widget.code).notifier).resync(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _plan.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = context.colors;
    if (_colors != null && _colors != c) _sync?.theme(c);
    _colors = c;
  }

  SceneFrame _frame(ViewerState v) => SceneFrame(
    scene: v.scene,
    flagged: v.report.flagged,
    previews: {
      for (final e in v.previews.entries) e.key: (e.value.x, e.value.z),
    },
  );

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider(widget.code));

    ref.listen(viewerProvider(widget.code), (before, now) {
      if (now.hasError && before?.hasValue != true) {
        context.go('/live?error=noroom');
        return;
      }
      final v = now.value;
      if (v == null) return;
      _sync?.update(_frame(v));
      if (before?.value?.status != v.status) {
        final say = switch (v.status) {
          ViewerStatus.reconnecting => S.reconnecting,
          ViewerStatus.ended => S.ownerStopped,
          ViewerStatus.live => null,
        };
        if (say != null) {
          SemanticsService.sendAnnouncement(
            View.of(context),
            say,
            TextDirection.ltr,
          );
        }
      }
    });

    final v = viewer.value;
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: Sizes.appBar,
              child: Row(
                children: [
                  const SizedBox(width: Space.xs),
                  RoomCraftIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: S.back,
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/live'),
                  ),
                  Expanded(
                    child: Text(
                      v?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RoomCraftTheme.heading(c, TypeScale.title),
                    ),
                  ),
                  if (v != null)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.lg),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width / 2,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              LiveBadge(
                                reconnecting:
                                    v.status == ViewerStatus.reconnecting,
                              ),
                              const SizedBox(height: Space.xs),
                              Text(
                                S.updatedAt(_clock(v.updatedAt)),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: v == null
                  ? const Padding(
                      padding: EdgeInsets.all(Space.lg),
                      child: Column(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Skeleton(radius: Radii.card),
                          ),
                          SizedBox(height: Space.lg),
                          Expanded(
                            flex: 2,
                            child: Skeleton(radius: Radii.card),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        Positioned.fill(child: _views(v)),
                        if (v.status == ViewerStatus.ended) ...[
                          Positioned.fill(child: ColoredBox(color: c.scrim)),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(Space.xl),
                              child: RoomCraftCard(
                                padding: const EdgeInsets.all(Space.xl),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.sensors_off_rounded,
                                      size: 32,
                                      color: c.textSecondary,
                                    ),
                                    const SizedBox(height: Space.md),
                                    Text(
                                      S.ownerStopped,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: Space.xl),
                                    PrimaryButton(
                                      label: S.backToStart,
                                      onPressed: () => context.go('/live'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  Widget _views(ViewerState v) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final split = ref.watch(settingsProvider.select((s) => s.viewSplit));
    final unit = ref.watch(settingsProvider.select((s) => s.unit));
    final view3d = Stack(
      key: _view3dKey,
      children: [
        Positioned.fill(
          child: View3D(
            buildInit: (SceneBridge bridge) {
              final sync = _sync = SceneSync(bridge);
              return sync.init(
                _frame(v),
                mode: 'viewer',
                reduceMotion: MediaQuery.disableAnimationsOf(context),
                colors: context.colors,
              );
            },
            onReady: (_) {
              final now = ref.read(viewerProvider(widget.code)).value;
              if (now != null) _sync?.afterInit(_frame(now));
              _sync?.camera(_preset);
            },
            onMessage: (_) {},
          ),
        ),
        Positioned(
          top: Space.md,
          left: Space.md,
          child: PresetPill(
            value: _preset,
            onChanged: (p) {
              setState(() => _preset = p);
              _sync?.camera(p);
            },
          ),
        ),
      ],
    );
    final plan = Stack(
      children: [
        Positioned.fill(
          child: PlanView(
            scene: v.displayScene,
            controller: _plan,
            unit: unit,
            overlay: PlanOverlay(flagged: v.report.flagged),
          ),
        ),
        Positioned(
          top: Space.sm,
          right: Space.md,
          child: UnitChip(unit: unit),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (landscape) {
          return Row(
            children: [
              Expanded(flex: 3, child: view3d),
              const SizedBox(width: Space.lg),
              Expanded(flex: 2, child: plan),
            ],
          );
        }
        final free = box.maxHeight - Space.lg;
        final h3d = (free * split)
            .clamp(math.min(240.0, free - 160), math.max(free - 160, 0.0))
            .toDouble();
        return Column(
          children: [
            SizedBox(height: h3d, child: view3d),
            const SizedBox(height: Space.lg),
            Expanded(child: plan),
          ],
        );
      },
    );
  }
}
