import 'package:flutter/material.dart';

/// Full-width primary action button with a built-in busy state.
///
/// When [isLoading] is true the label is replaced by a spinner and the button
/// is disabled, so callers don't have to juggle that wiring per form.
///
/// The width is this widget's own, not the ambient theme's. It used to come
/// from a consuming app setting `filledButtonTheme` to an infinite minimum
/// width, which made every OTHER filled button in that app full-width too —
/// including the confirm in an [AlertDialog]'s action row, where it takes the
/// whole bar, overflows the OverflowBar and drops Cancel onto a line of its
/// own. A widget documented as full-width has to say so itself, so an app can
/// leave its filled buttons at a sane default and still get a form button that
/// fills the form.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    super.key,
  });

  /// Button text.
  final String label;

  /// Tap handler; ignored while [isLoading]. Pass null to disable.
  final VoidCallback? onPressed;

  /// Shows a spinner and disables the button when true.
  final bool isLoading;

  /// Optional leading icon (hidden while loading).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    final onTap = isLoading ? null : onPressed;

    // Size.fromHeight is Size(double.infinity, 48): fill the width, keep the
    // 48 touch target.
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    );

    if (icon != null && !isLoading) {
      return FilledButton.icon(
        onPressed: onTap,
        style: style,
        icon: Icon(icon),
        label: child,
      );
    }
    return FilledButton(onPressed: onTap, style: style, child: child);
  }
}
