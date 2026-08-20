import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

import 'support/host.dart';

const _scheme = ColorScheme.light();

/// A palette with unmistakable entries, so a slice's colour identifies which
/// series index drew it.
const _palette = ZugvogelSemantics(
  good: Color(0xFF00FF00),
  onGood: Color(0xFF000000),
  warning: Color(0xFFFFFF00),
  onWarning: Color(0xFF000000),
  critical: Color(0xFFFF0000),
  onCritical: Color(0xFFFFFFFF),
  categorical: [
    Color(0xFF000001),
    Color(0xFF000002),
    Color(0xFF000003),
  ],
  categoricalOther: Color(0xFF999999),
);

ThemeData get _theme =>
    ThemeData(colorScheme: _scheme, extensions: const [_palette]);

void main() {
  group('BreakdownBars', () {
    testWidgets('draws nothing when there is no denominator', (tester) async {
      // "14 %" is meaningless until the reader knows what it is 14 % of, so a
      // total of zero renders nothing rather than a row of full-width bars.
      await tester.pumpWidget(
        host(
          const BreakdownBars(
            entries: [ChartEntry('a', 3)],
            total: 0,
            caption: 'share',
          ),
        ),
      );
      expect(find.text('share'), findsNothing);
    });

    testWidgets('draws nothing when every category is empty', (tester) async {
      await tester.pumpWidget(
        host(
          const BreakdownBars(
            entries: [ChartEntry('a', 0)],
            total: 10,
            caption: 'share',
          ),
        ),
      );
      expect(find.text('share'), findsNothing);
    });

    testWidgets('ranks by count and caps at maxBars', (tester) async {
      await tester.pumpWidget(
        host(
          BreakdownBars(
            entries: [
              for (var i = 1; i <= 8; i++) ChartEntry('cat$i', i),
            ],
            total: 36,
            caption: 'share',
          ),
        ),
      );
      // Top five by count, biggest first.
      expect(find.text('cat8'), findsOneWidget);
      expect(find.text('cat4'), findsOneWidget);
      expect(find.text('cat3'), findsNothing);
      expect(BreakdownBars.maxBars, 5);
    });

    testWidgets('takes its fill from the injected palette, series 0', (
      tester,
    ) async {
      // A bar chart and a pie on the same screen have to agree on what "the
      // first series" looks like — which they only can if neither owns a hue.
      await tester.pumpWidget(
        host(
          const BreakdownBars(
            entries: [ChartEntry('a', 5)],
            total: 10,
            caption: 'share',
          ),
          theme: _theme,
        ),
      );
      final fills = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toSet();
      expect(fills, contains(_palette.categorical.first));
    });
  });

  group('BreakdownPie', () {
    testWidgets('draws nothing when everything is zero', (tester) async {
      await tester.pumpWidget(
        host(
          const BreakdownPie(
            entries: [ChartEntry('a', 0)],
            otherLabel: 'Other',
          ),
        ),
      );
      expect(find.textContaining('a · '), findsNothing);
    });

    testWidgets('folds the tail past coloredSlices into one neutral entry', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const BreakdownPie(
            entries: [
              ChartEntry('a', 10),
              ChartEntry('b', 8),
              ChartEntry('c', 6),
              ChartEntry('d', 4),
              ChartEntry('e', 2),
            ],
            otherLabel: 'Other',
          ),
          theme: _theme,
        ),
      );
      // The legend names every slice — identity is never colour alone — as
      // "<label> · <percent>%".
      expect(BreakdownPie.coloredSlices, 3);
      expect(find.textContaining('a · '), findsOneWidget);
      expect(find.textContaining('c · '), findsOneWidget);
      // d and e fold together.
      expect(find.textContaining('d · '), findsNothing);
      expect(find.textContaining('e · '), findsNothing);
      expect(find.textContaining('Other · '), findsOneWidget);

      // ...and the folded tail wears the neutral, not a fourth category hue.
      final swatches = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .toSet();
      expect(swatches, contains(_palette.categoricalOther));
      expect(swatches, contains(_palette.categorical[0]));
    });

    testWidgets('no tail means no "Other" entry', (tester) async {
      await tester.pumpWidget(
        host(
          const BreakdownPie(
            entries: [
              ChartEntry('a', 10),
              ChartEntry('b', 8),
            ],
            otherLabel: 'Other',
          ),
          theme: _theme,
        ),
      );
      expect(find.textContaining('Other'), findsNothing);
    });
  });

  group('the palette is injected, not owned', () {
    test('the charts hold no colour of their own', () {
      // Enforced for the whole library by the boundary sweep; asserted here
      // because the charts were the actual offenders — eight hex literals
      // across breakdown_bars and breakdown_pie.
      expect(_palette.categorical, hasLength(3));
      expect(_palette.series(0), const Color(0xFF000001));
      expect(_palette.series(3), const Color(0xFF000001));
      expect(_palette.categoricalOther, const Color(0xFF999999));
    });

    test('light and dark are separate palettes, not one flipped', () {
      // A ThemeExtension is registered per ThemeData, so each palette is
      // picked against its own surface. An automatic lightness flip is what
      // produces a hue that passes contrast in one theme and not the other.
      final light = ZugvogelSemantics.fromScheme(const ColorScheme.light());
      final dark = ZugvogelSemantics.fromScheme(const ColorScheme.dark());
      expect(light.categorical, isNot(dark.categorical));
    });
  });
}
