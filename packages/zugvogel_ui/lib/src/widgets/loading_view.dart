import 'package:flutter/material.dart';
import 'package:zugvogel_ui/src/injection/strings.dart';
import 'package:zugvogel_ui/src/theme/spacing.dart';

/// Centered loading indicator with an optional label. The default async/empty
/// loading state across the app.
class LoadingView extends StatelessWidget {
  const LoadingView({this.label, super.key});

  /// Overrides the default "loading…" label. Pass an empty string to hide it.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? context.zv.loadingLabel;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (text.isNotEmpty) ...[
            const SizedBox(height: ZugvogelSpacing.md),
            Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
