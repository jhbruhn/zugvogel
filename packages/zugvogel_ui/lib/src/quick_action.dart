import 'package:flutter/material.dart';
import 'package:zugvogel_core/zugvogel_core.dart';
import 'package:zugvogel_ui/src/errors.dart';
import 'package:zugvogel_ui/src/injection/strings.dart';
import 'package:zugvogel_ui/src/widgets/destructive_action_button.dart';

/// Runs a one-tap quick action — a list row's mark-done, an end-now, a tile
/// delete — and surfaces a failure as the standard [errorMessage] snackbar.
///
/// Form sheets show repository errors inline, but these shortcuts have no
/// surface of their own: without this, a failed call (offline, server error)
/// was completely silent. Messenger and strings are snapshotted before the
/// await so a tile disposed mid-flight can still report.
Future<void> runQuickAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final strings = context.zv;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } on Object catch (error, stackTrace) {
    reportCaughtError(error, stackTrace);
    messenger.showSnackBar(
      SnackBar(content: Text(errorMessage(strings, error))),
    );
  }
}

/// Shows a cancel/confirm [AlertDialog] and, once confirmed, runs [action] via
/// [runQuickAction]. The confirm-then-delete flow every timeline tile's delete
/// affordance otherwise repeats.
Future<void> confirmAndDelete(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Future<void> Function() action,
}) async {
  final strings = context.zv;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(strings.actionCancel),
        ),
        // Filled and error-coloured, not a second text button: see
        // [DestructiveActionButton].
        DestructiveActionButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await runQuickAction(context, action);
}
