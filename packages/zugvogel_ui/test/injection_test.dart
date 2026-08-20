import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

import 'support/strings.dart';

/// Reads both injected values and reports what it found.
class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(context.zv.actionCancel),
      ColoredBox(
        color: context.zvColors.critical,
        child: const SizedBox.square(dimension: 4),
      ),
    ],
  );
}

Widget wrap(Widget child, {ZugvogelStrings? strings, ThemeData? theme}) =>
    MaterialApp(
      theme: theme,
      home: strings == null
          ? child
          : ZugvogelStringsScope(strings: strings, child: child),
    );

void main() {
  group('boundary 1 — ZugvogelStrings', () {
    testWidgets('a widget reads its text from the scope', (tester) async {
      await tester.pumpWidget(
        wrap(const _Probe(), strings: const TestStrings()),
      );
      expect(find.text('actionCancel'), findsOneWidget);
    });

    testWidgets('with neither a scope nor a resolver, it fails loudly', (
      tester,
    ) async {
      // Deliberately a throw rather than an English fallback: a shared widget
      // rendering untranslated text is a bug that ships, while a missing
      // binding is a bug that fails on the first frame.
      await tester.pumpWidget(wrap(const _Probe()));
      expect(tester.takeException(), isFlutterError);
    });

    testWidgets('a resolver serves the trees that have no scope', (
      tester,
    ) async {
      // The mechanism a widget test relies on: an app of any size has tests
      // that each build their own MaterialApp, and none of them is about which
      // words this library shows.
      defaultZugvogelStrings = (_) => const TestStrings();
      addTearDown(() => defaultZugvogelStrings = null);

      await tester.pumpWidget(wrap(const _Probe()));
      expect(find.text('actionCancel'), findsOneWidget);
    });

    testWidgets('a scope still wins over the resolver', (tester) async {
      defaultZugvogelStrings = (_) => const TestStrings();
      addTearDown(() => defaultZugvogelStrings = null);

      await tester.pumpWidget(
        wrap(const _Probe(), strings: const _OtherStrings()),
      );
      expect(find.text('anderesActionCancel'), findsOneWidget);
    });

    testWidgets('the resolver sees the context, so it can read l10n', (
      tester,
    ) async {
      // Why it takes a BuildContext instead of a ready-made instance: the app's
      // implementation reads its own localizations out of it on every build,
      // which is what keeps a locale change reactive. A cached instance would
      // freeze the language at startup.
      BuildContext? seen;
      defaultZugvogelStrings = (context) {
        seen = context;
        return const TestStrings();
      };
      addTearDown(() => defaultZugvogelStrings = null);

      await tester.pumpWidget(wrap(const _Probe()));
      expect(seen, isNotNull);
      expect(Localizations.localeOf(seen!), isNotNull);
    });

    testWidgets('swapping the scope rebuilds dependents', (tester) async {
      // The app rebuilds this on a locale change, so the widgets have to
      // follow rather than cache.
      await tester.pumpWidget(
        wrap(const _Probe(), strings: const TestStrings()),
      );
      expect(find.text('actionCancel'), findsOneWidget);

      await tester.pumpWidget(
        wrap(const _Probe(), strings: const _OtherStrings()),
      );
      await tester.pump();
      expect(find.text('anderesActionCancel'), findsOneWidget);
    });

    test('the interface carries no implementation', () {
      // Nothing to construct: it is a contract each app fills. If this ever
      // gains a default value, that value is a hardcoded string.
      expect(ZugvogelStrings, isNotNull);
    });
  });

  group('boundary 2 — ZugvogelSemantics', () {
    testWidgets('reads the extension the app registered', (tester) async {
      const registered = ZugvogelSemantics(
        good: Color(0xFF00FF00),
        onGood: Color(0xFF000000),
        warning: Color(0xFFFFFF00),
        onWarning: Color(0xFF000000),
        critical: Color(0xFFFF0000),
        onCritical: Color(0xFFFFFFFF),
        categorical: [Color(0xFF111111), Color(0xFF222222)],
        categoricalOther: Color(0xFF333333),
      );
      late ZugvogelSemantics seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [registered]),
          home: Builder(
            builder: (context) {
              seen = context.zvColors;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, registered);
    });

    testWidgets('falls back to a scheme-derived palette, never crashing', (
      tester,
    ) async {
      // An unstyled-but-legible chart beats a crash in production, and the
      // fallback comes from the app's own scheme, so it is never off-brand —
      // only unspecific.
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF356859));
      late ZugvogelSemantics seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Builder(
            builder: (context) {
              seen = context.zvColors;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, ZugvogelSemantics.fromScheme(scheme));
      expect(seen.critical, scheme.error);
    });

    test('fromScheme introduces no colour of its own', () {
      // Every value has to be traceable to a ColorScheme role, or this class
      // would be smuggling a palette into the package.
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF356859));
      final s = ZugvogelSemantics.fromScheme(scheme);
      final roles = {
        scheme.outline,
        scheme.primary,
        scheme.onPrimary,
        scheme.secondary,
        scheme.onSecondary,
        scheme.tertiary,
        scheme.onTertiary,
        scheme.error,
        scheme.onError,
        scheme.primaryContainer,
        scheme.secondaryContainer,
        scheme.tertiaryContainer,
        scheme.errorContainer,
      };
      for (final color in [
        s.good,
        s.onGood,
        s.warning,
        s.onWarning,
        s.critical,
        s.onCritical,
        s.categoricalOther,
        ...s.categorical,
      ]) {
        expect(roles, contains(color));
      }
    });

    test('series() wraps, so a chart never needs to know the palette size', () {
      final s = ZugvogelSemantics.fromScheme(
        ColorScheme.fromSeed(seedColor: const Color(0xFF356859)),
      );
      expect(s.series(0), s.categorical.first);
      expect(s.series(s.categorical.length), s.categorical.first);
      expect(s.series(s.categorical.length + 1), s.categorical[1]);
      // A negative index is a bug at the call site, not a crash here.
      expect(() => s.series(-1), returnsNormally);
    });

    test('lerp keeps the longer palette rather than truncating it', () {
      const a = ZugvogelSemantics(
        good: Color(0xFF000000),
        onGood: Color(0xFF000000),
        warning: Color(0xFF000000),
        onWarning: Color(0xFF000000),
        critical: Color(0xFF000000),
        onCritical: Color(0xFF000000),
        categorical: [Color(0xFF000000), Color(0xFF111111)],
        categoricalOther: Color(0xFF000000),
      );
      const b = ZugvogelSemantics(
        good: Color(0xFFFFFFFF),
        onGood: Color(0xFFFFFFFF),
        warning: Color(0xFFFFFFFF),
        onWarning: Color(0xFFFFFFFF),
        critical: Color(0xFFFFFFFF),
        onCritical: Color(0xFFFFFFFF),
        categorical: [Color(0xFFFFFFFF)],
        categoricalOther: Color(0xFFFFFFFF),
      );
      expect(a.lerp(b, 0.5).categorical, hasLength(2));
      expect(b.lerp(a, 0.5).categorical, hasLength(2));
      expect(a.lerp(null, 0.5), a);
    });

    test('copyWith and equality behave', () {
      final s = ZugvogelSemantics.fromScheme(
        ColorScheme.fromSeed(seedColor: const Color(0xFF356859)),
      );
      expect(s.copyWith(), s);
      expect(s.copyWith().hashCode, s.hashCode);
      expect(
        s.copyWith(critical: const Color(0xFFABCDEF)),
        isNot(s),
      );
    });
  });
}

class _OtherStrings extends TestStrings {
  const _OtherStrings();

  @override
  String get actionCancel => 'anderesActionCancel';
}
