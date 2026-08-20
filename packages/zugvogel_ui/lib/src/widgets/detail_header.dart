import 'package:flutter/material.dart';
import 'package:zugvogel_ui/src/theme/spacing.dart';

/// Name-first identity header for a detail screen: a dominant [title], an
/// optional muted [subtitle] line, and an optional status [chipLabel]. An
/// optional [leading] slot holds an avatar to the left of the text.
///
/// Pure presentation — the caller resolves every string, so the same header
/// serves several kinds of record without knowing any domain type. That is
/// what makes it shareable at all.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    required this.title,
    this.subtitle,
    this.footer,
    this.chipLabel,
    this.chipAlert = false,
    this.leading,
    this.trailing,
    this.onTitleTap,
    this.titleTapTooltip,
    super.key,
  });

  /// The dominant headline — a name, or whatever identifies the record
  /// when it has none.
  final String title;

  /// When set, [title] becomes tappable — e.g. a header linking to the parent
  /// record it belongs to — instead of being plain text.
  final VoidCallback? onTitleTap;

  /// Tooltip shown on the tappable title; only meaningful with [onTitleTap].
  final String? titleTapTooltip;

  /// Muted secondary line (e.g. "Species · 2026-014"); omitted when null/empty.
  final String? subtitle;

  /// Optional extra line under the subtitle, aligned with the text column.
  /// Sits above the status chip; omitted when null.
  final Widget? footer;

  /// Status chip text; omitted when null.
  final String? chipLabel;

  /// Renders the chip in error-container colours to flag an abnormal state —
  /// something over capacity, overdue, or out of range.
  final bool chipAlert;

  /// Optional leading widget (avatar) shown left of the text.
  final Widget? leading;

  /// Optional trailing widget (e.g. a read-only badge), aligned top-end.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    Widget titleText = Text(title, style: theme.textTheme.headlineSmall);
    if (onTitleTap != null) {
      titleText = InkWell(
        onTap: onTitleTap,
        borderRadius: BorderRadius.circular(4),
        mouseCursor: SystemMouseCursors.click,
        child: titleText,
      );
      if (titleTapTooltip != null) {
        titleText = Tooltip(message: titleTapTooltip, child: titleText);
      }
    }

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleText,
        if (hasSubtitle) ...[
          const SizedBox(height: ZugvogelSpacing.xs),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (footer != null) ...[
          const SizedBox(height: ZugvogelSpacing.xs),
          footer!,
        ],
        if (chipLabel != null) ...[
          const SizedBox(height: ZugvogelSpacing.sm),
          Chip(
            label: Text(chipLabel!),
            visualDensity: VisualDensity.compact,
            backgroundColor: chipAlert
                ? theme.colorScheme.errorContainer
                : null,
            labelStyle: chipAlert
                ? TextStyle(color: theme.colorScheme.onErrorContainer)
                : null,
          ),
        ],
      ],
    );

    // Fill the width and align left so a shrink-wrapped header is never
    // centred by a parent Column's default cross-axis alignment.
    if (leading == null && trailing == null) {
      return Align(alignment: AlignmentDirectional.centerStart, child: text);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: ZugvogelSpacing.md),
        ],
        Expanded(child: text),
        if (trailing != null) ...[
          const SizedBox(width: ZugvogelSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}
