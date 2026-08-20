@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zugvogel_ui/testing.dart';
import 'package:zugvogel_ui/zugvogel_ui.dart';

void main() {
  // Resolve the real MaterialLocalizations for a known locale so the formatted
  // strings are deterministic.
  late MaterialLocalizations m;

  setUp(() async {
    m = await GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  });

  group('formatLocalDate', () {
    test('returns empty string for null', () {
      expect(formatLocalDate(m, null), '');
    });

    test('converts a UTC timestamp to local time before formatting', () {
      // PocketBase stores UTC; the displayed date must be the local one.
      final utc = DateTime.utc(2026, 3, 4, 9, 30);
      final local = utc.toLocal();

      expect(formatLocalDate(m, utc), m.formatMediumDate(local));
      expect(
        formatLocalDate(m, utc, withTime: true),
        '${m.formatMediumDate(local)}, '
        '${m.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
      );
    });

    test('leaves an already-local value alone', () {
      // `toLocal()` is idempotent, which is what lets form state and picker
      // results share one formatter with the server's UTC timestamps.
      final local = DateTime(2026, 3, 4, 9, 30);
      expect(formatLocalDate(m, local), m.formatMediumDate(local));
    });

    test('the short style is numeric and carries the year', () {
      final utc = DateTime.utc(2026, 6, 2, 9, 30);
      expect(
        formatLocalDate(m, utc, style: DateStyle.short),
        m.formatShortDate(utc.toLocal()),
      );
      // The distinction anything spanning seasons depends on: medium has no
      // year.
      expect(m.formatShortDate(utc.toLocal()), contains('2026'));
      expect(m.formatMediumDate(utc.toLocal()), isNot(contains('2026')));
    });

    test('the compact style is all-numeric, for a chart axis', () async {
      final utc = DateTime.utc(2026, 6, 2, 9, 30);
      expect(
        formatLocalDate(m, utc, style: DateStyle.compact),
        m.formatCompactDate(utc.toLocal()),
      );
      // Why it exists: German spells the month out in the short form, which is
      // twice the width a chart axis has for a label (federfall-yapf).
      final de = await GlobalMaterialLocalizations.delegate.load(
        const Locale('de'),
      );
      expect(de.formatShortDate(utc.toLocal()), contains('Juni'));
      expect(de.formatCompactDate(utc.toLocal()), isNot(contains('Juni')));
    });
  });

  group('DateField', () {
    Widget host(Widget child) => MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

    testWidgets('shows the placeholder when there is no value', (tester) async {
      await tester.pumpWidget(
        host(
          DateField(
            label: 'Admitted',
            value: null,
            placeholder: 'not set',
            onPick: () {},
          ),
        ),
      );
      expect(find.text('not set'), findsOneWidget);
    });

    testWidgets('renders a UTC value as the LOCAL date', (tester) async {
      final utc = DateTime.utc(2026, 3, 4, 9, 30);
      await tester.pumpWidget(
        host(DateField(label: 'Admitted', value: utc, onPick: () {})),
      );
      expect(find.text(m.formatMediumDate(utc.toLocal())), findsOneWidget);
    });

    testWidgets('showTime appends the time of day', (tester) async {
      final utc = DateTime.utc(2026, 3, 4, 9, 30);
      await tester.pumpWidget(
        host(
          DateField(
            label: 'Admitted',
            value: utc,
            showTime: true,
            onPick: () {},
          ),
        ),
      );
      expect(
        find.textContaining(
          m.formatTimeOfDay(TimeOfDay.fromDateTime(utc.toLocal())),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping picks, unless disabled', (tester) async {
      var picks = 0;
      await tester.pumpWidget(
        host(
          DateField(label: 'Admitted', value: null, onPick: () => picks++),
        ),
      );
      await tester.tap(find.byType(InkWell));
      expect(picks, 1);

      await tester.pumpWidget(
        host(
          DateField(
            label: 'Admitted',
            value: null,
            enabled: false,
            onPick: () => picks++,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      expect(picks, 1);
    });

    testWidgets('the clear action appears only when there is something to '
        'clear', (tester) async {
      var cleared = 0;
      await tester.pumpWidget(
        host(
          DateField(
            label: 'Admitted',
            value: null,
            onPick: () {},
            onClear: () => cleared++,
          ),
        ),
      );
      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.pumpWidget(
        host(
          DateField(
            label: 'Admitted',
            value: DateTime.utc(2026, 3, 4),
            onPick: () {},
            onClear: () => cleared++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.clear));
      expect(cleared, 1);

      // ...and not while disabled, even with a value and a handler.
      await tester.pumpWidget(
        host(
          DateField(
            label: 'Admitted',
            value: DateTime.utc(2026, 3, 4),
            enabled: false,
            onPick: () {},
            onClear: () => cleared++,
          ),
        ),
      );
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('the icon distinguishes a date from a date+time', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(DateField(label: 'x', value: null, onPick: () {})),
      );
      expect(find.byIcon(Icons.event_outlined), findsOneWidget);

      await tester.pumpWidget(
        host(
          DateField(label: 'x', value: null, showTime: true, onPick: () {}),
        ),
      );
      expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
    });
  });

  group('the sweep that keeps it that way (federfall-yok0)', () {
    test('nothing in the library formats a date directly', () {
      // The guard runs over Zugvogel's own packages here. Each app runs the
      // same function over its own lib/ — that is the point of exporting it
      // from package:zugvogel_ui/testing.dart rather than keeping it in this
      // file.
      final packages =
          Directory(
            '${_workspaceRoot()}/packages',
          ).listSync().whereType<Directory>().map(
            (d) => Directory('${d.path}/lib'),
          );

      final offenders = <String>[];
      for (final lib in packages) {
        if (!lib.existsSync()) continue;
        offenders.addAll(rawDateFormattingOffenders(lib));
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'A MaterialLocalizations formatter renders the fields it is handed '
            'and does NOT convert time zones, so calling one on a PocketBase '
            'timestamp shows the UTC calendar day — the previous day, in '
            'CET/CEST, for anything logged after 22:00 UTC. Use '
            'formatLocalDate:\n${offenders.join('\n')}',
      );
    });

    test('the sweep bites', () {
      // A guard that cannot fail is decoration. This proves the two patterns
      // it looks for are actually caught, without leaving a canary file
      // behind in the tree.
      final tmp = Directory.systemTemp.createTempSync('zv_sweep');
      addTearDown(() => tmp.deleteSync(recursive: true));

      File('${tmp.path}/screen.dart').writeAsStringSync('''
Widget build(BuildContext context) {
  final l10n = MaterialLocalizations.of(context);
  return Text(l10n.formatMediumDate(record.createdAt));
}
''');
      File('${tmp.path}/chart.dart').writeAsStringSync('''
final label = DateFormat.yMd(locale).format(record.createdAt);
''');
      File('${tmp.path}/ok.dart').writeAsStringSync('''
final label = DateFormat.yMd(locale).format(record.createdAt.toLocal());
// l10n.formatMediumDate(x) in a comment is not a call.
final month = DateFormat.MMM(locale).format(DateTime(2000, m));
''');

      final offenders = rawDateFormattingOffenders(tmp);
      expect(offenders, hasLength(2));
      expect(offenders.join('\n'), contains('screen.dart'));
      expect(offenders.join('\n'), contains('chart.dart'));
      expect(offenders.join('\n'), isNot(contains('ok.dart')));
    });

    test('the allowlist is honoured', () {
      final tmp = Directory.systemTemp.createTempSync('zv_sweep_allow');
      addTearDown(() => tmp.deleteSync(recursive: true));
      File('${tmp.path}/date_field.dart').writeAsStringSync('''
final s = materialL10n.formatMediumDate(local);
''');
      expect(rawDateFormattingOffenders(tmp), isEmpty);
      expect(
        rawDateFormattingOffenders(tmp, allowlist: const []),
        hasLength(1),
      );
    });
  });
}

/// Walks up to the workspace root, so the sweep does not depend on cwd.
String _workspaceRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('zugvogel_workspace')) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('Could not find the zugvogel workspace root');
    }
    dir = parent;
  }
}
