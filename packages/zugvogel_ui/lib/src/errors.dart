import 'package:zugvogel_data/zugvogel_data.dart';
import 'package:zugvogel_ui/src/injection/strings.dart';

/// Implemented by an app whose backend refuses writes with error CODES.
///
///
/// The shared package cannot hold the sentences: a code like
/// `spot_phase_needs_permitted` belongs to one product's domain and its wording
/// belongs in that product's ARB files. So the mapping is the app's, and this
/// is the seam — an optional companion to [ZugvogelStrings] that the app's own
/// implementation can also implement.
///
/// This exists instead of letting the server send prose. A hook does not know
/// which language the reader speaks, so a German message baked into a hook is
/// untranslatable by construction; it sends a code and the client owns the
/// sentence. An app whose hooks send no codes simply does not implement this,
/// and keeps its generic copy.
// The lint below suggests a typedef for a one-member abstract class. That is
// the wrong shape here: the point is that an app's EXISTING strings object
// carries the lookup, so `errorMessage` finds it without every call site
// passing a resolver. A function type cannot be implemented by the class that
// already holds the ARB.
// ignore: one_member_abstracts
abstract interface class ServerCodeStrings {
  /// The sentence for [code], or null when this app does not know it.
  ///
  /// Returning null is normal and must stay cheap: `data` keys also carry
  /// PocketBase's own field names, and those are not codes.
  String? serverErrorFor(String code);
}

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
    // A hook refusal the app has words for beats anything this function could
    // say. The backend enforces invariants an access rule cannot express, and
    // when it refuses one it is the only party that knows WHICH — but the
    // sentence is the client's, because the server does not know the reader's
    // language.
    //
    // First recognised code wins. Unknown ones are skipped rather than
    // reported: `data` keys also carry PocketBase's own field names, which are
    // not codes, and a per-field error is better summarised by the app's
    // generic copy while the form marks the fields.
    // A pattern, not an `is` check: promoting a parameter of an unrelated
    // interface type does not reach through, so the member would not resolve.
    if (strings case final ServerCodeStrings coded) {
      for (final code in error.serverCodes) {
        final text = coded.serverErrorFor(code);
        if (text != null) return text;
      }
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
