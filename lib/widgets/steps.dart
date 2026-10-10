import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// A numbered step with a solid coloured number.
class NumberedStep extends StatelessWidget {
  const NumberedStep({
    required this.number,
    required this.color,
    required this.ink,
    required this.text,
    super.key,
  });

  final int number;
  final Color color;
  final Color ink;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: Space.xxl,
          height: Space.xxl,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: ink),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ),
      ],
    ),
  );
}
