/// Shared Flutter widgets for the Zugvogel apps.
///
/// The three injection boundaries apply hardest here (see CLAUDE.md, and the
/// sweep in `test/injection_boundaries_test.dart` that enforces them):
///
/// 1. No widget imports an l10n class. Text arrives through an injected
///    `ZugvogelStrings`; a widget that knows the word "Abbrechen" is a bug.
/// 2. No widget names a colour. Widgets read `Theme.of(context).colorScheme`
///    plus `ZugvogelSemantics` for good/warning/critical and the categorical
///    chart palette.
/// 3. No widget reads configuration. Whatever it needs is passed in.
///
/// Together these are what keep a wide shared UI package from welding two
/// product designs together.
library;

export 'src/injection/semantics.dart';
export 'src/injection/strings.dart';
export 'src/widgets/date_field.dart';
