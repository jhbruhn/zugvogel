import 'package:zugvogel_data/zugvogel_data.dart';
import 'package:zugvogel_ui/src/injection/strings.dart';

/// Whether this app's backend writes error messages meant for its users.
///
/// **Off by default, and the default is the interesting part.** A PocketBase
/// hook can refuse a write for a reason no access rule could express, and it is
/// then the only party that knows why — so showing what it wrote is often
/// exactly right. But only if the app's hooks were written as *copy*.
///
/// The two consumers differ, which is why this is a per-app switch and not a
/// behaviour:
///
///   * eiermann's hooks speak German prose to volunteers — "Ein Spot wird erst
///     aktiv, wenn die Erkundung bei Zusage steht". Hiding that leaves the user
///     with "could not be saved" and no way forward.
///   * federfall's are English and some are addressed to a developer —
///     "audit_events is append-only." Surfacing those in a German UI would be
///     a regression, and no test would catch it: nothing asserts the wording
///     of a message that is not supposed to appear.
///
/// So an app opts in when its hook messages are ready to be read, and until then
/// it keeps its own localized copy. Set it in the same place as the other
/// bindings.
bool serverMessagesAreUserFacing = false;

/// Maps an arbitrary error into user-facing copy.
///
/// A [RepositoryException] is translated by its [RepositoryErrorKind]; anything
/// else falls back to a generic message. Use it to feed `AsyncValueView` or a
/// snackbar so the UI never shows a raw exception string.
///
/// The *mapping* is shared while the wording is injected, which is the point:
/// it is what stops one app quietly rendering "not reached, try again" over a
/// write whose outcome is genuinely unknown.
String errorMessage(ZugvogelStrings strings, Object error) {
  if (error is RepositoryException) {
    // A message the server wrote for a person wins over anything this
    // function could say — but only where the app has said its hooks write copy
    // (see [serverMessagesAreUserFacing]). The backend enforces invariants an
    // access rule cannot express, and when it refuses one it is the only party
    // that knows why; replacing that with "could not be saved" leaves the user
    // stuck.
    //
    // `serverMessage` is only ever set for a deliberate hook refusal, so
    // PocketBase's own boilerplate cannot arrive here either way. See
    // RepositoryException.serverMessage.
    if (serverMessagesAreUserFacing) {
      final fromServer = error.serverMessage;
      if (fromServer != null) return fromServer;
    }
    return switch (error.kind) {
      RepositoryErrorKind.network => strings.errorOffline,
      RepositoryErrorKind.unauthorized => strings.errorUnauthorized,
      RepositoryErrorKind.notFound => strings.errorNotFound,
      RepositoryErrorKind.validation => strings.errorValidation,
      RepositoryErrorKind.unknownOutcome => strings.errorUnknownOutcome,
      RepositoryErrorKind.unknown => strings.errorGenericTitle,
    };
  }
  return strings.errorGenericTitle;
}

/// Whether [error] means the app could not reach its server.
///
/// Lets a caller defer to the app-wide offline strip instead of restating the
/// connection in its own words — see `AsyncValueView`, which uses it to keep
/// loaded data on screen through a dropped connection.
bool isNetworkError(Object error) =>
    error is RepositoryException && error.kind == RepositoryErrorKind.network;

/// Like [errorMessage], but phrased for a surface that failed to *load*.
///
/// [errorMessage]'s network copy promises "your entry is kept", which only
/// makes sense for a write — a failed read has no entry to keep. The offline
/// strip already accounts for the connection, so this reports the one thing
/// the strip cannot know: that this particular content is missing.
String loadErrorMessage(ZugvogelStrings strings, Object error) =>
    isNetworkError(error)
    ? strings.errorLoadFailed
    : errorMessage(strings, error);
