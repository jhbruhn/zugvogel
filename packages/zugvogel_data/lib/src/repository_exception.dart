import 'package:pocketbase/pocketbase.dart';

/// A domain-level failure raised by the repository layer.
///
/// PocketBase surfaces transport/validation problems as [ClientException];
/// repositories translate those into this type so callers (and the UI error
/// states) depend on a stable shape rather than the SDK's. The original is kept
/// in [cause] for logging.
class RepositoryException implements Exception {
  const RepositoryException(
    this.message, {
    this.kind = RepositoryErrorKind.unknown,
    this.statusCode,
    this.cause,
    this.serverMessage,
  });

  /// Builds a [RepositoryException] from a PocketBase [ClientException],
  /// classifying it by HTTP status / connectivity.
  factory RepositoryException.fromClient(ClientException e) {
    final status = e.statusCode;
    final kind = switch (status) {
      0 => RepositoryErrorKind.network,
      401 || 403 => RepositoryErrorKind.unauthorized,
      404 => RepositoryErrorKind.notFound,
      400 || 422 => RepositoryErrorKind.validation,
      _ => RepositoryErrorKind.unknown,
    };
    return RepositoryException(
      _messageFor(kind, e),
      kind: kind,
      statusCode: status,
      cause: e,
      serverMessage: _deliberateServerMessage(kind, e),
    );
  }

  /// Human-oriented (non-localized) summary; the UI maps [kind] to localized
  /// copy where it matters.
  final String message;

  /// Coarse classification used for branching and UI mapping.
  final RepositoryErrorKind kind;

  /// Originating HTTP status code, when known.
  final int? statusCode;

  /// The underlying error, preserved for logging.
  final Object? cause;

  /// A message the SERVER wrote to be read by a person, when it sent one.
  ///
  /// Null unless the response has the shape of a deliberate refusal from a hook
  /// — see [_deliberateServerMessage]. A backend can enforce invariants an
  /// access rule cannot express, and when it refuses one it is the only party
  /// that knows why: "a Spot only becomes active once the Erkundung reaches a
  /// yes" is not a sentence any client can reconstruct from a status code.
  /// Dropping it leaves the user with "could not be saved" and no way forward,
  /// which is what happened before this field existed.
  final String? serverMessage;

  /// Whether this looks like a connectivity failure (no server reached).
  bool get isNetwork => kind == RepositoryErrorKind.network;

  /// The server's own message, but only when the response shape says a HOOK
  /// deliberately wrote it.
  ///
  /// PocketBase produces three different 4xx shapes and only one of them
  /// carries prose meant for a person:
  ///
  /// - **field validation** — 400, `data` holds per-field errors, `message` is
  ///   boilerplate ("Failed to create record.").
  /// - **a hook's refusal** — 400, `data` is EMPTY, `message` is what the hook
  ///   wrote.
  /// - **an access rule** — 404, `data` empty, `message` is "The requested
  ///   resource wasn't found."
  ///
  /// So: a validation status with an EMPTY `data` map is a hook talking. A
  /// populated `data` is per-field validation, where the form shows the fields
  /// and the app's own summary belongs at the top. And an access-rule refusal
  /// arrives as 404 — PocketBase hides existence deliberately — so it never
  /// reaches this branch and its English copy cannot leak into the UI.
  ///
  /// Restricting this to the validation kinds is the whole safety argument. A
  /// blanket "show the server's message" would surface PocketBase's own English
  /// boilerplate for every 401, 404 and 500, which is worse than the localized
  /// copy it would replace.
  static String? _deliberateServerMessage(
    RepositoryErrorKind kind,
    ClientException e,
  ) {
    if (kind != RepositoryErrorKind.validation) return null;
    final response = e.response;
    final data = response['data'];
    // A non-empty `data` means per-field errors: not a hook's prose.
    if (data is Map && data.isNotEmpty) return null;
    final message = response['message'];
    if (message is! String || message.trim().isEmpty) return null;
    return message.trim();
  }

  static String _messageFor(RepositoryErrorKind kind, ClientException e) {
    return switch (kind) {
      RepositoryErrorKind.network => 'Could not reach the server',
      RepositoryErrorKind.unauthorized => 'Not authorized',
      RepositoryErrorKind.notFound => 'Not found',
      RepositoryErrorKind.validation => 'Invalid request',
      // Never produced by fromClient (a ClientException means the server
      // answered); listed for exhaustiveness.
      RepositoryErrorKind.unknownOutcome =>
        'The request outcome could not be determined',
      RepositoryErrorKind.unknown => e.toString(),
    };
  }

  @override
  String toString() =>
      'RepositoryException($kind, status: $statusCode): $message';
}

/// Coarse categories of repository failure.
enum RepositoryErrorKind {
  /// No response from the server (offline, DNS, timeout).
  network,

  /// Authentication/authorization rejected the request (401/403).
  unauthorized,

  /// The requested record does not exist (404).
  notFound,

  /// The server rejected the payload (400/422).
  validation,

  /// A write timed out client-side after the request left the device — the
  /// server may still have committed it, so blindly retrying can duplicate
  /// the change. This is why it is a kind of its own and not `network`: the
  /// UI must not say "not reached, try again" over a write that may have
  /// landed. See `newIdempotencyKey` for the safe way to retry one.
  unknownOutcome,

  /// Anything else.
  unknown,
}
