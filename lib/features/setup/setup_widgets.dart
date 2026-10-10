import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme/tokens.dart';
import '../../core/units.dart';
import '../../widgets/buttons.dart';
import '../../widgets/fields.dart';

/// Label, minus, typed value, plus, and a slider underneath. Values are
/// metres; the field shows the display unit.
class DimensionRow extends StatefulWidget {
  const DimensionRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final DisplayUnit unit;
  final ValueChanged<double> onChanged;

  @override
  State<DimensionRow> createState() => _DimensionRowState();
}

class _DimensionRowState extends State<DimensionRow> {
  late final TextEditingController _text = TextEditingController(
    text: _format(),
  );
  final _focus = FocusNode();

  String _format() => widget.unit
      .fromMetres(widget.value)
      .toStringAsFixed(widget.unit == DisplayUnit.feet ? 1 : 2);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        _submit(_text.text);
      }
    });
  }

  @override
  void didUpdateWidget(DimensionRow old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus &&
        (old.value != widget.value || old.unit != widget.unit)) {
      _text.text = _format();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String v) {
    final parsed = double.tryParse(v.replaceAll(',', '.'));
    if (parsed != null) widget.onChanged(widget.unit.toMetres(parsed));
    _text.text = _format();
  }

  void _step(double by) =>
      widget.onChanged(((widget.value + by) * 10).roundToDouble() / 10);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasRange = widget.max > widget.min;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            RoomCraftIconButton(
              icon: Icons.remove_rounded,
              tooltip: '${S.decrease} ${widget.label.toLowerCase()}',
              onPressed: widget.value > widget.min + 1e-9
                  ? () => _step(-0.1)
                  : null,
            ),
            SizedBox(
              width: 96,
              child: RoomCraftTextField(
                controller: _text,
                focusNode: _focus,
                label: widget.label,
                dense: true,
                textAlign: TextAlign.center,
                suffixText: widget.unit.symbol,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onSubmitted: _submit,
              ),
            ),
            RoomCraftIconButton(
              icon: Icons.add_rounded,
              tooltip: '${S.increase} ${widget.label.toLowerCase()}',
              onPressed: widget.value < widget.max - 1e-9
                  ? () => _step(0.1)
                  : null,
            ),
          ],
        ),
        if (hasRange)
          Slider(
            value: widget.value.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            divisions: ((widget.max - widget.min) * 10).round().clamp(1, 1000),
            semanticFormatterCallback: (v) => widget.unit.format(v),
            onChanged: widget.onChanged,
            activeColor: c.primary,
          ),
      ],
    );
  }
}

/// "Door, left wall · at 0.9 m", a width stepper and delete.
class OpeningRow extends StatelessWidget {
  const OpeningRow({
    required this.icon,
    required this.title,
    required this.offset,
    required this.width,
    required this.selected,
    required this.onTap,
    required this.onNarrower,
    required this.onWider,
    required this.onDelete,
    super.key,
  });

  final IconData icon;
  final String title;
  final String offset;
  final String width;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onNarrower;
  final VoidCallback? onWider;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Material(
      color: selected
          ? Color.alphaBlend(c.primary.withValues(alpha: 0.10), c.surface)
          : c.surface,
      borderRadius: BorderRadius.circular(Radii.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.button),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.xs,
            Space.sm,
          ),
          child: LayoutBuilder(
            builder: (context, box) => Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              runSpacing: Space.xs,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(Radii.small),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: selected ? c.primary : c.textPrimary,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: text.titleSmall),
                            Text(offset, style: text.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoomCraftIconButton(
                      icon: Icons.remove_rounded,
                      tooltip: S.narrower,
                      onPressed: onNarrower,
                    ),
                    Text(
                      width,
                      style: text.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    RoomCraftIconButton(
                      icon: Icons.add_rounded,
                      tooltip: S.wider,
                      onPressed: onWider,
                    ),
                    RoomCraftIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: S.delete,
                      color: c.warningText,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
