import 'package:flutter/material.dart';
import 'package:zugvogel_ui/src/theme/spacing.dart';

/// A small rounded tag chip for a short status or category badge. Defaults to
/// the theme's secondary-container colours when [color]/[onColor] are omitted;
/// pass a `ZugvogelSemantics` role for a chip that carries a meaning.
class TagChip extends StatelessWidget {
  const TagChip({required this.label, this.color, this.onColor, super.key});

  final String label;
  final Color? color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = color ?? theme.colorScheme.secondaryContainer;
    final fg = onColor ?? theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZugvogelSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
