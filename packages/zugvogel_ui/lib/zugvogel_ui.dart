/// Shared Flutter widgets for the Zugvogel apps.
///
/// The three injection boundaries apply hardest here (see CLAUDE.md):
///
/// 1. No widget imports an l10n class. Text arrives through an injected
///    `ZugvogelStrings`; a widget that knows the word "Abbrechen" is a bug.
/// 2. No widget names a colour. Widgets read `Theme.of(context).colorScheme`
///    plus the `ZugvogelSemantics` theme extension for good/warning/critical.
/// 3. No widget reads configuration. Whatever it needs is passed in.
///
/// Together these are what keep a wide shared UI package from welding two
/// product designs together.
library;

// Exports land here as eiermann-d2a.8 through eiermann-d2a.13 move the widgets
// across.
