import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

import 'support/host.dart';
import 'support/strings.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('a busy button shows a spinner and refuses taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          PrimaryButton(
            label: 'Save',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });

    testWidgets('an icon is dropped while busy', (tester) async {
      await tester.pumpWidget(
        host(
          const PrimaryButton(
            label: 'Save',
            onPressed: null,
            icon: Icons.save,
          ),
        ),
      );
      expect(find.byIcon(Icons.save), findsOneWidget);

      await tester.pumpWidget(
        host(
          const PrimaryButton(
            label: 'Save',
            onPressed: null,
            icon: Icons.save,
            isLoading: true,
          ),
        ),
      );
      expect(find.byIcon(Icons.save), findsNothing);
    });
  });

  group('DestructiveActionButton (federfall-qo8f)', () {
    testWidgets('is filled, not a bare TextButton beside Cancel', (
      tester,
    ) async {
      // Two identical text buttons whose only difference is red text make the
      // error colour load-bearing — WCAG 2.1 SC 1.4.1 — and give the squint
      // test two equally prominent options on a dialog whose whole purpose is
      // to make the user stop. Shape and weight carry it; colour is redundant.
      await tester.pumpWidget(
        host(DestructiveActionButton(label: 'Delete', onPressed: () {})),
      );
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('uses the scheme error role, never a literal red', (
      tester,
    ) async {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF356859));
      await tester.pumpWidget(
        host(
          DestructiveActionButton(label: 'Delete', onPressed: () {}),
          theme: ThemeData(colorScheme: scheme),
        ),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final states = <WidgetState>{};
      expect(
        button.style?.backgroundColor?.resolve(states),
        scheme.error,
      );
      expect(button.style?.foregroundColor?.resolve(states), scheme.onError);
    });

    testWidgets('demoted drops to an outline so the safe route out-ranks it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DestructiveActionButton(
            label: 'Delete',
            demoted: true,
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('buildMenuItems', () {
    MenuAction action(String label, {bool destructive = false}) => MenuAction(
      icon: Icons.edit,
      label: label,
      onTap: () {},
      destructive: destructive,
    );

    test('a divider separates the destructive tail from the safe entries', () {
      // The colour is never the only thing marking the dangerous row
      // (WCAG 2.1 SC 1.4.1) — the same rule DestructiveActionButton applies in
      // dialogs.
      final items = buildMenuItems([
        action('Edit'),
        action('Share'),
        action('Delete', destructive: true),
      ]);
      expect(items.whereType<PopupMenuDivider>(), hasLength(1));
      expect(items.indexWhere((i) => i is PopupMenuDivider), 2);
    });

    test('a lone destructive entry gets no divider', () {
      // A rule above a single row reads as a missing item.
      final items = buildMenuItems([action('Delete', destructive: true)]);
      expect(items.whereType<PopupMenuDivider>(), isEmpty);
      expect(items, hasLength(1));
    });

    test('two destructive entries share one divider', () {
      final items = buildMenuItems([
        action('Edit'),
        action('Delete', destructive: true),
        action('Purge', destructive: true),
      ]);
      expect(items.whereType<PopupMenuDivider>(), hasLength(1));
    });

    test('an all-safe menu gets none', () {
      final items = buildMenuItems([action('Edit'), action('Share')]);
      expect(items.whereType<PopupMenuDivider>(), isEmpty);
    });
  });

  group('Validators', () {
    const s = TestStrings();

    test('required rejects empty and whitespace', () {
      final v = Validators.required(s);
      expect(v(null), 'fieldRequired');
      expect(v(''), 'fieldRequired');
      expect(v('   '), 'fieldRequired');
      expect(v('x'), isNull);
    });

    test('url accepts http(s) with a host, and passes empty through', () {
      final v = Validators.url(s);
      expect(v(''), isNull, reason: 'compose with required for mandatory');
      expect(v('https://a.example'), isNull);
      expect(v('http://a.example:8090/pb'), isNull);
      expect(v('a.example'), 'fieldInvalidUrl');
      expect(v('ftp://a.example'), 'fieldInvalidUrl');
      expect(v('https://'), 'fieldInvalidUrl');
    });

    test('email is a plausibility check, not RFC 5322', () {
      final v = Validators.email(s);
      expect(v(''), isNull);
      expect(v('a@b.de'), isNull);
      expect(v('a@b'), 'fieldInvalidEmail');
      expect(v('a b@c.de'), 'fieldInvalidEmail');
      expect(v('@b.de'), 'fieldInvalidEmail');
    });

    test('minLength does NOT trim — a password may end in a space', () {
      final v = Validators.minLength(s, 4);
      expect(v(''), isNull);
      expect(v('abc'), 'fieldMinLength(4)');
      expect(v('abc '), isNull);
    });

    test('intMin rejects non-integers and anything below the floor', () {
      final v = Validators.intMin(s, 1);
      expect(v(''), isNull);
      expect(v('0'), 'fieldIntMin(1)');
      expect(v('1'), isNull);
      expect(v('1.5'), 'fieldIntMin(1)');
      expect(v('x'), 'fieldIntMin(1)');
    });

    test('compose returns the FIRST failure', () {
      final v = Validators.compose([
        Validators.required(s),
        Validators.email(s),
      ]);
      expect(v(''), 'fieldRequired');
      expect(v('nope'), 'fieldInvalidEmail');
      expect(v('a@b.de'), isNull);
    });
  });

  group('number formatting', () {
    const de = TestStrings(localeName: 'de');
    const en = TestStrings();

    test('follows the locale the user is reading', () {
      // A dot in a German UI beside a keyboard that produces commas is how a
      // decimal point gets misread.
      expect(formatNumber(de, 5.24), '5,24');
      expect(formatNumber(en, 5.24), '5.24');
    });

    test('no grouping separator — the parser could not read it back', () {
      expect(formatNumber(de, 1234.5), '1234,5');
      expect(formatNumber(en, 1234.5), '1234.5');
    });

    test('trailing zeros are dropped', () {
      expect(formatNumber(de, 248), '248');
    });

    test('an amount always shows two fraction digits', () {
      // "12 €" and "12,00 €" are the same amount, but a donation figure read
      // against a bank statement should look like one.
      //
      // Compared with the space normalised: intl puts a NON-BREAKING space
      // (U+00A0) between the number and the symbol in German, which is
      // correct — and invisible in a failure message, so it is worth naming
      // rather than being surprised by.
      String plain(String s) => s.replaceAll('\u00a0', ' ');
      expect(plain(formatAmountCents(de, 1200, symbol: '€')), '12,00 €');
      expect(plain(formatAmountCents(de, 1250, symbol: '€')), '12,50 €');
      expect(formatAmountCents(de, 1200, symbol: '€'), contains('\u00a0'));
      // English puts the symbol in front, and intl knows that too.
      expect(plain(formatAmountCents(en, 1250, symbol: '€')), '€12.50');
    });

    test('the currency symbol is injected, never assumed', () {
      expect(formatAmountCents(de, 1250, symbol: 'CHF'), contains('CHF'));
    });

    test('parseAmountToCents accepts the German comma', () {
      expect(parseAmountToCents('12,50'), 1250);
      expect(parseAmountToCents('12.50'), 1250);
      expect(parseAmountToCents(' 12 '), 1200);
    });

    test('a negative amount is null, not clamped — -5 is a typo', () {
      expect(parseAmountToCents('-5'), isNull);
      expect(parseAmountToCents('abc'), isNull);
      expect(parseAmountToCents(''), isNull);
    });

    test('cents are rounded, so no caller accumulates float error', () {
      expect(parseAmountToCents('0,005'), 1);
      expect(parseAmountToCents('19,999'), 2000);
    });
  });

  group('AppTextField', () {
    testWidgets('validates on interaction and shows the message', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AppTextField(
            label: 'Email',
            validator: Validators.email(const TestStrings()),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'nope');
      await tester.pump();
      expect(find.text('fieldInvalidEmail'), findsOneWidget);
    });

    testWidgets('a multiline field aligns its label with the hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AppTextField(label: 'Notes', maxLines: 4)),
      );
      // Keeps the resting label at the top of a prose field instead of
      // vertically centred.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.alignLabelWithHint, isTrue);
      expect(field.maxLines, 4);
    });
  });

  group('TagChip and IconChip', () {
    testWidgets('a tag chip defaults to the secondary container role', (
      tester,
    ) async {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF356859));
      await tester.pumpWidget(
        host(
          const TagChip(label: 'confirmed'),
          theme: ThemeData(colorScheme: scheme),
        ),
      );
      final box = tester.widget<Container>(find.byType(Container).first);
      expect(
        (box.decoration! as BoxDecoration).color,
        scheme.secondaryContainer,
      );
    });

    testWidgets('a tag chip takes an injected semantic colour', (tester) async {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF356859));
      final semantics = ZugvogelSemantics.fromScheme(scheme);
      await tester.pumpWidget(
        host(
          TagChip(label: 'overdue', color: semantics.critical),
          theme: ThemeData(colorScheme: scheme),
        ),
      );
      final box = tester.widget<Container>(find.byType(Container).first);
      expect((box.decoration! as BoxDecoration).color, semantics.critical);
    });

    testWidgets('an icon chip renders the icon it is given', (tester) async {
      await tester.pumpWidget(host(const IconChip(Icons.egg_outlined)));
      expect(find.byIcon(Icons.egg_outlined), findsOneWidget);
    });
  });

  group('DetailHeader', () {
    testWidgets('omits an empty subtitle and a null chip', (tester) async {
      await tester.pumpWidget(host(const DetailHeader(title: 'Lotte')));
      expect(find.text('Lotte'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);

      await tester.pumpWidget(
        host(const DetailHeader(title: 'Lotte', subtitle: '')),
      );
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('a tappable title carries its tooltip', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          DetailHeader(
            title: 'Lotte',
            onTitleTap: () => taps++,
            titleTapTooltip: 'open record',
          ),
        ),
      );
      expect(find.byType(Tooltip), findsOneWidget);
      await tester.tap(find.text('Lotte'));
      expect(taps, 1);
    });

    testWidgets('chipAlert switches the chip to the error container', (
      tester,
    ) async {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF356859));
      await tester.pumpWidget(
        host(
          const DetailHeader(
            title: 'Aviary 3',
            chipLabel: 'over capacity',
            chipAlert: true,
          ),
          theme: ThemeData(colorScheme: scheme),
        ),
      );
      expect(
        tester.widget<Chip>(find.byType(Chip)).backgroundColor,
        scheme.errorContainer,
      );
    });
  });
}
