import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:zugvogel_pb_client/src/map_config.dart';

/// Everything this package needs to know about the app using it.
///
/// This is injection boundary 3 made concrete: no widget, provider or helper
/// in Zugvogel reads a compile-time define or an `AppEnvironment`. The app
/// builds one of these from its own defines and overrides
/// [pbClientConfigProvider] with it, and the package reads nothing else.
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     pbClientConfigProvider.overrideWithValue(
///       PbClientConfig(
///         service: 'federfall',
///         fallbackServerName: 'Federfall',
///         mapFallback: MapConfig(...),        // from dart-defines
///         webBaseUrlOverride: AppEnvironment.pocketbaseUrlOverride,
///         allowInsecureHttp: AppEnvironment.flavor == AppFlavor.development,
///       ),
///     ),
///   ],
///   child: const App(),
/// )
/// ```
@immutable
class PbClientConfig {
  const PbClientConfig({
    required this.service,
    required this.fallbackServerName,
    required this.mapFallback,
    this.webBaseUrlOverride,
    this.allowInsecureHttp = false,
    String? storageKeyPrefix,
    String? userAgentName,
    Duration? probeTimeout,
  }) : _storageKeyPrefix = storageKeyPrefix,
       _userAgentName = userAgentName,
       probeTimeout = probeTimeout ?? const Duration(seconds: 8);

  // storageKeyPrefix and userAgentName are nullable parameters backing
  // non-nullable getters that fall back to `service`, so neither can be an
  // initialising formal.
  // ignore_for_file: prefer_initializing_formals

  /// The app's service identifier, lowercase and URL-safe: `federfall`,
  /// `eiermann`.
  ///
  /// Three things derive from it — the `/api/<service>/info` route, the
  /// identity marker that route must return, and the default storage key
  /// prefix — because they have to agree, and one field cannot disagree with
  /// itself.
  final String service;

  /// Instance name shown to the user when `/info` does not send one.
  final String fallbackServerName;

  /// The map source to use when the server prescribes none. Built by the app
  /// from its own dart-defines; see [MapConfig.resolve].
  final MapConfig mapFallback;

  /// Build-time base-URL override, for a dev setup where app and backend run
  /// on different ports. Empty or null means none.
  ///
  /// On web this wins over the serving origin. On native it never
  /// auto-configures anything — that would skip the setup screen — it only
  /// prefills the setup field.
  final String? webBaseUrlOverride;

  /// Whether to accept a plain `http://` server on a non-loopback host.
  ///
  /// False everywhere that matters: `http` sends the bearer token in
  /// cleartext. A development flavor sets it true so it can reach a plain-http
  /// PocketBase on the local network. Loopback is always allowed regardless.
  final bool allowInsecureHttp;

  /// Caps the `/info` probe. A black-holed server must fail fast into the
  /// fallback rather than park the user on a spinner for the OS socket
  /// timeout.
  final Duration probeTimeout;

  final String? _storageKeyPrefix;
  final String? _userAgentName;

  /// Namespace for persisted keys, defaulting to [service].
  ///
  /// Two Zugvogel apps must never share an auth payload: the token belongs to
  /// the origin that issued it, and on web they can be served from the same
  /// host under different paths.
  String get storageKeyPrefix => _storageKeyPrefix ?? service;

  /// Product name in the `User-Agent`, defaulting to [service].
  String get userAgentName => _userAgentName ?? service;

  /// The unauthenticated identity/capability route: `/api/<service>/info`.
  String get infoPath => '/api/$service/info';

  /// Key the auth payload is stored under.
  String get authStorageKey => '$storageKeyPrefix.auth';

  /// Key the native server URL is stored under.
  String get serverUrlStorageKey => '$storageKeyPrefix.serverUrl';

  /// Whether a build-time base-URL override was provided.
  bool get hasWebBaseUrlOverride =>
      webBaseUrlOverride != null && webBaseUrlOverride!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is PbClientConfig &&
      other.service == service &&
      other.fallbackServerName == fallbackServerName &&
      other.mapFallback == mapFallback &&
      other.webBaseUrlOverride == webBaseUrlOverride &&
      other.allowInsecureHttp == allowInsecureHttp &&
      other.storageKeyPrefix == storageKeyPrefix &&
      other.userAgentName == userAgentName &&
      other.probeTimeout == probeTimeout;

  @override
  int get hashCode => Object.hash(
    service,
    fallbackServerName,
    mapFallback,
    webBaseUrlOverride,
    allowInsecureHttp,
    storageKeyPrefix,
    userAgentName,
    probeTimeout,
  );
}

/// The app's [PbClientConfig]. **The app must override this.**
///
/// Deliberately throws rather than defaulting to something plausible: a
/// silently-wrong service name would point every request at the wrong `/info`
/// route and store the auth payload under the wrong key, which is far harder
/// to notice than a startup failure.
final pbClientConfigProvider = Provider<PbClientConfig>(
  (ref) => throw UnimplementedError(
    "pbClientConfigProvider must be overridden in the app's ProviderScope. "
    'See PbClientConfig for what to pass.',
  ),
  name: 'pbClientConfigProvider',
);
