import 'package:zugvogel_data/zugvogel_data.dart';
import 'package:zugvogel_ui/src/injection/strings.dart';

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
    // function could say. The backend enforces invariants an access rule
    // cannot express, and when it refuses one it is the only party that knows
    // why — "a Spot only becomes active once the Erkundung reaches a yes" is
    // not reconstructible from a status code. Replacing it with "could not be
    // saved" leaves the user stuck, which is what it did before.
    //
    // Only ever set for a deliberate hook refusal; PocketBase's own English
    // boilerplate cannot arrive here. See RepositoryException.serverMessage.
    final fromServer = error.serverMessage;
    if (fromServer != null) return fromServer;
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
