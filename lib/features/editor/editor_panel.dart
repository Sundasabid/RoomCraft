import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/buttons.dart';
import '../../widgets/motion.dart';
import '../../widgets/surfaces.dart';

/// A sheet that lives inside the editor, so the room stays touchable behind
/// it. Portrait: a draggable bottom sheet (swipe down closes). Landscape: a
/// 360 dp panel from the right.
class EditorPanel extends StatefulWidget {
  const EditorPanel({
    required this.landscape,
    required this.builder,
    required this.onClose,
    required this.controller,
    this.initial = 0.6,
    this.snaps = const [0.3, 0.6, 0.9],
    super.key,
  });

  final bool landscape;
  final Widget Function(BuildContext, ScrollController) builder;
  final VoidCallback onClose;
  final DraggableScrollableController controller;
  final double initial;
  final List<double> snaps;

  @override
  State<EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<EditorPanel> {
  final _sideScroll = ScrollController();
  final _scope = FocusScopeNode(debugLabel: 'EditorPanel');

  /// The control that opened the sheet; focus returns to it on close.
  FocusNode? _opener;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_watch);
    final f = FocusManager.instance.primaryFocus;
    if (f != null && f is! FocusScopeNode) _opener = f;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_watch);
    _sideScroll.dispose();
    _scope.dispose();
    final opener = _opener;
    if (opener != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (opener.context != null && opener.canRequestFocus) {
          opener.requestFocus();
        }
      });
    }
    super.dispose();
  }

  /// Screen readers stay inside the sheet until it closes, and can close it
  /// with their dismiss gesture.
  Widget _trap(Widget child) => BlockSemantics(
    child: Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      onDismiss: widget.onClose,
      child: FocusScope(
        node: _scope,
        autofocus: true,
        child: FocusTraversalGroup(child: child),
      ),
    ),
  );

  void _watch() {
    if (widget.controller.isAttached && widget.controller.size < 0.08) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (widget.landscape) {
      return _trap(
        Container(
          width: Sizes.sidePanel,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(Radii.card),
            ),
            boxShadow: softShadow(c),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: RoomCraftIconButton(
                  icon: Icons.close_rounded,
                  tooltip: S.closePanel,
                  onPressed: widget.onClose,
                ),
              ),
              Expanded(child: widget.builder(context, _sideScroll)),
            ],
          ),
        ),
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    return DraggableScrollableSheet(
      controller: widget.controller,
      initialChildSize: widget.initial,
      minChildSize: 0,
      maxChildSize: widget.snaps.last,
      snap: true,
      snapSizes: widget.snaps,
      snapAnimationDuration: motion(context, Motion.sheet),
      builder: (context, scroll) => _trap(
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: width >= Sizes.tabletBreakpoint ? Sizes.maxFormWidth : width,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(Radii.card),
              ),
              boxShadow: [
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) {
                    final h = MediaQuery.sizeOf(context).height;
                    final c = widget.controller;
                    c.jumpTo(
                      (c.size - d.delta.dy / h).clamp(0.0, widget.snaps.last),
                    );
                  },
                  onVerticalDragEnd: (_) {
                    final c = widget.controller;
                    if (c.size < widget.snaps.first * 0.6) {
                      widget.onClose();
                      return;
                    }
                    final nearest = widget.snaps.reduce(
                      (a, b) => (a - c.size).abs() < (b - c.size).abs() ? a : b,
                    );
                    c.animateTo(
                      nearest,
                      duration: motion(context, Motion.medium),
                      curve: Motion.curve,
                    );
                  },
                  child: const SheetHandle(),
                ),
                Expanded(child: widget.builder(context, scroll)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
