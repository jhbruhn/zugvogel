import 'package:intl/intl.dart';
import 'package:zugvogel_ui/src/injection/strings.dart';

/// Formats [value] in the active locale — `5,24` in German, `5.24` in English.
///
/// Every user-facing number goes through here so a measurement never shows a
/// dot in a German UI while the keyboard next to it produces commas: mixing
/// the two separators in a number somebody acts on is exactly how a decimal
/// point gets misread.
///
/// Grouping separators are deliberately off. These numbers are round-tripped
/// through number fields whose parser only knows to turn a comma into a dot,
/// so a grouped `1.234,5` would come back as nonsense.
/// Trailing zeros are dropped, so a whole number reads `248`, not `248.0`.
String formatNumber(
  ZugvogelStrings strings,
  double value, {
  int maxFractionDigits = 6,
}) {
  final format = NumberFormat.decimalPattern(strings.localeName)
    ..turnOffGrouping()
    ..maximumFractionDigits = maxFractionDigits;
  return format.format(value);
}

/// Formats integer [cents] as an amount in the active locale — `12,50 €` in
/// German, `€12.50` in English (intl supplies the symbol's position).
///
/// Money is stored and passed around as integer cents precisely so no
/// arithmetic ever touches a binary float; this is the only place it becomes a
/// string, and [parseAmountToCents] is the only place a string becomes cents
/// again.
///
/// [symbol] is required rather than defaulted: a currency is configuration, and
/// a shared package that assumes one is a shared package that is wrong for
/// somebody.
///
/// Always two fraction digits, unlike [formatNumber]: "12 €" and "12,00 €" are
/// the same amount, but a donation figure read against a bank statement should
/// look like a donation figure.
String formatAmountCents(
  ZugvogelStrings strings,
  int cents, {
  required String symbol,
}) {
  final format = NumberFormat.currency(
    locale: strings.localeName,
    symbol: symbol,
    decimalDigits: 2,
  );
  return format.format(cents / 100);
}

/// Integer cents from what somebody typed, or null if it is not a number.
///
/// Accepts a decimal comma the same way every other numeric field does
/// (`double.tryParse` after swapping in a dot) — the German keyboard produces
/// one, and a field that rejects it is a field nobody can fill in. The double
/// lives only inside this function: it is rounded to cents before it leaves, so
/// no caller can accumulate float error.
///
/// A negative amount answers null rather than clamping to zero — the field
/// refuses it, because `-5` is a typo and storing 0 would hide it.
int? parseAmountToCents(String text) {
  final euros = double.tryParse(text.trim().replaceAll(',', '.'));
  if (euros == null || euros.isNaN || euros.isInfinite || euros < 0) {
    return null;
  }
  return (euros * 100).round();
}
