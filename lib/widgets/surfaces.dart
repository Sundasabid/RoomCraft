import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme/tokens.dart';
import 'over_3d.dart';
import 'pressable.dart';

List<BoxShadow> softShadow(RoomCraftColors c) => [
  BoxShadow(color: c.shadow, blurRadius: 16, offset: const Offset(0, 4)),
];

/// White, radius 16, soft tonal shadow, 16 dp padding.
class RoomCraftCard extends StatelessWidget {
  const RoomCraftCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.lg),
    this.color,
    this.border,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(Radii.card);
    final body = Material(
      color: color ?? c.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: border == null
              ? null
              : BoxDecoration(border: border, borderRadius: radius),
          child: child,
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: softShadow(c)),
      child: onTap == null ? body : Pressable(onTap: onTap, child: body),
    );
  }
}

/// The 4 by 40 dp handle at the top of every sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: S.dragToResize,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Center(
        child: Container(
          width: Sizes.sheetHandleWidth,
          height: Sizes.sheetHandleHeight,
          decoration: BoxDecoration(
            color: context.colors.fieldBorder,
            borderRadius: BorderRadius.circular(Radii.round),
          ),
        ),
      ),
    ),
  );
}

/// Draggable bottom sheet with snap points at 30, 60 and 90 percent.
Future<T?> showRoomCraftSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext, ScrollController) builder,
  double initial = 0.6,
  List<double> snaps = const [0.3, 0.6, 0.9],
}) {
  final width = MediaQuery.sizeOf(context).width;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxWidth: width >= Sizes.tabletBreakpoint ? Sizes.maxFormWidth : width,
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initial,
      minChildSize: snaps.first,
      maxChildSize: snaps.last,
      snap: true,
      snapSizes: snaps,
      builder: (context, controller) => Column(
        children: [
          const SheetHandle(),
          Expanded(child: builder(context, controller)),
        ],
      ),
    ),
  );
}

/// White dialog, radius 20, 24 dp padding, right-aligned text actions.
Future<T?> showRoomCraftDialog<T>(
  BuildContext context, {
  required String title,
  Widget? body,
  required List<Widget> actions,
}) => showDialog<T>(
  context: context,
  builder: (context) => Over3D(
    child: AlertDialog(
      title: Text(title),
      content: body,
      contentPadding: const EdgeInsets.fromLTRB(
        Space.xl,
        Space.lg,
        Space.xl,
        0,
      ),
      actionsPadding: const EdgeInsets.all(Space.lg),
      actions: actions,
    ),
  ),
);

/// Dark pill toast, floating. Returns true when Undo was tapped.
Future<bool> showToast(
  BuildContext context,
  String message, {
  bool withUndo = false,
  double bottomOffset = 0,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final c = context.colors;
  // Undo lives inside the content (not a SnackBarAction) so the whole toast
  // can sit over the browser's 3D view and still take taps.
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Over3D(
        child: Row(
          children: [
            Expanded(child: Text(message)),
            if (withUndo)
              TextButton(
                onPressed: () => messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                ),
                style: TextButton.styleFrom(foregroundColor: c.onToast),
                child: const Text(S.undo),
              ),
          ],
        ),
      ),
      duration: withUndo ? Motion.toastUndo : Motion.toastShort,
      margin: EdgeInsets.fromLTRB(
        Space.lg,
        0,
        Space.lg,
        Space.lg + bottomOffset,
      ),
    ),
  );
  final reason = await controller.closed;
  return reason == SnackBarClosedReason.action;
}

enum BannerTone { warning, info, calm }

/// Radius 12 banner. Warning: terracotta tint. Info: sand. Calm: sage tint.
class RoomCraftBanner extends StatelessWidget {
  const RoomCraftBanner({
    required this.message,
    this.tone = BannerTone.warning,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final BannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (
      Color fill,
      Color border,
      Color fg,
      IconData defaultIcon,
    ) = switch (tone) {
      BannerTone.warning => (
        Color.alphaBlend(c.warning.withValues(alpha: 0.12), c.surface),
        c.warning.withValues(alpha: 0.4),
        c.warningText,
        Icons.warning_amber_rounded,
      ),
      BannerTone.info => (
        c.surfaceAlt,
        c.fieldBorder,
        c.textPrimary,
        Icons.cloud_off_rounded,
      ),
      BannerTone.calm => (
        Color.alphaBlend(c.primary.withValues(alpha: 0.14), c.surface),
        c.primary.withValues(alpha: 0.4),
        c.textPrimary,
        Icons.visibility_rounded,
      ),
    };
    return Semantics(
      liveRegion: tone == BannerTone.warning,
      child: Container(
        constraints: const BoxConstraints(minHeight: Sizes.touch),
        padding: const EdgeInsets.only(left: Space.md, right: Space.xs),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(icon ?? defaultIcon, size: 20, color: fg),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.sm),
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: fg,
                  minimumSize: const Size(Sizes.touch, Sizes.touch),
                  textStyle: Theme.of(context).textTheme.titleSmall,
                ),
                child: Text(actionLabel!),
              )
            else
              const SizedBox(width: Space.sm),
          ],
        ),
      ),
    );
  }
}
