/// Test-only helpers for the apps that consume Zugvogel.
///
/// Imported from an app's `test/`, never from its `lib/` — it reaches for
/// `dart:io` and would not compile for web.
///
/// The guards here exist because their defects are invisible in review and on
/// a CI machine, and only surface for real users: a date rendered a day early
/// near midnight, a font that only fails on the deployed web build. A guard
/// that covers code nobody has written yet is the only kind that holds.
library;

export 'src/testing/date_format_sweep.dart';
