import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/tokens.dart';
import 'motion.dart';

/// 56 dp text field with a floating label.
class RoomCraftTextField extends StatelessWidget {
  const RoomCraftTextField({
    required this.controller,
    required this.label,
    this.errorText,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.inputFormatters,
    this.suffixText,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.dense = false,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;
  final bool autofocus;
  final TextAlign textAlign;
  final bool dense;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.button),
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: dense ? null : label,
        hintText: dense ? label : null,
        errorText: errorText,
        suffixText: suffixText,
        counterText: '',
        filled: true,
        isDense: dense,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? c.background
            : c.surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: dense ? Space.sm : Space.lg,
          vertical: dense ? Space.md : Space.lg,
        ),
        labelStyle: TextStyle(color: c.textSecondary),
        floatingLabelStyle: TextStyle(color: c.primary),
        suffixStyle: TextStyle(color: c.textSecondary),
        errorStyle: TextStyle(color: c.warningText, fontSize: TypeScale.label),
        enabledBorder: border(c.fieldBorder, 1),
        focusedBorder: border(c.primary, 2),
        errorBorder: border(c.warning, 2),
        focusedErrorBorder: border(c.warning, 2),
      ),
    );
  }
}

/// Round 56 dp finish swatch with its name below; a 3 dp ring when current.
class Swatch extends StatelessWidget {
  const Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              AnimatedContainer(
                duration: motion(context, Motion.fast),
                width: Sizes.swatch + 8,
                height: Sizes.swatch + 8,
                padding: const EdgeInsets.all(Space.xs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? c.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.swatchEdge),
                  ),
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
