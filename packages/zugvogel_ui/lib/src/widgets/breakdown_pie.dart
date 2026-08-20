import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zugvogel_ui/src/injection/semantics.dart';
import 'package:zugvogel_ui/src/theme/spacing.dart';
import 'package:zugvogel_ui/src/widgets/breakdown_bars.dart';
import 'package:zugvogel_ui/src/widgets/breakdown_card.dart';

/// The share of a whole, as a donut: the top few categories in fixed colours
/// plus everything else folded into one neutral slice.
///
/// ── Only for a set that partitions its whole ────────────────────────────────
/// The ring IS the sum of [entries]: every slice is drawn as its share of that
/// sum and labelled with the same fraction, so the picture and the numbers
/// cannot disagree. There is deliberately no way to hand it a different
/// denominator — that is what let the conditions donut fill half its ring with
/// a slice labelled 14 % (federfall-qogh). A quantity whose categories overlap
/// or leave a remainder is not a share of this whole and belongs in
/// [BreakdownBars], which measures each bar against a stated total on its own.
///
/// ── Why only three colours ──────────────────────────────────────────────────
/// A pie is an "all pairs" form — every slice can end up beside every other, so
/// each pair of colours has to be separable on its own, not just from its
/// neighbours. Validated against the CVD, normal-vision and contrast checks
/// (OKLab ΔE), three hues plus a neutral is what clears them in BOTH themes;
/// a fourth hue puts two colours on screen that a full-colour reader struggles
/// to tell apart, let alone a colourblind one. So the tail folds into
/// [otherLabel] rather than growing new hues — and the card's own rows below
/// still list every category with its exact count, which is the honest answer
/// to "what is in Other?".
///
/// Colours are assigned by RANK within this chart and are not comparable
/// across charts; the legend and the rows are what carry identity.
class BreakdownPie extends StatelessWidget {
  const BreakdownPie({
    required this.entries,
    required this.otherLabel,
    super.key,
  });

  final List<ChartEntry> entries;

  /// Name for the folded tail (e.g. "Other").
  final String otherLabel;

  /// How many categories keep a colour of their own before the rest folds.
  static const int coloredSlices = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Categorical hues in fixed order, then the neutral for the folded tail.
    // Injected: light and dark are separate palettes registered per ThemeData,
    // each picked against its own surface — an automatic lightness flip is what
    // produces a hue that passes contrast in one theme and not the other.
    final semantics = context.zvColors;
    final hues = [
      for (var i = 0; i < coloredSlices; i++) semantics.series(i),
    ];
    final otherColor = semantics.categoricalOther;

    final ranked = [...entries]..sort((a, b) => b.count.compareTo(a.count));
    final shown = ranked.take(coloredSlices).toList();
    final tail = ranked.skip(coloredSlices).fold<int>(0, (s, e) => s + e.count);
    final sum = ranked.fold<int>(0, (s, e) => s + e.count);
    if (sum <= 0) return const SizedBox.shrink();

    final slices = <(String, int, Color)>[
      for (var i = 0; i < shown.length; i++)
        (shown[i].label, shown[i].count, hues[i]),
      if (tail > 0) (otherLabel, tail, otherColor),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: PieChart(
            PieChartData(
              // A donut, not a full pie: the hole gives the eye a shape to
              // compare arcs against, and it is where the total sits.
              centerSpaceRadius: 34,
              // A surface-coloured gap so adjacent fills never read as one.
              sectionsSpace: 2,
              startDegreeOffset: -90,
              sections: [
                for (final (_, count, color) in slices)
                  PieChartSectionData(
                    value: count.toDouble(),
                    color: color,
                    radius: 38,
                    // Only a slice with room gets a number on it; the rest are
                    // named in the legend and counted in the rows below.
                    showTitle: count / sum >= 0.08,
                    title: '${(count / sum * 100).round()}%',
                    titleStyle: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZugvogelSpacing.sm),
        // Identity is never colour alone: every slice is named here, and the
        // exact counts sit in the rows under this chart.
        Wrap(
          spacing: ZugvogelSpacing.md,
          runSpacing: ZugvogelSpacing.xs,
          children: [
            for (final (label, count, color) in slices)
              _LegendEntry(
                color: color,
                label: label,
                percent: (count / sum * 100).round(),
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label $percent%',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: ZugvogelSpacing.xs),
          // Text wears text tokens, never the series colour — the chip beside
          // it carries the identity.
          Text(
            '$label · $percent%',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
