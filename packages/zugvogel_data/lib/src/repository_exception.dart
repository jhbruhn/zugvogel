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
    this.serverCodes = const <String>[],
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
      serverCodes: _serverCodes(kind, e),
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

  /// Machine-readable codes a hook attached to a deliberate refusal.
  ///
  /// A backend enforces invariants an access rule cannot express, and when it
  /// refuses one it is the only party that knows which. But it must NOT say so
  /// in words: it does not know which language the reader speaks, so prose from
  /// a hook is untranslatable by construction. It sends codes; the client owns
  /// the sentence.
  ///
  /// Empty for everything that is not a hook refusal — see [_serverCodes].
  final List<String> serverCodes;

  /// Whether this looks like a connectivity failure (no server reached).
  bool get isNetwork => kind == RepositoryErrorKind.network;

  /// The refusal codes in a response, or empty when there are none.
  ///
  /// **How a code even gets here.** PocketBase rewrites the VALUES in an
  /// `ApiError`'s `data`: every leaf becomes
  /// `{code: "validation_invalid_value", message: "Invalid value."}` at any
  /// depth, and an already correctly-shaped `{code, message}` is re-coerced and
  /// nested one level deeper. It also rewrites `message` itself — a hook
  /// throwing "plain" produces "Plain.", capitalised and full-stopped. The one
  /// thing that survives verbatim is the KEY, so a hook writes its code there:
  ///
  /// ```js
  /// throw new ApiError(400, "spot phase requires prospect_stage=permitted", {
  ///   spot_phase_needs_permitted: 1,
  /// });
  /// ```
  ///
  /// Measured against PocketBase 0.39.8, not assumed.
  ///
  /// **Why field names cannot be confused with codes.** PocketBase's own
  /// field validation fills `data` with the offending FIELD names, which are
  /// keys too. Nothing tells them apart structurally — a caller resolves the
  /// codes it knows and ignores the rest, so an unrecognised field name finds
  /// no translation and falls through to the app's generic copy. Which is the
  /// right outcome for a per-field error anyway: the form marks the fields.
  ///
  /// Restricted to the validation kinds: an access-rule refusal is a 404 (
  /// PocketBase hides existence deliberately) and carries no codes.
  static List<String> _serverCodes(
    RepositoryErrorKind kind,
    ClientException e,
  ) {
    if (kind != RepositoryErrorKind.validation) return const <String>[];
    final data = e.response['data'];
    if (data is! Map) return const <String>[];
    return data.keys.map((k) => k.toString()).toList(growable: false);
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
