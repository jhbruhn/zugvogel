import 'package:flutter/material.dart';
import 'package:zugvogel_ui/src/injection/strings.dart';
import 'package:zugvogel_ui/src/theme/spacing.dart';

/// Centered error state with an icon, message and optional retry button. Used
/// by `AsyncValueView` and anywhere a load/action fails.
class ErrorView extends StatelessWidget {
  const ErrorView({this.message, this.onRetry, super.key});

  /// The user-facing message; falls back to a generic localized title.
  final String? message;

  /// When non-null, a retry button is shown that invokes this.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final zv = context.zv;
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZugvogelSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: ZugvogelSpacing.md),
            Text(
              message ?? zv.errorGenericTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: ZugvogelSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(zv.actionRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
