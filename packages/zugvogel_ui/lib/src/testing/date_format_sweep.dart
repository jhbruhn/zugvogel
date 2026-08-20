import 'dart:io';

/// Files that legitimately format a date, excluded from the sweep.
///
/// In Zugvogel that is `date_field.dart` and nothing else. An app adds its own
/// path only if it genuinely owns a second formatter, which it should not.
///
/// This file is on the list because it cannot not be: the pattern it searches
/// for is written out inside it, and a guard that reports itself reports
/// nothing useful.
const defaultDateFormattingAllowlist = <String>[
  'date_field.dart',
  'date_format_sweep.dart',
];

/// Every place under [root] that formats a date without converting it to local
/// time first, as `path:line` (or `path: statement`) strings.
///
/// **Why this is a source sweep and not a test per screen.** A
/// `MaterialLocalizations` formatter renders the fields it is handed and does
/// not convert time zones, so calling one on a PocketBase timestamp shows the
/// UTC calendar day. In CET/CEST that is the *previous* day for anything
/// logged after 22:00 UTC. On a UTC-clocked CI machine the bug is invisible;
/// it reaches real users as an off-by-one date near midnight, one screen at a
/// time, and federfall-yok0 collected nine of them before anyone noticed. A
/// screen written next month would reintroduce it in silence — so the guard
/// has to cover code that does not exist yet.
///
/// Both apps run this over their own `lib/`:
///
/// ```dart
/// test('nothing but the date field formats a date', () {
///   expect(rawDateFormattingOffenders(Directory('lib')), isEmpty);
/// });
/// ```
List<String> rawDateFormattingOffenders(
  Directory root, {
  Iterable<String> allowlist = defaultDateFormattingAllowlist,
}) => [
  ..._materialFormatterOffenders(root, allowlist),
  ..._intlFormatterOffenders(root, allowlist),
];

/// Calls to a `MaterialLocalizations` date/time formatter outside the one file
/// allowed to make them.
List<String> _materialFormatterOffenders(
  Directory root,
  Iterable<String> allowlist,
) {
  final banned = RegExp(
    r'\.format(Medium|Short|Full|Compact)Date\b|\.formatTimeOfDay\b',
  );
  final offenders = <String>[];
  for (final file in sweepableDartFiles(root, allowlist)) {
    final lines = stripComments(file.readAsStringSync()).split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (banned.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
    }
  }
  return offenders;
}

/// `intl` `DateFormat.format(...)` calls on a value that was not made local.
///
/// `.toLocal()` is a no-op on a value that is already local, so adding it is
/// never the wrong call — which is what makes a blanket rule workable here.
List<String> _intlFormatterOffenders(
  Directory root,
  Iterable<String> allowlist,
) {
  final offenders = <String>[];
  for (final file in sweepableDartFiles(root, allowlist)) {
    // Split on `;`, not on newlines: these calls chain across several lines
    // (`DateFormat.yMd(\n  locale,\n).add_Hm().format(x.toLocal())`).
    for (final statement in stripComments(
      file.readAsStringSync(),
    ).split(';')) {
      if (!statement.contains('DateFormat')) continue;
      if (!statement.contains('.format(')) continue;
      // A `DateTime(...)` built right there is local by construction — the
      // month-name lookups in the charts format `DateTime(2000, month)`.
      if (statement.contains('DateTime(')) continue;
      if (statement.contains('toLocal()')) continue;
      offenders.add('${file.path}: ${statement.trim()}');
    }
  }
  return offenders;
}

/// Hand-written Dart under [root], minus generated trees and [allowlist].
Iterable<File> sweepableDartFiles(
  Directory root,
  Iterable<String> allowlist,
) => root
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where(
      (f) =>
          !f.path.endsWith('.g.dart') &&
          !f.path.endsWith('.freezed.dart') &&
          !f.path.contains('/l10n/gen/') &&
          !allowlist.any(f.path.endsWith),
    );

/// Blanks out `//` line and `///` doc comments, so a sweep applies to code and
/// not to the places that legitimately *discuss* the banned spellings.
///
/// Blanked rather than dropped: the offender list reports line numbers, and
/// dropping lines would report them against a file the developer cannot open.
String stripComments(String source) => source
    .split('\n')
    .map((line) => line.trimLeft().startsWith('//') ? '' : line)
    .join('\n');
