import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:zugvogel_pb_client/src/config.dart';
import 'package:zugvogel_pb_client/src/server_info.dart';
import 'package:zugvogel_pb_client/src/user_agent_client.dart';

/// Normalises a user-entered server address into a canonical base URL, or
/// returns `null` when the input cannot be a valid http(s) URL.
///
/// Rules: trim; assume `https://` when no scheme is given (so `pigeons.example`
/// and `192.168.1.5:8090` work); accept only http/https; require a host; drop
/// any query/fragment and trailing slashes while preserving an explicit port
/// and sub-path (some self-hosters run PocketBase under a path).
String? normalizeServerUrl(String input) {
  var raw = input.trim();
  if (raw.isEmpty) return null;
  if (!raw.contains('://')) raw = 'https://$raw';

  final uri = Uri.tryParse(raw);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return null;
  }

  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}

/// Outcome of probing a candidate server address.
@immutable
sealed class ServerProbeResult {
  const ServerProbeResult();

  /// A verified backend at [baseUrl] (already normalised), with the
  /// capabilities it reported.
  const factory ServerProbeResult.reachable(String baseUrl, ServerInfo info) =
      ProbeReachable;

  /// The input is not a syntactically valid http(s) URL.
  const factory ServerProbeResult.invalidUrl() = ProbeInvalidUrl;

  /// An explicit `http://` scheme was given for a non-loopback host, which
  /// would send the bearer token in cleartext. Rejected before probing.
  const factory ServerProbeResult.insecureHttp() = ProbeInsecureHttp;

  /// The address could not be reached (DNS/connection failure or timeout).
  const factory ServerProbeResult.unreachable() = ProbeUnreachable;

  /// Something answered, but it is not this app's backend: no identity marker
  /// for the configured service — a generic PocketBase, an unrelated host
  /// returning a 200, or the *other* Zugvogel app's server.
  const factory ServerProbeResult.wrongService() = ProbeWrongService;
}

final class ProbeReachable extends ServerProbeResult {
  const ProbeReachable(this.baseUrl, this.info);

  final String baseUrl;

  /// The server's reported identity + capabilities.
  final ServerInfo info;

  @override
  bool operator ==(Object other) =>
      other is ProbeReachable && other.baseUrl == baseUrl && other.info == info;

  @override
  int get hashCode => Object.hash(baseUrl, info);
}

final class ProbeInvalidUrl extends ServerProbeResult {
  const ProbeInvalidUrl();
}

final class ProbeInsecureHttp extends ServerProbeResult {
  const ProbeInsecureHttp();
}

final class ProbeUnreachable extends ServerProbeResult {
  const ProbeUnreachable();
}

final class ProbeWrongService extends ServerProbeResult {
  const ProbeWrongService();
}

/// Fetches a server's `/info` and returns the decoded JSON body. Behind a
/// typedef so tests can supply a fake without real networking.
typedef ServerInfoProber = Future<Object?> Function(String baseUrl);

/// Validates a candidate server address before it is persisted
/// (federfall-7nf.1): normalise → fetch `/info` → require the service identity
/// marker → classify the outcome. A generic PocketBase has no such route (404)
/// and is rejected as the wrong service.
class ServerProbe {
  const ServerProbe({required this.config, this.prober});

  /// The app's config: which `/info` route to call, which marker to require,
  /// and whether plain http is tolerated.
  final PbClientConfig config;

  /// Test seam: supply a fake to probe without real networking. Null in the
  /// app, where [_probeInfo] builds a live PocketBase call.
  final ServerInfoProber? prober;

  Future<Object?> _probeInfo(String baseUrl) async {
    final fake = prober;
    if (fake != null) return fake(baseUrl);
    final ua = await loadUserAgent(config.userAgentName);
    return PocketBase(
      baseUrl,
      httpClientFactory: () => UserAgentClient(ua),
    ).send(config.infoPath).timeout(config.probeTimeout);
  }

  Future<ServerProbeResult> probe(String input) async {
    final normalized = normalizeServerUrl(input);
    if (normalized == null) return const ServerProbeResult.invalidUrl();

    // http:// sends the bearer token in cleartext. The OS already blocks it in
    // release builds (no usesCleartextTraffic/ATS exception), which just
    // surfaces as an opaque connection failure — reject it here instead with a
    // clear reason. Loopback stays allowed as the local-dev escape hatch; a
    // development flavor additionally sets allowInsecureHttp so it can reach a
    // plain-http PocketBase on the local network (its Android manifest carries
    // the matching usesCleartextTraffic, so both layers agree).
    final uri = Uri.parse(normalized);
    final host = uri.host.toLowerCase();
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (uri.scheme == 'http' && !isLoopback && !config.allowInsecureHttp) {
      return const ServerProbeResult.insecureHttp();
    }

    try {
      final info = ServerInfo.tryParse(
        await _probeInfo(normalized),
        service: config.service,
        fallbackName: config.fallbackServerName,
      );
      // Something answered, but without the marker it is not this backend (a
      // bare PocketBase, a reverse proxy, an unrelated 200, the other app).
      return info == null
          ? const ServerProbeResult.wrongService()
          : ServerProbeResult.reachable(normalized, info);
    } on ClientException catch (e) {
      // statusCode 0 == no HTTP response at all (connection refused, DNS,
      // abort); any real status (e.g. a 404 for the missing route on a generic
      // PocketBase) means it answered but is not this service.
      return e.statusCode == 0
          ? const ServerProbeResult.unreachable()
          : const ServerProbeResult.wrongService();
    } on TimeoutException {
      return const ServerProbeResult.unreachable();
    }
  }
}

final Provider<ServerProbe> serverProbeProvider = Provider.autoDispose(
  (ref) => ServerProbe(config: ref.watch(pbClientConfigProvider)),
  name: 'serverProbeProvider',
);
