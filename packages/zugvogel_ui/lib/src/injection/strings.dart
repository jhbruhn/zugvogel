import 'package:flutter/widgets.dart';

/// Every piece of user-facing text the shared widgets need.
///
/// **Injection boundary 1.** No widget in this package imports an l10n class.
/// A widget that knows the word "Abbrechen" by itself is a bug: it welds one
/// product's voice into code two products share. Each app implements this
/// interface over its own ARB files and hands it down through
/// [ZugvogelStringsScope].
///
/// Adding a member here is a deliberate act. It obliges *both* apps to write a
/// translation, so the question to answer first is whether the string belongs
/// to a shared widget at all — a label that only one product would ever show
/// belongs in that product, passed in as a parameter.
///
/// ```dart
/// class FederfallStrings implements ZugvogelStrings {
///   FederfallStrings(this._l10n);
///   final AppLocalizations _l10n;
///
///   @override
///   String get actionCancel => _l10n.actionCancel;
///   // ...
/// }
/// ```
abstract interface class ZugvogelStrings {
  /// BCP-47 name of the active locale, for `intl` number and date formatting.
  ///
  /// Comes from the app's l10n rather than `Platform.localeName`: the app may
  /// only support a subset of locales, and formatting has to follow the
  /// language the user is actually reading.
  String get localeName;

  // ── Actions ───────────────────────────────────────────────────────────────

  String get actionCancel;
  String get actionRetry;
  String get actionSave;

  // ── Discarding an edit ────────────────────────────────────────────────────

  String get discardChangesTitle;
  String get discardChangesMessage;
  String get discardConfirm;
  String get discardKeepEditing;

  // ── State views ───────────────────────────────────────────────────────────

  String get loadingLabel;
  String get emptyGeneric;

  /// Shown while the app cannot reach its server.
  String get offlineNotice;

  // ── Repository errors ─────────────────────────────────────────────────────
  //
  // One per RepositoryErrorKind. These are the only user-facing rendering of a
  // failure, so each app phrases them in its own voice — but the mapping from
  // kind to string is shared, which is what stops one app quietly showing
  // "retry" over a write that may have landed.

  String get errorGenericTitle;
  String get errorOffline;
  String get errorUnauthorized;
  String get errorNotFound;
  String get errorValidation;

  /// A write whose outcome is unknown: the request left the device and the
  /// server may have committed it. Must NOT read as "not reached, try again" —
  /// a blind retry can duplicate data.
  String get errorUnknownOutcome;

  /// A failed *read*. Deliberately separate from [errorOffline], whose copy
  /// promises the user's entry is kept — a failed read has no entry to keep.
  String get errorLoadFailed;

  // ── Field validation ──────────────────────────────────────────────────────

  String get fieldRequired;
  String get fieldInvalidEmail;
  String get fieldInvalidUrl;
  String fieldMinLength(int min);
  String fieldIntMin(int min);

  // ── Photos and images ─────────────────────────────────────────────────────

  String get photoAddAction;
  String get photoCaptureAction;
  String get imageCropTitle;
  String get imageCropFailed;
  String get imagePrevious;
  String get imageNext;
  String get imageShareAction;
  String get imageShareFailed;
}

/// Builds the strings for a context — normally by reading the app's own
/// localizations out of it.
typedef ZugvogelStringsResolver = ZugvogelStrings Function(BuildContext);

/// How the shared widgets find their text when no [ZugvogelStringsScope] is
/// above them. Set once, by the app's bootstrap and by its test harness.
///
/// A scope is the better mechanism and still wins over this. But an app of any
/// size has widget tests that each build their own `MaterialApp`, and no seam
/// reaches all of them: federfall has 69 such files, and none of them is about
/// which words this library shows. Requiring a scope would mean editing every
/// one.
///
/// It takes the [BuildContext] rather than a ready-made [ZugvogelStrings]
/// precisely so it stays locale-reactive: the app's implementation reads its
/// own localizations out of that context on every build, which registers the
/// dependency on `Localizations` that a locale change needs. A cached instance
/// would freeze the language at startup.
///
/// ```dart
/// // in bootstrap(), and in test/flutter_test_config.dart
/// defaultZugvogelStrings = (context) => FederfallStrings(context.l10n);
/// ```
ZugvogelStringsResolver? defaultZugvogelStrings;

/// Hands a [ZugvogelStrings] down to the shared widgets.
///
/// Place it below `Localizations` — inside `MaterialApp.builder` — so the
/// implementation can read the app's own l10n from context and the strings
/// follow a locale change:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   builder: (context, child) => ZugvogelStringsScope(
///     strings: FederfallStrings(AppLocalizations.of(context)),
///     child: child!,
///   ),
/// )
/// ```
class ZugvogelStringsScope extends InheritedWidget {
  const ZugvogelStringsScope({
    required this.strings,
    required super.child,
    super.key,
  });

  final ZugvogelStrings strings;

  /// The strings for this subtree.
  ///
  /// Resolution order: a [ZugvogelStringsScope] above this context, else
  /// [defaultZugvogelStrings]. With neither, it throws — a shared widget
  /// rendering untranslated text is a bug that ships, while a missing binding
  /// is a bug that fails on the first frame of development.
  static ZugvogelStrings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ZugvogelStringsScope>();
    if (scope != null) return scope.strings;

    final resolver = defaultZugvogelStrings;
    if (resolver != null) return resolver(context);

    throw FlutterError(
      'No ZugvogelStrings. Either wrap the subtree in a ZugvogelStringsScope, '
      'or set defaultZugvogelStrings once at startup (and in '
      'test/flutter_test_config.dart). See ZugvogelStrings.',
    );
  }

  @override
  bool updateShouldNotify(ZugvogelStringsScope oldWidget) =>
      strings != oldWidget.strings;
}

/// `context.zv.actionCancel`, the way an app writes `context.l10n`.
extension ZugvogelStringsContext on BuildContext {
  /// The shared widgets' text for this subtree.
  ZugvogelStrings get zv => ZugvogelStringsScope.of(this);
}
