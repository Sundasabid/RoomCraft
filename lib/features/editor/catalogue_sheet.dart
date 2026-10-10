import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../core/units.dart';
import '../../domain/scene/catalogue.dart';
import '../../widgets/chips.dart';
import 'item_thumbnail.dart';

/// "Add furniture": a short tray with category chips over one row of
/// cards, so the room stays in view while furnishing.
class CatalogueSheet extends StatefulWidget {
  const CatalogueSheet({
    required this.scroll,
    required this.unit,
    required this.full,
    required this.onAdd,
    super.key,
  });

  final ScrollController scroll;
  final DisplayUnit unit;
  final bool full;
  final ValueChanged<String> onAdd;

  /// Height the tray needs at the current text size.
  static double heightFor(BuildContext context) =>
      _CatalogueSheetState.heightFor(context);

  @override
  State<CatalogueSheet> createState() => _CatalogueSheetState();
}

class _CatalogueSheetState extends State<CatalogueSheet> {
  Category? _category;

  static const _labels = {
    null: S.catAll,
    Category.sleep: S.catSleep,
    Category.sit: S.catSit,
    Category.store: S.catStore,
    Category.work: S.catWork,
    Category.decor: S.catDecor,
  };

  /// One solid colour per category, so the tray reads at a glance.
  static Color tint(RoomCraftColors c, Category cat) => switch (cat) {
    Category.sleep => c.sky,
    Category.sit => c.coral,
    Category.store => c.sunflower,
    Category.work => c.primaryAction,
    Category.decor => c.coral,
  };

  /// Height the tray needs at the current text size.
  static double heightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    return Sizes.sheetHandleHeight +
        Space.xl +
        28 * scale +
        Space.sm +
        Sizes.touch +
        Space.sm +
        cardHeight(context) +
        Space.lg;
  }

  static double cardHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    return _thumb + Space.sm + 34 * scale + Space.sm;
  }

  static const _thumb = 84.0;
  static const _cardWidth = 116.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final items = Catalogue.items
        .where((i) => _category == null || i.category == _category)
        .toList();
    return ListView(
      controller: widget.scroll,
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            children: [
              Expanded(child: Text(S.addFurniture, style: text.titleLarge)),
              if (widget.full)
                Flexible(
                  child: Text(
                    S.roomFull,
                    textAlign: TextAlign.end,
                    style: text.bodySmall?.copyWith(color: c.warningText),
                  ),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.sm,
          ),
          child: Row(
            children: [
              for (final e in _labels.entries) ...[
                RoomCraftChip(
                  label: e.value,
                  selected: _category == e.key,
                  onTap: () => setState(() => _category = e.key),
                ),
                const SizedBox(width: Space.sm),
              ],
            ],
          ),
        ),
        SizedBox(
          height: cardHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.md),
            itemBuilder: (context, i) => _Card(
              item: items[i],
              tint: tint(c, items[i].category),
              size: widget.unit.formatSize(items[i].width, items[i].depth),
              enabled: !widget.full,
              onTap: () => widget.onAdd(items[i].id),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
      ],
    );
  }
}

/// A furniture card: the drawing on a soft block of its category colour,
/// with a solid plus badge, then its name and size.
class _Card extends StatelessWidget {
  const _Card({
    required this.item,
    required this.tint,
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  final CatalogueItem item;
  final Color tint;
  final String size;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final block = Color.alphaBlend(tint.withValues(alpha: 0.22), c.surface);
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${S.toolAdd} ${item.name}, $size',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: SizedBox(
          width: _CatalogueSheetState._cardWidth,
          child: Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: enabled ? onTap : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: _CatalogueSheetState._thumb,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: block,
                              borderRadius: BorderRadius.circular(Radii.card),
                            ),
                            child: Center(
                              child: ItemThumbnail(
                                item: item,
                                size: _CatalogueSheetState._thumb - Space.md,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: Space.sm,
                          right: Space.sm,
                          child: Container(
                            width: Space.xl,
                            height: Space.xl,
                            decoration: BoxDecoration(
                              color: c.primaryAction,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: c.onPrimaryAction,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.xs,
                      Space.sm,
                      Space.xs,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall,
                        ),
                        Text(
                          size,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            color: c.textSecondary,
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
      ),
    );
  }
}
