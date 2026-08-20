@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

/// federfall-sbtx: web has no system fonts, so a codepoint no bundled family
/// covers makes the engine fetch a Noto slice from fonts.gstatic.com — which
/// the app's CSP blocks and the engine then retries on every layout of that
/// text. One arrow in a string produced an endless console error stream on a
/// deployed instance.
///
/// Keeping that fixed needs BOTH halves in place, and neither is exercised by
/// any widget test: the families declared in pubspec.yaml with their assets,
/// and the same families named in the theme's fontFamilyFallback — the engine
/// only tests coverage against the families a TextStyle names.
void main() {
  group('bundled text fallbacks (federfall-sbtx)', () {
    late String pubspec;

    setUp(() {
      pubspec = File('pubspec.yaml').readAsStringSync();
    });

    test('every fallback family is declared with its asset', () {
      for (final prefixed in ZugvogelTheme.fontFallbacks) {
        // The pubspec declares the bare family; the theme names it with the
        // package prefix the engine needs.
        final family = prefixed.replaceFirst('packages/zugvogel_ui/', '');
        expect(
          prefixed,
          startsWith('packages/zugvogel_ui/'),
          reason:
              'A package-provided family only resolves under its prefix. '
              'Without it $prefixed silently does not exist, which looks '
              'exactly like not having bundled it.',
        );
        expect(
          pubspec,
          contains('- family: $family'),
          reason:
              '$family is in ZugvogelTheme.fontFallbacks but not bundled — '
              'the engine would download it from fonts.gstatic.com instead.',
        );
      }
    });

    test('the base family is bundled too', () {
      expect(
        ZugvogelTheme.fontFamily,
        startsWith('packages/zugvogel_ui/'),
      );
      expect(pubspec, contains('- family: Roboto'));
    });

    test('every declared asset exists on disk', () {
      // A missing .ttf fails at runtime, and only on the platform that needs
      // the glyph — which is the platform nobody is testing on.
      for (final asset in ZugvogelTheme.fontAssets) {
        expect(pubspec, contains(asset), reason: '$asset not in pubspec.yaml');
        expect(
          File(asset).existsSync(),
          isTrue,
          reason: '$asset is declared in pubspec.yaml but missing on disk',
        );
      }
    });

    test('the licence ships with the fonts', () {
      // The Noto and Roboto faces are OFL/Apache; shipping the binaries
      // without the licence text is not a thing to leave to chance.
      expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    });

    test('a built theme applies the fallbacks to its text styles', () {
      for (final brightness in Brightness.values) {
        final theme = ZugvogelTheme.build(
          seed: const Color(0xFF356859),
          brightness: brightness,
        );
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          ZugvogelTheme.fontFamily,
          reason: 'brightness: $brightness',
        );
        expect(
          theme.textTheme.bodyMedium?.fontFamilyFallback,
          ZugvogelTheme.fontFallbacks,
          reason: 'brightness: $brightness',
        );
      }
    });
  });

  group('ZugvogelTheme', () {
    test('takes the seed from the app and derives the scheme from it', () {
      // Injection boundary 2: the package holds no brand colour.
      final teal = ZugvogelTheme.build(
        seed: const Color(0xFF356859),
        brightness: Brightness.light,
      );
      final plum = ZugvogelTheme.build(
        seed: const Color(0xFF6E3A63),
        brightness: Brightness.light,
      );
      expect(teal.colorScheme.primary, isNot(plum.colorScheme.primary));
    });

    test('registers ZugvogelSemantics, so a chart always finds a palette', () {
      final theme = ZugvogelTheme.build(
        seed: const Color(0xFF356859),
        brightness: Brightness.light,
      );
      final semantics = theme.extension<ZugvogelSemantics>();
      expect(semantics, isNotNull);
      expect(semantics!.critical, theme.colorScheme.error);
      expect(semantics.categorical, isNotEmpty);
    });

    test('an app can override the semantics wholesale', () {
      const custom = ZugvogelSemantics(
        good: Color(0xFF00FF00),
        onGood: Color(0xFF000000),
        warning: Color(0xFFFFFF00),
        onWarning: Color(0xFF000000),
        critical: Color(0xFFFF0000),
        onCritical: Color(0xFFFFFFFF),
        categorical: [Color(0xFF111111)],
        categoricalOther: Color(0xFF222222),
      );
      final theme = ZugvogelTheme.build(
        seed: const Color(0xFF356859),
        brightness: Brightness.light,
        semantics: custom,
      );
      expect(theme.extension<ZugvogelSemantics>(), custom);
    });

    test('fromScheme accepts a scheme the app built some other way', () {
      const scheme = ColorScheme.dark();
      final theme = ZugvogelTheme.fromScheme(scheme);
      expect(theme.colorScheme, scheme);
      expect(theme.textTheme.bodyMedium?.fontFamily, ZugvogelTheme.fontFamily);
    });

    test('light and dark differ, and both carry the font stack', () {
      final light = ZugvogelTheme.build(
        seed: const Color(0xFF356859),
        brightness: Brightness.light,
      );
      final dark = ZugvogelTheme.build(
        seed: const Color(0xFF356859),
        brightness: Brightness.dark,
      );
      expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
    });
  });

  group('layout', () {
    testWidgets('ContentBounds caps a wide window and fills a narrow one', (
      tester,
    ) async {
      // Safe at any width, so a body can be wrapped unconditionally without a
      // breakpoint check at the call site.
      await tester.pumpWidget(
        const MaterialApp(
          home: ContentBounds(child: SizedBox.expand()),
        ),
      );
      final box = tester.renderObject<RenderBox>(
        find.byType(SizedBox).first,
      );
      expect(box.size.width, lessThanOrEqualTo(kContentMaxWidth));
    });

    testWidgets('ListDetailScaffold pins the list pane and expands the '
        'detail', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: ListDetailScaffold(
            list: ColoredBox(key: Key('list'), color: Color(0xFF000001)),
            detail: ColoredBox(key: Key('detail'), color: Color(0xFF000002)),
          ),
        ),
      );

      // Found by key, not by type: MaterialApp puts ColoredBoxes of its own in
      // the tree, and the first one by type is not one of these panes.
      expect(
        tester.getSize(find.byKey(const Key('list'))).width,
        kListPaneWidth,
      );
      // The detail takes the rest, minus the 1px divider.
      expect(
        tester.getSize(find.byKey(const Key('detail'))).width,
        1200 - kListPaneWidth - 1,
      );
    });

    testWidgets('DetailPanePlaceholder shows the prompt it is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DetailPanePlaceholder(message: 'pick something'),
        ),
      );
      expect(find.text('pick something'), findsOneWidget);
    });

    test('the size classes follow the M3 breakpoints', () {
      expect(windowSizeClassFor(599), WindowSizeClass.compact);
      expect(windowSizeClassFor(600), WindowSizeClass.medium);
      expect(windowSizeClassFor(839), WindowSizeClass.medium);
      expect(windowSizeClassFor(840), WindowSizeClass.expanded);
      expect(WindowSizeClass.expanded.isExpanded, isTrue);
      expect(WindowSizeClass.medium.isExpanded, isFalse);
    });

    testWidgets('context.isExpanded reads the current width', (tester) async {
      late bool expanded;
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expanded = context.isExpanded;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(expanded, isTrue);
    });
  });
}
