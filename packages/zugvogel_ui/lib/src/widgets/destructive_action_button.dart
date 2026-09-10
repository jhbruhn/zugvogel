import 'package:flutter/material.dart';

/// The size a button in a dialog's action row asks for.
///
/// 64 is Material's own minimum width; 48 keeps the touch target. It has to be
/// stated rather than inherited because a consuming app may set
/// `filledButtonTheme` to an infinite minimum width for its form buttons — see
/// `PrimaryButton` — and an action-row button that obeys that takes the whole
/// bar, overflowing the OverflowBar so the Cancel beside it lands on a line of
/// its own.
const kDialogActionSize = Size(64, 48);

/// The confirm button on a dialog that is about to destroy something
/// (federfall-qo8f).
///
/// Never a bare [TextButton] beside Cancel: two identical text buttons whose
/// only difference is red text make the error colour *load-bearing*, which
/// fails WCAG 2.1 SC 1.4.1 (use of colour) and gives the squint test two
/// equally prominent options on a dialog whose whole purpose is to make the
/// user stop. Here shape and weight carry the distinction and the colour is
/// redundant on top.
///
/// Pass [demoted] where the dialog **also** offers a reversible alternative —
/// deactivating a record instead of deleting it. The safe route keeps the
/// filled primary slot, so this drops to an outline: still unmistakably not
/// Cancel, but no longer outranking the way out.
class DestructiveActionButton extends StatelessWidget {
  const DestructiveActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.demoted = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  /// Optional leading icon — e.g. `Icons.delete_forever` on a cascading
  /// delete, where a third redundant signal is worth the space.
  final IconData? icon;

  /// True when a reversible alternative shares the action row and should
  /// out-rank this button. See the class doc.
  final bool demoted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (demoted) {
      // No minimumSize: an outlined button is not subject to the app's
      // filledButtonTheme, so the demoted variant never stretched.
      final style = OutlinedButton.styleFrom(
        foregroundColor: scheme.error,
        side: BorderSide(color: scheme.error),
      );
      return icon == null
          ? OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon),
              label: Text(label),
            );
    }

    final style = FilledButton.styleFrom(
      backgroundColor: scheme.error,
      foregroundColor: scheme.onError,
      minimumSize: kDialogActionSize,
    );
    return icon == null
        ? FilledButton(
            onPressed: onPressed,
            style: style,
            child: Text(label),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}
