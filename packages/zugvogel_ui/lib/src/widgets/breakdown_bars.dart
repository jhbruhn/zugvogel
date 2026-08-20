import 'package:flutter/material.dart';
import 'package:zugvogel_ui/src/injection/semantics.dart';
import 'package:zugvogel_ui/src/theme/spacing.dart';
import 'package:zugvogel_ui/src/widgets/breakdown_card.dart';

/// The leading categories of a quantity that does NOT partition a whole, each
/// drawn as its own share of a stated [total].
///
/// ── Why bars and not a donut ────────────────────────────────────────────────
/// Diagnoses are multi-response data: one case can carry several, so the counts
/// overlap and their sum is not a number of anything. A ring would have to
/// normalise them against each other and would then draw a picture its own
/// percentages contradict (federfall-qogh). A bar carries no such claim — its
/// length is `count / total` and nothing else, which is exactly what its label
/// says, so the two agree by construction and each bar can be read on its own.
///
/// [caption] names the denominator, because "14 %" is meaningless until the
/// reader knows what it is 14 % of. The card's rows below carry every category
/// with its exact count; these bars are the shape of the leading few.
class BreakdownBars extends StatelessWidget {
  const BreakdownBars({
    required this.entries,
    required this.total,
    required this.caption,
    super.key,
  });

  final List<ChartEntry> entries;

  /// What each bar is measured against (e.g. the period's intakes).
  final int total;

  /// Names [total] in the reader's language, e.g. "Share of intakes".
  final String caption;

  /// How many bars are drawn before the card's rows take over.
  static const int maxBars = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // One hue for every bar: these are one series measured the same way, not
    // categories to tell apart — the label sits beside each bar and carries
    // its identity. It is the palette's FIRST entry, so a bar chart and a pie
    // on the same screen agree on what "the first series" looks like.
    final fill = context.zvColors.series(0);
    if (total <= 0) return const SizedBox.shrink();

    final ranked = [...entries]..sort((a, b) => b.count.compareTo(a.count));
    final shown = ranked.where((e) => e.count > 0).take(maxBars).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: ZugvogelSpacing.sm),
        for (final e in shown)
          _Bar(
            label: e.label,
            fraction: (e.count / total).clamp(0.0, 1.0),
            fill: fill,
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.fraction, required this.fill});

  final String label;
  final double fraction;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rounded = (fraction * 100).round();
    // A share too small to round up to a percent still happened, so it never
    // reads as "0 %" beside a row counting it.
    final percent = rounded == 0 && fraction > 0 ? '<1%' : '$rounded%';
    return Semantics(
      label: '$label $percent',
      child: Padding(
        padding: const EdgeInsets.only(bottom: ZugvogelSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: ZugvogelSpacing.xs),
                Text(
                  percent,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZugvogelSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 6,
                color: theme.colorScheme.surfaceContainerHighest,
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fraction,
                  child: ColoredBox(color: fill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
