import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme/tokens.dart';

/// Shown instead of crashing when env.json was not passed to the build.
class SetupNeededScreen extends StatelessWidget {
  const SetupNeededScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Sizes.maxFormWidth),
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings_suggest_rounded,
                    size: 56,
                    color: c.primary,
                  ),
                  const SizedBox(height: Space.lg),
                  Text(S.setupNeededTitle, style: text.titleLarge),
                  const SizedBox(height: Space.sm),
                  Text(
                    S.setupNeededBody,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: c.textSecondary),
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
