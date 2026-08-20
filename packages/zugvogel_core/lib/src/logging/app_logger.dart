import 'dart:developer' as developer;

/// Severity levels; values mirror `dart:developer` log levels so they show up
/// sensibly in DevTools and IDE logs.
enum LogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  const LogLevel(this.value);

  /// Numeric level passed to `dart:developer`.
  final int value;
}

/// Field names whose values are redacted before a payload reaches a log sink.
///
/// These are the person-shaped columns every Zugvogel app has: whoever handed
/// the animal over, whoever is looking after it, how to reach them. An app
/// with more of them passes its own list to [AppLogger.piiKeys] — the default
/// is a floor, not a ceiling.
const defaultPiiLogKeys = <String>[
  'first_name',
  'last_name',
  'organisation',
  'phone',
  'alt_phone',
  'email',
  'notes',
];

/// Redacts secrets/PII from a string before it reaches a log sink.
///
/// `ClientException.toString()` (surfaced via `RepositoryException.cause`)
/// includes the full request URL — which can carry a short-lived PocketBase
/// protected-file token (`?token=...`) — and the raw JSON error response,
/// which can echo back PII the user submitted (finder name/phone/email) in
/// validation error bodies. This runs on every message/error that passes
/// through [AppLogger], including the ones that today only reach local
/// logcat/DevTools.
///
/// DO NOT wire a crash-reporting SDK (Sentry etc.) into [AppLogger] without
/// routing through this first — that would ship tokens/PII off-device
/// (OWASP A09, sensitive data exposure).
String scrubLogPayload(
  String text, {
  Iterable<String> piiKeys = defaultPiiLogKeys,
}) {
  var out = text;
  // ?token=... / &token=... query params.
  out = out.replaceAllMapped(
    RegExp('([?&]token=)[^&\\s"\']+'),
    (m) => '${m[1]}***',
  );
  // Authorization: Bearer ... headers.
  out = out.replaceAllMapped(
    RegExp('(Bearer\\s+)[^\\s"\']+', caseSensitive: false),
    (m) => '${m[1]}***',
  );
  // PII field values as echoed in request/response bodies (both JSON
  // `"key":"value"` and Dart Map.toString() `key: value` shapes).
  for (final key in piiKeys) {
    out = out.replaceAllMapped(
      RegExp('("?$key"?\\s*:\\s*)("[^"]*"|[^,}]+)'),
      (m) => '${m[1]}***',
    );
  }
  return out;
}

/// A logging facade.
///
/// Thin wrapper over `dart:developer` so call sites stay simple and a single
/// [minLevel] gate keeps production logs quiet. Error reporting (Sentry etc.)
/// can later hook in here without touching call sites — read the warning on
/// [scrubLogPayload] first.
///
/// [channel] and [minLevel] are injected. This package holds no configuration
/// and reads no compile-time define, so it cannot know an app's name or
/// whether this build is a release one; the app decides both and hands them
/// over (injection boundary 3).
class AppLogger {
  const AppLogger({
    this.channel = 'app',
    this.minLevel = LogLevel.debug,
    this.piiKeys = defaultPiiLogKeys,
  });

  /// Name logs appear under when a call site does not override it.
  final String channel;

  /// Messages below this level are dropped.
  final LogLevel minLevel;

  /// Field names redacted from every message and error. See [scrubLogPayload].
  final Iterable<String> piiKeys;

  void debug(String message, {String? name}) =>
      _log(LogLevel.debug, message, name: name);

  void info(String message, {String? name}) =>
      _log(LogLevel.info, message, name: name);

  void warning(String message, {Object? error, String? name}) =>
      _log(LogLevel.warning, message, error: error, name: name);

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? name,
  }) => _log(
    LogLevel.error,
    message,
    error: error,
    stackTrace: stackTrace,
    name: name,
  );

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? name,
  }) {
    if (level.value < minLevel.value) return;
    developer.log(
      scrubLogPayload(message, piiKeys: piiKeys),
      level: level.value,
      name: name ?? channel,
      error: error == null
          ? null
          : scrubLogPayload(error.toString(), piiKeys: piiKeys),
      stackTrace: stackTrace,
    );
  }
}

/// The logger the app's bootstrap configured, for call sites without a `Ref`
/// (e.g. [reportCaughtError]).
///
/// An app sets this once, to the same instance its provider graph exposes, so
/// a crash-reporting hook wired in there also sees errors reported outside the
/// graph. Defaults to a plain logger for tests and tools that never bootstrap.
AppLogger rootLogger = const AppLogger();

/// Reports an error swallowed by a broad `on Object` handler.
///
/// Such handlers deliberately show the user only a generic message; this keeps
/// the underlying error observable for debugging and crash reporting by
/// routing it through [rootLogger] — the same funnel an app's bootstrap wires
/// the global error handlers into. Logging (rather than
/// `FlutterError.reportError`) is used on purpose: widget tests treat reported
/// framework errors as failures, but a swallowed error is expected behaviour.
void reportCaughtError(
  Object error,
  StackTrace stackTrace, {
  String? context,
}) => rootLogger.error(
  context ?? 'Unexpected error (shown to the user as a generic message)',
  error: error,
  stackTrace: stackTrace,
);
